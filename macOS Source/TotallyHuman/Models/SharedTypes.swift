// SharedTypes.swift — Gemeinsame Datenmodelle für die gesamte App
// Totally Human — KI-Musik-Detektor (native macOS, kein Python)
// Alle Module referenzieren diese Typen.

import Foundation

// MARK: - Analyse-Konfiguration
struct AnalysisConfig {
    static let standardSampleRate: Double = 44100.0
    static let fftSizes: [Int] = [2048, 4096, 8192]
    static let fftWeights: [Double] = [0.25, 0.45, 0.30]
    static let ssmWeight: Double = 0.15
    static let analysisFreqBandHz: (Double, Double) = (5000.0, 16000.0)
    static let segmentLengthSeconds: Double = 10.0
    static let featureVectorSize: Int = 128
    static let supportedExtensions: Set<String> = ["mp3","wav","aiff","aif","m4a","flac","ogg","opus","wma","alac"]
}

// MARK: - Artefakt-Ergebnis (Fingerprint einer FFT-Größe)
struct ArtefaktErgebnis {
    var frequenzen: [Double]           // Hz-Werte für jedes Spektrum-Bin
    var mittleresSpektrumDB: [Double]  // Gemitteltes Amplitudenspektrum in dB
    var grundlinieDB: [Double]         // Morphologisch geschätzte Grundlinie
    var fingerprint: [Double]          // Spektrum minus Grundlinie
    var peakIndizes: [Int]             // Indizes der erkannten Peaks
    var peakFrequenzen: [Double]       // Hz-Werte der Peaks
    var peakProminenzen: [Double]      // Prominenz jedes Peaks in dB
    var peakAbstandHz: Double          // Mittlerer Peak-Abstand
    var regelmaessigkeit: Double       // Regelmäßigkeit 0..1
    var artefaktStaerke: Double        // Haupt-Score
    var anzahlPeaks: Int               // Anzahl erkannter Peaks
}

// MARK: - Ensemble-Ergebnis
struct EnsembleErgebnis {
    var hauptErgebnis: ArtefaktErgebnis  // Repräsentativ für 4096-FFT
    var einzelScores: [Double]          // Score je FFT-Größe
    var ensembleVarianz: Double          // Varianz (hoch = Manipulationsverdacht)
    var ensembleScore: Double            // Gewichtetes Mittel
}

// MARK: - Spektrale Merkmale
struct SpektralMerkmale {
    var hochfrequenzAnteil: Double        // Energie > 8 kHz
    var spektraleFlachheit: Double        // Flatness [0..1]
    var cutoffSchaerfe: Double            // Schärfe eines HF-Cutoffs
    var zeitlicheStationaritaet: Double   // Temporale Stationarität [0..1]
}

// MARK: - Frequenzband-Ergebnis
struct FrequenzBandErgebnis {
    var bandGrenzenHz: [(Double, Double)]  // (Untergrenze, Obergrenze) je Band
    var bandStaerken: [Double]             // Artefaktstärke je Band
    var bandAnteile: [Double]              // Prozentualer Anteil je Band
    var staerktesBandHz: (Double, Double) // Stärkstes Band
}

// MARK: - Zeit-Segment-Ergebnis
struct ZeitSegmentErgebnis {
    var segmentZeitenS: [(Double, Double)]  // (Start, Ende) in Sekunden
    var segmentStaerken: [Double]           // Artefaktstärke je Segment
    var segmentAnteile: [Double]            // Prozentualer Anteil
    var staerktesSegmentS: (Double, Double) // Stärkstes Segment
}

// MARK: - Splice-Erkennung
struct SpliceErgebnis {
    var spliceVerdacht: Bool
    var splicePositionen: [Int]
    var maxGradient: Double
}

// MARK: - Verschleierungs-Analyse
struct VerschleierungsErgebnis {
    var verdachtGesamt: Bool
    var hinweise: [String]
    var spliceVerdacht: Bool
    var masteringAnomalie: Bool
    var wiederholungsAnomalie: Bool
}

