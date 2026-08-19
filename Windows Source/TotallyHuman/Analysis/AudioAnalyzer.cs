using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using TotallyHuman.Utilities;

namespace TotallyHuman.Analysis;

/// <summary>
/// Native C#-Nachbildung der Python/Swift-Analysekette.
///
/// Der 128-dimensionale Merkmalsvektor wird EXAKT wie im Original berechnet:
///   1. Audio laden -> 44100 Hz, Mono, auf max |x| = 1.0 normalisiert
///   2. Zeitlich gemitteltes Leistungsspektrum (nFFT = 4096, hop = 1024, Hann-Fenster)
///   3. Grundlinie via Minimum- -> Maximum- -> Uniform-Filter (Fenster 21, Modus "reflect")
///   4. Fingerprint = Spektrum(dB) - Grundlinie(dB)  (KEINE Begrenzung auf >= 0)
///   5. Auf Band 5000-16000 Hz beschränken
///   6. In 128 gleich große Index-Bereiche aufteilen und je Bereich mitteln
/// </summary>
public static class AudioAnalyzer
{
    public const double SampleRate = 44100.0;
    public const int NFFT = 4096;
    public const int Hop = 1024;
    public const double BandUnten = 5000.0;
    public const double BandOben = 16000.0;
    public const int FeatureBins = 128;

    public class AnalyseResultat
    {
        public double[] FrequenzenBand = Array.Empty<double>();
        public double[] SpektrumBandDB = Array.Empty<double>();
        public double[] GrundlinieBandDB = Array.Empty<double>();
        public double[] FingerprintBand = Array.Empty<double>();
        public double[] Merkmalsvektor = Array.Empty<double>();   // 128-dim
        public double[] PeakFrequenzen = Array.Empty<double>();
        public double[] PeakProminenzen = Array.Empty<double>();
        public double PeakAbstandHz;
        public double Regelmaessigkeit;
        public double ArtefaktStaerke;
        public double DauerSekunden;
        public List<(double Start, double Ende)> SegmentZeiten = new();
        public List<double> SegmentStaerken = new();
    }

    public class AnalyseFehler : Exception
    {
        public AnalyseFehler(string message) : base(message) { }
    }

    // MARK: - Öffentliche API

    /// <summary>Liest eine Datei und führt die vollständige Analyse durch.</summary>
    public static AnalyseResultat Analysiere(string pfad)
    {
        double[] samples = AudioLoader.LadeMonoSamples(pfad, SampleRate);
        if (samples.Length == 0)
            throw new AnalyseFehler("Die Audiodatei enthält keine Samples.");
        return Analysiere(samples, SampleRate);
    }

    /// <summary>Berechnet nur den 128-dim Merkmalsvektor (für das Training).</summary>
    public static double[] Merkmalsvektor(string pfad) => Analysiere(pfad).Merkmalsvektor;

    // MARK: - Vollständige Analyse

    public static AnalyseResultat Analysiere(double[] samples, double sr)
    {
        // 1. Gemitteltes Leistungsspektrum (dB) + Frequenzen
        var (freqs, spektrumDB) = MittleresSpektrumDB(samples, sr, NFFT, Hop);

        // 2. Grundlinie über volle Auflösung
        var grundlinie = SchaetzeGrundlinie(spektrumDB, 21);

        // 3. Fingerprint über volle Auflösung
        var fingerprintVoll = new double[spektrumDB.Length];
        for (int i = 0; i < spektrumDB.Length; i++)
            fingerprintVoll[i] = spektrumDB[i] - grundlinie[i];

        // 4. Band beschränken
        double nyquist = sr / 2.0;
        double ober = Math.Min(BandOben, nyquist - 1.0);
        var idxBand = new List<int>(freqs.Length);
        for (int i = 0; i < freqs.Length; i++)
            if (freqs[i] >= BandUnten && freqs[i] <= ober)
                idxBand.Add(i);

        var fBand = idxBand.Select(i => freqs[i]).ToArray();
        var fpBand = idxBand.Select(i => fingerprintVoll[i]).ToArray();
        var spekBand = idxBand.Select(i => spektrumDB[i]).ToArray();
        var grundBand = idxBand.Select(i => grundlinie[i]).ToArray();

        // 5. 128-dim Merkmalsvektor
        var vektor = BinMittel(fpBand, FeatureBins);

        // 6. Peaks & Regelmäßigkeit
        var (peakFreqs, peakProms) = FindePeaks(fpBand, fBand, 1.0);
        var (abstand, regel) = BewerteRegelmaessigkeit(peakFreqs, fpBand);
        int topN = Math.Min(10, peakProms.Length);
        double topProminenz = topN > 0
            ? peakProms.OrderBy(x => x).TakeLast(topN).Sum() / topN
            : 0.0;
        double artefakt = topProminenz * (0.3 + 0.7 * regel);

        double dauer = samples.Length / sr;

        // Zeitliche Segmente (10 s)
        var segZeiten = new List<(double, double)>();
        var segStaerken = new List<double>();
        int segLen = (int)(10.0 * sr);
        if (segLen > 0)
        {
            int start = 0;
            while (start < samples.Length)
            {
                int ende = Math.Min(start + segLen, samples.Length);
                if (ende - start < (int)(2.0 * sr)) break;
                var seg = new double[ende - start];
                Array.Copy(samples, start, seg, 0, ende - start);
                var (_, sdb) = MittleresSpektrumDB(seg, sr, NFFT, Hop);
                var baseLine = SchaetzeGrundlinie(sdb, 21);
                var fp = new double[sdb.Length];
                for (int i = 0; i < sdb.Length; i++) fp[i] = sdb[i] - baseLine[i];
                var bandFp = idxBand.Where(i => i < fp.Length).Select(i => fp[i]).ToArray();
                var (_, pr) = FindePeaks(bandFp, fBand, 1.0);
                int tN = Math.Min(10, pr.Length);
                double tp = tN > 0 ? pr.OrderBy(x => x).TakeLast(tN).Sum() / tN : 0.0;
                segZeiten.Add(((double)start / sr, (double)ende / sr));
                segStaerken.Add(tp);
                start += segLen;
            }
        }

        return new AnalyseResultat
        {
            FrequenzenBand = fBand,
            SpektrumBandDB = spekBand,
            GrundlinieBandDB = grundBand,
            FingerprintBand = fpBand,
            Merkmalsvektor = vektor,
            PeakFrequenzen = peakFreqs,
            PeakProminenzen = peakProms,
            PeakAbstandHz = abstand,
            Regelmaessigkeit = regel,
            ArtefaktStaerke = artefakt,
            DauerSekunden = dauer,
            SegmentZeiten = segZeiten,
            SegmentStaerken = segStaerken
        };
    }

