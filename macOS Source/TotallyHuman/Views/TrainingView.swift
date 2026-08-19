import Foundation
import SwiftUI
import Charts
import UniformTypeIdentifiers

struct TrainingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(appState.t("training.title"))
                    .font(.title.bold())
                Text(appState.t("training.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Kennzahlen
                HStack(spacing: 16) {
                    trainingSummaryCard(title: appState.t("training.totalSamples"), value: "\(appState.trainingSampleCount)")
                    trainingSummaryCard(title: appState.t("training.realMusic"), value: "\(appState.trainingEchtCount)")
                    trainingSummaryCard(title: appState.t("training.aiMusic"), value: "\(appState.trainingKICount)")
                    trainingSummaryCard(title: appState.t("training.accuracy"), value: String(format: "%.1f %%", appState.trainingAccuracy * 100))
                }

                // Modell-Modus & Speicherort
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: appState.modellIstTrainiert ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(appState.modellIstTrainiert ? .green : .orange)
                            Text(appState.modellIstTrainiert ? appState.t("training.modeTrained") : appState.t("training.modeHeuristic"))
                                .font(.callout.weight(.semibold))
                            Spacer()
                            Button {
                                appState.speicherordnerOeffnen()
                            } label: {
                                Label(appState.t("training.folder"), systemImage: "folder")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .help(appState.t("training.folderHelp"))
                        }

                        // Tatsächlich genutzter Speicherort (klickbar via „Ordner").
                        if !appState.speicherOrdner.isEmpty {
                            Text(appState.speicherOrdner)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }

                        if !appState.persistenzOK {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                    Text(appState.t("training.saveFailed"))
                                        .font(.caption2.weight(.semibold))
                                }
                                if let fehler = appState.speicherFehler {
                                    Text(fehler)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label(appState.t("training.modelLocation"), systemImage: "brain")
                        .font(.caption.weight(.semibold))
                }

                // Aktionen
                GroupBox {
                    HStack(spacing: 12) {
                        trainingDropZone(
                            titel: appState.t("training.realMusic"),
                            symbol: "person.wave.2",
                            farbe: .green,
                            label: .echt
                        )
                        trainingDropZone(
                            titel: appState.t("training.aiMusic"),
                            symbol: "cpu",
                            farbe: .orange,
                            label: .ki
                        )
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label(appState.t("training.step1"), systemImage: "square.and.arrow.down")
                        .font(.caption.weight(.semibold))
                }

                // Training starten
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        if appState.trainingEchtCount < 1 || appState.trainingKICount < 1 {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text(appState.t("training.needBoth"))
                                    .font(.caption2)
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        HStack(spacing: 8) {
                            Button {
                                appState.starteTraining()
                            } label: {
                                Label(appState.t("training.start"), systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .disabled(appState.istBeschaeftigt || appState.trainingEchtCount < 1 || appState.trainingKICount < 1)

                            Button(role: .destructive) {
                                appState.loescheAlleTrainingsdaten()
                            } label: {
                                Label(appState.t("training.delete"), systemImage: "trash")
                            }
                            .disabled(appState.istBeschaeftigt || appState.trainingSampleCount == 0)
                        }

                        Button {
                            appState.seedDatenNeuImportieren()
                        } label: {
                            Label(appState.t("training.reseed"), systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .disabled(appState.istBeschaeftigt)

                        HStack(spacing: 8) {
                            if appState.istBeschaeftigt {
                                ProgressView().controlSize(.small)
                            }
                            Text(appState.trainingStatusText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label(appState.t("training.step2"), systemImage: "brain.head.profile")
                        .font(.caption.weight(.semibold))
                }

                if !appState.trainingProgressPoints.isEmpty {
                    GroupBox {
                        Chart(appState.trainingProgressPoints) { point in
                            LineMark(x: .value(appState.t("training.run"), point.epoch), y: .value(appState.t("training.accuracy"), point.accuracy))
                                .foregroundStyle(.orange)
                            PointMark(x: .value(appState.t("training.run"), point.epoch), y: .value(appState.t("training.accuracy"), point.accuracy))
                                .foregroundStyle(.yellow)
                        }
                        .chartYScale(domain: 0...1)
                        .frame(height: 140)
                    } label: {
                        Label(appState.t("training.progress"), systemImage: "chart.xyaxis.line")
                            .font(.caption.weight(.semibold))
                    }
                }

                if !appState.trainingProbes.isEmpty {
                    GroupBox {
                        ScrollView {
                            VStack(spacing: 2) {
                                ForEach(appState.trainingProbes.prefix(50)) { probe in
                                    HStack(spacing: 8) {
                                        Text(probe.dateiName.isEmpty ? appState.t("training.seed") : probe.dateiName)
                                            .font(.caption2)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(probe.label == .echt ? appState.t("training.labelReal") : appState.t("training.labelAI"))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(probe.label == .echt ? .green : .orange)
                                    }
                                    .padding(.vertical, 2)
                                }
                                if appState.trainingProbes.count > 50 {
                                    Text(moreLabel(appState.trainingProbes.count - 50))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .frame(height: 180)
                    } label: {
                        Label(dataLabel(appState.trainingProbes.count), systemImage: "list.bullet")
                            .font(.caption.weight(.semibold))
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { appState.waehleTrainingsordner(label: .echt) } label: {
                    Label(appState.t("training.addRealMusic"), systemImage: "plus")
                }
                Button { appState.waehleTrainingsordner(label: .ki) } label: {
                    Label(appState.t("training.addAIMusic"), systemImage: "plus")
                }
            }
        }
    }

    private func moreLabel(_ n: Int) -> String {
        appState.selectedLanguage == "en" ? "… and \(n) more" : "… und \(n) weitere"
    }

    private func dataLabel(_ n: Int) -> String {
        (appState.selectedLanguage == "en" ? "Data" : "Daten") + " (\(n))"
    }

    private func trainingDropZone(titel: String, symbol: String, farbe: Color, label: TrainingsProbe.TrainingsLabel) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(farbe)
            Text(titel).font(.caption.weight(.semibold))
            Text(appState.t("training.dragOrClick"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(farbe.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(farbe.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5])))
        .contentShape(Rectangle())
        .onTapGesture { appState.waehleTrainingsordner(label: label) }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            appState.dropTraining(providers, label: label)
        }
    }

    private func speicherZeile(titel: String, pfad: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.caption.bold()).foregroundStyle(.secondary)
            Text(pfad.isEmpty ? "—" : pfad)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trainingSummaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.12)))
    }
}

#Preview {
    TrainingView().environmentObject(AppState())
}
