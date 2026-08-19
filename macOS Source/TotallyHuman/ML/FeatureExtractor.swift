import Foundation
import Accelerate

/// Extrahiert 128-dimensionale Merkmalsvektoren aus Audiodaten.
/// Die Implementierung ist bewusst robust und ohne externe Abhängigkeiten gehalten.
enum FeatureExtractor {
    static let targetFeatureCount = AnalysisConfig.featureVectorSize

    /// Erzeugt einen normalisierten Merkmalsvektor aus einem bereits vorverarbeiteten Zeitreihensignal.
    /// - Parameter samples: Monosignal im Bereich ungefähr -1...1.
    /// - Returns: 128-dimensionale Feature-Repräsentation.
    static func extractFeatures(from samples: [Double], sampleRate: Double = AnalysisConfig.standardSampleRate) -> [Double] {
        guard !samples.isEmpty else { return Array(repeating: 0.0, count: targetFeatureCount) }

        let normalized = normalize(samples)
        let frameCount = max(1, min(64, normalized.count / 512))
        let chunkSize = max(32, normalized.count / frameCount)

        var features: [Double] = []
        features.reserveCapacity(targetFeatureCount)

        // Globale statistische Merkmale
        features.append(mean(normalized))
        features.append(standardDeviation(normalized))
        features.append(minimum(normalized))
        features.append(maximum(normalized))
        features.append(rms(normalized))
        features.append(zeroCrossingRate(normalized))
        features.append(skewness(normalized))
        features.append(kurtosis(normalized))

        // Segmentierte Energie- und Dynamikmerkmale
        let chunks = chunked(normalized, size: chunkSize)
        for chunk in chunks.prefix(24) {
            features.append(meanAbsoluteValue(chunk))
            features.append(rms(chunk))
            features.append(standardDeviation(chunk))
            features.append(zeroCrossingRate(chunk))
        }

        // Gradient- und Hüllkurvenmerkmale
        let derivative = discreteDerivative(normalized)
        let derivativeChunks = chunked(derivative, size: max(16, derivative.count / max(1, frameCount)))
        for chunk in derivativeChunks.prefix(12) {
            features.append(meanAbsoluteValue(chunk))
            features.append(rms(chunk))
        }

        // Frequenzbasierte Schätzwerte über eine einfache DFT-Repräsentation.
        let spectralSummary = spectralFeatures(from: normalized, sampleRate: sampleRate)
        features.append(contentsOf: spectralSummary)

        // Form- und Verlaufsmuster via Interpolation auf feste Länge.
        let resampled = resample(normalized, to: 32)
        features.append(contentsOf: resampled)

        // Leichte Kontextmerkmale aus der absoluten Hüllkurve.
        let envelope = movingAverage(normalized.map { abs($0) }, window: max(8, normalized.count / 64))
        let envelopeResampled = resample(envelope, to: 16)
        features.append(contentsOf: envelopeResampled)

        return padOrTruncate(normalize(features), to: targetFeatureCount)
    }

    /// Kombiniert mehrere Teilvektoren zu einem stabilen Gesamtvektor.
    static func combine(_ vectors: [[Double]]) -> [Double] {
        guard let first = vectors.first else { return Array(repeating: 0.0, count: targetFeatureCount) }
        var accum = Array(repeating: 0.0, count: first.count)
        for vector in vectors where vector.count == first.count {
            for i in 0..<vector.count { accum[i] += vector[i] }
        }
        let count = Double(max(1, vectors.filter { $0.count == first.count }.count))
        return normalize(accum.map { $0 / count })
    }

    // MARK: - Spektrale Merkmale

