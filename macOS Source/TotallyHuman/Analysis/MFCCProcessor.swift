// MFCCProcessor.swift — Extraktion von MFCC-Merkmalen mit Mel-Filterbank und DCT
// Totally Human — native Analysekomponente für macOS 13+

import Foundation
import Accelerate

/// Berechnet MFCCs und zusätzliche spektrale Hilfsmerkmale aus einem Audiosignal.
struct MFCCProcessor {
    let sampleRate: Double
    let fftSize: Int
    let melBandCount: Int
    let coefficientCount: Int
    let frequencyBand: (Double, Double)

    init(sampleRate: Double = AnalysisConfig.standardSampleRate,
         fftSize: Int = 2048,
         melBandCount: Int = 40,
         coefficientCount: Int = 13,
         frequencyBand: (Double, Double) = AnalysisConfig.analysisFreqBandHz) {
        self.sampleRate = sampleRate
        self.fftSize = max(512, fftSize)
        self.melBandCount = max(20, melBandCount)
        self.coefficientCount = max(8, coefficientCount)
        self.frequencyBand = frequencyBand
    }

    /// Extrahiert einen kompakten MFCC-Vektor mit Delta- und Energiewerten auf 128 Dimensionen erweitert.
    func extrahiereMerkmalsvektor(from samples: [Double]) -> [Double] {
        guard samples.count >= 32 else {
            return Array(repeating: 0.0, count: AnalysisConfig.featureVectorSize)
        }

        let frames = framedSamples(samples)
        var mfccAccum = Array(repeating: 0.0, count: coefficientCount)
        var deltaAccum = Array(repeating: 0.0, count: coefficientCount)
        var energyValues: [Double] = []

        for frame in frames {
            let spectrum = powerSpectrum(for: frame)
            let melEnergies = applyMelFilterBank(to: spectrum)
            let logMel = melEnergies.map { log(max($0, 1.0e-12)) }
            let mfcc = dctCoefficients(from: logMel)
            for i in 0..<coefficientCount { mfccAccum[i] += mfcc[i] }
            energyValues.append(frameEnergy(frame))
        }

        let frameCount = Double(frames.count)
        let meanMFCC = mfccAccum.map { $0 / frameCount }
        let deltas = deltaCoefficients(from: frames)
        for i in 0..<coefficientCount { deltaAccum[i] = deltas[i] }

        let energyMean = energyValues.reduce(0, +) / max(Double(energyValues.count), 1.0)
        let energyStd = standardDeviation(energyValues, mean: energyMean)

        var featureVector: [Double] = []
        featureVector.append(contentsOf: meanMFCC)
        featureVector.append(contentsOf: deltaAccum)
        featureVector.append(energyMean)
        featureVector.append(energyStd)

        let spectral = spectralFeatures(from: samples)
        featureVector.append(spectral.hochfrequenzAnteil)
        featureVector.append(spectral.spektraleFlachheit)
        featureVector.append(spectral.cutoffSchaerfe)
        featureVector.append(spectral.zeitlicheStationaritaet)

        if featureVector.count < AnalysisConfig.featureVectorSize {
            featureVector.append(contentsOf: Array(repeating: 0.0, count: AnalysisConfig.featureVectorSize - featureVector.count))
        }
        return Array(featureVector.prefix(AnalysisConfig.featureVectorSize))
    }

    /// Berechnet ein gesamtendes Spektralmerkmal-Set für nachgelagerte Analysen.
    func spectralFeatures(from samples: [Double]) -> SpektralMerkmale {
        let frames = framedSamples(samples)
        guard !frames.isEmpty else {
            return SpektralMerkmale(hochfrequenzAnteil: 0, spektraleFlachheit: 0, cutoffSchaerfe: 0, zeitlicheStationaritaet: 0)
        }

        let averagedSpectrum = averageSpectrum(for: frames)
        let highFreqStartHz = max(8000.0, frequencyBand.0)
        let nyquist = sampleRate / 2.0
        let binResolution = nyquist / Double(max(averagedSpectrum.count - 1, 1))
        let highFreqStartBin = min(averagedSpectrum.count - 1, Int(highFreqStartHz / binResolution))

        let totalEnergy = averagedSpectrum.reduce(0, +)
        let highEnergy = averagedSpectrum.dropFirst(highFreqStartBin).reduce(0, +)
        let flatness = spectralFlatness(of: averagedSpectrum)
        let cutoffSharpness = spectralCutoffSharpness(of: averagedSpectrum)
        let stationarity = temporalStationarity(frames: frames)

        return SpektralMerkmale(
            hochfrequenzAnteil: totalEnergy > 0 ? highEnergy / totalEnergy : 0,
            spektraleFlachheit: flatness,
            cutoffSchaerfe: cutoffSharpness,
            zeitlicheStationaritaet: stationarity
        )
    }

    // MARK: - Interne Hilfsfunktionen

    private func framedSamples(_ samples: [Double]) -> [[Double]] {
        let hopSize = max(fftSize / 4, 256)
        let window = hannWindow(count: fftSize)
        var frames: [[Double]] = []
        var index = 0

        while index < samples.count {
            var frame = Array(repeating: 0.0, count: fftSize)
            let end = min(samples.count, index + fftSize)
            for i in index..<end {
                frame[i - index] = samples[i] * window[i - index]
            }
            frames.append(frame)
            index += hopSize
        }
        return frames
    }

    private func hannWindow(count: Int) -> [Double] {
        guard count > 1 else { return [1.0] }
        return (0..<count).map { i in
            0.5 - 0.5 * cos((2.0 * .pi * Double(i)) / Double(count - 1))
        }
    }

