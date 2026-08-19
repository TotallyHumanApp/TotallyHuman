import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    var title: String
    var subtitle: String
    var isActive: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: isActive ? "arrow.down.doc.fill" : "arrow.down.doc")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(isActive ? .orange : .secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isActive ? Color.orange : Color.gray.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [8]))
        )
    }
}

#Preview {
    DropZoneView(title: "Dateien ablegen", subtitle: "Ziehe Audiodateien hierher, um die Analyse zu starten.", isActive: true)
        .padding()
        .background(Color.black)
}
