using System;

namespace TotallyHuman.Analysis;

/// <summary>
/// Iterative Radix-2 Cooley-Tukey FFT (in-place) für Größen, die Zweierpotenzen sind
/// (2048 / 4096 / 8192). Ersetzt Apples vDSP aus dem Swift-Original.
///
/// Ein konstanter, über alle Bins gleicher Skalierungsfaktor ist unkritisch, da er
/// sich im Fingerprint (Spektrum - Grundlinie, in dB) vollständig heraushebt.
/// </summary>
public static class Fft
{
    /// <summary>Vorwärts-FFT in-place. re/im müssen Länge n (Zweierpotenz) haben.</summary>
    public static void Forward(double[] re, double[] im)
    {
        int n = re.Length;
        if (n <= 1) return;

        // Bit-Reversal-Permutation
        for (int i = 1, j = 0; i < n; i++)
        {
            int bit = n >> 1;
            for (; (j & bit) != 0; bit >>= 1)
                j ^= bit;
            j ^= bit;
            if (i < j)
            {
                (re[i], re[j]) = (re[j], re[i]);
                (im[i], im[j]) = (im[j], im[i]);
            }
        }

        // Danielson-Lanczos
        for (int len = 2; len <= n; len <<= 1)
        {
            double ang = -2.0 * Math.PI / len;
            double wReal = Math.Cos(ang);
            double wImag = Math.Sin(ang);
            for (int i = 0; i < n; i += len)
            {
                double curReal = 1.0;
                double curImag = 0.0;
                for (int k = 0; k < len / 2; k++)
                {
                    int a = i + k;
                    int b = i + k + len / 2;
                    double tReal = re[b] * curReal - im[b] * curImag;
                    double tImag = re[b] * curImag + im[b] * curReal;
                    re[b] = re[a] - tReal;
                    im[b] = im[a] - tImag;
                    re[a] += tReal;
                    im[a] += tImag;
                    double nextReal = curReal * wReal - curImag * wImag;
                    curImag = curReal * wImag + curImag * wReal;
                    curReal = nextReal;
                }
            }
        }
    }
}
