// SelfSimilarityMatrix.swift — Berechnung von SSM-Matrix und SSM-Score
// Totally Human — native Analysekomponente für macOS 13+

import Foundation
import Accelerate

/// Analysiert die Selbstähnlichkeit eines Merkmalsverlaufs zur Erkennung periodischer Muster und Splices.
struct SelfSimilarityMatrix {
    let segmentSize: Int
    let similarityThreshold: Double

    init(segmentSize: Int = 32, similarityThreshold: Double = 0.82) {
        self.segmentSize = max(8, segmentSize)
        self.similarityThreshold = min(max(similarityThreshold, 0.0), 1.0)
    }

    /// Erstellt eine Selbstähnlichkeitsmatrix aus einem Merkmalsvektor.
    func matrix(for featureVector: [Double]) -> [[Double]] {
        let segments = segmentFeatureVector(featureVector)
        guard !segments.isEmpty else { return [] }

        var matrix = Array(repeating: Array(repeating: 0.0, count: segments.count), count: segments.count)
        for i in 0..<segments.count {
            for j in i..<segments.count {
                let similarity = cosineSimilarity(segments[i], segments[j])
                matrix[i][j] = similarity
                matrix[j][i] = similarity
            }
        }
        return matrix
    }

    /// Liefert einen kompakten Score für regelmäßige Wiederholungen im SSM.
    func score(for featureVector: [Double]) -> Double {
        let ssm = matrix(for: featureVector)
        guard !ssm.isEmpty else { return 0 }

        var highSimilarityCount = 0
        var totalCount = 0
        var diagonalEnergy = 0.0

        for i in 0..<ssm.count {
            for j in 0..<ssm.count {
                guard i != j else { continue }
                totalCount += 1
                if ssm[i][j] >= similarityThreshold { highSimilarityCount += 1 }
                if abs(i - j) <= 2 { diagonalEnergy += ssm[i][j] }
            }
        }

        let repeatRatio = Double(highSimilarityCount) / Double(max(totalCount, 1))
        let diagonalBonus = min(max(diagonalEnergy / Double(max(ssm.count * 2, 1)), 0), 1)
        return min(max(0.65 * repeatRatio + 0.35 * diagonalBonus, 0), 1)
    }

    /// Erkennt mögliche Splice-Kanten über abrupte Ähnlichkeitswechsel.
    func spliceKandidaten(in featureVector: [Double]) -> [Int] {
        let ssm = matrix(for: featureVector)
        guard ssm.count >= 3 else { return [] }

        var candidates: [Int] = []
        for i in 1..<(ssm.count - 1) {
            let prev = averageSimilarity(forRow: ssm[i - 1])
            let current = averageSimilarity(forRow: ssm[i])
            let next = averageSimilarity(forRow: ssm[i + 1])
            let gradient = abs(next - prev) + abs(current - prev)
            if gradient > 0.18 { candidates.append(i) }
        }
        return candidates
    }

    /// Wandelt die SSM in ein strukturiertes Ergebnis um.
    func analyze(featureVector: [Double]) -> (score: Double, matrix: [[Double]], splicePositions: [Int], maxGradient: Double) {
        let ssm = matrix(for: featureVector)
        let score = self.score(for: featureVector)
        let splicePositions = spliceKandidaten(in: featureVector)
        let maxGradient = splicePositions.map { position -> Double in
            let prev = averageSimilarity(forRow: ssm[max(position - 1, 0)])
            let current = averageSimilarity(forRow: ssm[position])
            let next = averageSimilarity(forRow: ssm[min(position + 1, ssm.count - 1)])
            return max(abs(current - prev), abs(next - current))
        }.max() ?? 0
        return (score, ssm, splicePositions, maxGradient)
    }

    private func segmentFeatureVector(_ featureVector: [Double]) -> [[Double]] {
        guard !featureVector.isEmpty else { return [] }
        if featureVector.count <= segmentSize { return [normalize(featureVector)] }

        var segments: [[Double]] = []
        var index = 0
        while index < featureVector.count {
            let end = min(index + segmentSize, featureVector.count)
            segments.append(normalize(Array(featureVector[index..<end])))
            index = end
        }
        return segments
    }

    private func normalize(_ vector: [Double]) -> [Double] {
        guard !vector.isEmpty else { return [] }
        let mean = vector.reduce(0, +) / Double(vector.count)
        let variance = vector.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(vector.count)
        let std = sqrt(max(variance, 1.0e-12))
        return vector.map { ($0 - mean) / std }
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        let count = min(a.count, b.count)
        guard count > 0 else { return 0 }
        var dot = 0.0
        var normA = 0.0
        var normB = 0.0
        for i in 0..<count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? min(max((dot / denom + 1.0) / 2.0, 0), 1) : 0
    }

    private func averageSimilarity(forRow row: [Double]) -> Double {
        guard !row.isEmpty else { return 0 }
        let values = row.filter { $0 > 0 }
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}
