using System;
using System.Collections.Generic;
using System.Linq;
using TotallyHuman.Models;

namespace TotallyHuman.Analysis;

/// <summary>Segmentweise FFT-Ensemble-Analyse. 1:1 Port von FFTAnalyzer.swift.</summary>
public sealed class FFTAnalyzer
{
    public EnsembleErgebnis AnalysiereEnsemble(double[] samples, double sampleRate)
    {
        var fftGroessen = AnalysisConfig.FftSizes;
        var fftWeights = AnalysisConfig.FftWeights;
        var resultate = new List<ArtefaktErgebnis>();
        var einzelScores = new List<double>();

        foreach (var groesse in fftGroessen)
        {
            var artefakt = Analysiere(samples, sampleRate, groesse);
            resultate.Add(artefakt);
            einzelScores.Add(artefakt.ArtefaktStaerke);
        }

        double gewichteteSumme = 0;
        for (int i = 0; i < einzelScores.Count; i++)
            gewichteteSumme += einzelScores[i] * fftWeights[i];
        double normGewichte = fftWeights.Sum();
        double ensembleScore = normGewichte > 0 ? gewichteteSumme / normGewichte : 0;
        double mean = einzelScores.Sum() / Math.Max(1, einzelScores.Count);
        double ensembleVarianz = einzelScores.Select(s => Math.Pow(s - mean, 2)).Sum() / Math.Max(1, einzelScores.Count);
        var hauptErgebnis = resultate[Math.Min(1, Math.Max(0, resultate.Count - 1))];

        return new EnsembleErgebnis
        {
            HauptErgebnis = hauptErgebnis,
            EinzelScores = einzelScores.ToArray(),
            EnsembleVarianz = ensembleVarianz,
            EnsembleScore = ensembleScore
        };
    }

    public ArtefaktErgebnis Analysiere(double[] samples, double sampleRate, int fftSize)
    {
        var segment = samples.Take(fftSize).ToArray();
        var padded = Pad(segment, fftSize);
        var spektrum = AmplitudeSpectrum(padded, fftSize);
        var freqs = Frequenzen(fftSize, sampleRate);
        var band = AnalysisConfig.AnalysisFreqBandHz;
        var selektierteIndizes = Enumerable.Range(0, freqs.Length)
            .Where(i => freqs[i] >= band.Unten && freqs[i] <= band.Oben).ToArray();
        var selektierteFrequenzen = selektierteIndizes.Select(i => freqs[i]).ToArray();
        var selektiertesSpektrum = selektierteIndizes.Select(i => spektrum[i]).ToArray();
        var grundlinie = MorphologischeGrundlinie(selektiertesSpektrum);
        var fingerprint = new double[selektiertesSpektrum.Length];
        for (int i = 0; i < fingerprint.Length; i++)
            fingerprint[i] = Math.Max(0, selektiertesSpektrum[i] - grundlinie[i]);
        var peaks = ErkennePeaks(fingerprint);
        var peakIndizes = peaks.Select(p => p.Index).ToArray();
        var peakFrequenzen = peaks.Select(p => selektierteFrequenzen[p.Index]).ToArray();
        var peakProminenzen = peaks.Select(p => p.Prominenz).ToArray();
        var peakAbstandHz = MittlererPeakAbstand(peakFrequenzen);
        var regelmaessigkeit = BerechneRegelmaessigkeit(peakFrequenzen, peakProminenzen);
        var artefaktStaerke = BerechneArtefaktStaerke(fingerprint, peaks, regelmaessigkeit);

        return new ArtefaktErgebnis
        {
            Frequenzen = selektierteFrequenzen,
            MittleresSpektrumDB = selektiertesSpektrum,
            GrundlinieDB = grundlinie,
            Fingerprint = fingerprint,
            PeakIndizes = peakIndizes,
            PeakFrequenzen = peakFrequenzen,
            PeakProminenzen = peakProminenzen,
            PeakAbstandHz = peakAbstandHz,
            Regelmaessigkeit = regelmaessigkeit,
            ArtefaktStaerke = artefaktStaerke,
            AnzahlPeaks = peakIndizes.Length
        };
    }

    private static double[] Pad(double[] segment, int fftSize)
    {
        if (segment.Length >= fftSize) return segment.Take(fftSize).ToArray();
        var outArr = new double[fftSize];
        Array.Copy(segment, outArr, segment.Length);
        return outArr;
    }

