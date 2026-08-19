using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;
using TotallyHuman.Analysis;
using TotallyHuman.Database;
using TotallyHuman.ML;
using TotallyHuman.Models;
using TotallyHuman.Utilities;

namespace TotallyHuman.ViewModels;

public enum SidebarSelection { Analyse, Batch, Training, Visualisierung, Einstellungen }

/// <summary>
/// Zentraler, beobachtbarer Zustand der App (INotifyPropertyChanged).
/// Port von AppState.swift.
/// </summary>
public sealed class AppState : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? name = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    private void Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        OnPropertyChanged(name);
    }

    // MARK: - Navigation
    private SidebarSelection _sidebarSelection = SidebarSelection.Analyse;
    public SidebarSelection SidebarSelection { get => _sidebarSelection; set => Set(ref _sidebarSelection, value); }

    // MARK: - Allgemeiner Status
    private string _statusText = Loc.Get("status.ready");
    public string StatusText { get => _statusText; set => Set(ref _statusText, value); }

    private bool _istBeschaeftigt;
    public bool IstBeschaeftigt { get => _istBeschaeftigt; set => Set(ref _istBeschaeftigt, value); }

    // MARK: - Einstellungen (automatisch persistiert)
    private double _qualityThreshold = 70;
    public double QualityThreshold { get => _qualityThreshold; set { Set(ref _qualityThreshold, value); SpeichereEinstellungen(); } }

    private bool _isOrangeThemeEnabled = true;
    public bool IsOrangeThemeEnabled { get => _isOrangeThemeEnabled; set { Set(ref _isOrangeThemeEnabled, value); SpeichereEinstellungen(); } }

    private bool _isPreviewEnabled = true;
    public bool IsPreviewEnabled { get => _isPreviewEnabled; set { Set(ref _isPreviewEnabled, value); SpeichereEinstellungen(); } }

    private string _selectedLanguage = "de";
    public string SelectedLanguage
    {
        get => _selectedLanguage;
        set
        {
            if (_selectedLanguage == value) return;
            _selectedLanguage = value;
            OnPropertyChanged();
            Loc.SetLanguage(value);
            SpeichereEinstellungen();
        }
    }

    private double _segmentLengthSeconds = 10;
    public double SegmentLengthSeconds { get => _segmentLengthSeconds; set { Set(ref _segmentLengthSeconds, value); SpeichereEinstellungen(); } }

    private bool _requireBatchConfirmation;
    public bool RequireBatchConfirmation { get => _requireBatchConfirmation; set { Set(ref _requireBatchConfirmation, value); SpeichereEinstellungen(); } }

    private bool _showDetailedHints = true;
    public bool ShowDetailedHints { get => _showDetailedHints; set { Set(ref _showDetailedHints, value); SpeichereEinstellungen(); } }

    // MARK: - Analyse
    private DetektionsErgebnis? _currentAnalysisResult;
    public DetektionsErgebnis? CurrentAnalysisResult { get => _currentAnalysisResult; set => Set(ref _currentAnalysisResult, value); }

    public ObservableCollection<string> BatchQueue { get; } = new();
    public ObservableCollection<DetektionsErgebnis> BatchResults { get; } = new();

    // MARK: - Training
    private int _trainingSampleCount;
    public int TrainingSampleCount { get => _trainingSampleCount; set => Set(ref _trainingSampleCount, value); }
    private int _trainingEchtCount;
    public int TrainingEchtCount { get => _trainingEchtCount; set => Set(ref _trainingEchtCount, value); }
    private int _trainingKICount;
    public int TrainingKICount { get => _trainingKICount; set => Set(ref _trainingKICount, value); }
    private double _trainingAccuracy;
    public double TrainingAccuracy { get => _trainingAccuracy; set => Set(ref _trainingAccuracy, value); }
    private string _trainingStatusText = Loc.Get("status.ready");
    public string TrainingStatusText { get => _trainingStatusText; set => Set(ref _trainingStatusText, value); }
    public ObservableCollection<TrainingsProbe> TrainingProbes { get; } = new();

    // MARK: - Modell & Datenbank
    private LogistischesModell? _modell;
    public LogistischesModell? Modell { get => _modell; private set { Set(ref _modell, value); OnPropertyChanged(nameof(ModellIstTrainiert)); } }
    private readonly TrainingStore _trainingStore = new();

    // MARK: - Diagnose
    private string _speicherOrdner = "";
    public string SpeicherOrdner { get => _speicherOrdner; set => Set(ref _speicherOrdner, value); }
    private bool _persistenzOK = true;
    public bool PersistenzOK { get => _persistenzOK; set => Set(ref _persistenzOK, value); }
    private string? _speicherFehler;
    public string? SpeicherFehler { get => _speicherFehler; set => Set(ref _speicherFehler, value); }

    public bool ModellIstTrainiert => (Modell?.AnzahlBeispiele ?? 0) > 0;

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
    };

    public AppState()
    {
        LadeEinstellungen();
        Loc.SetLanguage(_selectedLanguage);
        Bootstrap();
    }

    // MARK: - Einstellungen (JSON in %APPDATA%)

    private string SettingsPfad => Path.Combine(AppSpeicherort.Basis, "einstellungen.json");

    private void LadeEinstellungen()
    {
        try
        {
            if (!File.Exists(SettingsPfad)) return;
            var d = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(File.ReadAllText(SettingsPfad));
            if (d == null) return;
            if (d.TryGetValue("qualityThreshold", out var q)) _qualityThreshold = q.GetDouble();
            if (d.TryGetValue("orangeTheme", out var o)) _isOrangeThemeEnabled = o.GetBoolean();
            if (d.TryGetValue("preview", out var p)) _isPreviewEnabled = p.GetBoolean();
            if (d.TryGetValue("language", out var l)) _selectedLanguage = l.GetString() ?? "de";
            if (d.TryGetValue("segmentLength", out var s)) _segmentLengthSeconds = s.GetDouble();
            if (d.TryGetValue("batchConfirm", out var b)) _requireBatchConfirmation = b.GetBoolean();
            if (d.TryGetValue("detailedHints", out var h)) _showDetailedHints = h.GetBoolean();
        }
        catch { /* Standardwerte behalten */ }
    }

    private void SpeichereEinstellungen()
    {
        try
        {
            var d = new Dictionary<string, object>
            {
                ["qualityThreshold"] = _qualityThreshold,
                ["orangeTheme"] = _isOrangeThemeEnabled,
                ["preview"] = _isPreviewEnabled,
                ["language"] = _selectedLanguage,
                ["segmentLength"] = _segmentLengthSeconds,
                ["batchConfirm"] = _requireBatchConfirmation,
                ["detailedHints"] = _showDetailedHints,
            };
            Directory.CreateDirectory(AppSpeicherort.Basis);
            File.WriteAllText(SettingsPfad, JsonSerializer.Serialize(d, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { /* Persistenz best effort */ }
    }

    // MARK: - Bootstrap / Seed-Import

    private void Bootstrap()
    {
        var vonPlatte = MLModelManager.Shared.TryLoadModel();
        if ((vonPlatte?.AnzahlBeispiele ?? 0) > 0)
        {
            Modell = vonPlatte;
        }
        else
        {
            var seedModell = LadeSeedModell();
            if (seedModell != null)
            {
                Modell = seedModell;
                try { MLModelManager.Shared.Save(seedModell); } catch { }
            }
            else
            {
                Modell = MLModelManager.Shared.LoadOrCreateDefault();
            }
        }

        if (_trainingStore.Proben.Count == 0)
        {
            int importiert = ImportiereSeedTrainingsdaten();
            StatusText = $"Seed-Import: {importiert} Beispiele geladen.";
        }

        AktualisiereProben();
        AktualisiereDiagnose();
        string modus = ModellIstTrainiert ? "trainiert" : "heuristisch";
        StatusText = $"Bereit — {TrainingSampleCount} Trainingsbeispiele, Modell mit {Modell?.AnzahlBeispiele ?? 0} Beispielen ({modus}).";
    }

    public void SeedDatenNeuImportieren()
    {
        var seedModell = LadeSeedModell();
        if (seedModell != null)
        {
            Modell = seedModell;
            try { MLModelManager.Shared.Save(seedModell); } catch { }
        }
        int importiert = ImportiereSeedTrainingsdaten();
        AktualisiereProben();
        AktualisiereDiagnose();
        string modus = ModellIstTrainiert ? "trainiert" : "heuristisch";
        TrainingStatusText = $"Seed neu importiert: {importiert} neue(s) Beispiel(e), Modell mit {Modell?.AnzahlBeispiele ?? 0} Beispielen ({modus}).";
        StatusText = TrainingStatusText;
    }

    private static Stream? OeffneEingebettet(string name)
    {
        var asm = Assembly.GetExecutingAssembly();
        // Logischer Name: TotallyHuman.Resources.<name>
        string voll = "TotallyHuman.Resources." + name;
        var stream = asm.GetManifestResourceStream(voll);
        if (stream != null) return stream;
        // Fallback: suchen nach Endung
        var match = asm.GetManifestResourceNames().FirstOrDefault(n => n.EndsWith(name, StringComparison.OrdinalIgnoreCase));
        return match != null ? asm.GetManifestResourceStream(match) : null;
    }

    private LogistischesModell? LadeSeedModell()
    {
        try
        {
            using var s = OeffneEingebettet("model_seed.json");
            if (s == null) return null;
            using var reader = new StreamReader(s);
            return JsonSerializer.Deserialize<LogistischesModell>(reader.ReadToEnd());
        }
        catch { return null; }
    }

    private int ImportiereSeedTrainingsdaten()
    {
        try
        {
            using var s = OeffneEingebettet("training_seed.json");
            if (s == null) return 0;
            using var reader = new StreamReader(s);
            var roh = JsonSerializer.Deserialize<List<TrainingsProbe>>(reader.ReadToEnd(), JsonOpts);
            if (roh == null) return 0;
            var neueProben = new List<TrainingsProbe>();
            foreach (var eintrag in roh)
            {
                if (eintrag.Merkmalsvektor.Length == 0) continue;
                neueProben.Add(new TrainingsProbe
                {
                    Id = Guid.NewGuid(),
                    DateiPfad = "",
                    DateiName = "Seed-Beispiel",
                    LabelRaw = eintrag.LabelRaw,
                    Merkmalsvektor = eintrag.Merkmalsvektor,
                    DateiSignatur = string.IsNullOrEmpty(eintrag.DateiSignatur) ? Guid.NewGuid().ToString() : eintrag.DateiSignatur,
                    HinzugefuegtAm = DateTime.Now
                });
            }
            return _trainingStore.Hinzufuegen(neueProben);
        }
        catch { return 0; }
    }

    // MARK: - Analyse

    public void Analysiere(IReadOnlyList<string> urls)
    {
        var dateien = urls.SelectMany(AudioFileHelper.FindeAudioDateien).Distinct().ToList();
        if (dateien.Count == 0)
        {
            StatusText = "Keine unterstützten Audiodateien gefunden.";
            return;
        }
        var modellSnapshot = Modell;
        IstBeschaeftigt = true;
        BatchQueue.Clear();
        foreach (var d in dateien) BatchQueue.Add(Path.GetFileName(d));
        StatusText = $"Analysiere {dateien.Count} Datei(en) …";

        Task.Run(() =>
        {
            var ergebnisse = new List<DetektionsErgebnis>();
            var engine = new DetectionEngine();
            for (int i = 0; i < dateien.Count; i++)
            {
                var datei = dateien[i];
                UI(() => StatusText = $"Analysiere ({i + 1}/{dateien.Count}): {Path.GetFileName(datei)}");
                try
                {
                    var erg = engine.Analysiere(datei, modellSnapshot);
                    ergebnisse.Add(erg);
                }
                catch (Exception ex)
                {
                    UI(() => StatusText = $"Fehler bei {Path.GetFileName(datei)}: {ex.Message}");
                }
            }
            UI(() =>
            {
                if (ergebnisse.Count > 0)
                {
                    CurrentAnalysisResult = ergebnisse[0];
                }
                BatchResults.Clear();
                foreach (var e in ergebnisse) BatchResults.Add(e);
                IstBeschaeftigt = false;
                StatusText = $"Analyse abgeschlossen — {ergebnisse.Count} Datei(en).";
                if (ergebnisse.Count > 1) SidebarSelection = SidebarSelection.Batch;
            });
        });
    }

    public void LeereBatch()
    {
        BatchResults.Clear();
        BatchQueue.Clear();
        StatusText = Loc.Get("status.ready");
    }

    // MARK: - Training

    public void ImportiereTrainingsdaten(IReadOnlyList<string> urls, TrainingsLabel label)
    {
        var dateien = urls.SelectMany(AudioFileHelper.FindeAudioDateien).Distinct().ToList();
        if (dateien.Count == 0)
        {
            TrainingStatusText = "Keine Audiodateien gefunden.";
            return;
        }
        IstBeschaeftigt = true;
        TrainingStatusText = "Extrahiere Merkmale …";
        Task.Run(() =>
        {
            int hinzugefuegt = 0;
            for (int i = 0; i < dateien.Count; i++)
            {
                var datei = dateien[i];
                UI(() => TrainingStatusText = $"Merkmale ({i + 1}/{dateien.Count}): {Path.GetFileName(datei)}");
                try
                {
                    var sig = AudioFileHelper.Md5Signatur(datei);
                    var vektor = AudioAnalyzer.Merkmalsvektor(datei);
                    var probe = new TrainingsProbe
                    {
                        Id = Guid.NewGuid(),
                        DateiPfad = datei,
                        DateiName = Path.GetFileName(datei),
                        Label = label,
                        Merkmalsvektor = vektor,
                        DateiSignatur = sig,
                        HinzugefuegtAm = DateTime.Now
                    };
                    if (_trainingStore.Hinzufuegen(probe)) hinzugefuegt++;
                }
                catch { /* Datei überspringen */ }
            }
            UI(() =>
            {
                AktualisiereProben();
                AktualisiereDiagnose();
                IstBeschaeftigt = false;
                string bez = label == TrainingsLabel.Ki ? "KI-Musik" : "Echte Musik";
                TrainingStatusText = $"{hinzugefuegt} neue(s) Beispiel(e) als {bez} hinzugefügt (gesamt {_trainingStore.Proben.Count}). Tipp: „Modell trainieren“.";
            });
        });
    }

    public void StarteTraining()
    {
        var proben = _trainingStore.Proben.ToList();
        if (proben.Count < 2)
        {
            TrainingStatusText = $"Mindestens 2 Beispiele nötig (aktuell {proben.Count}).";
            return;
        }
        int echt = proben.Count(p => p.Label == TrainingsLabel.Echt);
        int ki = proben.Count(p => p.Label == TrainingsLabel.Ki);
        if (echt < 1 || ki < 1)
        {
            TrainingStatusText = $"Es werden Beispiele beider Klassen benötigt (echt: {echt}, KI: {ki}).";
            return;
        }
        IstBeschaeftigt = true;
        TrainingStatusText = $"Training läuft ({proben.Count} Beispiele) …";
        Task.Run(() =>
        {
            var lr = new LogisticRegression();
            var neuesModell = lr.Train(proben);
            try { MLModelManager.Shared.Save(neuesModell); } catch { }
            UI(() =>
            {
                Modell = neuesModell;
                TrainingAccuracy = neuesModell.KreuzvalidierungsGenauigkeit;
                TrainingStatusText = $"Training abgeschlossen — Genauigkeit {neuesModell.KreuzvalidierungsGenauigkeit * 100:F1} % ({proben.Count} Beispiele).";
                IstBeschaeftigt = false;
                OnPropertyChanged(nameof(ModellIstTrainiert));
            });
        });
    }

    public void LoescheAlleTrainingsdaten()
    {
        _trainingStore.Leeren();
        AktualisiereProben();
        AktualisiereDiagnose();
        TrainingStatusText = "Alle Trainingsdaten gelöscht.";
    }

    public void SpeicherordnerOeffnen()
    {
        try
        {
            Directory.CreateDirectory(_trainingStore.BasisOrdner);
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = _trainingStore.BasisOrdner,
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            StatusText = "Ordner konnte nicht geöffnet werden: " + ex.Message;
        }
    }

    private void AktualisiereDiagnose()
    {
        PersistenzOK = _trainingStore.PersistenzAktiv;
        SpeicherOrdner = _trainingStore.BasisOrdner;
        SpeicherFehler = PersistenzOK ? null : _trainingStore.LetzterFehler;
    }

    private void AktualisiereProben()
    {
        var proben = _trainingStore.Proben.ToList();
        TrainingProbes.Clear();
        foreach (var p in proben) TrainingProbes.Add(p);
        TrainingSampleCount = proben.Count;
        TrainingEchtCount = proben.Count(p => p.Label == TrainingsLabel.Echt);
        TrainingKICount = proben.Count(p => p.Label == TrainingsLabel.Ki);
        AktualisiereGenauigkeit();
    }

    private void AktualisiereGenauigkeit()
    {
        var m = Modell;
        if (m == null || TrainingProbes.Count == 0) return;
        int korrekt = 0, bewertet = 0;
        foreach (var probe in TrainingProbes)
        {
            if (probe.Merkmalsvektor.Length != m.Gewichte.Length) continue;
            double p = m.Vorhersage(probe.Merkmalsvektor);
            int vorhergesagt = p >= 0.5 ? 1 : 0;
            if (vorhergesagt == (int)probe.Label) korrekt++;
            bewertet++;
        }
        if (bewertet > 0) TrainingAccuracy = (double)korrekt / bewertet;
    }

    private static void UI(Action action)
    {
        var app = Application.Current;
        if (app?.Dispatcher != null && !app.Dispatcher.CheckAccess())
            app.Dispatcher.Invoke(action);
        else
            action();
    }
}
