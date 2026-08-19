using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using TotallyHuman.Models;

namespace TotallyHuman.Utilities;

/// <summary>
/// Hilfsfunktionen rund um Audiodateien: unterstützte Formate, MD5-Signatur
/// (für Deduplizierung) und rekursives Auffinden von Audiodateien. Port von
/// AudioFileHelper.swift.
/// </summary>
public static class AudioFileHelper
{
    public static readonly HashSet<string> UnterstuetzteEndungen = AnalysisConfig.SupportedExtensions;

    public static bool IstAudioDatei(string pfad)
        => UnterstuetzteEndungen.Contains(Path.GetExtension(pfad).TrimStart('.').ToLowerInvariant());

    /// <summary>MD5-Signatur des Dateiinhalts (streaming, speicherschonend).</summary>
    public static string Md5Signatur(string pfad)
    {
        try
        {
            using var stream = File.OpenRead(pfad);
            using var md5 = MD5.Create();
            byte[] hash = md5.ComputeHash(stream);
            return ToHex(hash);
        }
        catch
        {
            // Fallback: Pfad-basierter Hash
            using var md5 = MD5.Create();
            return ToHex(md5.ComputeHash(Encoding.UTF8.GetBytes(pfad)));
        }
    }

    private static string ToHex(byte[] bytes)
    {
        var sb = new StringBuilder(bytes.Length * 2);
        foreach (var b in bytes) sb.Append(b.ToString("x2"));
        return sb.ToString();
    }

    /// <summary>Findet alle unterstützten Audiodateien (rekursiv), oder gibt die Datei selbst zurück.</summary>
    public static List<string> FindeAudioDateien(string pfad)
    {
        var ergebnis = new List<string>();
        if (File.Exists(pfad))
        {
            if (IstAudioDatei(pfad)) ergebnis.Add(pfad);
            return ergebnis;
        }
        if (!Directory.Exists(pfad)) return ergebnis;

        try
        {
            foreach (var f in Directory.EnumerateFiles(pfad, "*", SearchOption.AllDirectories))
            {
                var name = Path.GetFileName(f);
                if (name.StartsWith(".")) continue; // versteckte Dateien überspringen
                if (IstAudioDatei(f)) ergebnis.Add(f);
            }
        }
        catch { /* Zugriffsfehler ignorieren */ }

        return ergebnis.OrderBy(p => Path.GetFileName(p), StringComparer.CurrentCulture).ToList();
    }
}
