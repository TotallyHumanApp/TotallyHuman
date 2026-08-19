using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using TotallyHuman.Models;
using TotallyHuman.Utilities;

namespace TotallyHuman.Analysis;

/// <summary>
/// Führt eine echte Datei-Analyse durch: dekodiert das Audio, berechnet den
/// kompatiblen Merkmalsvektor und klassifiziert mit dem trainierten Modell.
/// 1:1 Port von DetectionEngine.swift.
/// </summary>
public sealed class DetectionEngine
{
    public DetektionsErgebnis Analysiere(string pfad, LogistischesModell? modell)
    {
        var res = AudioAnalyzer.Analysiere(pfad);

        bool modellTrainiert = (modell?.AnzahlBeispiele ?? 0) > 0
                               && (modell?.Gewichte.Length == res.Merkmalsvektor.Length);
        double kiWahrscheinlichkeit;
        AnalyseModus modus;
        if (modellTrainiert && modell != null)
        {
            kiWahrscheinlichkeit = modell.Vorhersage(res.Merkmalsvektor);
            modus = AnalyseModus.Trainiert;
        }
        else
        {
            // Heuristik: Artefaktstärke auf 0..1 abbilden.
            kiWahrscheinlichkeit = Math.Max(0, Math.Min(1, res.ArtefaktStaerke / 6.0));
            modus = AnalyseModus.Heuristisch;
        }

        double prozent = kiWahrscheinlichkeit * 100.0;
        bool istKI = kiWahrscheinlichkeit >= 0.5;
        Empfehlung empfehlung;
        if (kiWahrscheinlichkeit >= 0.6) empfehlung = Empfehlung.KlarKiGeneriert;
        else if (kiWahrscheinlichkeit <= 0.4) empfehlung = Empfehlung.KlarMenschlich;
        else empfehlung = Empfehlung.ManuellePruefung;

        double konfidenz = Math.Min(1.0, Math.Abs(kiWahrscheinlichkeit - 0.5) * 2.0);
        double staerkstesSegment = res.SegmentStaerken.Count > 0 ? res.SegmentStaerken.Max() : 0;
        double zeitlicherAnteil = res.SegmentStaerken.Count == 0
            ? 0
            : (double)res.SegmentStaerken.Count(s => s > 1.0) / res.SegmentStaerken.Count * 100.0;

        var hinweise = new List<string>();
        hinweise.Add(modellTrainiert
            ? $"Klassifikation mit trainiertem Modell ({modell?.AnzahlBeispiele ?? 0} Beispiele)."
            : "Heuristische Analyse (kein trainiertes Modell).");
        if (res.Regelmaessigkeit > 0.6) hinweise.Add("Regelmäßige Spektral-Peaks erkannt (Indiz für KI).");
        if (staerkstesSegment > 2.0) hinweise.Add("Auffällige Artefakte in einzelnen Zeitsegmenten.");

        bool verschleierung = res.Regelmaessigkeit > 0.75 && res.PeakFrequenzen.Length > 12;

        return new DetektionsErgebnis
        {
            DateiPfad = pfad,
            DateiName = Path.GetFileName(pfad),
            IstKIGeneriert = istKI,
            KiWahrscheinlichkeitProzent = prozent,
            ArtefaktScore = res.ArtefaktStaerke,
            Einstufung = istKI ? "KI-generiert" : "Menschlich",
            Empfehlung = empfehlung,
            KonfidenzScore = konfidenz,
            KonfidenzText = konfidenz > 0.6 ? "hoch" : (konfidenz > 0.3 ? "mittel" : "niedrig"),
            AnzahlPeaks = res.PeakFrequenzen.Length,
            MittlererPeakAbstandHz = res.PeakAbstandHz,
            PeakRegelmaessigkeit = res.Regelmaessigkeit,
            SsmScore = 0,
            EnsembleScores = Array.Empty<double>(),
            EnsembleVarianz = 0,
            ZeitlicherKIAnteilProzent = zeitlicherAnteil,
            SplicePositionen = Array.Empty<int>(),
            VerschleierungsHinweise = verschleierung
                ? new List<string> { "Sehr regelmäßige Struktur — möglicher Verschleierungsversuch." }
                : new List<string>(),
            VerschleierungsVerdacht = verschleierung,
            Modus = modus,
            Hinweise = hinweise,
            AnalyseDatum = DateTime.Now,
            FrequenzBandAnteile = Array.Empty<double>(),
            FrequenzBandGrenzen = Array.Empty<double[]>(),
            SegmentZeiten = res.SegmentZeiten.Select(t => new[] { t.Start, t.Ende }).ToArray(),
            SegmentStaerken = res.SegmentStaerken.ToArray(),
            SpektrumFrequenzen = res.FrequenzenBand,
            SpektrumWerte = res.SpektrumBandDB,
            FingerprintWerte = res.FingerprintBand,
            GrundlinieWerte = res.GrundlinieBandDB,
            SsmMatrix = Array.Empty<double[]>()
        };
    }

    /// <summary>MD5-Signatur zur Deduplizierung.</summary>
    public static string Signatur(string pfad) => AudioFileHelper.Md5Signatur(pfad);
}
