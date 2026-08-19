import Foundation
import SwiftUI
import Charts
import UniformTypeIdentifiers

struct AnalysisView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                DropZoneView(title: appState.t("analysis.dropTitle"), subtitle: appState.t("analysis.dropSubtitle"), isActive: appState.isDropTargetActive)
                    .onDrop(of: [.fileURL], isTargeted: $appState.isDropTargetActive) { providers in
                        appState.dropAnalyse(providers)
                    }
                    .onTapGesture { appState.waehleDateienUndAnalysiere() }
                if appState.istBeschaeftigt {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(appState.statusText).foregroundStyle(.secondary)
                    }
                }
                verdictBanner
                metricsGrid
                spectrumChart
                hintsSection
                resultsSection
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.waehleDateienUndAnalysiere()
                } label: {
                    Label(appState.t("button.selectFile"), systemImage: "folder.badge.plus")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(appState.t("analysis.title"))
                .font(.title.bold())
            Text(appState.t("analysis.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var verdictBanner: some View {
        let result = appState.currentAnalysisResult
        let kiProzent = result?.kiWahrscheinlichkeitProzent ?? 0
        let echtProzent = max(0, 100 - kiProzent)
        let hatErgebnis = result != nil
        let istKI = kiProzent >= 50

        return VStack(spacing: 10) {
            if hatErgebnis {
                Text(istKI ? appState.t("verdict.ai") : appState.t("verdict.real"))
                    .font(.headline)
                    .foregroundStyle(istKI ? Color.orange : Color.green)
            } else {
                Text(appState.t("verdict.none"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                verdictHalf(prozent: kiProzent, titel: appState.t("label.aiMusic"), farbe: .orange, aktiv: hatErgebnis)
                Divider().frame(height: 60)
                verdictHalf(prozent: echtProzent, titel: appState.t("label.realMusic"), farbe: .green, aktiv: hatErgebnis)
            }

            if hatErgebnis {
                ProgressView(value: kiProzent, total: 100)
                    .tint(.orange)

                Text(String(format: appState.selectedLanguage == "en" ? "AI: %.1f %%   ·   REAL: %.1f %%" : "KI: %.1f %%   ·   ECHT: %.1f %%", kiProzent, echtProzent))
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .textSelection(.enabled)

                if let modus = result?.modus {
                    Text(modus == .trainiert ? appState.t("mode.trained") : appState.t("mode.heuristic"))
                        .font(.caption2)
                        .foregroundStyle(modus == .trainiert ? .green : .orange)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.35), lineWidth: 1))
    }

    private func verdictHalf(prozent: Double, titel: String, farbe: Color, aktiv: Bool) -> some View {
        VStack(spacing: 4) {
            Text(aktiv ? String(format: "%.0f %%", prozent) : "—")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(farbe)
            Text(titel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var metricsGrid: some View {
        let result = appState.currentAnalysisResult
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
            MetricCard(title: appState.t("metric.aiProbability"), value: result.map { String(format: "%.1f %%", $0.kiWahrscheinlichkeitProzent) } ?? "—", symbol: "brain")
            MetricCard(title: appState.t("metric.artifactScore"), value: result.map { String(format: "%.2f", $0.artefaktScore) } ?? "—", symbol: "waveform.path.ecg")
            MetricCard(title: appState.t("metric.confidence"), value: result.map { $0.konfidenzText } ?? "—", symbol: "checkmark.seal")
        }
    }

    private var spectrumChart: some View {
        GroupBox {
            Chart {
                if let result = appState.currentAnalysisResult, !result.spektrumFrequenzen.isEmpty, result.spektrumFrequenzen.count == result.spektrumWerte.count {
                    ForEach(Array(zip(result.spektrumFrequenzen, result.spektrumWerte)).indices, id: \ .self) { index in
                        LineMark(
                            x: .value(appState.t("chart.frequency"), result.spektrumFrequenzen[index]),
                            y: .value(appState.t("chart.level"), result.spektrumWerte[index])
                        )
                        .foregroundStyle(.orange)
                    }
                } else {
                    ForEach(sampleSpectrum) { point in
                        LineMark(x: .value(appState.t("chart.frequency"), point.frequency), y: .value(appState.t("chart.level"), point.level))
                            .foregroundStyle(.orange.gradient)
                    }
                }
            }
            .frame(height: 140)
            .chartXAxisLabel(appState.t("chart.frequencyHz"), alignment: .center)
            .chartYAxisLabel("dB", alignment: .center)
        } label: {
            Label(appState.t("chart.spectrum"), systemImage: "waveform")
                .font(.caption.weight(.semibold))
        }
    }

    private var hintsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                if let result = appState.currentAnalysisResult, !result.hinweise.isEmpty {
                    ForEach(Array(result.hinweise.enumerated()), id: \ .offset) { _, hint in
                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                            Text(hint)
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Text(appState.t("hints.none"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(appState.t("hints.title"), systemImage: "info.circle")
                .font(.caption.weight(.semibold))
        }
    }

    private var resultsSection: some View {
        GroupBox {
            VStack(spacing: 4) {
                if let result = appState.currentAnalysisResult {
                    ResultRow(label: appState.t("result.file"), value: result.dateiName)
                    ResultRow(label: appState.t("result.classification"), value: result.einstufung)
                    ResultRow(label: appState.t("result.mode"), value: result.modus == .trainiert ? appState.t("mode.trained") : appState.t("mode.heuristic"))
                    ResultRow(label: appState.t("result.date"), value: result.analyseDatum.formatted(date: .abbreviated, time: .shortened))
                } else {
                    Text(appState.t("result.none"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } label: {
            Label(appState.t("result.details"), systemImage: "doc.text")
                .font(.caption.weight(.semibold))
        }
    }
}

private struct MetricCard: View {
    var title: String
    var value: String
    var symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.4), lineWidth: 1))
    }
}

private struct SpectrumPoint: Identifiable {
    let id = UUID()
    let frequency: Double
    let level: Double
}

private let sampleSpectrum: [SpectrumPoint] = [
    .init(frequency: 200, level: -34),
    .init(frequency: 800, level: -22),
    .init(frequency: 1600, level: -28),
    .init(frequency: 3200, level: -18),
    .init(frequency: 6400, level: -12),
    .init(frequency: 9600, level: -20),
    .init(frequency: 12800, level: -27)
]

#Preview {
    AnalysisView().environmentObject(AppState())
}