    private static func spectralFeatures(from samples: [Double], sampleRate: Double) -> [Double] {
        let bins = min(32, max(8, samples.count / 128))
        let spectrum = magnitudeSpectrum(samples: samples, binCount: bins)
        let total = max(1e-12, spectrum.reduce(0.0, +))
        let centroid = spectrum.enumerated().reduce(0.0) { $0 + Double($1.offset) * $1.element } / total
        let rolloffIndex = spectralRolloff(spectrum)
        let flatness = spectralFlatness(spectrum)
        let entropy = spectralEntropy(spectrum)
        let bandwidth = spectralBandwidth(spectrum, centroid: centroid)
        let lowEnergy = spectrum.prefix(max(1, bins / 4)).reduce(0.0, +) / total
        let highEnergy = spectrum.suffix(max(1, bins / 4)).reduce(0.0, +) / total
        let midEnergy = spectrum.dropFirst(max(1, bins / 4)).dropLast(max(1, bins / 4)).reduce(0.0, +) / total
        let peakiness = (spectrum.max() ?? 0.0) / max(1e-12, spectrum.average())
        let freqScale = sampleRate / Double(max(1, samples.count))

        var output = [Double]()
        output.append(centroid * freqScale)
        output.append(Double(rolloffIndex) * freqScale)
        output.append(flatness)
        output.append(entropy)
        output.append(bandwidth * freqScale)
        output.append(lowEnergy)
        output.append(midEnergy)
        output.append(highEnergy)
        output.append(peakiness)
        output.append(spectrum.first ?? 0.0)
        output.append(spectrum.last ?? 0.0)
        output.append(spectrum.sorted().suffix(3).reduce(0.0, +) / 3.0)
        output.append(spectrum.sorted().prefix(3).reduce(0.0, +) / 3.0)
        output.append(contentsOf: resample(spectrum, to: 18))
        return output
    }

    private static func magnitudeSpectrum(samples: [Double], binCount: Int) -> [Double] {
        guard binCount > 0 else { return [] }
        let n = samples.count
        var spectrum = Array(repeating: 0.0, count: binCount)
        for k in 0..<binCount {
            var real = 0.0
            var imag = 0.0
            let step = 2.0 * Double.pi * Double(k) / Double(max(1, n))
            for (i, sample) in samples.enumerated() {
                let angle = step * Double(i)
                real += sample * cos(angle)
                imag -= sample * sin(angle)
            }
            spectrum[k] = sqrt(real * real + imag * imag) / Double(max(1, n))
        }
        return spectrum
    }

    private static func spectralRolloff(_ spectrum: [Double]) -> Int {
        let threshold = spectrum.reduce(0.0, +) * 0.85
        var sum = 0.0
        for (index, value) in spectrum.enumerated() {
            sum += value
            if sum >= threshold { return index }
        }
        return max(0, spectrum.count - 1)
    }

    private static func spectralFlatness(_ spectrum: [Double]) -> Double {
        let safe = spectrum.map { max($0, 1e-12) }
        let geo = exp(safe.map(log).reduce(0.0, +) / Double(safe.count))
        let arith = safe.reduce(0.0, +) / Double(safe.count)
        return geo / max(1e-12, arith)
    }

    private static func spectralEntropy(_ spectrum: [Double]) -> Double {
        let total = max(1e-12, spectrum.reduce(0.0, +))
        let normalized = spectrum.map { $0 / total }
        let entropy = -normalized.reduce(0.0) { partial, value in
            guard value > 0 else { return partial }
            return partial + value * log2(value)
        }
        return entropy / log2(Double(max(2, spectrum.count))) * -1.0
    }

    private static func spectralBandwidth(_ spectrum: [Double], centroid: Double) -> Double {
        let total = max(1e-12, spectrum.reduce(0.0, +))
        let variance = spectrum.enumerated().reduce(0.0) { partial, pair in
            let distance = Double(pair.offset) - centroid
            return partial + pair.element * distance * distance
        } / total
        return sqrt(max(0.0, variance))
    }

    // MARK: - Basisfunktionen