    private func powerSpectrum(for frame: [Double]) -> [Double] {
        let n = fftSize
        let log2n = vDSP_Length(log2(Double(n)))
        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return Array(repeating: 0.0, count: n / 2 + 1)
        }
        defer { vDSP_destroy_fftsetupD(fftSetup) }

        var real = frame
        if real.count < n { real.append(contentsOf: Array(repeating: 0.0, count: n - real.count)) }
        var imag = Array(repeating: 0.0, count: n)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var localSplit = DSPDoubleSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_fft_zipD(fftSetup, &localSplit, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }

        var magnitudes = Array(repeating: 0.0, count: n / 2 + 1)
        for i in 0...n/2 {
            let re = real[i]
            let im = imag[i]
            magnitudes[i] = re * re + im * im
        }
        return magnitudes
    }

    private func averageSpectrum(for frames: [[Double]]) -> [Double] {
        let binCount = fftSize / 2 + 1
        var accumulator = Array(repeating: 0.0, count: binCount)
        for frame in frames {
            let spectrum = powerSpectrum(for: frame)
            for i in 0..<binCount { accumulator[i] += spectrum[i] }
        }
        let divisor = max(Double(frames.count), 1.0)
        return accumulator.map { $0 / divisor }
    }

    private func applyMelFilterBank(to spectrum: [Double]) -> [Double] {
        let melMin = hzToMel(frequencyBand.0)
        let melMax = hzToMel(frequencyBand.1)
        let melPoints = (0..<(melBandCount + 2)).map { i -> Double in
            melMin + (Double(i) * (melMax - melMin) / Double(melBandCount + 1))
        }
        let hzPoints = melPoints.map(melToHz)
        let bins = hzPoints.map { frequencyToBin($0) }

        var energies = Array(repeating: 0.0, count: melBandCount)
        for band in 0..<melBandCount {
            let left = bins[band]
            let center = bins[band + 1]
            let right = bins[band + 2]
            guard right > left else { continue }

            if center > left {
                for k in left..<center {
                    let weight = Double(k - left) / Double(max(center - left, 1))
                    energies[band] += spectrum[clamped: k] * weight
                }
            }
            if right > center {
                for k in center..<right {
                    let weight = Double(right - k) / Double(max(right - center, 1))
                    energies[band] += spectrum[clamped: k] * weight
                }
            }
        }
        return energies
    }

    private func dctCoefficients(from melEnergies: [Double]) -> [Double] {
        let n = melEnergies.count
        var coefficients = Array(repeating: 0.0, count: coefficientCount)
        for k in 0..<coefficientCount {
            var sum = 0.0
            for nIdx in 0..<n {
                sum += melEnergies[nIdx] * cos(.pi / Double(n) * (Double(nIdx) + 0.5) * Double(k))
            }
            coefficients[k] = sum
        }
        return coefficients
    }

    private func deltaCoefficients(from frames: [[Double]]) -> [Double] {
        guard frames.count >= 3 else { return Array(repeating: 0.0, count: coefficientCount) }
        let coeffs = frames.map { dctCoefficients(from: applyMelFilterBank(to: powerSpectrum(for: $0)).map { log(max($0, 1.0e-12)) }) }
        var delta = Array(repeating: 0.0, count: coefficientCount)
        for i in 1..<(coeffs.count - 1) {
            for c in 0..<coefficientCount {
                delta[c] += (coeffs[i + 1][c] - coeffs[i - 1][c]) * 0.5
            }
        }
        return delta.map { $0 / Double(coeffs.count - 2) }
    }

    private func frameEnergy(_ frame: [Double]) -> Double {
        frame.reduce(0.0) { $0 + $1 * $1 } / Double(max(frame.count, 1))
    }

    private func spectralFlatness(of spectrum: [Double]) -> Double {
        let values = spectrum.map { max($0, 1.0e-12) }
        let gm = exp(values.map(log).reduce(0, +) / Double(values.count))
        let am = values.reduce(0, +) / Double(values.count)
        return am > 0 ? min(max(gm / am, 0), 1) : 0
    }

    private func spectralCutoffSharpness(of spectrum: [Double]) -> Double {
        guard spectrum.count > 4 else { return 0 }
        let peak = spectrum.max() ?? 0
        let median = spectrum.sorted()[spectrum.count / 2]
        return peak > 0 ? min(max((peak - median) / peak, 0), 1) : 0
    }

    private func temporalStationarity(frames: [[Double]]) -> Double {
        let energies = frames.map(frameEnergy)
        let mean = energies.reduce(0, +) / Double(energies.count)
        let std = standardDeviation(energies, mean: mean)
        return 1.0 / (1.0 + std / max(mean, 1.0e-12))
    }

    private func standardDeviation(_ values: [Double], mean: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let variance = values.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return sqrt(variance)
    }

    private func hzToMel(_ hz: Double) -> Double { 2595.0 * log10(1.0 + hz / 700.0) }
    private func melToHz(_ mel: Double) -> Double { 700.0 * (pow(10.0, mel / 2595.0) - 1.0) }
    private func frequencyToBin(_ hz: Double) -> Int {
        let bin = Int((hz / (sampleRate / 2.0)) * Double(fftSize / 2))
        return max(0, min(fftSize / 2, bin))
    }
}

private extension Array {
    /// Zugriff mit Begrenzung: außerhalb liegende Indizes liefern das erste bzw. letzte Element.
    subscript(clamped index: Int) -> Element {
        precondition(!isEmpty, "clamped subscript auf leerem Array")
        if index < 0 { return self[0] }
        if index >= count { return self[count - 1] }
        return self[index]
    }
}
