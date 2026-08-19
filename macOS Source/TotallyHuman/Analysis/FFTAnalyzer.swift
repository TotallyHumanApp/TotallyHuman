import Foundation
import Accelerate

// MARK: - Segmentweise FFT-Ensemble-Analyse
final class FFTAnalyzer {
    init() {}
    
    // Berechnet für jede FFT-Größe ein Artefakt-Ergebnis und bündelt diese zu einem Ensemble-Ergebnis.
    func analysiereEnsemble(samples: [Float], sampleRate: Double) -> EnsembleErgebnis {
        let fftGroessen = AnalysisConfig.fftSizes
        let fftWeights = AnalysisConfig.fftWeights
        var resultate: [ArtefaktErgebnis] = []
        var einzelScores: [Double] = []
        
        for groesse in fftGroessen {
            let artefakt = analysiere(samples: samples, sampleRate: sampleRate, fftSize: groesse)
            resultate.append(artefakt)
            einzelScores.append(artefakt.artefaktStaerke)
        }
        
        let gewichteteSumme = zip(einzelScores, fftWeights).reduce(0.0) { $0 + ($1.0 * $1.1) }
        let normGewichte = fftWeights.reduce(0, +)
        let ensembleScore = normGewichte > 0 ? gewichteteSumme / normGewichte : 0
        let mean = einzelScores.reduce(0, +) / Double(max(1, einzelScores.count))
        let ensembleVarianz = einzelScores.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(1, einzelScores.count))
        let hauptErgebnis = resultate[min(1, max(0, resultate.count - 1))]
        
