using System;
using System.Collections.Generic;
using System.ComponentModel;

namespace TotallyHuman.Utilities;

/// <summary>
/// Einfaches, Dictionary-basiertes Zweisprachigkeitssystem (Deutsch / Englisch).
/// Aufruf: <c>Loc.Get("key")</c>. Sprachwechsel via <c>Loc.SetLanguage("en")</c>
/// löst <see cref="LanguageChanged"/> aus, damit die UI sich neu bindet.
/// </summary>
public static class Loc
{
    public static string Language { get; private set; } = "de";

    public static event EventHandler? LanguageChanged;

    public static void SetLanguage(string lang)
    {
        lang = (lang == "en") ? "en" : "de";
        if (lang == Language) return;
        Language = lang;
        LanguageChanged?.Invoke(null, EventArgs.Empty);
    }

    public static string Get(string key)
    {
        var table = Language == "en" ? En : De;
        if (table.TryGetValue(key, out var v)) return v;
        // Fallback auf Deutsch, dann auf den Schlüssel selbst.
        return De.TryGetValue(key, out var d) ? d : key;
    }

    // Kurzform
    public static string T(string key) => Get(key);

    private static readonly Dictionary<string, string> De = new()
    {
        // App / Navigation
        ["app.title"] = "Totally Human — KI-Musik-Detektor",
        ["nav.section.analysis"] = "Analyse",
        ["nav.section.model"] = "Modell",
        ["nav.section.info"] = "Info",
        ["nav.analyse"] = "Datei prüfen",
        ["nav.batch"] = "Stapelanalyse",
        ["nav.training"] = "Training",
        ["nav.visualisierung"] = "Visualisierung",
        ["nav.einstellungen"] = "Einstellungen",
        ["status.ready"] = "Bereit",

        // Analyse-Tab
        ["analysis.title"] = "Analyse",
        ["analysis.subtitle"] = "Bewertet spektrale Artefakte und Hinweisindikatoren für KI-generierte Musik.",
        ["analysis.drop.title"] = "Einzelanalyse",
        ["analysis.drop.subtitle"] = "Ziehe eine Audiodatei per Drag & Drop hierher oder klicke auf „Datei auswählen“.",
        ["analysis.openfile"] = "Datei auswählen",
        ["analysis.noresult"] = "Noch keine Analyse durchgeführt",
        ["analysis.ki"] = "KI-generiert",
        ["analysis.human"] = "Echte Musik",
        ["analysis.kimusic"] = "KI-Musik",
        ["analysis.humanmusic"] = "Echte Musik",
        ["analysis.mode.trained"] = "Trainiert",
        ["analysis.mode.heuristic"] = "Heuristisch",
        ["analysis.metric.probability"] = "KI-Wahrscheinlichkeit",
        ["analysis.metric.artefact"] = "Artefakt-Score",
        ["analysis.metric.confidence"] = "Konfidenz",
        ["analysis.spectrum"] = "Spektrum",
        ["analysis.hints"] = "Hinweise",
        ["analysis.nohints"] = "Keine Hinweise.",
        ["analysis.details"] = "Details",
        ["analysis.noresult.details"] = "Kein Ergebnis vorhanden.",
        ["analysis.file"] = "Datei",
        ["analysis.classification"] = "Einstufung",
        ["analysis.mode"] = "Modus",
        ["analysis.date"] = "Datum",
        ["axis.freq"] = "Frequenz (Hz)",
        ["axis.db"] = "dB",

        // Batch-Tab
        ["batch.title"] = "Stapelanalyse",
        ["batch.subtitle"] = "Analysiere mehrere Dateien oder ganze Ordner gleichzeitig.",
        ["batch.choose"] = "Dateien / Ordner auswählen",
        ["batch.clear"] = "Liste leeren",
        ["batch.summary.total"] = "Dateien gesamt",
        ["batch.summary.ki"] = "KI-generiert",
        ["batch.summary.human"] = "Menschlich",
        ["batch.col.file"] = "Datei",
        ["batch.col.result"] = "Ergebnis",
        ["batch.col.probability"] = "KI-Wahrsch.",
        ["batch.col.confidence"] = "Konfidenz",
        ["batch.col.mode"] = "Modus",
        ["batch.empty"] = "Noch keine Dateien analysiert.",

        // Training-Tab
        ["training.title"] = "Training",
        ["training.subtitle"] = "Füge echte und KI-generierte Musik hinzu und starte einen neuen Trainingslauf. Die Daten werden lokal gespeichert.",
        ["training.total"] = "Beispiele gesamt",
        ["training.real"] = "Echte Musik",
        ["training.ki"] = "KI-Musik",
        ["training.accuracy"] = "Genauigkeit",
        ["training.mode.trained"] = "Modus: Trainiert",
        ["training.mode.heuristic"] = "Modus: heuristisch",
        ["training.openfolder"] = "Ordner öffnen",
        ["training.add.real"] = "Echte Musik hinzufügen",
        ["training.add.ki"] = "KI-Musik hinzufügen",
        ["training.dropreal"] = "Echte Musik hierher ziehen",
        ["training.dropki"] = "KI-Musik hierher ziehen",
        ["training.start"] = "Modell trainieren",
        ["training.reseed"] = "Seed-Daten neu importieren",
        ["training.clear"] = "Alle Trainingsdaten löschen",
        ["training.samples"] = "Trainingsproben",
        ["training.col.name"] = "Name",
        ["training.col.label"] = "Label",
        ["training.col.added"] = "Hinzugefügt",
        ["training.persist.error"] = "Speichern fehlgeschlagen – Daten nur im Arbeitsspeicher.",

        // Visualisierung-Tab
        ["viz.title"] = "Visualisierung",
        ["viz.subtitle"] = "Spektrum, Fingerprint und Segment-Stärken der zuletzt analysierten Datei.",
        ["viz.spectrum"] = "Spektrum & Fingerprint",
        ["viz.spectrum.line"] = "Spektrum (dB)",
        ["viz.fingerprint.line"] = "Fingerprint",
        ["viz.baseline.line"] = "Grundlinie",
        ["viz.segments"] = "Segment-Stärken",
        ["viz.segments.axis"] = "Segment",
        ["viz.strength"] = "Stärke",
        ["viz.empty"] = "Noch keine Analyse — bitte zuerst eine Datei im Analyse-Tab prüfen.",

        // Einstellungen-Tab
        ["settings.title"] = "Einstellungen",
        ["settings.autosave"] = "Änderungen werden automatisch gespeichert – kein Speichern-Button nötig.",
        ["settings.appearance"] = "Darstellung",
        ["settings.orangetheme"] = "Dunkles Orangethema aktiv",
        ["settings.preview"] = "Automatische Vorschau",
        ["settings.language"] = "Sprache",
        ["settings.lang.de"] = "Deutsch",
        ["settings.lang.en"] = "Englisch",
        ["settings.analysis"] = "Analyse",
        ["settings.quality"] = "Qualitätsschwelle",
        ["settings.segment"] = "Segmentlänge (Sekunden)",
        ["settings.batchconfirm"] = "Batch-Bestätigung vor Start",
        ["settings.detailedhints"] = "Ausgabe detaillierter Hinweise",
        ["settings.storage"] = "Speicher & Daten",
        ["settings.openfolder"] = "Speicherordner öffnen",
        ["settings.reseed"] = "Seed-Daten neu importieren",
        ["settings.about"] = "Über",
        ["settings.about.text"] = "Totally Human erkennt KI-generierte Musik anhand spektraler Artefakte im Hochfrequenzband (5–16 kHz) und einem logistischen Modell.",

        // Allgemein
        ["common.yes"] = "Ja",
        ["common.no"] = "Nein",
        ["common.busy"] = "Bitte warten …",
    };

