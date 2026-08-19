import Foundation

// MARK: - Signalverarbeitung für Grundlinie, Fingerprint und Artefakt-Ergebnis
final class SignalProcessor {
    init() {}
    
    // Ermittelt aus einem FFT-Ensemble das zusammengefasste Artefakt-Ergebnis.
    func verarbeite(ensemble: EnsembleErgebnis) -> ArtefaktErgebnis {
        let haupt = ensemble.hauptErgebnis
        let gewicht = max(0, min(1, ensemble.ensembleScore))
        let varianzBonus = min(1, ensemble.ensembleVarianz / 10.0)
        let score = max(0, min(1, haupt.artefaktStaerke * 0.7 + gewicht * 0.2 + varianzBonus * 0.1))
        return ArtefaktErgebnis(frequenzen: haupt.frequenzen, mittleresSpektrumDB: haupt.mittleresSpektrumDB, grundlinieDB: haupt.grundlinieDB, fingerprint: haupt.fingerprint, peakIndizes: haupt.peakIndizes, peakFrequenzen: haupt.peakFrequenzen, peakProminenzen: haupt.peakProminenzen, peakAbstandHz: haupt.peakAbstandHz, regelmaessigkeit: haupt.regelmaessigkeit, artefaktStaerke: score, anzahlPeaks: haupt.anzahlPeaks)
    }
    
    // Berechnet eine robuste Grundlinie als geglättete Hüllkurve.
    func berechneGrundlinie(spektrum: [Double]) -> [Double] {
        guard !spektrum.isEmpty else { return [] }
        let fenster = max(3, spektrum.count / 48)
        return spektrum.enumerated().map { index, wert in
            let lower = max(0, index - fenster)
            let upper = min(spektrum.count - 1, index + fenster)
            let slice = spektrum[lower...upper]
            return slice.sorted()[max(0, slice.count / 4)]
        }
    }
    
    // Bildet den Fingerprint als Differenz zwischen Spektrum und Grundlinie.
    func berechneFingerprint(spektrum: [Double], grundlinie: [Double]) -> [Double] {
        let count = min(spektrum.count, grundlinie.count)
        guard count > 0 else { return [] }
        return (0..<count).map { max(0, spektrum[$0] - grundlinie[$0]) }
    }
    
    // Erkennt signifikante Peaks und bewertet die Regelmäßigkeit.
    func erkennePeaks(fingerprint: [Double]) -> (indizes: [Int], frequenzen: [Double], prominenzen: [Double], regelmaessigkeit: Double) {
        guard fingerprint.count >= 3 else { return ([], [], [], 0) }
        var peakIndizes: [Int] = []
        var peakProminenzen: [Double] = []
        for i in 1..<(fingerprint.count - 1) {
            if fingerprint[i] > fingerprint[i - 1], fingerprint[i] >= fingerprint[i + 1], fingerprint[i] > 0.12 {
                let lokalerBoden = min(fingerprint[max(0, i - 6)...i].min() ?? 0, fingerprint[i...min(fingerprint.count - 1, i + 6)].min() ?? 0)
                peakIndizes.append(i)
                peakProminenzen.append(max(0, fingerprint[i] - lokalerBoden))
            }
        }
        let abstaende = zip(peakIndizes, peakIndizes.dropFirst()).map { Double($1 - $0) }
        let regelmaessigkeit = berechneRegelmaessigkeit(abstaende: abstaende, prominenzen: peakProminenzen)
        return (peakIndizes, peakIndizes.map { Double($0) }, peakProminenzen, regelmaessigkeit)
    }
    
    // Bewertet Artefaktstärke anhand von Peaks, Fingerprint-Energie und Regelmäßigkeit.
    func berechneArtefaktStaerke(fingerprint: [Double], peakAnzahl: Int, regelmaessigkeit: Double) -> Double {
        let energie = fingerprint.isEmpty ? 0 : fingerprint.reduce(0, +) / Double(fingerprint.count)
        let energieScore = min(1, energie / 10.0)
        let peakScore = min(1, Double(peakAnzahl) / 16.0)
        return max(0, min(1, energieScore * 0.45 + peakScore * 0.35 + regelmaessigkeit * 0.20))
    }
    
    private func berechneRegelmaessigkeit(abstaende: [Double], prominenzen: [Double]) -> Double {
        guard !abstaende.isEmpty else { return 0 }
        let mean = abstaende.reduce(0, +) / Double(abstaende.count)
        let variance = abstaende.map { pow($0 - mean, 2) }.reduce(0, +) / Double(abstaende.count)
        let cv = mean > 0 ? sqrt(variance) / mean : 1
        let prominence = prominenzen.isEmpty ? 0 : min(1, prominenzen.reduce(0, +) / Double(prominenzen.count) / 6.0)
        return max(0, min(1, (1 - min(cv, 1)) * 0.75 + prominence * 0.25))
    }
}
