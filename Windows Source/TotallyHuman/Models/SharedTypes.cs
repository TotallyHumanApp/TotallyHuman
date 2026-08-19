using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace TotallyHuman.Models;

// SharedTypes.cs — Gemeinsame Datenmodelle (1:1 Port von SharedTypes.swift)
// Totally Human — KI-Musik-Detektor / AI Music Detector

/// <summary>Zentrale Analyse-Konfiguration.</summary>
public static class AnalysisConfig
{
    public const double StandardSampleRate = 44100.0;
    public static readonly int[] FftSizes = { 2048, 4096, 8192 };
    public static readonly double[] FftWeights = { 0.25, 0.45, 0.30 };
    public const double SsmWeight = 0.15;
    public static readonly (double Unten, double Oben) AnalysisFreqBandHz = (5000.0, 16000.0);
    public const double SegmentLengthSeconds = 10.0;
    public const int FeatureVectorSize = 128;
    public static readonly HashSet<string> SupportedExtensions = new(StringComparer.OrdinalIgnoreCase)
        { "mp3", "wav", "aiff", "aif", "m4a", "flac", "ogg", "opus", "wma", "alac" };
}

// MARK: - Artefakt-Ergebnis (Fingerprint einer FFT-Größe)
public struct ArtefaktErgebnis
{
    public double[] Frequenzen;
    public double[] MittleresSpektrumDB;
    public double[] GrundlinieDB;
    public double[] Fingerprint;
    public int[] PeakIndizes;
    public double[] PeakFrequenzen;
    public double[] PeakProminenzen;
    public double PeakAbstandHz;
    public double Regelmaessigkeit;
    public double ArtefaktStaerke;
    public int AnzahlPeaks;
}

// MARK: - Ensemble-Ergebnis
public struct EnsembleErgebnis
{
    public ArtefaktErgebnis HauptErgebnis;
    public double[] EinzelScores;
    public double EnsembleVarianz;
    public double EnsembleScore;
}

/// <summary>Empfehlungs-Kategorie der Detektion.</summary>
public enum Empfehlung
{
    KlarKiGeneriert,
    KlarMenschlich,
    ManuellePruefung,
    Verschleierungsverdacht
}

public static class EmpfehlungExtensions
{
    /// <summary>Roher String-Wert (kompatibel mit Swift-Enum rawValue).</summary>
    public static string RawValue(this Empfehlung e) => e switch
    {
        Empfehlung.KlarKiGeneriert => "KLAR KI-GENERIERT",
        Empfehlung.KlarMenschlich => "KLAR MENSCHLICH",
        Empfehlung.ManuellePruefung => "MANUELLE PRÜFUNG EMPFOHLEN",
        Empfehlung.Verschleierungsverdacht => "VERSCHLEIERUNGSVERDACHT",
        _ => ""
    };

    /// <summary>Farbe (red/green/orange/purple) wie im Original.</summary>
    public static string Farbe(this Empfehlung e) => e switch
    {
        Empfehlung.KlarKiGeneriert => "red",
        Empfehlung.KlarMenschlich => "green",
        Empfehlung.ManuellePruefung => "orange",
        Empfehlung.Verschleierungsverdacht => "purple",
        _ => "orange"
    };
}

/// <summary>Analysemodus: heuristisch oder trainiert.</summary>
public enum AnalyseModus
{
    Heuristisch,
    Trainiert
}

public static class AnalyseModusExtensions
{
    public static string RawValue(this AnalyseModus m) => m == AnalyseModus.Trainiert ? "trainiert" : "heuristisch";
}

