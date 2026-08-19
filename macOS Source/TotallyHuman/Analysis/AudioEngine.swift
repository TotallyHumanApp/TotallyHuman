import Foundation
import AVFoundation
import Accelerate

// MARK: - Audio-Engine für das Laden und Vorverarbeiten von Audiodateien
final class AudioEngine {
    struct AudioAnalyseDaten {
        let sampleRate: Double
        let kanalAnzahl: Int
        let dauerSeconds: Double
        let samples: [Float]
    }
    
    init() {}
    
    // Lädt eine Audiodatei, wandelt sie in Mono um, resampelt auf die Standard-Rate und normalisiert die Amplitude.
    func ladeUndVorverarbeiteAudio(dateiPfad: String) throws -> AudioAnalyseDaten {
        let url = URL(fileURLWithPath: dateiPfad)
        let audioDatei = try AVAudioFile(forReading: url)
        let inputFormat = audioDatei.processingFormat
        let inputFrameCount = AVAudioFrameCount(audioDatei.length)
        guard inputFrameCount > 0 else {
            return AudioAnalyseDaten(sampleRate: AnalysisConfig.standardSampleRate, kanalAnzahl: 1, dauerSeconds: 0, samples: [])
        }
        
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: inputFrameCount) else {
            throw NSError(domain: "AudioEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Der Audio-Puffer konnte nicht erstellt werden."])
        }
        try audioDatei.read(into: inputBuffer)
        
        let kanalAnzahl = Int(inputFormat.channelCount)
        let monoSamples = konvertiereZuMono(buffer: inputBuffer)
        let monoSampleRate = inputFormat.sampleRate
        let targetSampleRate = AnalysisConfig.standardSampleRate
        let resampled = resample(samples: monoSamples, from: monoSampleRate, to: targetSampleRate)
        let normalisiert = normalisiere(samples: resampled)
        let dauerSeconds = Double(normalisiert.count) / targetSampleRate
        
        return AudioAnalyseDaten(sampleRate: targetSampleRate, kanalAnzahl: kanalAnzahl, dauerSeconds: dauerSeconds, samples: normalisiert)
    }
    
    // Zerlegt die Audiodaten in überlappungsfreie Segmente fester Länge.
    func segmentiere(samples: [Float], sampleRate: Double, segmentLengthSeconds: Double = AnalysisConfig.segmentLengthSeconds) -> [[Float]] {
        let segmentLaenge = max(1, Int(segmentLengthSeconds * sampleRate))
        guard !samples.isEmpty else { return [] }
        var ergebnis: [[Float]] = []
        var index = 0
        while index < samples.count {
            let endIndex = min(index + segmentLaenge, samples.count)
            ergebnis.append(Array(samples[index..<endIndex]))
            index = endIndex
        }
        return ergebnis
    }
    
    private func konvertiereZuMono(buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return [] }
        
        if channelCount == 1 {
            return Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        }
        
        var mono = [Float](repeating: 0, count: frameLength)
        for channel in 0..<channelCount {
            let data = channelData[channel]
            for frame in 0..<frameLength {
                mono[frame] += data[frame] / Float(channelCount)
            }
        }
        return mono
    }
    
    private func resample(samples: [Float], from inputSampleRate: Double, to targetSampleRate: Double) -> [Float] {
        guard !samples.isEmpty else { return [] }
        if abs(inputSampleRate - targetSampleRate) < 0.5 { return samples }
        let ratio = targetSampleRate / inputSampleRate
        let outputCount = max(1, Int((Double(samples.count) * ratio).rounded()))
        return linearesResampling(samples: samples, outputCount: outputCount)
    }
    
    private func linearesResampling(samples: [Float], outputCount: Int) -> [Float] {
        guard samples.count > 1, outputCount > 0 else { return samples }
        var output = [Float](repeating: 0, count: outputCount)
        let scale = Double(samples.count - 1) / Double(max(1, outputCount - 1))
        for i in 0..<outputCount {
            let position = Double(i) * scale
            let lower = Int(floor(position))
            let upper = min(lower + 1, samples.count - 1)
            let frac = Float(position - Double(lower))
            output[i] = samples[lower] * (1 - frac) + samples[upper] * frac
        }
        return output
    }
    
    private func normalisiere(samples: [Float]) -> [Float] {
        guard let maxAbs = samples.map({ abs($0) }).max(), maxAbs > 0 else { return samples }
        let faktor = 1.0 / maxAbs
        return samples.map { $0 * faktor }
    }
}
