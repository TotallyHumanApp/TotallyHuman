import Foundation
import SwiftUI
import Charts

struct VisualizationView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(appState.t("viz.title"))
                    .font(.largeTitle.bold())
                Text(appState.t("viz.subtitle"))
                    .foregroundStyle(.secondary)

                GroupBox(appState.t("viz.classification")) {
                    Chart(appState.visualizationSeries) { point in
                        LineMark(x: .value(appState.t("viz.index"), point.index), y: .value(appState.t("viz.value"), point.value))
                            .foregroundStyle(.orange)
                        PointMark(x: .value(appState.t("viz.index"), point.index), y: .value(appState.t("viz.value"), point.value))
                            .foregroundStyle(.yellow)
                    }
                    .frame(height: 220)
                }

                GroupBox(appState.t("viz.segments")) {
                    Chart(appState.currentAnalysisResult?.segmentStaerken.indices.map { index in
                        VisualizationSegment(index: index, strength: appState.currentAnalysisResult?.segmentStaerken[index] ?? 0)
                    } ?? []) { segment in
                        BarMark(x: .value(appState.t("viz.segment"), segment.index), y: .value(appState.t("viz.strength"), segment.strength))
                            .foregroundStyle(.orange.gradient)
                    }
                    .frame(height: 220)
                }

                GroupBox(appState.t("viz.ssm")) {
                    if let matrix = appState.currentAnalysisResult?.ssmMatrix, !matrix.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(matrix.indices, id: \.self) { row in
                                HStack(spacing: 4) {
                                    ForEach(matrix[row].indices, id: \.self) { column in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.orange.opacity(matrix[row][column].clamped(to: 0...1)))
                                            .frame(width: 10, height: 10)
                                    }
                                }
                            }
                        }
                    } else {
                        Text(appState.t("viz.noMatrix"))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct VisualizationPoint: Identifiable {
    let id = UUID()
    let index: Int
    let value: Double
}

private struct VisualizationSegment: Identifiable {
    let id = UUID()
    let index: Int
    let strength: Double
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double { min(max(self, range.lowerBound), range.upperBound) }
}

#Preview {
    VisualizationView().environmentObject(AppState())
}