/// <summary>Vollständiges Detektions-Ergebnis (1:1 zu DetektionsErgebnis.swift).</summary>
public class DetektionsErgebnis
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string DateiPfad { get; set; } = "";
    public string DateiName { get; set; } = "";
    public bool IstKIGeneriert { get; set; }
    public double KiWahrscheinlichkeitProzent { get; set; }
    public double ArtefaktScore { get; set; }
    public string Einstufung { get; set; } = "";
    public Empfehlung Empfehlung { get; set; } = Empfehlung.ManuellePruefung;
    public double KonfidenzScore { get; set; }
    public string KonfidenzText { get; set; } = "";
    public int AnzahlPeaks { get; set; }
    public double MittlererPeakAbstandHz { get; set; }
    public double PeakRegelmaessigkeit { get; set; }
    public double SsmScore { get; set; }
    public double[] EnsembleScores { get; set; } = Array.Empty<double>();
    public double EnsembleVarianz { get; set; }
    public double ZeitlicherKIAnteilProzent { get; set; }
    public int[] SplicePositionen { get; set; } = Array.Empty<int>();
    public List<string> VerschleierungsHinweise { get; set; } = new();
    public bool VerschleierungsVerdacht { get; set; }
    public AnalyseModus Modus { get; set; } = AnalyseModus.Heuristisch;
    public List<string> Hinweise { get; set; } = new();
    public DateTime AnalyseDatum { get; set; } = DateTime.Now;

    // Detail-Daten für die Visualisierung
    public double[] FrequenzBandAnteile { get; set; } = Array.Empty<double>();
    public double[][] FrequenzBandGrenzen { get; set; } = Array.Empty<double[]>();
    public double[][] SegmentZeiten { get; set; } = Array.Empty<double[]>();
    public double[] SegmentStaerken { get; set; } = Array.Empty<double>();
    public double[] SpektrumFrequenzen { get; set; } = Array.Empty<double>();
    public double[] SpektrumWerte { get; set; } = Array.Empty<double>();
    public double[] FingerprintWerte { get; set; } = Array.Empty<double>();
    public double[] GrundlinieWerte { get; set; } = Array.Empty<double>();
    public double[][] SsmMatrix { get; set; } = Array.Empty<double[]>();
}

/// <summary>Label für Trainingsproben.</summary>
public enum TrainingsLabel
{
    Echt = 0,
    Ki = 1
}

/// <summary>Eine einzelne Trainingsprobe (128-dim Merkmalsvektor).</summary>
public class TrainingsProbe
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [JsonPropertyName("dateiPfad")]
    public string DateiPfad { get; set; } = "";

    [JsonPropertyName("dateiName")]
    public string DateiName { get; set; } = "";

    // Serialisiert als Int (0/1) — kompatibel mit Swift & Seed-JSON.
    [JsonPropertyName("label")]
    public int LabelRaw { get; set; }

    [JsonIgnore]
    public TrainingsLabel Label
    {
        get => LabelRaw == 1 ? TrainingsLabel.Ki : TrainingsLabel.Echt;
        set => LabelRaw = (int)value;
    }

    [JsonPropertyName("merkmalsvektor")]
    public double[] Merkmalsvektor { get; set; } = Array.Empty<double>();

    [JsonPropertyName("dateiSignatur")]
    public string DateiSignatur { get; set; } = "";

    [JsonPropertyName("hinzugefuegtAm")]
    public DateTime HinzugefuegtAm { get; set; } = DateTime.Now;
}

/// <summary>Logistisches Modell (Gewichte + Bias). 1:1 zu LogistischesModell.swift.</summary>
public class LogistischesModell
{
    [JsonPropertyName("gewichte")]
    public double[] Gewichte { get; set; } = Array.Empty<double>();

    [JsonPropertyName("bias")]
    public double Bias { get; set; }

    [JsonPropertyName("trainingsZeit")]
    public DateTime TrainingsZeit { get; set; } = DateTime.Now;

    [JsonPropertyName("anzahlBeispiele")]
    public int AnzahlBeispiele { get; set; }

    [JsonPropertyName("kreuzvalidierungsGenauigkeit")]
    public double KreuzvalidierungsGenauigkeit { get; set; }

    /// <summary>Sigmoid-Vorhersage der KI-Wahrscheinlichkeit.</summary>
    public double Vorhersage(double[] merkmale)
    {
        if (merkmale.Length != Gewichte.Length) return 0.5;
        double summe = Bias;
        for (int i = 0; i < merkmale.Length; i++)
            summe += Gewichte[i] * merkmale[i];
        return Sigmoid(summe);
    }

    private static double Sigmoid(double x)
    {
        if (x >= 0) return 1.0 / (1.0 + Math.Exp(-x));
        double z = Math.Exp(x);
        return z / (1.0 + z);
    }
}