    private static readonly Dictionary<string, string> En = new()
    {
        ["app.title"] = "Totally Human — AI Music Detector",
        ["nav.section.analysis"] = "Analysis",
        ["nav.section.model"] = "Model",
        ["nav.section.info"] = "Info",
        ["nav.analyse"] = "Check File",
        ["nav.batch"] = "Batch Analysis",
        ["nav.training"] = "Training",
        ["nav.visualisierung"] = "Visualization",
        ["nav.einstellungen"] = "Settings",
        ["status.ready"] = "Ready",

        ["analysis.title"] = "Analysis",
        ["analysis.subtitle"] = "Evaluates spectral artefacts and indicator metrics for AI-generated music.",
        ["analysis.drop.title"] = "Single Analysis",
        ["analysis.drop.subtitle"] = "Drag & drop an audio file here or click “Choose File”.",
        ["analysis.openfile"] = "Choose File",
        ["analysis.noresult"] = "No analysis performed yet",
        ["analysis.ki"] = "AI-generated",
        ["analysis.human"] = "Real Music",
        ["analysis.kimusic"] = "AI Music",
        ["analysis.humanmusic"] = "Real Music",
        ["analysis.mode.trained"] = "Trained",
        ["analysis.mode.heuristic"] = "Heuristic",
        ["analysis.metric.probability"] = "AI Probability",
        ["analysis.metric.artefact"] = "Artefact Score",
        ["analysis.metric.confidence"] = "Confidence",
        ["analysis.spectrum"] = "Spectrum",
        ["analysis.hints"] = "Hints",
        ["analysis.nohints"] = "No hints.",
        ["analysis.details"] = "Details",
        ["analysis.noresult.details"] = "No result available.",
        ["analysis.file"] = "File",
        ["analysis.classification"] = "Classification",
        ["analysis.mode"] = "Mode",
        ["analysis.date"] = "Date",
        ["axis.freq"] = "Frequency (Hz)",
        ["axis.db"] = "dB",

        ["batch.title"] = "Batch Analysis",
        ["batch.subtitle"] = "Analyze multiple files or entire folders at once.",
        ["batch.choose"] = "Choose Files / Folder",
        ["batch.clear"] = "Clear List",
        ["batch.summary.total"] = "Total Files",
        ["batch.summary.ki"] = "AI-generated",
        ["batch.summary.human"] = "Human",
        ["batch.col.file"] = "File",
        ["batch.col.result"] = "Result",
        ["batch.col.probability"] = "AI Prob.",
        ["batch.col.confidence"] = "Confidence",
        ["batch.col.mode"] = "Mode",
        ["batch.empty"] = "No files analyzed yet.",

        ["training.title"] = "Training",
        ["training.subtitle"] = "Add real and AI-generated music and start a new training run. Data is stored locally.",
        ["training.total"] = "Total Samples",
        ["training.real"] = "Real Music",
        ["training.ki"] = "AI Music",
        ["training.accuracy"] = "Accuracy",
        ["training.mode.trained"] = "Mode: Trained",
        ["training.mode.heuristic"] = "Mode: Heuristic",
        ["training.openfolder"] = "Open Folder",
        ["training.add.real"] = "Add Real Music",
        ["training.add.ki"] = "Add AI Music",
        ["training.dropreal"] = "Drag real music here",
        ["training.dropki"] = "Drag AI music here",
        ["training.start"] = "Train Model",
        ["training.reseed"] = "Re-import Seed Data",
        ["training.clear"] = "Delete All Training Data",
        ["training.samples"] = "Training Samples",
        ["training.col.name"] = "Name",
        ["training.col.label"] = "Label",
        ["training.col.added"] = "Added",
        ["training.persist.error"] = "Saving failed – data only in memory.",

        ["viz.title"] = "Visualization",
        ["viz.subtitle"] = "Spectrum, fingerprint and segment strengths of the most recently analyzed file.",
        ["viz.spectrum"] = "Spectrum & Fingerprint",
        ["viz.spectrum.line"] = "Spectrum (dB)",
        ["viz.fingerprint.line"] = "Fingerprint",
        ["viz.baseline.line"] = "Baseline",
        ["viz.segments"] = "Segment Strengths",
        ["viz.segments.axis"] = "Segment",
        ["viz.strength"] = "Strength",
        ["viz.empty"] = "No analysis yet — please check a file in the Analysis tab first.",

        ["settings.title"] = "Settings",
        ["settings.autosave"] = "Changes are saved automatically – no save button needed.",
        ["settings.appearance"] = "Appearance",
        ["settings.orangetheme"] = "Dark orange theme enabled",
        ["settings.preview"] = "Automatic preview",
        ["settings.language"] = "Language",
        ["settings.lang.de"] = "German",
        ["settings.lang.en"] = "English",
        ["settings.analysis"] = "Analysis",
        ["settings.quality"] = "Quality Threshold",
        ["settings.segment"] = "Segment Length (seconds)",
        ["settings.batchconfirm"] = "Confirm before batch start",
        ["settings.detailedhints"] = "Output detailed hints",
        ["settings.storage"] = "Storage & Data",
        ["settings.openfolder"] = "Open Storage Folder",
        ["settings.reseed"] = "Re-import Seed Data",
        ["settings.about"] = "About",
        ["settings.about.text"] = "Totally Human detects AI-generated music via spectral artefacts in the high-frequency band (5–16 kHz) and a logistic model.",

        ["common.yes"] = "Yes",
        ["common.no"] = "No",
        ["common.busy"] = "Please wait …",
    };
}
