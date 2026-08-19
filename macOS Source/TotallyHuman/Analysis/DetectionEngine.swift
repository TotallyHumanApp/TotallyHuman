import Foundation

/// Führt eine echte Datei-Analyse durch: dekodiert das Audio, berechnet den
/// Python-kompatiblen Merkmalsvektor und klassifiziert mit dem trainierten Modell.
final class DetectionEngine {

    /// Analysiert eine reale Audiodatei.
    /// - Parameters:
    ///   - url: Pfad zur Audiodatei
    ///   - modell: trainiertes logistisches Modell (128 Gewichte). Ist es untrainiert
    ///             (anzahlBeispiele == 0), wird eine reine Heuristik verwendet.
    func analysiere(url: URL, modell: LogistischesModell?) throws -> DetektionsErgebnis {
        let res = try AudioAnalyzer.analysiere(url: url)

        let modellTrainiert = (modell?.anzahlBeispiele ?? 0) > 0 && (modell?.gewichte.count == res.merkmalsvektor.count)
        let kiWahrscheinlichkeit: Double
        let modus: DetektionsErgebnis.AnalyseModus
        if modellTrainiert, let m = modell {
            kiWahrscheinlichkeit = m.vorhersage(merkmale: res.merkmalsvektor)
            modus = .trainiert
        } else {
            // Heuristik: Artefaktstärke auf 0..1 abbilden.
            kiWahrscheinlichkeit = max(0, min(1, res.artefaktStaerke / 6.0))
            modus = .heuristisch
        }

        let prozent = kiWahrscheinlichkeit * 100.0
        let istKI = kiWahrscheinlichkeit >= 0.5
        let empfehlung: DetektionsErgebnis.Empfehlung
        if kiWahrscheinlichkeit >= 0.6 { empfehlung = .klarkiGeneriert }
        else if kiWahrscheinlichkeit <= 0.4 { empfehlung = .klarMenschlich }
        else { empfehlung = .manuellePruefung }

        let konfidenz = min(1.0, abs(kiWahrscheinlichkeit - 0.5) * 2.0)
        let staerkstesSegment = res.segmentStaerken.max() ?? 0
        let zeitlicherAnteil = res.segmentStaerken.isEmpty ? 0 :
            Double(res.segmentStaerken.filter { $0 > 1.0 }.count) / Double(res.segmentStaerken.count) * 100.0

        var hinweise: [String] = []
        hinweise.append(modellTrainiert
            ? Loc.s("Klassifikation mit trainiertem Modell (\(modell?.anzahlBeispiele ?? 0) Beispiele).",
                    "Classification with trained model (\(modell?.anzahlBeispiele ?? 0) samples).")
            : Loc.s("Heuristische Analyse (kein trainiertes Modell).",
                    "Heuristic analysis (no trained model)."))
        if res.regelmaessigkeit > 0.6 { hinweise.append(Loc.s("Regelmäßige Spektral-Peaks erkannt (Indiz für KI).",
                                                              "Regular spectral peaks detected (indication of AI).")) }
        if staerkstesSegment > 2.0 { hinweise.append(Loc.s("Auffällige Artefakte in einzelnen Zeitsegmenten.",
                                                           "Notable artifacts in individual time segments.")) }

        let verschleierung = res.regelmaessigkeit > 0.75 && res.peakFrequenzen.count > 12

        return DetektionsErgebnis(
            dateiPfad: url.path,
            dateiName: url.lastPathComponent,
            istKIGeneriert: istKI,
            kiWahrscheinlichkeitProzent: prozent,
            artefaktScore: res.artefaktStaerke,
            einstufung: istKI ? Loc.s("KI-generiert", "AI-generated") : Loc.s("Menschlich", "Human"),
            empfehlung: empfehlung,
            konfidenzScore: konfidenz,
            konfidenzText: konfidenz > 0.6 ? Loc.s("hoch", "high") : (konfidenz > 0.3 ? Loc.s("mittel", "medium") : Loc.s("niedrig", "low")),
            anzahlPeaks: res.peakFrequenzen.count,
            mittlererPeakAbstandHz: res.peakAbstandHz,
            peakRegelmaessigkeit: res.regelmaessigkeit,
            ssmScore: 0,
            ensembleScores: [],
            ensembleVarianz: 0,
            zeitlicherKIAnteilProzent: zeitlicherAnteil,
            splicePositionen: [],
            verschleierungsHinweise: verschleierung ? [Loc.s("Sehr regelmäßige Struktur — möglicher Verschleierungsversuch.",
                                                             "Very regular structure — possible obfuscation attempt.")] : [],
            verschleierungsVerdacht: verschleierung,
            modus: modus,
            hinweise: hinweise,
            analyseDatum: Date(),
            frequenzBandAnteile: [],
            frequenzBandGrenzen: [],
            segmentZeiten: res.segmentZeiten.map { [$0.0, $0.1] },
            segmentStaerken: res.segmentStaerken,
            spektrumFrequenzen: res.frequenzenBand,
            spektrumWerte: res.spektrumBandDB,
            fingerprintWerte: res.fingerprintBand,
            grundlinieWerte: res.grundlinieBandDB,
            ssmMatrix: []
        )
    }

    /// Berechnet die Datei-Signatur (MD5) für Deduplizierung in der Trainingsdatenbank.
    static func signatur(url: URL) -> String {
        AudioFileHelper.md5Signatur(url: url)
    }
}
