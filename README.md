# Totally Human — AI Music Detector

**Totally Human** ist eine native Desktop-App zur Erkennung von KI-generierter Musik. Sie analysiert Audiodateien auf spektrale Artefakte und statistische Auffälligkeiten, die typisch für synthetisch erzeugte Musik sind, und gibt das Ergebnis als prozentuale Schätzung aus: Wie viel der analysierten Musik ist vermutlich KI-generiert, wie viel menschlich?

Die App ist **zweisprachig** (Deutsch / Englisch) und die Sprache lässt sich jederzeit in den Einstellungen umschalten — die Oberfläche wechselt sofort (live) und die Auswahl wird für den nächsten Start gespeichert.

---

## Plattformen

Dieses Repository enthält den Quellcode für **beide** Plattformen sowie die bereits **kompilierten, gebauten Versionen** der App:

| Plattform | Quellcode | Kompilierter Build |
|-----------|-----------|--------------------|
| **macOS** | `macOS Source/` | `Totally Human.app` |
| **Windows** | `Windows Source/` | `Totally Human.exe` |

> Die Dateien `Totally Human.app` und `Totally Human.exe` sind bereits gebaute, lauffähige Versionen der App — kein Build erforderlich.

---

## Features

- **Datei-Analyse** — Einzeldatei-Analyse per Drag & Drop oder Dateiauswahl. Zeigt KI-Wahrscheinlichkeit, Artefakt-Score, Konfidenz, Klassifikation und Zusatzinformationen.
- **Batch-Analyse** — Mehrere Dateien gleichzeitig; tabellarische Ergebnisse und eine Zusammenfassung (KI / menschlich).
- **Training** — Eigene Beispiele hinzufügen (echte und KI-generierte Musik), Modell neu trainieren und Seed-Daten importieren. Alle Daten werden lokal gespeichert.
- **Visualisierung** — Spektrum, Baseline und Fingerprint als Diagramme sowie Segment-Stärken.
- **Einstellungen** — Sprache, Theme, Qualitätsschwelle, Segmentlänge, Speicherordner und Seed-Re-Import.

---

## Algorithmus

Die App erkennt KI-generierte Musik anhand mehrerer Verfahren:

- **Fourier-Artefakt-Analyse** — regelmäßige Peaks zwischen 5–16 kHz
- **Self-Similarity-Matrix** (MFCC-basiert)
- **Splice-Erkennung** — zeitliche Inkonsistenzen
- **Obfuscation-Erkennung**

Das Ergebnis wird als **Prozentsatz** angezeigt und schätzt, wie viel der analysierten Musik KI-generiert gegenüber menschlich erstellt ist.

Empfohlene Schwellenwerte: **KI ≥ 0,6** · **menschlich ≤ 0,4** · sonst manuelle Prüfung.

---

## Systemanforderungen

### macOS
- macOS 13.0 (Ventura) oder neuer
- Xcode 15+ (nur zum Bauen aus dem Quellcode)

### Windows
- Windows 10/11 (64-Bit)
- Keine separate .NET-Installation nötig — die EXE ist selbstständig (das .NET-Runtime ist eingebettet) und läuft per Doppelklick.

---

## Benutzerdaten

Trainingsdaten, das trainierte Modell und Einstellungen werden lokal gespeichert:

- **macOS:** `~/Library/Application Support/TotallyHuman/`
- **Windows:** `%APPDATA%\TotallyHuman\`

Beim ersten Start werden eingebettete Seed-Daten (`model_seed.json`, `training_seed.json`, 148 Beispiele) automatisch importiert. Die Trainingsdatenbank wird mit jeder Trainingssitzung inkrementell erweitert.

---

## Build

### macOS (aus dem Quellcode)
1. `TotallyHuman.xcodeproj` in Xcode öffnen
2. Signing: eigenes Team wählen oder „Sign to Run Locally“
3. `Cmd+R` zum Ausführen

### Windows (aus dem Quellcode)
**Option A — Automatisch via GitHub Actions (empfohlen):** Das Repository enthält den Workflow `.github/workflows/build.yml`. Bei jedem Push auf `main`/`master` (oder manuell über Actions → Build Windows EXE → Run workflow) baut ein `windows-latest`-Runner die portable EXE und stellt sie als Artefakt `TotallyHuman-Windows` bereit.

**Option B — Lokal auf Windows:** Erfordert das .NET 8 SDK.

```bash
dotnet publish TotallyHuman/TotallyHuman.csproj -c Release -r win-x64 --self-contained true \
  -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -o publish
```

Ergebnis: `publish\TotallyHuman.exe` (portabel, keine Installation nötig).

> **Hinweis:** WPF ist Windows-spezifisch. `dotnet build`/`publish` funktioniert nur unter Windows (oder auf dem GitHub-Actions-`windows-latest`-Runner). Unter Linux/macOS kann der C#-Code geprüft, aber keine lauffähige EXE erzeugt werden.

---

## Technologie

- **macOS:** Swift / SwiftUI, Apple vDSP (FFT)
- **Windows:** .NET 8 / WPF (`net8.0-windows`), MVVM-Architektur mit `AppState` als beobachtbarem Zustand
  - **NAudio + NAudio.Vorbis** für Audio-Dekodierung (MP3, WAV, AIFF, M4A, FLAC, OGG, OPUS, WMA, ALAC → Mono, 44,1 kHz, normalisiert)
  - **OxyPlot.Wpf** für Diagramme
  - Manuelle Radix-2-FFT (ersetzt Apple vDSP), Ensemble mit FFT-Größen 2048/4096/8192

---

## Support & Links

Wenn dir das Projekt gefällt und du seine Entwicklung unterstützen möchtest:

- **Projekt unterstützen:** https://ko-fi.com/totallyhumanapp/
- **GitHub:** https://github.com/TotallyHumanApp/
- **Instagram:** https://www.instagram.com/totallyhumanapp/
- **Kontakt:** totallyhumanapp@gmail.com

---

## Lizenz

Alle Rechte verbleiben beim Autor. Dieses Repository wird ohne Lizenz bereitgestellt — die Nutzung, Vervielfältigung und Weiterverbreitung des Codes ist ohne ausdrückliche Genehmigung nicht gestattet.
