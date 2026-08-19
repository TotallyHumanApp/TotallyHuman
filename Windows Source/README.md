Totally Human — AI Music Detector (Windows)

Standalone Windows port of the macOS app Totally Human. Detects AI-generated
music based on spectral artifacts in the high-frequency range (5–16 kHz), combined with a
logistic regression model. The app is a C#/WPF project (.NET 8) and is distributed as a
portable TotallyHuman.exe.

No Python, no Tkinter, no separate .NET installation required. The published
EXE is self-contained (the .NET runtime is embedded) and runs directly on
Windows 10/11 (64-bit) with a double-click.

Features
The interface is bilingual (German / English, switchable in Settings —
immediately, without restarting) and uses a dark orange theme. Five sections:

File Analysis
Single-file analysis via drag & drop or file selection. Displays AI probability, artifact score, confidence, classification, and additional information.
Batch Analysis
Multiple files at once; tabular results and a summary (AI / human).

Training
Add real and AI-generated music as examples, retrain the model, and import seed data. All data is stored locally.

Visualization
Spectrum, baseline, and fingerprint displayed as charts, along with segment strengths (OxyPlot).

Settings
Language, theme, quality threshold, segment length, storage folder, and seed re-import.

User Data Directory

Training data, the trained model, and settings are stored locally at:

%APPDATA%\TotallyHuman\

On first launch, embedded seed data (model_seed.json, training_seed.json,
148 examples) is automatically imported.

Build

Option A — Automatically via GitHub Actions (recommended)
The repository contains the workflow .github/workflows/build.yml. On every push to
main/master (or manually via Actions → Build Windows EXE → Run workflow), a
windows-latest runner builds the portable EXE and makes it available as the Artifact
TotallyHuman-Windows. Simply download it and run TotallyHuman.exe.

Option B — Locally on Windows

Requirement: .NET 8 SDK

https://dotnet.microsoft.com/download/dotnet/8.0

dotnet publish TotallyHuman/TotallyHuman.csproj -c Release -r win-x64 --self-contained true
-p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true `
-o publish

Result: publish\TotallyHuman.exe (portable, no installation required).
Technology

.NET 8 / WPF (net8.0-windows), MVVM-style architecture with AppState as observable state.

NAudio + NAudio.Vorbis for audio decoding (MP3, WAV, AIFF, M4A, FLAC, OGG, OPUS, WMA, ALAC → Mono, 44.1 kHz, normalized).

OxyPlot.Wpf for charts.

Manual radix-2 FFT (replacing Apple's vDSP), ensemble using FFT sizes 2048/4096/8192.

Recommended thresholds: AI ≥ 0.6 · human ≤ 0.4 · otherwise manual review.

Note About Building on Linux/macOS

WPF is Windows-specific. Running dotnet build/publish for this project only works
on Windows (or on the GitHub Actions windows-latest runner). On Linux/macOS,
the C# code can be checked, but a working EXE cannot be produced.