// MARK: - Vollständiges Detektions-Ergebnis
struct DetektionsErgebnis: Identifiable, Codable {
    let id: UUID
    var dateiPfad: String
    var dateiName: String
    var istKIGeneriert: Bool
    var kiWahrscheinlichkeitProzent: Double
    var artefaktScore: Double
    var einstufung: String
    var empfehlung: Empfehlung
    var konfidenzScore: Double
    var konfidenzText: String
    var anzahlPeaks: Int
    var mittlererPeakAbstandHz: Double
    var peakRegelmaessigkeit: Double
    var ssmScore: Double
    var ensembleScores: [Double]
    var ensembleVarianz: Double
    var zeitlicherKIAnteilProzent: Double
    var splicePositionen: [Int]
    var verschleierungsHinweise: [String]
    var verschleierungsVerdacht: Bool
    var modus: AnalyseModus
    var hinweise: [String]
    var analyseDatum: Date
    
    // Optionale Detail-Daten (für Visualisierung)
    var frequenzBandAnteile: [Double]
    var frequenzBandGrenzen: [[Double]]
    var segmentZeiten: [[Double]]
    var segmentStaerken: [Double]
    var spektrumFrequenzen: [Double]
    var spektrumWerte: [Double]
    var fingerprintWerte: [Double]
    var grundlinieWerte: [Double]
    var ssmMatrix: [[Double]]
    
    enum Empfehlung: String, Codable, CaseIterable {
        case klarkiGeneriert = "KLAR KI-GENERIERT"
        case klarMenschlich = "KLAR MENSCHLICH"
        case manuellePruefung = "MANUELLE PRÜFUNG EMPFOHLEN"
        case verschleierungsverdacht = "VERSCHLEIERUNGSVERDACHT"
        
        var farbe: String {
            switch self {
            case .klarkiGeneriert: return "red"
            case .klarMenschlich: return "green"
            case .manuellePruefung: return "orange"
            case .verschleierungsverdacht: return "purple"
            }
        }
        
