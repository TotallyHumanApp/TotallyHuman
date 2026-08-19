import Foundation
import SwiftUI
import Charts
import UniformTypeIdentifiers

struct BatchAnalysisView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(appState.t("batch.title"))
                    .font(.largeTitle.bold())
                Text(appState.t("batch.subtitle"))
                    .foregroundStyle(.secondary)

                DropZoneView(title: appState.t("batch.dropTitle"), subtitle: appState.t("batch.dropSubtitle"), isActive: appState.isDropTargetActive)
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

                GroupBox(appState.t("batch.queue")) {
                    VStack(spacing: 8) {
                        if appState.batchQueue.isEmpty {
                            Text(appState.t("batch.queueEmpty"))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(appState.batchQueue, id: \.self) { entry in
                                ResultRow(label: entry, value: appState.t("batch.ready"))
                            }
                        }
                    }
                }

                GroupBox(appState.t("batch.results")) {
                    VStack(spacing: 8) {
                        if appState.batchResults.isEmpty {
                            Text(appState.t("batch.resultsEmpty"))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(appState.batchResults) { result in
                                VStack(spacing: 6) {
                                    ResultRow(label: result.dateiName, value: result.einstufung)
                                    ResultRow(label: appState.t("batch.ai"), value: String(format: "%.1f %%", result.kiWahrscheinlichkeitProzent))
                                }
                                Divider()
                            }
                        }
                    }
                }

                GroupBox(appState.t("batch.distribution")) {
                    Chart(appState.batchResults) { result in
                        BarMark(
                            x: .value(appState.t("result.file"), result.dateiName),
                            y: .value(appState.t("batch.ai"), result.kiWahrscheinlichkeitProzent)
                        )
                        .foregroundStyle(.orange.gradient)
                    }
                    .frame(height: 260)
                }
            }
            .padding(24)
        }
    }
}

#Preview {
    BatchAnalysisView().environmentObject(AppState())
}
