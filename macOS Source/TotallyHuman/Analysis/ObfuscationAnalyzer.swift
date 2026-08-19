// ObfuscationAnalyzer.swift — Verschleierungsanalyse, Spektralmerkmale und Gesamtbewertung
// Totally Human — native Analysekomponente für macOS 13+

import Foundation

/// Bewertet typische Verschleierungsstrategien wie Splices, Mastering-Anomalien und Wiederholungsmuster.
struct ObfuscationAnalyzer {
    let mfccProcessor: MFCCProcessor
    let temporalAnalyzer: TemporalAnalyzer
    let ssmAnalyzer: SelfSimilarityMatrix

    init(mfccProcessor: MFCCProcessor = MFCCProcessor(),
         temporalAnalyzer: TemporalAnalyzer = TemporalAnalyzer(),
         ssmAnalyzer: SelfSimilarityMatrix = SelfSimilarityMatrix()) {
        self.mfccProcessor = mfccProcessor
        self.temporalAnalyzer = temporalAnalyzer
        self.ssmAnalyzer = ssmAnalyzer
    }

    /// Führt eine Verschleierungsanalyse auf einem Sampleset aus.
    func analyze(samples: [Double]) -> VerschleierungsErgebnis {
        let spectral = mfccProcessor.spectralFeatures(from: samples)
        let featureVector = mfccProcessor.extrahiereMerkmalsvektor(from: samples)
        let ssmAnalysis = ssmAnalyzer.analyze(featureVector: featureVector)
        let splice = temporalAnalyzer.spliceErkennung(samples: samples, featureProvider: mfccProcessor)

        let masteringAnomaly = detectMasteringAnomaly(spectral: spectral, ssmScore: ssmAnalysis.score)
        let repetitionAnomaly = detectRepetitionAnomaly(ssmScore: ssmAnalysis.score, spectral: spectral)
        let spliceVerdacht = splice.spliceVerdacht || !ssmAnalysis.splicePositions.isEmpty

        var hints: [String] = []
        if spliceVerdacht { hints.append(Loc.s("Möglicher Schnitt oder abruptes Umschalten im Zeitverlauf erkannt.",
                                                "Possible cut or abrupt switch detected over time.")) }
        if masteringAnomaly { hints.append(Loc.s("Auffällige Hochfrequenz- oder Flachheitswerte deuten auf unnatürliches Mastering hin.",
                                                  "Notable high-frequency or flatness values suggest unnatural mastering.")) }
        if repetitionAnomaly { hints.append(Loc.s("Wiederholungsmuster im Selbstähnlichkeitsbild sprechen für synthetische Strukturierung.",
                                                   "Repetition patterns in the self-similarity image suggest synthetic structuring.")) }
        if spectral.zeitlicheStationaritaet < 0.45 { hints.append(Loc.s("Geringe zeitliche Stationarität im Spektrum.",
                                                                        "Low temporal stationarity in the spectrum.")) }

        let overallSuspicion = spliceVerdacht || masteringAnomaly || repetitionAnomaly
        return VerschleierungsErgebnis(
            verdachtGesamt: overallSuspicion,
            hinweise: hints,
            spliceVerdacht: spliceVerdacht,
            masteringAnomalie: masteringAnomaly,
            wiederholungsAnomalie: repetitionAnomaly
        )
    }

    /// Kombiniert SSM, Flatness und HF-Anteil zu einem robusten Verschleierungssignal.
    func verschleierungsScore(samples: [Double]) -> Double {
        let spectral = mfccProcessor.spectralFeatures(from: samples)
        let featureVector = mfccProcessor.extrahiereMerkmalsvektor(from: samples)
        let ssmAnalysis = ssmAnalyzer.analyze(featureVector: featureVector)
        let temporalScore = temporalAnalyzer.zeitlicherKIAnteil(samples: samples, featureProvider: mfccProcessor) / 100.0

        let score = 0.30 * spectral.spektraleFlachheit +
                    0.25 * spectral.hochfrequenzAnteil +
                    0.20 * ssmAnalysis.score +
                    0.15 * temporalScore +
                    0.10 * (1.0 - spectral.zeitlicheStationaritaet)
        return min(max(score, 0), 1)
    }

    /// Liefert die spektralen Merkmale für UI und weitergehende Analysen.
    func spektraleMerkmale(samples: [Double]) -> SpektralMerkmale {
        mfccProcessor.spectralFeatures(from: samples)
    }

    /// Liefert den SSM-Score und die Matrix für Visualisierung.
    func ssmAnalyse(samples: [Double]) -> (score: Double, matrix: [[Double]]) {
        let featureVector = mfccProcessor.extrahiereMerkmalsvektor(from: samples)
        let analysis = ssmAnalyzer.analyze(featureVector: featureVector)
        return (analysis.score, analysis.matrix)
    }

    private func detectMasteringAnomaly(spectral: SpektralMerkmale, ssmScore: Double) -> Bool {
        let lowFlatness = spectral.spektraleFlachheit < 0.20
        let hardCutoff = spectral.cutoffSchaerfe > 0.85
        let excessiveHF = spectral.hochfrequenzAnteil < 0.10
        return (lowFlatness && hardCutoff) || (excessiveHF && ssmScore > 0.40)
    }

    private func detectRepetitionAnomaly(ssmScore: Double, spectral: SpektralMerkmale) -> Bool {
        ssmScore > 0.55 && spectral.zeitlicheStationaritaet < 0.55
    }
}