    // MARK: - Gemitteltes Leistungsspektrum

    public static (double[] Freqs, double[] Db) MittleresSpektrumDB(double[] signal, double sr, int nFFT, int hop)
    {
        int halfN = nFFT / 2;
        int bins = halfN + 1;   // wie np.fft.rfft: N/2 + 1
        var frequenzen = new double[bins];
        for (int i = 0; i < bins; i++)
            frequenzen[i] = i * sr / nFFT;

        // Hann-Fenster exakt wie np.hanning: w[n] = 0.5 - 0.5*cos(2*pi*n/(N-1))
        var fenster = new double[nFFT];
        double denom = nFFT - 1;
        for (int n = 0; n < nFFT; n++)
            fenster[n] = 0.5 - 0.5 * Math.Cos(2.0 * Math.PI * n / denom);

        var powerSumme = new double[bins];
        int frameZahl = 0;

        var re = new double[nFFT];
        var im = new double[nFFT];

        void ProcessFrame(int start)
        {
            for (int n = 0; n < nFFT; n++)
            {
                int idx = start + n;
                double s = (idx >= 0 && idx < signal.Length) ? signal[idx] : 0.0;
                re[n] = s * fenster[n];
                im[n] = 0.0;
            }
            Fft.Forward(re, im);
            for (int k = 0; k < bins; k++)
                powerSumme[k] += re[k] * re[k] + im[k] * im[k];
        }

        if (signal.Length >= nFFT)
        {
            int letzterStart = signal.Length - nFFT;
            int start = 0;
            while (start <= letzterStart)
            {
                ProcessFrame(start);
                frameZahl++;
                start += hop;
            }
        }

        if (frameZahl == 0)
        {
            // Signal kürzer als nFFT: einmal mit Zero-Padding.
            ProcessFrame(0);
            frameZahl = 1;
        }

        double inv = 1.0 / frameZahl;
        var db = new double[bins];
        for (int k = 0; k < bins; k++)
            db[k] = 10.0 * Math.Log10(powerSumme[k] * inv + 1e-12);
        return (frequenzen, db);
    }

    // MARK: - Grundlinie (Minimum -> Maximum -> Uniform), reflect

    public static double[] SchaetzeGrundlinie(double[] spektrumDB, int fensterBins)
    {
        var untere = MinimumFilter1d(spektrumDB, fensterBins);
        var obere = MaximumFilter1d(untere, fensterBins);
        return UniformFilter1d(obere, fensterBins);
    }

    private static int ReflectIndex(int j, int n)
    {
        // scipy 'reflect' (d c b a | a b c d | d c b a)
        if (n == 1) return 0;
        int i = j;
        int periode = 2 * n;
        i = ((i % periode) + periode) % periode;
        if (i >= n) i = periode - 1 - i;
        return i;
    }

    private static double[] MinimumFilter1d(double[] x, int size)
    {
        int n = x.Length;
        if (n == 0) return x;
        int r = size / 2;
        var outArr = new double[n];
        for (int i = 0; i < n; i++)
        {
            double m = double.MaxValue;
            for (int d = -r; d <= r; d++)
            {
                double v = x[ReflectIndex(i + d, n)];
                if (v < m) m = v;
            }
            outArr[i] = m;
        }
        return outArr;
    }

