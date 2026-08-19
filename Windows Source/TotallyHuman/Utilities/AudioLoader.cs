using System;
using System.Collections.Generic;
using System.IO;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;
using NAudio.Vorbis;

namespace TotallyHuman.Utilities;

/// <summary>
/// Dekodiert beliebige Audiodateien zu Mono-Float bei der Zielrate (44100 Hz) und
/// normalisiert auf max |x| = 1.0 — Windows-Äquivalent zu AVFoundation im Swift-Original.
///
/// Verwendet NAudio: MediaFoundationReader für mp3/wav/m4a/aac/wma/flac/aiff,
/// NAudio.Vorbis für ogg/opus. Fallback auf AudioFileReader.
/// </summary>
public static class AudioLoader
{
    public static double[] LadeMonoSamples(string pfad, double zielRate)
    {
        using WaveStream reader = OeffneReader(pfad);
        ISampleProvider sampleProvider = reader.ToSampleProvider();

        // Mehrkanal -> Mono (Mittelwert aller Kanäle)
        if (sampleProvider.WaveFormat.Channels > 1)
            sampleProvider = new MultiChannelToMonoSampleProvider(sampleProvider);

        // Resampling auf Zielrate
        if (Math.Abs(sampleProvider.WaveFormat.SampleRate - zielRate) > 0.5)
            sampleProvider = new WdlResamplingSampleProvider(sampleProvider, (int)zielRate);

        // Alle Samples einlesen
        var alle = new List<float>(1 << 20);
        var puffer = new float[16384];
        int gelesen;
        while ((gelesen = sampleProvider.Read(puffer, 0, puffer.Length)) > 0)
            for (int i = 0; i < gelesen; i++)
                alle.Add(puffer[i]);

        int anzahl = alle.Count;
        var outArr = new double[anzahl];
        double maxBetrag = 0.0;
        for (int i = 0; i < anzahl; i++)
        {
            double v = alle[i];
            outArr[i] = v;
            double a = Math.Abs(v);
            if (a > maxBetrag) maxBetrag = a;
        }

        // Normalisierung auf max |x| = 1.0 (stille Dateien unverändert lassen).
        if (maxBetrag > 1e-8)
        {
            double inv = 1.0 / maxBetrag;
            for (int i = 0; i < anzahl; i++) outArr[i] *= inv;
        }
        return outArr;
    }

    private static WaveStream OeffneReader(string pfad)
    {
        string ext = Path.GetExtension(pfad).TrimStart('.').ToLowerInvariant();
        try
        {
            if (ext is "ogg" or "opus")
                return new VorbisWaveReader(pfad);
            // MediaFoundation deckt mp3, wav, m4a, alac, aac, wma und (Win10+) flac/aiff ab.
            return new MediaFoundationReader(pfad);
        }
        catch
        {
            // Fallback: AudioFileReader (wav/mp3/aiff).
            return new AudioFileReader(pfad);
        }
    }
}

/// <summary>Mischt beliebig viele Kanäle zu einem Mono-Kanal (arithmetisches Mittel).</summary>
internal sealed class MultiChannelToMonoSampleProvider : ISampleProvider
{
    private readonly ISampleProvider _source;
    private readonly int _channels;
    private float[] _buffer = Array.Empty<float>();

    public MultiChannelToMonoSampleProvider(ISampleProvider source)
    {
        _source = source;
        _channels = source.WaveFormat.Channels;
        WaveFormat = WaveFormat.CreateIeeeFloatWaveFormat(source.WaveFormat.SampleRate, 1);
    }

    public WaveFormat WaveFormat { get; }

    public int Read(float[] buffer, int offset, int count)
    {
        int quellSamples = count * _channels;
        if (_buffer.Length < quellSamples) _buffer = new float[quellSamples];
        int gelesen = _source.Read(_buffer, 0, quellSamples);
        int frames = gelesen / _channels;
        for (int f = 0; f < frames; f++)
        {
            float summe = 0f;
            for (int c = 0; c < _channels; c++)
                summe += _buffer[f * _channels + c];
            buffer[offset + f] = summe / _channels;
        }
        return frames;
    }
}