    private static double[] AmplitudeSpectrum(double[] samples, int fftSize)
    {
        if (fftSize <= 0 || samples.Length < fftSize) return Array.Empty<double>();
        int halfN = fftSize / 2;
        // Hamming-Fenster: 0.54 - 0.46*cos(2*pi*n/(N-1))  (wie vDSP_hamm_window)
        var re = new double[fftSize];
        var im = new double[fftSize];
        double denom = fftSize - 1;
        for (int n = 0; n < fftSize; n++)
        {
            double w = 0.54 - 0.46 * Math.Cos(2.0 * Math.PI * n / denom);
            re[n] = samples[n] * w;
            im[n] = 0.0;
        }
        Fft.Forward(re, im);
        var magnitudes = new double[halfN];
        for (int k = 0; k < halfN; k++)
        {
            double mag = re[k] * re[k] + im[k] * im[k];
            magnitudes[k] = 10.0 * Math.Log10(Math.Max(mag, 1e-12));
        }
        return magnitudes;
    }

    private static double[] Frequenzen(int fftSize, double sampleRate)
    {
        int bins = Math.Max(1, fftSize / 2);
        var f = new double[bins];
        for (int i = 0; i < bins; i++) f[i] = i * sampleRate / fftSize;
        return f;
    }

    private static double[] MorphologischeGrundlinie(double[] values)
    {
        if (values.Length == 0) return Array.Empty<double>();
        int radius = Math.Max(2, values.Length / 64);
        var outArr = new double[values.Length];
        for (int index = 0; index < values.Length; index++)
        {
            int lower = Math.Max(0, index - radius);
            int upper = Math.Min(values.Length - 1, index + radius);
            double m = double.MaxValue;
            for (int j = lower; j <= upper; j++) m = Math.Min(m, values[j]);
            outArr[index] = m;
        }
        return outArr;
    }

    private static List<(int Index, double Prominenz)> ErkennePeaks(double[] values)
    {
        var peaks = new List<(int, double)>();
        if (values.Length < 3) return peaks;
        for (int i = 1; i < values.Length - 1; i++)
        {
            if (values[i] > values[i - 1] && values[i] >= values[i + 1] && values[i] > 0.15)
            {
                double leftMin = double.MaxValue;
                for (int j = Math.Max(0, i - 8); j <= i; j++) leftMin = Math.Min(leftMin, values[j]);
                double rightMin = double.MaxValue;
                for (int j = i; j <= Math.Min(values.Length - 1, i + 8); j++) rightMin = Math.Min(rightMin, values[j]);
                double localMin = Math.Min(leftMin, rightMin);
                peaks.Add((i, Math.Max(0, values[i] - localMin)));
            }
        }
        return peaks.OrderByDescending(p => p.Item2).Select(p => (p.Item1, p.Item2)).ToList();
    }

    private static double MittlererPeakAbstand(double[] frequenzen)
    {
        if (frequenzen.Length < 2) return 0;
        double s = 0;
        for (int i = 1; i < frequenzen.Length; i++) s += frequenzen[i] - frequenzen[i - 1];
        return s / (frequenzen.Length - 1);
    }

    private static double BerechneRegelmaessigkeit(double[] peakFrequenzen, double[] prominenzen)
    {
        if (peakFrequenzen.Length < 2) return 0;
        var abstaende = new double[peakFrequenzen.Length - 1];
        for (int i = 1; i < peakFrequenzen.Length; i++) abstaende[i - 1] = peakFrequenzen[i] - peakFrequenzen[i - 1];
        double mean = abstaende.Sum() / abstaende.Length;
        double variance = abstaende.Select(a => Math.Pow(a - mean, 2)).Sum() / abstaende.Length;
        double cv = mean > 0 ? Math.Sqrt(variance) / mean : 1;
        double prominenceScore = Math.Min(1, (prominenzen.Sum() / prominenzen.Length) / 6.0);
        return Math.Max(0, Math.Min(1, (1.0 - Math.Min(cv, 1.0)) * 0.7 + prominenceScore * 0.3));
    }

    private static double BerechneArtefaktStaerke(double[] fingerprint, List<(int Index, double Prominenz)> peaks, double regelmaessigkeit)
    {
        double peakScore = Math.Min(1, peaks.Count / 12.0);
        double meanFingerprint = fingerprint.Length == 0 ? 0 : fingerprint.Sum() / fingerprint.Length;
        double energyScore = Math.Min(1, Math.Max(0, meanFingerprint / 12.0));
        double regularityBonus = regelmaessigkeit * 0.35;
        return Math.Max(0, Math.Min(1, peakScore * 0.45 + energyScore * 0.4 + regularityBonus));
    }
}