    private static double[] MaximumFilter1d(double[] x, int size)
    {
        int n = x.Length;
        if (n == 0) return x;
        int r = size / 2;
        var outArr = new double[n];
        for (int i = 0; i < n; i++)
        {
            double m = double.MinValue;
            for (int d = -r; d <= r; d++)
            {
                double v = x[ReflectIndex(i + d, n)];
                if (v > m) m = v;
            }
            outArr[i] = m;
        }
        return outArr;
    }

    private static double[] UniformFilter1d(double[] x, int size)
    {
        int n = x.Length;
        if (n == 0) return x;
        int r = size / 2;
        var outArr = new double[n];
        for (int i = 0; i < n; i++)
        {
            double s = 0.0;
            for (int d = -r; d <= r; d++)
                s += x[ReflectIndex(i + d, n)];
            outArr[i] = s / size;
        }
        return outArr;
    }

    // MARK: - 128-Bin-Mittelung (np.linspace Index-Aufteilung)

    public static double[] BinMittel(double[] fp, int bins)
    {
        if (fp.Length == 0) return new double[bins];
        var grenzen = new int[bins + 1];
        double size = fp.Length;
        for (int i = 0; i <= bins; i++)
            grenzen[i] = (int)(size * i / bins);   // linspace(0, size, bins+1)
        var outArr = new double[bins];
        for (int i = 0; i < bins; i++)
        {
            int a = grenzen[i];
            int b = grenzen[i + 1];
            if (b > a)
            {
                double s = 0.0;
                for (int k = a; k < b; k++) s += fp[k];
                outArr[i] = s / (b - a);
            }
            else
            {
                outArr[i] = 0.0;
            }
        }
        return outArr;
    }

    // MARK: - Peak-Erkennung (vereinfachte scipy.find_peaks-Nachbildung)

    private static (double[] Freqs, double[] Proms) FindePeaks(double[] fp, double[] f, double prominenz)
    {
        if (fp.Length < 3) return (Array.Empty<double>(), Array.Empty<double>());
        var freqs = new List<double>();
        var proms = new List<double>();
        for (int i = 1; i < fp.Length - 1; i++)
        {
            if (fp[i] > fp[i - 1] && fp[i] >= fp[i + 1] && fp[i] >= prominenz)
            {
                double linksMin = fp[i];
                int j = i;
                while (j > 0 && fp[j] <= fp[i]) { linksMin = Math.Min(linksMin, fp[j]); j--; }
                double rechtsMin = fp[i];
                int k = i;
                while (k < fp.Length - 1 && fp[k] <= fp[i]) { rechtsMin = Math.Min(rechtsMin, fp[k]); k++; }
                double basis = Math.Max(linksMin, rechtsMin);
                double p = fp[i] - basis;
                if (p >= prominenz)
                {
                    freqs.Add(f[i]);
                    proms.Add(p);
                }
            }
        }
        return (freqs.ToArray(), proms.ToArray());
    }

    private static (double Abstand, double Regel) BewerteRegelmaessigkeit(double[] peakFrequenzen, double[] fp)
    {
        if (peakFrequenzen.Length < 3) return (0, 0);
        var sortiert = peakFrequenzen.OrderBy(x => x).ToArray();
        var abstaende = new List<double>();
        for (int i = 1; i < sortiert.Length; i++)
            abstaende.Add(sortiert[i] - sortiert[i - 1]);
        double mittel = abstaende.Sum() / abstaende.Count;
        double regelAbstand = 0.0;
        if (mittel > 1e-6)
        {
            double varianz = abstaende.Select(a => Math.Pow(a - mittel, 2)).Sum() / abstaende.Count;
            double cv = Math.Sqrt(varianz) / mittel;
            regelAbstand = Math.Max(0, Math.Min(1, 1 - cv));
        }

        double m = fp.Sum() / fp.Length;
        var zentriert = fp.Select(v => v - m).ToArray();
        double auto0 = 0.0;
        foreach (var v in zentriert) auto0 += v * v;
        double regelAuto = 0.0;
        if (auto0 > 1e-9)
        {
            double maxNeben = 0.0;
            int maxLag = Math.Min(zentriert.Length - 1, zentriert.Length);
            if (zentriert.Length > 5)
            {
                for (int lag = 3; lag < maxLag; lag++)
                {
                    double s = 0.0;
                    for (int i = 0; i < zentriert.Length - lag; i++)
                        s += zentriert[i] * zentriert[i + lag];
                    double norm = s / auto0;
                    if (norm > maxNeben) maxNeben = norm;
                }
            }
            regelAuto = Math.Max(0, Math.Min(1, maxNeben));
        }
        double regel = 0.5 * regelAbstand + 0.5 * regelAuto;
        return (mittel, Math.Max(0, Math.Min(1, regel)));
    }
}
