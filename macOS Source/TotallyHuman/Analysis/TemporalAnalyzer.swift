// TemporalAnalyzer.swift — Analyse von Zeitsegmenten, zeitlichem KI-Anteil und Splices
// Totally Human — native Analysekomponente für macOS 13+

import Foundation

/// Zerlegt ein Signal in zeitliche Fenster und bewertet deren Unregelmäßigkeiten.
struct TemporalAnalyzer {
    let sampleRate: Double
    let segmentLengthSeconds: Double
    let spliceSensitivity: Double

    init(sampleRate: Double = AnalysisConfig.standardSampleRate,
         segmentLengthSeconds: Double = AnalysisConfig.segmentLengthSeconds,
         spliceSensitivity: Double = 0.35) {
        self.sampleRate = sampleRate
        self.segmentLengthSeconds = max(2.0, segmentLengthSeconds)
        self.spliceSensitivity = min(max(spliceSensitivity, 0.0), 1.0)
    }

    /// Analysiert die zeitliche Struktur und gibt Segmentstärken zurück.
    func analyze(samples: [Double], featureProvider: MFCCProcessor) -> ZeitSegmentErgebnis {
        guard !samples.isEmpty else {
            return ZeitSegmentErgebnis(segmentZeitenS: [], segmentStaerken: [], segmentAnteile: [], staerktesSegmentS: (0, 0))
        }

        let segmentSize = max(Int(sampleRate * segmentLengthSeconds), 1)
        var segmentZeiten: [(Double, Double)] = []
        var segmentStaerken: [Double] = []

        var start = 0
        while start < samples.count {
            let end = min(start + segmentSize, samples.count)
            let segment = Array(samples[start..<end])
            let strength = temporalAnomalyScore(segment: segment, processor: featureProvider)
            segmentZeiten.append((Double(start) / sampleRate, Double(end) / sampleRate))
            segmentStaerken.append(strength)
            start = end
        }

        let total = segmentStaerken.reduce(0, +)
        let segmentAnteile = segmentStaerken.map { total > 0 ? $0 / total : 0 }
        let strongestIndex = segmentStaerken.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0

        return ZeitSegmentErgebnis(
            segmentZeitenS: segmentZeiten,
            segmentStaerken: segmentStaerken,
            segmentAnteile: segmentAnteile,
            staerktesSegmentS: segmentZeiten[safe: strongestIndex] ?? (0, 0)
        )
    }

    /// Ermittelt den zeitlichen KI-Anteil als Prozentwert auf Basis der stärksten Segmente.
    func zeitlicherKIAnteil(samples: [Double], featureProvider: MFCCProcessor) -> Double {
        let result = analyze(samples: samples, featureProvider: featureProvider)
        guard !result.segmentStaerken.isEmpty else { return 0 }

        let sorted = result.segmentStaerken.sorted(by: >)
        let topCount = max(1, Int(ceil(Double(sorted.count) * 0.3)))
        let topAverage = sorted.prefix(topCount).reduce(0, +) / Double(topCount)
        let overallAverage = result.segmentStaerken.reduce(0, +) / Double(result.segmentStaerken.count)

        let contrast = max(topAverage - overallAverage, 0)
        let normalized = min(max(contrast / max(overallAverage, 1.0e-12), 0), 1)
        return normalized * 100.0
    }

    /// Liefert Verdachtspositionen für Schnitte anhand abrupter Energie- und Merkmalswechsel.
    func spliceErkennung(samples: [Double], featureProvider: MFCCProcessor) -> SpliceErgebnis {
        let result = analyze(samples: samples, featureProvider: featureProvider)
        guard result.segmentStaerken.count >= 3 else {
            return SpliceErgebnis(spliceVerdacht: false, splicePositionen: [], maxGradient: 0)
        }

        var positions: [Int] = []
        var maxGradient = 0.0
        for i in 1..<(result.segmentStaerken.count - 1) {
            let left = result.segmentStaerken[i - 1]
            let center = result.segmentStaerken[i]
            let right = result.segmentStaerken[i + 1]
            let gradient = max(abs(center - left), abs(right - center))
            maxGradient = max(maxGradient, gradient)
            if gradient > spliceSensitivity * max(result.segmentStaerken.max() ?? 1, 1.0) {
                positions.append(i)
            }
        }

        return SpliceErgebnis(spliceVerdacht: !positions.isEmpty, splicePositionen: positions, maxGradient: maxGradient)
    }

    private func temporalAnomalyScore(segment: [Double], processor: MFCCProcessor) -> Double {
        let features = processor.spectralFeatures(from: segment)
        let mfcc = processor.extrahiereMerkmalsvektor(from: segment)
        let flatnessContribution = 1.0 - features.spektraleFlachheit
        let hfContribution = features.hochfrequenzAnteil
        let stationarityPenalty = 1.0 - features.zeitlicheStationaritaet
        let mfccVariance = vectorVariance(mfcc)
        let normalizedVariance = min(max(mfccVariance / 20.0, 0), 1)

        return min(max(0.35 * flatnessContribution + 0.30 * hfContribution + 0.20 * stationarityPenalty + 0.15 * normalizedVariance, 0), 1)
    }

    private func vectorVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        return values.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(values.count)
    }
}

