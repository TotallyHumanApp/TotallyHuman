using System;
using System.IO;
using System.Text.Json;
using TotallyHuman.Models;
using TotallyHuman.Utilities;

namespace TotallyHuman.ML;

/// <summary>
/// Verwaltet ML-Modelle inkl. Persistenz. 1:1 Port von MLModelManager.swift.
/// Speicherort: %APPDATA%\TotallyHuman\ML\logistisches_modell.json
/// </summary>
public sealed class MLModelManager
{
    public static readonly MLModelManager Shared = new();

    public string StorageDir { get; }

    private static readonly JsonSerializerOptions PrettyOptions = new()
    {
        WriteIndented = true,
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
    };

    public MLModelManager()
    {
        StorageDir = Path.Combine(AppSpeicherort.Basis, "ML");
        try { Directory.CreateDirectory(StorageDir); } catch { /* ignore */ }
    }

    public string ModelPfad => Path.Combine(StorageDir, "logistisches_modell.json");

    public void Save(LogistischesModell model)
    {
        Directory.CreateDirectory(StorageDir);
        string json = JsonSerializer.Serialize(model, PrettyOptions);
        // Atomar schreiben
        string tmp = ModelPfad + ".tmp";
        File.WriteAllText(tmp, json);
        if (File.Exists(ModelPfad)) File.Delete(ModelPfad);
        File.Move(tmp, ModelPfad);
    }

    public LogistischesModell LoadModel()
    {
        string json = File.ReadAllText(ModelPfad);
        return JsonSerializer.Deserialize<LogistischesModell>(json)
               ?? throw new InvalidDataException("Modell konnte nicht dekodiert werden.");
    }

    public LogistischesModell? TryLoadModel()
    {
        try { return LoadModel(); }
        catch { return null; }
    }

    public LogistischesModell LoadOrCreateDefault(int featureCount = AnalysisConfig.FeatureVectorSize)
    {
        return TryLoadModel() ?? new LogistischesModell
        {
            Gewichte = new double[featureCount],
            Bias = 0.0,
            TrainingsZeit = DateTime.Now,
            AnzahlBeispiele = 0,
            KreuzvalidierungsGenauigkeit = 0.0
        };
    }

    public void StoreTrainedModel(LogisticRegression classifier) => Save(classifier.Model);
}
