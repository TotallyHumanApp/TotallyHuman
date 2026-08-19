import Foundation
import SQLite3

/// Verwaltet ML-Modelle inkl. Persistenz im Application-Support-Verzeichnis.
final class MLModelManager {
    static let shared = MLModelManager()

    let storageURL: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        // Gleiche, garantiert beschreibbare Basis wie die Trainingsdaten nutzen,
        // damit Modell + Trainingsdaten im selben Ordner liegen und „Ordner öffnen"
        // wirklich beide zeigt.
        storageURL = AppSpeicherort.basis.appendingPathComponent("ML", isDirectory: true)
        try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
    }

    var modelURL: URL { storageURL.appendingPathComponent("logistisches_modell.json") }

    func save(_ model: LogistischesModell) throws {
        let data = try JSONEncoder.prettyPrintedGerman.encode(model)
        try data.write(to: modelURL, options: [.atomic])
    }

    func loadModel() throws -> LogistischesModell {
        let data = try Data(contentsOf: modelURL)
        return try JSONDecoder.german.decode(LogistischesModell.self, from: data)
    }

    func loadOrCreateDefault(featureCount: Int = AnalysisConfig.featureVectorSize) -> LogistischesModell {
        (try? loadModel()) ?? LogistischesModell(
            gewichte: Array(repeating: 0.0, count: featureCount),
            bias: 0.0,
            trainingsZeit: Date(),
            anzahlBeispiele: 0,
            kreuzvalidierungsGenauigkeit: 0.0
        )
    }

    func storeTrainedModel(from classifier: LogisticRegression) throws {
        try save(classifier.model)
    }
}

private extension JSONEncoder {
    static var prettyPrintedGerman: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var german: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