    private static func normalize(_ values: [Double]) -> [Double] {
        guard let maxAbs = values.map({ abs($0) }).max(), maxAbs > 0 else { return values }
        return values.map { $0 / maxAbs }
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        return values.reduce(0.0, +) / Double(values.count)
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        let m = mean(values)
        let variance = values.reduce(0.0) { $0 + ($1 - m) * ($1 - m) } / Double(values.count)
        return sqrt(max(0.0, variance))
    }

    private static func minimum(_ values: [Double]) -> Double { values.min() ?? 0.0 }
    private static func maximum(_ values: [Double]) -> Double { values.max() ?? 0.0 }
    private static func rms(_ values: [Double]) -> Double { sqrt(values.map { $0 * $0 }.reduce(0.0, +) / Double(max(1, values.count))) }
    private static func meanAbsoluteValue(_ values: [Double]) -> Double { values.map(abs).reduce(0.0, +) / Double(max(1, values.count)) }

    private static func zeroCrossingRate(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        var crossings = 0
        for i in 1..<values.count {
            let prev = values[i - 1]
            let current = values[i]
            if (prev >= 0 && current < 0) || (prev < 0 && current >= 0) { crossings += 1 }
        }
        return Double(crossings) / Double(values.count - 1)
    }

    private static func skewness(_ values: [Double]) -> Double {
        guard values.count > 2 else { return 0.0 }
        let m = mean(values)
        let sd = standardDeviation(values)
        guard sd > 0 else { return 0.0 }
        let n = Double(values.count)
        return values.reduce(0.0) { $0 + pow(($1 - m) / sd, 3) } / n
    }

    private static func kurtosis(_ values: [Double]) -> Double {
        guard values.count > 3 else { return 0.0 }
        let m = mean(values)
        let sd = standardDeviation(values)
        guard sd > 0 else { return 0.0 }
        let n = Double(values.count)
        return values.reduce(0.0) { $0 + pow(($1 - m) / sd, 4) } / n - 3.0
    }

    private static func discreteDerivative(_ values: [Double]) -> [Double] {
        guard values.count > 1 else { return values }
        return zip(values.dropFirst(), values).map { $0 - $1 }
    }

    private static func chunked(_ values: [Double], size: Int) -> [[Double]] {
        guard size > 0 else { return [values] }
        var result: [[Double]] = []
        var index = 0
        while index < values.count {
            let end = Swift.min(values.count, index + size)
            result.append(Array(values[index..<end]))
            index = end
        }
        return result
    }

    private static func movingAverage(_ values: [Double], window: Int) -> [Double] {
        guard !values.isEmpty else { return [] }
        let window = max(1, window)
        var result: [Double] = []
        result.reserveCapacity(values.count)
        var sum = 0.0
        for i in 0..<values.count {
            sum += values[i]
            if i >= window { sum -= values[i - window] }
            result.append(sum / Double(min(i + 1, window)))
        }
        return result
    }

    private static func resample(_ values: [Double], to targetCount: Int) -> [Double] {
        guard targetCount > 0 else { return [] }
        guard values.count > 1 else { return Array(repeating: values.first ?? 0.0, count: targetCount) }
        if values.count == targetCount { return values }
        var result: [Double] = []
        result.reserveCapacity(targetCount)
        let maxIndex = Double(values.count - 1)
        for i in 0..<targetCount {
            let position = maxIndex * Double(i) / Double(targetCount - 1)
            let lower = Int(floor(position))
            let upper = Int(ceil(position))
            if lower == upper {
                result.append(values[lower])
            } else {
                let fraction = position - Double(lower)
                result.append(values[lower] * (1.0 - fraction) + values[upper] * fraction)
            }
        }
        return result
    }

    private static func padOrTruncate(_ values: [Double], to targetCount: Int) -> [Double] {
        if values.count == targetCount { return values }
        if values.count > targetCount { return Array(values.prefix(targetCount)) }
        return values + Array(repeating: 0.0, count: targetCount - values.count)
    }
}

private extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0.0 }
        return reduce(0.0, +) / Double(count)
    }
}
