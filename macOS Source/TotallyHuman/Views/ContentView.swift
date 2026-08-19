import Foundation
import SwiftUI
import Charts

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            List(selection: $appState.sidebarSelection) {
                Section(appState.t("sidebar.section.analysis")) {
                    Label(appState.t("sidebar.analyse"), systemImage: "waveform.badge.magnifyingglass")
                        .tag(AppState.SidebarSelection.analyse)
                    Label(appState.t("sidebar.batch"), systemImage: "square.stack.3d.up")
                        .tag(AppState.SidebarSelection.batch)
                }
                Section(appState.t("sidebar.section.model")) {
                    Label(appState.t("sidebar.training"), systemImage: "brain.head.profile")
                        .tag(AppState.SidebarSelection.training)
                    Label(appState.t("sidebar.visualization"), systemImage: "chart.xyaxis.line")
                        .tag(AppState.SidebarSelection.visualisierung)
                }
                Section(appState.t("sidebar.section.info")) {
                    Label(appState.t("sidebar.settings"), systemImage: "gearshape")
                        .tag(AppState.SidebarSelection.einstellungen)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.black)
        } detail: {
            ZStack {
                Color.black.ignoresSafeArea()
                switch appState.sidebarSelection {
                case .analyse:
                    AnalysisView()
                case .batch:
                    BatchAnalysisView()
                case .training:
                    TrainingView()
                case .visualisierung:
                    VisualizationView()
                case .einstellungen:
                    SettingsPanelView()
                }
            }
        }
        .accentColor(.orange)
        .preferredColorScheme(.dark)
    }
}

private struct SettingsPanelView: View {
    @EnvironmentObject var appState: AppState

    private var segmentLabel: String {
        let n = Int(appState.segmentLengthSeconds)
        return appState.selectedLanguage == "en"
            ? "Segment length: \(n) seconds"
            : "Segmentlänge: \(n) Sekunden"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(appState.t("settings.title"))
                    .font(.title.bold())
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(appState.t("settings.autosave"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                GroupBox(appState.t("settings.appearance")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(appState.t("settings.orangeTheme"), isOn: $appState.isOrangeThemeEnabled)
                        Toggle(appState.t("settings.preview"), isOn: $appState.isPreviewEnabled)
                        Picker(appState.t("settings.language"), selection: $appState.selectedLanguage) {
                            Text(appState.t("settings.german")).tag("de")
                            Text(appState.t("settings.english")).tag("en")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                }

                GroupBox(appState.t("settings.analysis")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Stepper(segmentLabel, value: $appState.segmentLengthSeconds, in: 5...30, step: 5)
                        Toggle(appState.t("settings.batchConfirm"), isOn: $appState.requireBatchConfirmation)
                        Toggle(appState.t("settings.detailedHints"), isOn: $appState.showDetailedHints)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(16)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
