// Localization.swift — Zweisprachige Oberfläche (Deutsch / Englisch)
// Totally Human — KI-Musik-Detektor (native macOS)
//
// Zentrale, sehr einfache Lokalisierung: Alle sichtbaren Texte der Oberfläche
// liegen hier als Schlüssel -> (Deutsch, Englisch) vor. Die aktuell gewählte
// Sprache steckt in `AppState.selectedLanguage` ("de" oder "en").
//
// Verwendung in den Views:   appState.t("schlüssel")
// Da `selectedLanguage` ein @Published-Wert ist, aktualisiert SwiftUI die
// Oberfläche automatisch live, sobald die Sprache in den Einstellungen
// umgeschaltet wird.

import Foundation

enum Loc {

    /// Aktuell gewählte Sprache ("de" / "en"). Wird von `AppState` gespiegelt,
    /// damit auch Klassen ohne Zugriff auf `AppState` (z. B. die Analyse-Engine)
    /// ihre sichtbaren Texte übersetzen können.
    static var aktuelleSprache: String = "de"

    /// Kurzform für Schichten ohne `AppState` (Analyse-Engine):
    /// liefert je nach aktueller Sprache den passenden Text.
    static func s(_ de: String, _ en: String) -> String {
        aktuelleSprache == "en" ? en : de
    }

