import Foundation
import AVFoundation
import Accelerate

/// Native Nachbildung der Python-Analysekette aus `ki_musik_detektor_v7_improved.py`.
///
/// Wichtig für Kompatibilität mit dem importierten Modell/den Trainingsdaten:
/// Der 128-dimensionale Merkmalsvektor MUSS exakt wie in Python berechnet werden:
///   1. Audio laden -> 44100 Hz, Mono, auf max |x| = 1.0 normalisiert
///   2. Zeitlich gemitteltes Leistungsspektrum (n_fft = 4096, hop = 1024, Hann-Fenster)
///   3. Grundlinie via Minimum- -> Maximum- -> Uniform-Filter (Fenster 21, Modus "reflect")
///   4. Fingerprint = Spektrum(dB) - Grundlinie(dB)  (KEINE Begrenzung auf >= 0)
///   5. Auf Band 5000-16000 Hz beschränken
///   6. In 128 gleich große Index-Bereiche aufteilen und je Bereich mitteln
///
/// Ein konstanter dB-Offset (durch FFT-Skalierung/Normalisierung) hebt sich in Schritt 4
/// vollständig heraus, daher ist die absolute Skalierung unkritisch — nur die Form zählt.
enum AudioAnalyzer {

    struct AnalyseResultat {
        var frequenzenBand: [Double]
        var spektrumBandDB: [Double]
        var grundlinieBandDB: [Double]
        var fingerprintBand: [Double]
        var merkmalsvektor: [Double]        // 128-dim, kompatibel mit Python
        var peakFrequenzen: [Double]
        var peakProminenzen: [Double]
        var peakAbstandHz: Double
        var regelmaessigkeit: Double
        var artefaktStaerke: Double
        var dauerSekunden: Double
        var segmentZeiten: [(Double, Double)]
        var segmentStaerken: [Double]
    }

    static let sampleRate: Double = 44100.0
    static let nFFT: Int = 4096
    static let hop: Int = 1024
    static let bandUnten: Double = 5000.0
    static let bandOben: Double = 16000.0
    static let featureBins: Int = 128

    enum AnalyseFehler: LocalizedError {
        case dateiNichtLesbar(String)
        case keineSamples
        var errorDescription: String? {
            switch self {
            case .dateiNichtLesbar(let p): return Loc.s("Audiodatei konnte nicht gelesen werden: \(p)",
                                                        "Audio file could not be read: \(p)")
            case .keineSamples: return Loc.s("Die Audiodatei enthält keine Samples.",
                                             "The audio file contains no samples.")
            }
        }
    }

    // MARK: - Öffentliche API

    /// Liest eine Datei und führt die vollständige Analyse durch.
    static func analysiere(url: URL) throws -> AnalyseResultat {
        let samples = try ladeMonoSamples(url: url, zielRate: sampleRate)
        guard !samples.isEmpty else { throw AnalyseFehler.keineSamples }
        return analysiere(samples: samples, sampleRate: sampleRate)
    }

    /// Berechnet nur den 128-dim Merkmalsvektor (für das Training).
    static func merkmalsvektor(url: URL) throws -> [Double] {
        try analysiere(url: url).merkmalsvektor
    }

    // MARK: - Audio laden (AVFoundation)

    /// Dekodiert eine beliebige Audiodatei zu Mono-Float bei `zielRate` und normalisiert.
    static func ladeMonoSamples(url: URL, zielRate: Double) throws -> [Double] {
        guard let file = try? AVAudioFile(forReading: url) else {
            throw AnalyseFehler.dateiNichtLesbar(url.path)
        }
        let quellFormat = file.processingFormat
        guard let zielFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: zielRate,
                                             channels: 1,
                                             interleaved: false) else {
            throw AnalyseFehler.dateiNichtLesbar(url.path)
        }

        guard let converter = AVAudioConverter(from: quellFormat, to: zielFormat) else {
            throw AnalyseFehler.dateiNichtLesbar(url.path)
        }

