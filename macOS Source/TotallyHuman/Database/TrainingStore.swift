// TrainingStore.swift — Robuster, menschenlesbarer Trainingsdaten-Speicher
// Totally Human — KI-Musik-Detektor (native macOS, kein Python)
//
// Warum eine JSON-Datei statt SQLite?
//   Die frühere SQLite-Anbindung konnte auf manchen Systemen still fehlschlagen
//   (Sandbox / Application-Support-Rechte). Dann wurde beim Import zwar hochgezählt,
//   aber nichts persistiert ("148 importiert, aber 0 in der DB"). Eine einfache,
//   atomar geschriebene JSON-Datei ist robust, transparent und für den Nutzer
//   direkt einsehbar. Bei Schreibfehlern greift ein In-Memory-Fallback, damit die
//   App im laufenden Betrieb niemals in den heuristischen Modus zurückfällt.
//
// Speicherort (lokal, bleibt zwischen Starts erhalten -> Modell lernt dauerhaft dazu):
//   ~/Library/Application Support/Totally Human/trainingsdaten.json

import Foundation
import AppKit

/// Ermittelt EINMALIG einen tatsächlich beschreibbaren Basis-Speicherort und legt
/// ihn sofort an. Dadurch existiert der Ordner ab dem ersten Start — auch wenn das
/// bevorzugte „Application Support"-Verzeichnis (z. B. wegen Rechten/Sandbox) nicht
/// beschreibbar ist. Modell UND Trainingsdaten teilen sich diese Basis, damit beim
/// „Ordner öffnen" wirklich der genutzte Ordner erscheint.
enum AppSpeicherort {

    /// Der final genutzte Basis-Ordner (garantiert beschreibbar oder Temp als Notnagel).
    static let basis: URL = ermittleBasis()

    /// Fehlermeldung, falls der bevorzugte Ort nicht beschreibbar war.
    private(set) static var fehler: String?

    private static func ermittleBasis() -> URL {
        let fm = FileManager.default
        var kandidaten: [URL] = []

        if let appSup = try? fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true) {
            kandidaten.append(appSup.appendingPathComponent("Totally Human", isDirectory: true))
        }
        let home = fm.homeDirectoryForCurrentUser
        kandidaten.append(home.appendingPathComponent("Library/Application Support/Totally Human", isDirectory: true))
        kandidaten.append(home.appendingPathComponent("Documents/Totally Human", isDirectory: true))
        kandidaten.append(fm.temporaryDirectory.appendingPathComponent("Totally Human", isDirectory: true))

        for kandidat in kandidaten {
            if istBeschreibbar(kandidat) {
                fehler = nil
                NSLog("[TotallyHuman] Speicherort: \(kandidat.path)")
                return kandidat
            }
        }
        // Absoluter Notnagel — sollte nie erreicht werden.
        let notnagel = fm.temporaryDirectory.appendingPathComponent("Totally Human", isDirectory: true)
        try? fm.createDirectory(at: notnagel, withIntermediateDirectories: true)
        return notnagel
    }

    /// Legt den Ordner an und prüft mit einer echten Schreibprobe, ob er nutzbar ist.
    private static func istBeschreibbar(_ dir: URL) -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let probe = dir.appendingPathComponent(".schreibtest")
            try Data("ok".utf8).write(to: probe, options: .atomic)
            try? fm.removeItem(at: probe)
            return true
        } catch {
            fehler = error.localizedDescription
            NSLog("[TotallyHuman] Speicherort nicht beschreibbar (\(dir.path)): \(error)")
            return false
        }
    }
}

final class TrainingStore {

    /// Alle bekannten Trainingsproben (Quelle der Wahrheit im Speicher).
    private(set) var proben: [TrainingsProbe] = []

    /// Wird true, sobald das Laden/Speichern auf die Platte funktioniert hat.
    private(set) var persistenzAktiv: Bool = false

    /// Letzte Fehlermeldung (für die Statusanzeige), falls vorhanden.
    var letzterFehler: String? { eigenerFehler ?? AppSpeicherort.fehler }
    private var eigenerFehler: String?

    // MARK: - Pfad

    /// Vollständiger Pfad der Trainingsdaten-Datei.
    let dateiURL: URL

    /// Der genutzte Basis-Ordner (für „Ordner öffnen").
    var basisOrdner: URL { AppSpeicherort.basis }

    /// Für die UI: menschenlesbarer Pfad des Trainingsdaten-Speichers.
    var pfad: String { dateiURL.path }

    init() {
        // Basis ist bereits angelegt & beschreibbar geprüft -> Ordner existiert ab Start.
        self.dateiURL = AppSpeicherort.basis
            .appendingPathComponent("trainingsdaten.json")
        laden()
    }

    // MARK: - Laden / Speichern

    /// Lädt die Trainingsdaten von der Platte (falls vorhanden).
    func laden() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dateiURL.path) else {
            // Datei existiert noch nicht — ist beim ersten Start normal.
            // Der Ordner wurde bereits in AppSpeicherort angelegt & getestet.
            persistenzAktiv = (AppSpeicherort.fehler == nil)
            return
        }
        do {
            let data = try Data(contentsOf: dateiURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            proben = try decoder.decode([TrainingsProbe].self, from: data)
            persistenzAktiv = true
            eigenerFehler = nil
            NSLog("[TotallyHuman] Trainingsdaten geladen: \(proben.count) Beispiele aus \(dateiURL.path)")
        } catch {
            eigenerFehler = error.localizedDescription
            NSLog("[TotallyHuman] Trainingsdaten laden fehlgeschlagen: \(error)")
        }
    }

    /// Schreibt die Trainingsdaten atomar auf die Platte.
    @discardableResult
    func speichern() -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: dateiURL.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(proben)
            try data.write(to: dateiURL, options: .atomic)
            persistenzAktiv = true
            eigenerFehler = nil
            return true
        } catch {
            // In-Memory-Fallback: Daten bleiben im Arbeitsspeicher erhalten,
            // damit die App weiterläuft; nur die Persistenz ist beeinträchtigt.
            persistenzAktiv = false
            eigenerFehler = error.localizedDescription
            NSLog("[TotallyHuman] Trainingsdaten speichern fehlgeschlagen: \(error)")
            return false
        }
    }

    // MARK: - Mutationen

    /// Fügt eine Probe hinzu. Dedupliziert anhand der Datei-Signatur.
    /// Gibt true zurück, wenn tatsächlich NEU eingefügt wurde.
    @discardableResult
    func hinzufuegen(_ probe: TrainingsProbe) -> Bool {
        if !probe.dateiSignatur.isEmpty,
           proben.contains(where: { $0.dateiSignatur == probe.dateiSignatur }) {
            return false   // Duplikat
        }
        proben.append(probe)
        speichern()
        return true
    }

    /// Fügt mehrere Proben hinzu. Gibt die Anzahl der wirklich neu eingefügten zurück.
    @discardableResult
    func hinzufuegen(_ neue: [TrainingsProbe]) -> Int {
        var eingefuegt = 0
        for p in neue {
            if !p.dateiSignatur.isEmpty,
               proben.contains(where: { $0.dateiSignatur == p.dateiSignatur }) {
                continue
            }
            proben.append(p)
            eingefuegt += 1
        }
        if eingefuegt > 0 { speichern() }
        return eingefuegt
    }

    /// Löscht alle Trainingsdaten.
    func leeren() {
        proben.removeAll()
        speichern()
    }
}