    /// Übersetzungstabelle. Erster Wert = Deutsch, zweiter Wert = Englisch.
    static let tabelle: [String: (de: String, en: String)] = [

        // MARK: Seitenleiste (ContentView)
        "sidebar.section.analysis": ("Analyse", "Analysis"),
        "sidebar.analyse":          ("Datei prüfen", "Check file"),
        "sidebar.batch":            ("Stapelanalyse", "Batch analysis"),
        "sidebar.section.model":    ("Modell", "Model"),
        "sidebar.training":         ("Training", "Training"),
        "sidebar.visualization":    ("Visualisierung", "Visualization"),
        "sidebar.section.info":     ("Info", "Info"),
        "sidebar.settings":         ("Einstellungen", "Settings"),

        // MARK: Einstellungen (ContentView / SettingsView)
        "settings.title":        ("Einstellungen", "Settings"),
        "settings.autosave":     ("Änderungen werden automatisch gespeichert – kein Speichern-Button nötig.",
                                  "Changes are saved automatically – no save button needed."),
        "settings.appearance":   ("Darstellung", "Appearance"),
        "settings.orangeTheme":  ("Dunkles Orangethema aktiv", "Dark orange theme active"),
        "settings.preview":      ("Automatische Vorschau", "Automatic preview"),
        "settings.language":     ("Sprache", "Language"),
        "settings.german":       ("Deutsch", "German"),
        "settings.english":      ("Englisch", "English"),
        "settings.analysis":     ("Analyse", "Analysis"),
        "settings.batchConfirm": ("Batch-Bestätigung vor Start", "Confirm before batch start"),
        "settings.detailedHints":("Ausgabe detaillierter Hinweise", "Show detailed hints"),
        "settings.modeTrained":  ("Analysemodus: Trainiert", "Analysis mode: Trained"),

        // MARK: Menüleiste (TotallyHumanApp)
        "menu.analyzeFile":  ("Datei analysieren …", "Analyze file …"),
        "menu.openTraining": ("Training öffnen", "Open training"),
        "menu.quit":         ("Beenden", "Quit"),

        // MARK: Analyse-Ansicht
        "analysis.dropTitle":    ("Einzelanalyse", "Single analysis"),
        "analysis.dropSubtitle": ("Ziehe eine Audiodatei per Drag & Drop hierher oder klicke auf „Datei auswählen“.",
                                  "Drag & drop an audio file here or click “Select file”."),
        "analysis.title":        ("Analyse", "Analysis"),
        "analysis.subtitle":     ("Bewertet spektrale Artefakte und Hinweisindikatoren für KI-generierte Musik.",
                                  "Evaluates spectral artifacts and indicators for AI-generated music."),
        "verdict.ai":            ("KI-generiert", "AI-generated"),
        "verdict.real":          ("Echte Musik", "Real music"),
        "verdict.none":          ("Noch keine Analyse durchgeführt", "No analysis performed yet"),
        "label.aiMusic":         ("KI-Musik", "AI music"),
        "label.realMusic":       ("Echte Musik", "Real music"),
        "mode.trained":          ("Trainiert", "Trained"),
        "mode.heuristic":        ("Heuristisch", "Heuristic"),
        "metric.aiProbability":  ("KI-Wahrscheinlichkeit", "AI probability"),
        "metric.artifactScore":  ("Artefakt-Score", "Artifact score"),
        "metric.confidence":     ("Konfidenz", "Confidence"),
        "chart.spectrum":        ("Spektrum", "Spectrum"),
        "chart.frequency":       ("Frequenz", "Frequency"),
        "chart.level":           ("Pegel", "Level"),
        "chart.frequencyHz":     ("Frequenz (Hz)", "Frequency (Hz)"),
        "hints.title":           ("Hinweise", "Hints"),
        "hints.none":            ("Keine Hinweise.", "No hints."),
        "button.selectFile":     ("Datei auswählen", "Select file"),
        "result.details":        ("Details", "Details"),
        "result.file":           ("Datei", "File"),
        "result.classification": ("Einstufung", "Classification"),
        "result.mode":           ("Modus", "Mode"),
        "result.date":           ("Datum", "Date"),
        "result.none":           ("Kein Ergebnis vorhanden.", "No result available."),

        // MARK: Training-Ansicht
        "training.title":       ("Training", "Training"),
        "training.subtitle":    ("Füge echte und KI-generierte Musik hinzu und starte einen neuen Trainingslauf. Die Daten werden lokal gespeichert und wachsen mit jedem Durchlauf.",
                                 "Add real and AI-generated music and start a new training run. The data is stored locally and grows with each run."),
        "training.totalSamples":("Beispiele gesamt", "Total samples"),
        "training.realMusic":   ("Echte Musik", "Real music"),
        "training.aiMusic":     ("KI-Musik", "AI music"),
        "training.accuracy":    ("Genauigkeit", "Accuracy"),
        "training.modeTrained": ("Modus: Trainiert", "Mode: Trained"),
        "training.modeHeuristic":("Modus: heuristisch", "Mode: heuristic"),
        "training.folder":      ("Ordner", "Folder"),
        "training.folderHelp":  ("Öffnet den lokalen Ordner mit Modell und Trainingsdaten. Diese Dateien bleiben zwischen Programmstarts erhalten, sodass der Algorithmus dauerhaft dazulernt.",
                                 "Opens the local folder with the model and training data. These files persist between launches so the algorithm keeps learning."),
        "training.saveFailed":  ("Speichern fehlgeschlagen – Daten nur im Arbeitsspeicher.",
                                 "Saving failed – data only in memory."),
        "training.modelLocation":("Modell & Speicherort", "Model & storage location"),
        "training.dragOrClick": ("Ziehen oder klicken", "Drag or click"),
        "training.step1":       ("1 · Daten hinzufügen", "1 · Add data"),
        "training.needBoth":    ("Mindestens 1 echtes UND 1 KI-Beispiel benötigt.",
                                 "At least 1 real AND 1 AI sample required."),
        "training.start":       ("Training starten", "Start training"),
        "training.delete":      ("Löschen", "Delete"),
        "training.reseed":      ("Seed neu importieren", "Re-import seed"),
        "training.step2":       ("2 · Trainieren", "2 · Train"),
        "training.progress":    ("Verlauf", "Progress"),
        "training.run":         ("Lauf", "Run"),
        "training.seed":        ("Seed", "Seed"),
        "training.labelReal":   ("Echt", "Real"),
        "training.labelAI":     ("KI", "AI"),
        "training.addRealMusic":("Echte Musik +", "Real music +"),
        "training.addAIMusic":  ("KI-Musik +", "AI music +"),

        // MARK: Stapelanalyse
        "batch.title":       ("Stapelanalyse", "Batch analysis"),
        "batch.subtitle":    ("Analysiere mehrere Dateien in einem Durchgang und vergleiche die Ergebnisse direkt nebeneinander.",
                              "Analyze multiple files in one run and compare the results side by side."),
        "batch.dropTitle":   ("Ordner oder mehrere Dateien ablegen", "Drop a folder or multiple files"),
        "batch.dropSubtitle":("Unterstützt Drag & Drop für ganze Ordner und mehrere Audiodateien — oder klicke zum Auswählen.",
                              "Supports drag & drop for whole folders and multiple audio files — or click to select."),
        "batch.queue":       ("Warteschlange", "Queue"),
        "batch.queueEmpty":  ("Keine Dateien in der Warteschlange.", "No files in the queue."),
        "batch.ready":       ("Bereit", "Ready"),
        "batch.results":     ("Ergebnisse", "Results"),
        "batch.resultsEmpty":("Noch keine Batch-Ergebnisse vorhanden.", "No batch results yet."),
        "batch.ai":          ("KI", "AI"),
        "batch.distribution":("Verteilung", "Distribution"),

        // MARK: Visualisierung
        "viz.title":         ("Visualisierung", "Visualization"),
        "viz.subtitle":      ("Mehrere Diagramme für Spektrum, Zeitverlauf und Modellverhalten in einer Oberfläche.",
                              "Multiple charts for spectrum, time course and model behavior in one view."),
        "viz.classification":("Klassifikationsverlauf", "Classification course"),
        "viz.index":         ("Index", "Index"),
        "viz.value":         ("Wert", "Value"),
        "viz.segments":      ("Zeitliche Segmente", "Time segments"),
        "viz.segment":       ("Segment", "Segment"),
        "viz.strength":      ("Stärke", "Strength"),
        "viz.ssm":           ("SSM-Matrix", "SSM matrix"),
        "viz.noMatrix":      ("Keine Matrixdaten vorhanden.", "No matrix data available."),
    ]

    /// Liefert die Übersetzung für einen Schlüssel in der angegebenen Sprache.
    /// Fällt auf Deutsch bzw. den Schlüssel selbst zurück, falls unbekannt.
    static func t(_ key: String, _ sprache: String) -> String {
        guard let eintrag = tabelle[key] else { return key }
        return sprache == "en" ? eintrag.en : eintrag.de
    }
}

extension AppState {
    /// Komfort-Zugriff aus den Views: `appState.t("schlüssel")`.
    /// Nutzt automatisch die aktuell gewählte Sprache.
    func t(_ key: String) -> String {
        Loc.t(key, selectedLanguage)
    }

    /// Kurzform für dynamische Statustexte mit Interpolation:
    /// `s("Deutsch", "English")` liefert je nach aktueller Sprache den passenden Text.
    func s(_ de: String, _ en: String) -> String {
        selectedLanguage == "en" ? en : de
    }
}
