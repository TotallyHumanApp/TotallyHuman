using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using TotallyHuman.Models;
using TotallyHuman.Utilities;

namespace TotallyHuman.Database;

/// <summary>
/// Robuster, menschenlesbarer Trainingsdaten-Speicher (JSON). 1:1 Port von
/// TrainingStore.swift. Speicherort: %APPDATA%\TotallyHuman\trainingsdaten.json
/// </summary>
public sealed class TrainingStore
{
    private readonly List<TrainingsProbe> _proben = new();

    /// <summary>Alle bekannten Trainingsproben (Quelle der Wahrheit im Speicher).</summary>
    public IReadOnlyList<TrainingsProbe> Proben => _proben;

    /// <summary>true, sobald Laden/Speichern auf die Platte funktioniert hat.</summary>
    public bool PersistenzAktiv { get; private set; }

    private string? _eigenerFehler;
    public string? LetzterFehler => _eigenerFehler ?? AppSpeicherort.Fehler;

    public string DateiPfad { get; }
    public string BasisOrdner => AppSpeicherort.Basis;
    public string Pfad => DateiPfad;

    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
    };

    public TrainingStore()
    {
        DateiPfad = Path.Combine(AppSpeicherort.Basis, "trainingsdaten.json");
        Laden();
    }

    public void Laden()
    {
        if (!File.Exists(DateiPfad))
        {
            PersistenzAktiv = AppSpeicherort.Fehler == null;
            return;
        }
        try
        {
            string json = File.ReadAllText(DateiPfad);
            var geladen = JsonSerializer.Deserialize<List<TrainingsProbe>>(json, Options);
            _proben.Clear();
            if (geladen != null) _proben.AddRange(geladen);
            PersistenzAktiv = true;
            _eigenerFehler = null;
        }
        catch (Exception ex)
        {
            _eigenerFehler = ex.Message;
        }
    }

    public bool Speichern()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(DateiPfad)!);
            string json = JsonSerializer.Serialize(_proben, Options);
            string tmp = DateiPfad + ".tmp";
            File.WriteAllText(tmp, json);
            if (File.Exists(DateiPfad)) File.Delete(DateiPfad);
            File.Move(tmp, DateiPfad);
            PersistenzAktiv = true;
            _eigenerFehler = null;
            return true;
        }
        catch (Exception ex)
        {
            PersistenzAktiv = false;
            _eigenerFehler = ex.Message;
            return false;
        }
    }

    /// <summary>Fügt eine Probe hinzu (dedupliziert via Datei-Signatur). true = neu eingefügt.</summary>
    public bool Hinzufuegen(TrainingsProbe probe)
    {
        if (!string.IsNullOrEmpty(probe.DateiSignatur) &&
            _proben.Any(p => p.DateiSignatur == probe.DateiSignatur))
            return false;
        _proben.Add(probe);
        Speichern();
        return true;
    }

    /// <summary>Fügt mehrere Proben hinzu. Gibt die Anzahl wirklich neu eingefügter zurück.</summary>
    public int Hinzufuegen(IEnumerable<TrainingsProbe> neue)
    {
        int eingefuegt = 0;
        foreach (var p in neue)
        {
            if (!string.IsNullOrEmpty(p.DateiSignatur) &&
                _proben.Any(x => x.DateiSignatur == p.DateiSignatur))
                continue;
            _proben.Add(p);
            eingefuegt++;
        }
        if (eingefuegt > 0) Speichern();
        return eingefuegt;
    }

    public void Leeren()
    {
        _proben.Clear();
        Speichern();
    }
}