        var symbol: String {
            switch self {
            case .klarkiGeneriert: return "xmark.circle.fill"
            case .klarMenschlich: return "checkmark.circle.fill"
            case .manuellePruefung: return "questionmark.circle.fill"
            case .verschleierungsverdacht: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    enum AnalyseModus: String, Codable {
        case heuristisch = "heuristisch"
        case trainiert = "trainiert"
    }
    
    // Vollständiger Initialisierer (id wird automatisch erzeugt).
    init(
        dateiPfad: String,
        dateiName: String,
        istKIGeneriert: Bool,
        kiWahrscheinlichkeitProzent: Double,
        artefaktScore: Double,
        einstufung: String,
        empfehlung: Empfehlung,
        konfidenzScore: Double,
        konfidenzText: String,
        anzahlPeaks: Int,
        mittlererPeakAbstandHz: Double,
        peakRegelmaessigkeit: Double,
        ssmScore: Double,
        ensembleScores: [Double],
        ensembleVarianz: Double,
        zeitlicherKIAnteilProzent: Double,
        splicePositionen: [Int],
        verschleierungsHinweise: [String],
        verschleierungsVerdacht: Bool,
        modus: AnalyseModus,
        hinweise: [String],
        analyseDatum: Date,
        frequenzBandAnteile: [Double],
        frequenzBandGrenzen: [[Double]],
        segmentZeiten: [[Double]],
        segmentStaerken: [Double],
        spektrumFrequenzen: [Double],
        spektrumWerte: [Double],
        fingerprintWerte: [Double],
        grundlinieWerte: [Double],
        ssmMatrix: [[Double]]
    ) {
        self.id = UUID()
        self.dateiPfad = dateiPfad
        self.dateiName = dateiName
        self.istKIGeneriert = istKIGeneriert
        self.kiWahrscheinlichkeitProzent = kiWahrscheinlichkeitProzent
        self.artefaktScore = artefaktScore
        self.einstufung = einstufung
        self.empfehlung = empfehlung
        self.konfidenzScore = konfidenzScore
        self.konfidenzText = konfidenzText
        self.anzahlPeaks = anzahlPeaks
        self.mittlererPeakAbstandHz = mittlererPeakAbstandHz
        self.peakRegelmaessigkeit = peakRegelmaessigkeit
        self.ssmScore = ssmScore
        self.ensembleScores = ensembleScores
        self.ensembleVarianz = ensembleVarianz
        self.zeitlicherKIAnteilProzent = zeitlicherKIAnteilProzent
        self.splicePositionen = splicePositionen
        self.verschleierungsHinweise = verschleierungsHinweise
        self.verschleierungsVerdacht = verschleierungsVerdacht
        self.modus = modus
        self.hinweise = hinweise
        self.analyseDatum = analyseDatum
        self.frequenzBandAnteile = frequenzBandAnteile
        self.frequenzBandGrenzen = frequenzBandGrenzen
        self.segmentZeiten = segmentZeiten
        self.segmentStaerken = segmentStaerken
        self.spektrumFrequenzen = spektrumFrequenzen
        self.spektrumWerte = spektrumWerte
        self.fingerprintWerte = fingerprintWerte
        self.grundlinieWerte = grundlinieWerte
        self.ssmMatrix = ssmMatrix
    }

    init(dateiPfad: String) {
        self.id = UUID()
        self.dateiPfad = dateiPfad
        self.dateiName = URL(fileURLWithPath: dateiPfad).lastPathComponent
        self.istKIGeneriert = false
        self.kiWahrscheinlichkeitProzent = 0
        self.artefaktScore = 0
        self.einstufung = ""
        self.empfehlung = .manuellePruefung
        self.konfidenzScore = 0
        self.konfidenzText = ""
        self.anzahlPeaks = 0
        self.mittlererPeakAbstandHz = 0
        self.peakRegelmaessigkeit = 0
        self.ssmScore = 0
        self.ensembleScores = []
        self.ensembleVarianz = 0
        self.zeitlicherKIAnteilProzent = 0
        self.splicePositionen = []
        self.verschleierungsHinweise = []
        self.verschleierungsVerdacht = false
        self.modus = .heuristisch
        self.hinweise = []
        self.analyseDatum = Date()
        self.frequenzBandAnteile = []
        self.frequenzBandGrenzen = []
        self.segmentZeiten = []
        self.segmentStaerken = []
        self.spektrumFrequenzen = []
        self.spektrumWerte = []
        self.fingerprintWerte = []
        self.grundlinieWerte = []
        self.ssmMatrix = []
    }
}

// MARK: - Trainings-Probe
struct TrainingsProbe: Identifiable, Codable {
    let id: UUID
    var dateiPfad: String
    var dateiName: String
    var label: TrainingsLabel
    var merkmalsvektor: [Double]   // 128-dimensional
    var dateiSignatur: String      // MD5-Hash für Deduplizierung
    var hinzugefuegtAm: Date
    
    enum TrainingsLabel: Int, Codable {
        case echt = 0
        case ki = 1
        
        var bezeichnung: String {
            switch self { case .echt: return "Echte Musik"; case .ki: return "KI-Musik" }
        }
    }
}

// MARK: - ML Modell
struct LogistischesModell: Codable {
    var gewichte: [Double]   // 128 Gewichte + 1 Bias
    var bias: Double
    var trainingsZeit: Date
    var anzahlBeispiele: Int
    var kreuzvalidierungsGenauigkeit: Double
    
    func vorhersage(merkmale: [Double]) -> Double {
        guard merkmale.count == gewichte.count else { return 0.5 }
        var summe = bias
        for i in 0..<merkmale.count {
            summe += gewichte[i] * merkmale[i]
        }
        return sigmoid(summe)
    }
    
    private func sigmoid(_ x: Double) -> Double {
        if x >= 0 { return 1.0 / (1.0 + exp(-x)) }
        let z = exp(x); return z / (1.0 + z)
    }
}
