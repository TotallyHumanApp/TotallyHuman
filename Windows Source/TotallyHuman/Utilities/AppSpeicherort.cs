using System;
using System.IO;
using System.Text;

namespace TotallyHuman.Utilities;

/// <summary>
/// Ermittelt EINMALIG einen tatsächlich beschreibbaren Basis-Speicherort und legt ihn an.
/// Windows-Äquivalent zu ~/Library/Application Support/Totally Human/ des macOS-Originals:
///   %APPDATA%\TotallyHuman\  (mit Fallbacks auf Documents und Temp).
/// Modell UND Trainingsdaten teilen sich diese Basis.
/// </summary>
public static class AppSpeicherort
{
    private static readonly Lazy<string> _basis = new(ErmittleBasis);

    /// <summary>Der final genutzte Basis-Ordner (garantiert beschreibbar).</summary>
    public static string Basis => _basis.Value;

    /// <summary>Fehlermeldung, falls der bevorzugte Ort nicht beschreibbar war.</summary>
    public static string? Fehler { get; private set; }

    private static string ErmittleBasis()
    {
        var kandidaten = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "TotallyHuman"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "TotallyHuman"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "TotallyHuman"),
            Path.Combine(Path.GetTempPath(), "TotallyHuman"),
        };

        foreach (var kandidat in kandidaten)
        {
            if (IstBeschreibbar(kandidat))
            {
                Fehler = null;
                return kandidat;
            }
        }

        var notnagel = Path.Combine(Path.GetTempPath(), "TotallyHuman");
        try { Directory.CreateDirectory(notnagel); } catch { /* ignore */ }
        return notnagel;
    }

    private static bool IstBeschreibbar(string dir)
    {
        try
        {
            Directory.CreateDirectory(dir);
            var probe = Path.Combine(dir, ".schreibtest");
            File.WriteAllText(probe, "ok", Encoding.UTF8);
            File.Delete(probe);
            return true;
        }
        catch (Exception ex)
        {
            Fehler = ex.Message;
            return false;
        }
    }
}