        let quellFrames = AVAudioFrameCount(file.length)
        guard quellFrames > 0,
              let quellBuffer = AVAudioPCMBuffer(pcmFormat: quellFormat, frameCapacity: quellFrames) else {
            throw AnalyseFehler.keineSamples
        }
        try file.read(into: quellBuffer)

        // Ausgabekapazität grob abschätzen (Ratio + Puffer).
        let ratio = zielRate / quellFormat.sampleRate
        let zielKapazitaet = AVAudioFrameCount(Double(quellFrames) * ratio + 4096)
        guard let zielBuffer = AVAudioPCMBuffer(pcmFormat: zielFormat, frameCapacity: zielKapazitaet) else {
            throw AnalyseFehler.keineSamples
        }

        var geliefert = false
        var fehler: NSError?
        let status = converter.convert(to: zielBuffer, error: &fehler) { _, outStatus in
            if geliefert {
                outStatus.pointee = .noDataNow
                return nil
            }
            geliefert = true
            outStatus.pointee = .haveData
            return quellBuffer
        }

        if status == .error { throw AnalyseFehler.dateiNichtLesbar(url.path) }

        let anzahl = Int(zielBuffer.frameLength)
        guard anzahl > 0, let ch = zielBuffer.floatChannelData else { throw AnalyseFehler.keineSamples }
        let ptr = ch[0]
        var out = [Double](repeating: 0, count: anzahl)
        for i in 0..<anzahl { out[i] = Double(ptr[i]) }

