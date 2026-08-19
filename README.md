# Totally Human — AI Music Detector

**Totally Human** is a native desktop app for detecting AI-generated music. It analyzes audio files for spectral artifacts and statistical anomalies that are typical of synthetically produced music, and returns the result as a percentage estimate: how much of the analyzed music is likely AI-generated versus human-made.

The app is **bilingual** (German / English) and the language can be switched at any time in the settings — the interface changes immediately (live) and the selection is saved for the next launch.

---

## Platforms

This repository contains the source code for **both** platforms. The compiled, ready-to-run builds of the app are published as **GitHub Releases** (see the [Releases](https://github.com/TotallyHumanApp/TotallyHuman/releases) page).

| Platform | Source code | Compiled build |
|----------|-------------|----------------|
| **macOS** | `macOS Source/` | `Totally Human.app` (in Releases) |
| **Windows** | `Windows Source/` | `Totally Human.exe` (in Releases) |

> The `Totally Human.app` and `Totally Human.exe` files are already compiled, runnable versions of the app — no build required. Download them from the Releases page.

---

## Features

- **File Analysis** — Single-file analysis via drag & drop or file selection. Shows AI probability, artifact score, confidence, classification, and additional information.
- **Batch Analysis** — Multiple files at once; tabular results and a summary (AI / human).
- **Training** — Add your own examples (real and AI-generated music), retrain the model, and import seed data. All data is stored locally.
- **Visualization** — Spectrum, baseline, and fingerprint displayed as charts, along with segment strengths.
- **Settings** — Language, theme, quality threshold, segment length, storage folder, and seed re-import.

---

## Algorithm

The app detects AI-generated music using several methods:

- **Fourier artifact analysis** — regular peaks between 5–16 kHz
- **Self-similarity matrix** (MFCC-based)
- **Splice detection** — temporal inconsistencies
- **Obfuscation detection**

The result is displayed as a **percentage**, estimating how much of the analyzed music is AI-generated versus human-made.

Recommended thresholds: **AI ≥ 0.6** · **human ≤ 0.4** · otherwise manual review.

---

## System Requirements

### macOS
- macOS 13.0 (Ventura) or later
- Xcode 15+ (only required to build from source)

### Windows
- Windows 10/11 (64-bit)
- No separate .NET installation required — the EXE is self-contained (the .NET runtime is embedded) and runs with a double-click.

---

## User Data

Training data, the trained model, and settings are stored locally:

- **macOS:** `~/Library/Application Support/TotallyHuman/`
- **Windows:** `%APPDATA%\TotallyHuman\`

On first launch, embedded seed data (`model_seed.json`, `training_seed.json`, 148 examples) is automatically imported. The training database is expanded incrementally with each training session.

---

## Build

### macOS (from source)
1. Open `TotallyHuman.xcodeproj` in Xcode
2. Signing: select your Team or use "Sign to Run Locally"
3. Press `Cmd+R` to run the app

### Windows (from source)
**Option A — Automatically via GitHub Actions (recommended):** The repository contains the workflow `.github/workflows/build.yml`. On every push to `main`/`master` (or manually via Actions → Build Windows EXE → Run workflow), a `windows-latest` runner builds the portable EXE and makes it available as the artifact `TotallyHuman-Windows`.

**Option B — Locally on Windows:** Requires the .NET 8 SDK.

```bash
dotnet publish TotallyHuman/TotallyHuman.csproj -c Release -r win-x64 --self-contained true \
  -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -o publish
```

Result: `publish\TotallyHuman.exe` (portable, no installation required).

> **Note:** WPF is Windows-specific. `dotnet build`/`publish` only works on Windows (or on the GitHub Actions `windows-latest` runner). On Linux/macOS the C# code can be checked, but a working EXE cannot be produced.

---

## Technology

- **macOS:** Swift / SwiftUI, Apple vDSP (FFT)
- **Windows:** .NET 8 / WPF (`net8.0-windows`), MVVM-style architecture with `AppState` as observable state
  - **NAudio + NAudio.Vorbis** for audio decoding (MP3, WAV, AIFF, M4A, FLAC, OGG, OPUS, WMA, ALAC → Mono, 44.1 kHz, normalized)
  - **OxyPlot.Wpf** for charts
  - Manual radix-2 FFT (replacing Apple's vDSP), ensemble using FFT sizes 2048/4096/8192

---

## Support & Links

If you like the project and want to support its development:

- **Support the project:** https://ko-fi.com/totallyhumanapp/
- **GitHub:** https://github.com/TotallyHumanApp/
- **Instagram:** https://www.instagram.com/totallyhumanapp/
- **Contact:** totallyhumanapp@gmail.com

---

## License

All rights remain with the author. This repository is provided without a license — the use, reproduction, and redistribution of the code is not permitted without explicit permission.
