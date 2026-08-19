import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Zentraler, beobachtbarer Zustand der App. Alle Views greifen auf diese Instanz zu.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Navigation
    enum SidebarSelection: Hashable {
        case analyse, batch, training, visualisierung, einstellungen
    }
    @Published var sidebarSelection: SidebarSelection = .analyse

    // MARK: - Allgemeiner Status
    @Published var statusText: String = "Bereit"
    @Published var istBeschaeftigt: Bool = false
    @Published var trainingsmodusAktiv: Bool = false

    // MARK: - Einstellungen (werden automatisch lokal gespeichert)
    // Jede Änderung wird sofort in UserDefaults geschrieben (didSet) und beim
    // Programmstart wieder geladen (ladeEinstellungen()). Es ist KEIN „Speichern"-
    // oder „Übernehmen"-Button nötig — Änderungen sind sofort dauerhaft.
    @Published var qualityThreshold: Double = 70 {
        didSet { UserDefaults.standard.set(qualityThreshold, forKey: Keys.qualityThreshold) }
    }
    @Published var isOrangeThemeEnabled: Bool = true {
        didSet { UserDefaults.standard.set(isOrangeThemeEnabled, forKey: Keys.orangeTheme) }
    }
    @Published var isPreviewEnabled: Bool = true {
        didSet { UserDefaults.standard.set(isPreviewEnabled, forKey: Keys.preview) }
    }
    @Published var selectedLanguage: String = "de" {
        didSet {
            UserDefaults.standard.set(selectedLanguage, forKey: Keys.language)
            Loc.aktuelleSprache = selectedLanguage
        }
    }
    @Published var segmentLengthSeconds: Double = 10 {
        didSet { UserDefaults.standard.set(segmentLengthSeconds, forKey: Keys.segmentLength) }
    }
    @Published var requireBatchConfirmation: Bool = false {
        didSet { UserDefaults.standard.set(requireBatchConfirmation, forKey: Keys.batchConfirm) }
    }
    @Published var showDetailedHints: Bool = true {
        didSet { UserDefaults.standard.set(showDetailedHints, forKey: Keys.detailedHints) }
    }

    /// Schlüssel für die UserDefaults-Persistenz der Einstellungen.
    private enum Keys {
        static let qualityThreshold = "TotallyHuman.setting.qualityThreshold"
        static let orangeTheme      = "TotallyHuman.setting.orangeTheme"
        static let preview          = "TotallyHuman.setting.preview"
        static let language         = "TotallyHuman.setting.language"
        static let segmentLength    = "TotallyHuman.setting.segmentLength"
        static let batchConfirm     = "TotallyHuman.setting.batchConfirm"
        static let detailedHints    = "TotallyHuman.setting.detailedHints"
    }

    // MARK: - Analyse
    @Published var isDropTargetActive: Bool = false
    @Published var currentAnalysisResult: DetektionsErgebnis?
    @Published var letzterAnalyseErgebnis: DetektionsErgebnis?

    // MARK: - Stapelanalyse
    @Published var batchQueue: [String] = []
    @Published var batchResults: [DetektionsErgebnis] = []

    // MARK: - Training
    @Published var trainingSampleCount: Int = 0
    @Published var trainingEchtCount: Int = 0
    @Published var trainingKICount: Int = 0
    @Published var trainingAccuracy: Double = 0
    @Published var trainingStatusText: String = "Bereit"
    @Published var trainingProgressPoints: [TrainingsFortschritt] = []
    @Published var trainingProbes: [TrainingsProbe] = []

    // MARK: - Visualisierung
    @Published var visualizationSeries: [VisualisierungsPunkt] = []

    // MARK: - Modell & Datenbank
    @Published private(set) var modell: LogistischesModell?
    private let trainingStore = TrainingStore()

    // MARK: - Speicherort / Diagnose (für die UI)
    @Published private(set) var speicherPfadModell: String = ""
    @Published private(set) var speicherPfadTraining: String = ""
    @Published private(set) var speicherOrdner: String = ""
    @Published private(set) var speicherFehler: String?
    @Published private(set) var persistenzOK: Bool = true
    /// true, sobald ein trainiertes Modell (>0 Beispiele) aktiv ist — sonst heuristisch.
    var modellIstTrainiert: Bool { (modell?.anzahlBeispiele ?? 0) > 0 }

    // MARK: - Hilfstypen für Diagramme
    struct TrainingsFortschritt: Identifiable {
        let id = UUID()
        let epoch: Int
        let accuracy: Double
    }
    struct VisualisierungsPunkt: Identifiable {
        let id = UUID()
        let index: Int
        let value: Double
    }

    private let seedFlagKey = "TotallyHuman.seed.v1.importiert"

    init() {
        ladeEinstellungen()
        bootstrap()
    }

    /// Lädt die gespeicherten Einstellungen aus UserDefaults (falls vorhanden).
    /// Wird beim Programmstart aufgerufen, damit vorherige Änderungen erhalten bleiben.
    private func ladeEinstellungen() {
        let d = UserDefaults.standard
        if d.object(forKey: Keys.qualityThreshold) != nil { qualityThreshold = d.double(forKey: Keys.qualityThreshold) }
        if d.object(forKey: Keys.orangeTheme) != nil { isOrangeThemeEnabled = d.bool(forKey: Keys.orangeTheme) }
        if d.object(forKey: Keys.preview) != nil { isPreviewEnabled = d.bool(forKey: Keys.preview) }
        if let sprache = d.string(forKey: Keys.language) { selectedLanguage = sprache }
        if d.object(forKey: Keys.segmentLength) != nil { segmentLengthSeconds = d.double(forKey: Keys.segmentLength) }
        if d.object(forKey: Keys.batchConfirm) != nil { requireBatchConfirmation = d.bool(forKey: Keys.batchConfirm) }
        if d.object(forKey: Keys.detailedHints) != nil { showDetailedHints = d.bool(forKey: Keys.detailedHints) }
    }

    // MARK: - Initialisierung / Seed-Import

    private func bootstrap() {
        speicherPfadModell = MLModelManager.shared.modelURL.path
        speicherPfadTraining = trainingStore.pfad

        // Selbstheilender Seed-Import, am tatsächlichen Zustand ausgerichtet
        // (nicht an einem Flag). Idempotent dank Deduplizierung per Datei-Signatur.

        // 1) MODELL — WICHTIG: Wir verlassen uns NICHT auf den Platten-Roundtrip.
        //    Das (evtl. beschädigte) Modell von der Platte wird geladen; ist es
        //    leer (0 Beispiele), nehmen wir DIREKT das mitgelieferte Seed-Modell
        //    (148 Beispiele) im Speicher. Dadurch startet die App garantiert im
        //    trainierten Modus und niemals dauerhaft im heuristischen Modus.
        let vonPlatte = try? MLModelManager.shared.loadModel()
        if (vonPlatte?.anzahlBeispiele ?? 0) > 0 {
            modell = vonPlatte
        } else if let seedModell = ladeSeedModell() {
            modell = seedModell                       // <- direkt im Speicher aktiv
            try? MLModelManager.shared.save(seedModell) // Versuch zu persistieren (Best effort)
        } else {
            modell = MLModelManager.shared.loadOrCreateDefault()
        }

        // 2) TRAININGSDATEN — sind keine vorhanden, Seed-Beispiele importieren.
        if trainingStore.proben.isEmpty {
            let importiert = importiereSeedTrainingsdaten()
            statusText = s("Seed-Import: \(importiert) Beispiele geladen.",
                           "Seed import: \(importiert) samples loaded.")
        }
        UserDefaults.standard.set(true, forKey: seedFlagKey)

        aktualisiereProben()   // berechnet trainingAccuracy live gegen die Daten
        aktualisiereDiagnose()
        let modus = s(modellIstTrainiert ? "trainiert" : "heuristisch",
                      modellIstTrainiert ? "trained" : "heuristic")
        statusText = s("Bereit — \(trainingSampleCount) Trainingsbeispiele, Modell mit \(modell?.anzahlBeispiele ?? 0) Beispielen (\(modus)).",
                       "Ready — \(trainingSampleCount) training samples, model with \(modell?.anzahlBeispiele ?? 0) samples (\(modus)).")
        trainingStatusText = s("Bereit", "Ready")
    }

    /// Ermöglicht dem Nutzer, die mitgelieferten Seed-Daten manuell (neu) zu importieren.
    func seedDatenNeuImportieren() {
        // Seed-Modell DIREKT im Speicher aktivieren (kein Platten-Roundtrip).
        if let seedModell = ladeSeedModell() {
            modell = seedModell
            try? MLModelManager.shared.save(seedModell)
        }
        let importiert = importiereSeedTrainingsdaten()
        aktualisiereProben()   // berechnet trainingAccuracy live gegen die Daten
        aktualisiereDiagnose()
        let modus = s(modellIstTrainiert ? "trainiert" : "heuristisch",
                      modellIstTrainiert ? "trained" : "heuristic")
        trainingStatusText = s("Seed neu importiert: \(importiert) neue(s) Beispiel(e), Modell mit \(modell?.anzahlBeispiele ?? 0) Beispielen (\(modus)).",
                               "Seed re-imported: \(importiert) new sample(s), model with \(modell?.anzahlBeispiele ?? 0) samples (\(modus)).")
        statusText = trainingStatusText
    }

    /// Lädt das mitgelieferte Seed-Modell aus dem App-Bundle.
    private func ladeSeedModell() -> LogistischesModell? {
        guard let url = Bundle.main.url(forResource: "model_seed", withExtension: "json") else {
            NSLog("[TotallyHuman] model_seed.json NICHT im Bundle gefunden!")
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            NSLog("[TotallyHuman] model_seed.json konnte nicht gelesen werden.")
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let m = try decoder.decode(LogistischesModell.self, from: data)
            NSLog("[TotallyHuman] Seed-Modell geladen: \(m.gewichte.count) Gewichte, \(m.anzahlBeispiele) Beispiele.")
            return m
        } catch {
            NSLog("[TotallyHuman] Seed-Modell Dekodierung fehlgeschlagen: \(error)")
            return nil
        }
    }

    /// Importiert die mitgelieferten 148 Trainingsbeispiele in die lokale Datenbank.
    /// Gibt die Anzahl neu eingefügter Beispiele zurück. Idempotent (UNIQUE dateiSignatur).
    @discardableResult
    private func importiereSeedTrainingsdaten() -> Int {
        guard let url = Bundle.main.url(forResource: "training_seed", withExtension: "json") else {
            NSLog("[TotallyHuman] training_seed.json NICHT im Bundle gefunden!")
            return 0
        }
        guard let data = try? Data(contentsOf: url) else {
            NSLog("[TotallyHuman] training_seed.json konnte nicht gelesen werden.")
            return 0
        }
        guard let roh = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            NSLog("[TotallyHuman] training_seed.json hat ein unerwartetes Format.")
            return 0
        }
        var neueProben: [TrainingsProbe] = []
        for eintrag in roh {
            guard let label = eintrag["label"] as? Int,
                  let vektorRoh = eintrag["merkmalsvektor"] as? [Any] else { continue }
            let vektor = vektorRoh.compactMap { ($0 as? NSNumber)?.doubleValue }
            guard !vektor.isEmpty else { continue }
            let sig = (eintrag["dateiSignatur"] as? String) ?? UUID().uuidString
            neueProben.append(TrainingsProbe(
                id: UUID(),
                dateiPfad: "",
                dateiName: "Seed-Beispiel",
                label: TrainingsProbe.TrainingsLabel(rawValue: label) ?? .echt,
                merkmalsvektor: vektor,
                dateiSignatur: sig,
                hinzugefuegtAm: Date()
            ))
        }
        // Nur echte, neue Einfügungen werden gezählt (kein Phantom-Zähler mehr).
        let eingefuegt = trainingStore.hinzufuegen(neueProben)
        NSLog("[TotallyHuman] Seed-Trainingsdaten: \(eingefuegt) neu eingefügt von \(roh.count) (gesamt jetzt \(trainingStore.proben.count)).")
        return eingefuegt
    }

    // MARK: - Analyse (echte Dateien)

    func waehleDateienUndAnalysiere() {
        let panel = NSOpenPanel()
        panel.title = s("Audiodateien oder Ordner auswählen", "Select audio files or folder")
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = s("Analysieren", "Analyze")
        if panel.runModal() == .OK {
            let urls = panel.urls.flatMap { AudioFileHelper.findeAudioDateien(in: $0) }
            analysiere(urls: urls)
        }
    }

    func dropAnalyse(_ providers: [NSItemProvider]) -> Bool {
        ladeURLs(aus: providers) { urls in
            let audio = urls.flatMap { AudioFileHelper.findeAudioDateien(in: $0) }
            self.analysiere(urls: audio)
        }
        return true
    }

    func analysiere(urls: [URL]) {
        guard !urls.isEmpty else {
            statusText = s("Keine unterstützten Audiodateien gefunden.", "No supported audio files found.")
            return
        }
        let modellSnapshot = modell
        istBeschaeftigt = true
        batchQueue = urls.map { $0.lastPathComponent }
        statusText = s("Analysiere \(urls.count) Datei(en) …", "Analyzing \(urls.count) file(s) …")

        Task {
            var ergebnisse: [DetektionsErgebnis] = []
            for (i, url) in urls.enumerated() {
                self.statusText = self.s("Analysiere (\(i + 1)/\(urls.count)): \(url.lastPathComponent)",
                                         "Analyzing (\(i + 1)/\(urls.count)): \(url.lastPathComponent)")
                do {
                    let erg = try await Task.detached(priority: .userInitiated) {
                        try DetectionEngine().analysiere(url: url, modell: modellSnapshot)
                    }.value
                    ergebnisse.append(erg)
                } catch {
                    self.statusText = self.s("Fehler bei \(url.lastPathComponent): \(error.localizedDescription)",
                                             "Error with \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            if let erste = ergebnisse.first {
                self.currentAnalysisResult = erste
                self.letzterAnalyseErgebnis = erste
                self.aktualisiereVisualisierung(mit: erste)
            }
            self.batchResults = ergebnisse
            self.istBeschaeftigt = false
            self.statusText = self.s("Analyse abgeschlossen — \(ergebnisse.count) Datei(en).",
                                      "Analysis complete — \(ergebnisse.count) file(s).")
            if ergebnisse.count > 1 { self.sidebarSelection = .batch }
        }
    }

    // MARK: - Training

    func waehleTrainingsordner(label: TrainingsProbe.TrainingsLabel) {
        let panel = NSOpenPanel()
        let labelName = s(label.bezeichnung, label == .echt ? "Real music" : "AI music")
        panel.title = s("\(labelName): Ordner oder Dateien auswählen", "\(labelName): select folder or files")
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = s("Hinzufügen", "Add")
        if panel.runModal() == .OK {
            importiereTrainingsdaten(urls: panel.urls, label: label)
        }
    }

    func dropTraining(_ providers: [NSItemProvider], label: TrainingsProbe.TrainingsLabel) -> Bool {
        ladeURLs(aus: providers) { urls in
            self.importiereTrainingsdaten(urls: urls, label: label)
        }
        return true
    }

    func importiereTrainingsdaten(urls: [URL], label: TrainingsProbe.TrainingsLabel) {
        let dateien = urls.flatMap { AudioFileHelper.findeAudioDateien(in: $0) }
        guard !dateien.isEmpty else {
            trainingStatusText = s("Keine Audiodateien gefunden.", "No audio files found.")
            return
        }
        istBeschaeftigt = true
        trainingStatusText = s("Extrahiere Merkmale …", "Extracting features …")
        Task {
            var hinzugefuegt = 0
            for (i, datei) in dateien.enumerated() {
                self.trainingStatusText = self.s("Merkmale (\(i + 1)/\(dateien.count)): \(datei.lastPathComponent)",
                                                 "Features (\(i + 1)/\(dateien.count)): \(datei.lastPathComponent)")
                do {
                    let sig = AudioFileHelper.md5Signatur(url: datei)
                    let vektor = try await Task.detached(priority: .userInitiated) {
                        try AudioAnalyzer.merkmalsvektor(url: datei)
                    }.value
                    let probe = TrainingsProbe(
                        id: UUID(),
                        dateiPfad: datei.path,
                        dateiName: datei.lastPathComponent,
                        label: label,
                        merkmalsvektor: vektor,
                        dateiSignatur: sig,
                        hinzugefuegtAm: Date()
                    )
                    if self.trainingStore.hinzufuegen(probe) {
                        hinzugefuegt += 1
                    }
                } catch {
                    // einzelne Datei überspringen
                }
            }
            self.aktualisiereProben()
            self.aktualisiereDiagnose()
            self.istBeschaeftigt = false
            let labelName = self.s(label.bezeichnung, label == .echt ? "Real music" : "AI music")
            self.trainingStatusText = self.s("\(hinzugefuegt) neue(s) Beispiel(e) als \(labelName) hinzugefügt (gesamt \(self.trainingStore.proben.count)). Tipp: „Modell trainieren“, damit der Algorithmus dazulernt.",
                                             "\(hinzugefuegt) new sample(s) added as \(labelName) (total \(self.trainingStore.proben.count)). Tip: “Start training” so the algorithm keeps learning.")
        }
    }

    func starteTraining() {
        let proben = trainingStore.proben
        guard proben.count >= 2 else {
            trainingStatusText = s("Mindestens 2 Beispiele nötig (aktuell \(proben.count)).",
                                   "At least 2 samples required (currently \(proben.count)).")
            return
        }
        let echt = proben.filter { $0.label == .echt }.count
        let ki = proben.filter { $0.label == .ki }.count
        guard echt >= 1 && ki >= 1 else {
            trainingStatusText = s("Es werden Beispiele beider Klassen benötigt (echt: \(echt), KI: \(ki)).",
                                   "Samples of both classes are required (real: \(echt), AI: \(ki)).")
            return
        }
        istBeschaeftigt = true
        trainingStatusText = s("Training läuft (\(proben.count) Beispiele) …",
                               "Training in progress (\(proben.count) samples) …")
        Task {
            let neuesModell = await Task.detached(priority: .userInitiated) {
                let lr = LogisticRegression()
                return lr.train(samples: proben)
            }.value
            try? MLModelManager.shared.save(neuesModell)
            self.modell = neuesModell
            self.trainingAccuracy = neuesModell.kreuzvalidierungsGenauigkeit
            self.trainingStatusText = String(format: self.s("Training abgeschlossen — Genauigkeit %.1f %% (%d Beispiele).",
                                                             "Training complete — accuracy %.1f %% (%d samples)."),
                                              neuesModell.kreuzvalidierungsGenauigkeit * 100, proben.count)
            self.trainingProgressPoints.append(
                TrainingsFortschritt(epoch: self.trainingProgressPoints.count + 1,
                                     accuracy: neuesModell.kreuzvalidierungsGenauigkeit)
            )
            self.istBeschaeftigt = false
        }
    }

    func loescheAlleTrainingsdaten() {
        trainingStore.leeren()
        aktualisiereProben()
        aktualisiereDiagnose()
        trainingStatusText = s("Alle Trainingsdaten gelöscht.", "All training data deleted.")
    }

    /// Aktualisiert die Diagnose-Anzeigen (Pfade, Persistenzstatus, Fehlertext) für die UI.
    private func aktualisiereDiagnose() {
        persistenzOK = trainingStore.persistenzAktiv
        speicherOrdner = trainingStore.basisOrdner.path
        speicherPfadModell = MLModelManager.shared.modelURL.path
        speicherPfadTraining = trainingStore.pfad
        speicherFehler = persistenzOK ? nil : trainingStore.letzterFehler
    }

    /// Öffnet den tatsächlich genutzten Speicherordner im Finder (Modell + Trainingsdaten).
    func speicherordnerOeffnen() {
        let fm = FileManager.default
        let basis = trainingStore.basisOrdner
        // Ordner sicherstellen (existiert bereits, aber doppelt hält besser).
        try? fm.createDirectory(at: basis, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([basis])
    }

    private func aktualisiereProben() {
        let proben = trainingStore.proben
        trainingProbes = proben
        trainingSampleCount = proben.count
        trainingEchtCount = proben.filter { $0.label == .echt }.count
        trainingKICount = proben.filter { $0.label == .ki }.count
        // Genauigkeit live berechnen: aktuelles Modell gegen die aktuell vorhandenen
        // Trainingsdaten auswerten. So zeigt die Anzeige einen sinnvollen Wert, auch
        // wenn seit dem Datenimport noch kein neuer Trainingslauf gestartet wurde.
        aktualisiereGenauigkeit()
    }

    /// Bewertet das aktuelle Modell gegen die vorhandenen Trainingsdaten und
    /// aktualisiert `trainingAccuracy`. Reiner Auswertungsschritt (kein Training).
    private func aktualisiereGenauigkeit() {
        guard let m = modell, !trainingProbes.isEmpty else { return }
        var korrekt = 0
        var bewertet = 0
        for probe in trainingProbes where probe.merkmalsvektor.count == m.gewichte.count {
            let p = m.vorhersage(merkmale: probe.merkmalsvektor)
            let vorhergesagt = p >= 0.5 ? 1 : 0
            if vorhergesagt == probe.label.rawValue { korrekt += 1 }
            bewertet += 1
        }
        if bewertet > 0 {
            trainingAccuracy = Double(korrekt) / Double(bewertet)
        }
    }

    private func aktualisiereVisualisierung(mit result: DetektionsErgebnis) {
        visualizationSeries = result.fingerprintWerte.enumerated().map { index, wert in
            VisualisierungsPunkt(index: index, value: wert)
        }
    }

    // MARK: - Hilfsfunktionen

    private func ladeURLs(aus providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        var urls: [URL] = []
        let gruppe = DispatchGroup()
        let id = UTType.fileURL.identifier
        for p in providers where p.hasItemConformingToTypeIdentifier(id) {
            gruppe.enter()
            p.loadItem(forTypeIdentifier: id, options: nil) { item, _ in
                defer { gruppe.leave() }
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                } else if let url = item as? URL {
                    urls.append(url)
                }
            }
        }
        gruppe.notify(queue: .main) { completion(urls) }
    }
}