        // Normalisierung auf max |x| = 1.0 (stille Dateien unverändert lassen).
        var maxBetrag = 0.0
        for v in out { let a = abs(v); if a > maxBetrag { maxBetrag = a } }
        if maxBetrag > 1e-8 {
            let inv = 1.0 / maxBetrag
            for i in 0..<out.count { out[i] *= inv }
        }
        return out
    }

    // MARK: - Vollständige Analyse

    static func analysiere(samples: [Double], sampleRate sr: Double) -> AnalyseResultat {
        // 1. Gemitteltes Leistungsspektrum (dB) + Frequenzen
        let (freqs, spektrumDB) = mittleresSpektrumDB(signal: samples, sampleRate: sr, nFFT: nFFT, hop: hop)

        // 2. Grundlinie über volle Auflösung
        let grundlinie = schaetzeGrundlinie(spektrumDB: spektrumDB, fensterBins: 21)

        // 3. Fingerprint über volle Auflösung
        let fingerprintVoll = zip(spektrumDB, grundlinie).map { $0 - $1 }

        // 4. Band beschränken
        let nyquist = sr / 2.0
        let ober = min(bandOben, nyquist - 1.0)
        var idxBand: [Int] = []
        idxBand.reserveCapacity(freqs.count)
        for (i, f) in freqs.enumerated() where f >= bandUnten && f <= ober {
            idxBand.append(i)
        }
        let fBand = idxBand.map { freqs[$0] }
        let fpBand = idxBand.map { fingerprintVoll[$0] }
        let spekBand = idxBand.map { spektrumDB[$0] }
        let grundBand = idxBand.map { grundlinie[$0] }

        // 5. 128-dim Merkmalsvektor (Index-Mittelung)
        let vektor = binMittel(fpBand, bins: featureBins)

        // 6. Peaks & Regelmäßigkeit (nur für Anzeige/Heuristik)
        let (peakFreqs, peakProms) = findePeaks(fingerprint: fpBand, frequenzen: fBand, prominenz: 1.0)
        let (abstand, regel) = bewerteRegelmaessigkeit(peakFrequenzen: peakFreqs, fingerprintBand: fpBand)
        let topN = min(10, peakProms.count)
        let topProminenz = topN > 0 ? Array(peakProms.sorted().suffix(topN)).reduce(0,+) / Double(topN) : 0.0
        let artefakt = topProminenz * (0.3 + 0.7 * regel)

        let dauer = Double(samples.count) / sr

        // Zeitliche Segmente (10 s) — vereinfachte Stärke je Segment
        var segZeiten: [(Double, Double)] = []
        var segStaerken: [Double] = []
        let segLen = Int(10.0 * sr)
        if segLen > 0 {
            var start = 0
            while start < samples.count {
                let ende = min(start + segLen, samples.count)
                if ende - start < Int(2.0 * sr) { break }
                let seg = Array(samples[start..<ende])
                let (_, sdb) = mittleresSpektrumDB(signal: seg, sampleRate: sr, nFFT: nFFT, hop: hop)
                let base = schaetzeGrundlinie(spektrumDB: sdb, fensterBins: 21)
                let fp = zip(sdb, base).map { $0 - $1 }
                let bandFp = idxBand.filter { $0 < fp.count }.map { fp[$0] }
                let (_, pr) = findePeaks(fingerprint: bandFp, frequenzen: fBand, prominenz: 1.0)
                let tN = min(10, pr.count)
                let tp = tN > 0 ? Array(pr.sorted().suffix(tN)).reduce(0,+) / Double(tN) : 0.0
                segZeiten.append((Double(start)/sr, Double(ende)/sr))
                segStaerken.append(tp)
                start += segLen
            }
        }

        return AnalyseResultat(
            frequenzenBand: fBand,
            spektrumBandDB: spekBand,
            grundlinieBandDB: grundBand,
            fingerprintBand: fpBand,
            merkmalsvektor: vektor,
            peakFrequenzen: peakFreqs,
            peakProminenzen: peakProms,
            peakAbstandHz: abstand,
            regelmaessigkeit: regel,
            artefaktStaerke: artefakt,
            dauerSekunden: dauer,
            segmentZeiten: segZeiten,
            segmentStaerken: segStaerken
        )
    }

    // MARK: - Gemitteltes Leistungsspektrum (vDSP)

    static func mittleresSpektrumDB(signal: [Double], sampleRate sr: Double, nFFT: Int, hop: Int) -> (freqs: [Double], db: [Double]) {
        let halfN = nFFT / 2
        let bins = halfN + 1              // wie np.fft.rfft: N/2 + 1
        let frequenzen = (0..<bins).map { Double($0) * sr / Double(nFFT) }

        // Hann-Fenster exakt wie np.hanning: w[n] = 0.5 - 0.5*cos(2*pi*n/(N-1))
        var fenster = [Float](repeating: 0, count: nFFT)
        let denom = Double(nFFT - 1)
        for n in 0..<nFFT {
            fenster[n] = Float(0.5 - 0.5 * cos(2.0 * Double.pi * Double(n) / denom))
        }

        guard signal.count >= 1 else {
            return (frequenzen, [Double](repeating: 10.0 * log10(1e-12), count: bins))
        }

        let log2n = vDSP_Length(log2(Double(nFFT)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return (frequenzen, [Double](repeating: 10.0 * log10(1e-12), count: bins))
        }
        defer { vDSP_destroy_fftsetup(setup) }

        var powerSumme = [Double](repeating: 0, count: bins)
        var frameZahl = 0

        var windowed = [Float](repeating: 0, count: nFFT)
        var real = [Float](repeating: 0, count: halfN)
        var imag = [Float](repeating: 0, count: halfN)
        var quadrate = [Float](repeating: 0, count: halfN)

        let signalF = signal.map { Float($0) }
        let letzterStart = signalF.count - nFFT
        var start = 0
        while start <= letzterStart {
            // Fensterung
            signalF.withUnsafeBufferPointer { sp in
                vDSP_vmul(sp.baseAddress! + start, 1, fenster, 1, &windowed, 1, vDSP_Length(nFFT))
            }
            real.withUnsafeMutableBufferPointer { rp in
                imag.withUnsafeMutableBufferPointer { ip in
                    var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                    windowed.withUnsafeBufferPointer { wp in
                        wp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { cp in
                            vDSP_ctoz(cp, 2, &split, 1, vDSP_Length(halfN))
                        }
                    }
                    vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                    // quadrate[k] = real[k]^2 + imag[k]^2  (k = 0..halfN-1)
                    vDSP_zvmags(&split, 1, &quadrate, 1, vDSP_Length(halfN))
                    // DC steckt in real[0], Nyquist in imag[0] (gepackt) -> hier separat behandeln.
                    let dc = Double(rp[0])
                    let ny = Double(ip[0])
                    powerSumme[0] += dc * dc
                    powerSumme[halfN] += ny * ny
                    for k in 1..<halfN {
                        powerSumme[k] += Double(quadrate[k])
                    }
                }
            }
            frameZahl += 1
            start += hop
        }

        if frameZahl == 0 {
            // Signal kürzer als nFFT: einmal mit Zero-Padding.
            var padded = [Float](repeating: 0, count: nFFT)
            for i in 0..<min(nFFT, signalF.count) { padded[i] = signalF[i] }
            vDSP_vmul(padded, 1, fenster, 1, &windowed, 1, vDSP_Length(nFFT))
            real.withUnsafeMutableBufferPointer { rp in
                imag.withUnsafeMutableBufferPointer { ip in
                    var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                    windowed.withUnsafeBufferPointer { wp in
                        wp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { cp in
                            vDSP_ctoz(cp, 2, &split, 1, vDSP_Length(halfN))
                        }
                    }
                    vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                    vDSP_zvmags(&split, 1, &quadrate, 1, vDSP_Length(halfN))
                    let dc = Double(rp[0]); let ny = Double(ip[0])
                    powerSumme[0] += dc * dc
                    powerSumme[halfN] += ny * ny
                    for k in 1..<halfN { powerSumme[k] += Double(quadrate[k]) }
                }
            }
            frameZahl = 1
        }

        let inv = 1.0 / Double(frameZahl)
        let db = powerSumme.map { 10.0 * log10($0 * inv + 1e-12) }
        return (frequenzen, db)
    }

    // MARK: - Grundlinie (Minimum -> Maximum -> Uniform), reflect

    static func schaetzeGrundlinie(spektrumDB: [Double], fensterBins: Int) -> [Double] {
        let untere = minimumFilter1d(spektrumDB, size: fensterBins)
        let obere = maximumFilter1d(untere, size: fensterBins)
        return uniformFilter1d(obere, size: fensterBins)
    }

    private static func reflectIndex(_ j: Int, _ n: Int) -> Int {
        // scipy 'reflect' (d c b a | a b c d | d c b a)
        if n == 1 { return 0 }
        var i = j
        let periode = 2 * n
        i = ((i % periode) + periode) % periode
        if i >= n { i = periode - 1 - i }
        return i
    }

    private static func minimumFilter1d(_ x: [Double], size: Int) -> [Double] {
        let n = x.count
        guard n > 0 else { return x }
        let r = size / 2
        var out = [Double](repeating: 0, count: n)
        for i in 0..<n {
            var m = Double.greatestFiniteMagnitude
            for d in -r...r {
                let v = x[reflectIndex(i + d, n)]
                if v < m { m = v }
            }
            out[i] = m
        }
        return out
    }

    private static func maximumFilter1d(_ x: [Double], size: Int) -> [Double] {
        let n = x.count
        guard n > 0 else { return x }
        let r = size / 2
        var out = [Double](repeating: 0, count: n)
        for i in 0..<n {
            var m = -Double.greatestFiniteMagnitude
            for d in -r...r {
                let v = x[reflectIndex(i + d, n)]
                if v > m { m = v }
            }
            out[i] = m
        }
        return out
    }

    private static func uniformFilter1d(_ x: [Double], size: Int) -> [Double] {
        let n = x.count
        guard n > 0 else { return x }
        let r = size / 2
        var out = [Double](repeating: 0, count: n)
        for i in 0..<n {
            var s = 0.0
            for d in -r...r { s += x[reflectIndex(i + d, n)] }
            out[i] = s / Double(size)
        }
        return out
    }

    // MARK: - 128-Bin-Mittelung (np.linspace Index-Aufteilung)

    static func binMittel(_ fp: [Double], bins: Int) -> [Double] {
        guard !fp.isEmpty else { return [Double](repeating: 0, count: bins) }
        // indizes = linspace(0, fp.size, bins+1).astype(int)
        var grenzen = [Int](repeating: 0, count: bins + 1)
        let size = Double(fp.count)
        for i in 0...bins {
            grenzen[i] = Int(size * Double(i) / Double(bins))  // linspace(0,size,bins+1)
        }
        var out = [Double](repeating: 0, count: bins)
        for i in 0..<bins {
            let a = grenzen[i]
            let b = grenzen[i + 1]
            if b > a {
                var s = 0.0
                for k in a..<b { s += fp[k] }
                out[i] = s / Double(b - a)
            } else {
                out[i] = 0.0
            }
        }
        return out
    }

    // MARK: - Peak-Erkennung (vereinfachte scipy.find_peaks-Nachbildung)

    private static func findePeaks(fingerprint fp: [Double], frequenzen f: [Double], prominenz: Double) -> (freqs: [Double], proms: [Double]) {
        guard fp.count >= 3 else { return ([], []) }
        var freqs: [Double] = []
        var proms: [Double] = []
        for i in 1..<(fp.count - 1) {
            if fp[i] > fp[i - 1] && fp[i] >= fp[i + 1] && fp[i] >= prominenz {
                // lokale Prominenz: Höhe über dem höheren der beiden benachbarten Täler
                var linksMin = fp[i]
                var j = i
                while j > 0 && fp[j] <= fp[i] { linksMin = min(linksMin, fp[j]); j -= 1 }
                var rechtsMin = fp[i]
                var k = i
                while k < fp.count - 1 && fp[k] <= fp[i] { rechtsMin = min(rechtsMin, fp[k]); k += 1 }
                let basis = max(linksMin, rechtsMin)
                let p = fp[i] - basis
                if p >= prominenz {
                    freqs.append(f[i])
                    proms.append(p)
                }
            }
        }
        return (freqs, proms)
    }

    private static func bewerteRegelmaessigkeit(peakFrequenzen: [Double], fingerprintBand fp: [Double]) -> (abstand: Double, regel: Double) {
        guard peakFrequenzen.count >= 3 else { return (0, 0) }
        let sortiert = peakFrequenzen.sorted()
        var abstaende: [Double] = []
        for i in 1..<sortiert.count { abstaende.append(sortiert[i] - sortiert[i - 1]) }
        let mittel = abstaende.reduce(0, +) / Double(abstaende.count)
        var regelAbstand = 0.0
        if mittel > 1e-6 {
            let varianz = abstaende.map { pow($0 - mittel, 2) }.reduce(0, +) / Double(abstaende.count)
            let cv = sqrt(varianz) / mittel
            regelAbstand = max(0, min(1, 1 - cv))
        }
        // Autokorrelation des zentrierten Fingerprints
        let m = fp.reduce(0,+) / Double(fp.count)
        let zentriert = fp.map { $0 - m }
        var auto0 = 0.0
        for v in zentriert { auto0 += v * v }
        var regelAuto = 0.0
        if auto0 > 1e-9 {
            var maxNeben = 0.0
            let maxLag = min(zentriert.count - 1, zentriert.count)
            if zentriert.count > 5 {
                for lag in 3..<maxLag {
                    var s = 0.0
                    for i in 0..<(zentriert.count - lag) { s += zentriert[i] * zentriert[i + lag] }
                    let norm = s / auto0
                    if norm > maxNeben { maxNeben = norm }
                }
            }
            regelAuto = max(0, min(1, maxNeben))
        }
        let regel = 0.5 * regelAbstand + 0.5 * regelAuto
        return (mittel, max(0, min(1, regel)))
    }
}