        return EnsembleErgebnis(hauptErgebnis: hauptErgebnis, einzelScores: einzelScores, ensembleVarianz: ensembleVarianz, ensembleScore: ensembleScore)
    }
    
    // FFT-Analyse für ein einzelnes Fenster.
    func analysiere(samples: [Float], sampleRate: Double, fftSize: Int) -> ArtefaktErgebnis {
        let segment = Array(samples.prefix(fftSize))
        let padded = pad(segment: segment, to: fftSize)
        let spektrum = amplitudeSpectrum(samples: padded, fftSize: fftSize)
        let freqs = frequenzen(fftSize: fftSize, sampleRate: sampleRate)
        let band = AnalysisConfig.analysisFreqBandHz
        let selektierteIndizes = freqs.indices.filter { freqs[$0] >= band.0 && freqs[$0] <= band.1 }
        let selektierteFrequenzen = selektierteIndizes.map { freqs[$0] }
        let selektiertesSpektrum = selektierteIndizes.map { spektrum[$0] }
        let grundlinie = morphologischeGrundlinie(selektiertesSpektrum)
        let fingerprint = zip(selektiertesSpektrum, grundlinie).map { max(0, $0 - $1) }
        let peaks = erkennePeaks(values: fingerprint)
        let peakIndizes = peaks.map { $0.index }
        let peakFrequenzen = peaks.map { selektierteFrequenzen[$0.index] }
        let peakProminenzen = peaks.map { $0.prominenz }
        let peakAbstandHz = mittlererPeakAbstand(frequenzen: peakFrequenzen)
        let regelmaessigkeit = berechneRegelmaessigkeit(peakFrequenzen: peakFrequenzen, prominenzen: peakProminenzen)
        let artefaktStaerke = berechneArtefaktStaerke(fingerprint: fingerprint, peaks: peaks, regelmaessigkeit: regelmaessigkeit)
        
        return ArtefaktErgebnis(frequenzen: selektierteFrequenzen, mittleresSpektrumDB: selektiertesSpektrum, grundlinieDB: grundlinie, fingerprint: fingerprint, peakIndizes: peakIndizes, peakFrequenzen: peakFrequenzen, peakProminenzen: peakProminenzen, peakAbstandHz: peakAbstandHz, regelmaessigkeit: regelmaessigkeit, artefaktStaerke: artefaktStaerke, anzahlPeaks: peakIndizes.count)
    }
    
    private func pad(segment: [Float], to fftSize: Int) -> [Float] {
        guard segment.count < fftSize else { return Array(segment.prefix(fftSize)) }
        return segment + [Float](repeating: 0, count: fftSize - segment.count)
    }
    
    private func amplitudeSpectrum(samples: [Float], fftSize: Int) -> [Double] {
        guard fftSize > 0, samples.count >= fftSize else { return [] }
        let log2n = vDSP_Length(log2(Double(fftSize)))
        let halfN = fftSize / 2

        // Hamming-Fenster anwenden
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hamm_window(&window, vDSP_Length(fftSize), 0)
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var real = [Float](repeating: 0, count: halfN)
        var imag = [Float](repeating: 0, count: halfN)
        var magnitudes = [Float](repeating: 0, count: halfN)

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer { wp in
                    wp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { cp in
                        vDSP_ctoz(cp, 2, &split, 1, vDSP_Length(halfN))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(halfN))
            }
        }
        return magnitudes.map { 10.0 * log10(Double(max($0, 1e-12))) }
    }
    
    private func frequenzen(fftSize: Int, sampleRate: Double) -> [Double] {
        let bins = max(1, fftSize / 2)
        return (0..<bins).map { Double($0) * sampleRate / Double(fftSize) }
    }
    
    private func morphologischeGrundlinie(_ values: [Double]) -> [Double] {
        guard !values.isEmpty else { return [] }
        let radius = max(2, values.count / 64)
        return values.enumerated().map { index, _ in
            let lower = max(0, index - radius)
            let upper = min(values.count - 1, index + radius)
            return values[lower...upper].min() ?? values[index]
        }
    }
    
    private func erkennePeaks(values: [Double]) -> [(index: Int, prominenz: Double)] {
        guard values.count >= 3 else { return [] }
        var peaks: [(Int, Double)] = []
        for i in 1..<(values.count - 1) {
            if values[i] > values[i - 1], values[i] >= values[i + 1], values[i] > 0.15 {
                let localMin = min(values[max(0, i - 8)...i].min() ?? 0, values[i...min(values.count - 1, i + 8)].min() ?? 0)
                peaks.append((i, max(0, values[i] - localMin)))
            }
        }
        return peaks.sorted { $0.1 > $1.1 }
    }
    
    private func mittlererPeakAbstand(frequenzen: [Double]) -> Double {
        guard frequenzen.count >= 2 else { return 0 }
        let abstaende = zip(frequenzen, frequenzen.dropFirst()).map { $1 - $0 }
        return abstaende.reduce(0, +) / Double(abstaende.count)
    }
    
    private func berechneRegelmaessigkeit(peakFrequenzen: [Double], prominenzen: [Double]) -> Double {
        guard peakFrequenzen.count >= 2 else { return 0 }
        let abstaende = zip(peakFrequenzen, peakFrequenzen.dropFirst()).map { $1 - $0 }
        let mean = abstaende.reduce(0, +) / Double(abstaende.count)
        let variance = abstaende.map { pow($0 - mean, 2) }.reduce(0, +) / Double(abstaende.count)
        let cv = mean > 0 ? sqrt(variance) / mean : 1
        let prominenceScore = min(1, (prominenzen.reduce(0, +) / Double(prominenzen.count)) / 6.0)
        return max(0, min(1, (1.0 - min(cv, 1.0)) * 0.7 + prominenceScore * 0.3))
    }
    
    private func berechneArtefaktStaerke(fingerprint: [Double], peaks: [(index: Int, prominenz: Double)], regelmaessigkeit: Double) -> Double {
        let peakScore = min(1, Double(peaks.count) / 12.0)
        let meanFingerprint = fingerprint.isEmpty ? 0 : fingerprint.reduce(0, +) / Double(fingerprint.count)
        let energyScore = min(1, max(0, meanFingerprint / 12.0))
        let regularityBonus = regelmaessigkeit * 0.35
        return max(0, min(1, peakScore * 0.45 + energyScore * 0.4 + regularityBonus))
    }
}
