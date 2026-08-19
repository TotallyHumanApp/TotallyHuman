import Foundation
import SwiftUI
import AppKit

@main
struct TotallyHumanApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1040, minHeight: 720)
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 1320, height: 880)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(appState.t("menu.analyzeFile")) { appState.waehleDateienUndAnalysiere() }
                    .keyboardShortcut("o", modifiers: [.command])
            }
        }

        MenuBarExtra("Totally Human", systemImage: "waveform.path.ecg") {
            MenuBarContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Totally Human")
                .font(.headline)
            Text(appState.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Divider()
            Button(appState.t("menu.analyzeFile")) { appState.waehleDateienUndAnalysiere() }
            Button(appState.t("menu.openTraining")) { appState.sidebarSelection = .training }
            Divider()
            Button(appState.t("menu.quit")) { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 260)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Toggle(appState.t("settings.modeTrained"), isOn: $appState.trainingsmodusAktiv)
            Stepper(value: $appState.qualityThreshold, in: 0...100, step: 1) {
                Text(thresholdLabel)
            }
        }
        .padding()
        .frame(width: 360)
    }

    private var thresholdLabel: String {
        let n = Int(appState.qualityThreshold)
        return appState.selectedLanguage == "en" ? "Threshold: \(n) %" : "Schwelle: \(n) %"
    }
}
