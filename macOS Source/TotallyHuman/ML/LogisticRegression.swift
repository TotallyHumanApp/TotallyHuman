import Foundation
import Accelerate

/// Ein einfacher logistischer Klassifikator mit Gradient Descent und L2-Regularisierung.
final class LogisticRegression {
    struct Configuration {
        var learningRate: Double
        var iterations: Int
        var l2Strength: Double
        var tolerance: Double

        init(learningRate: Double = 0.05, iterations: Int = 1_500, l2Strength: Double = 0.001, tolerance: Double = 1e-6) {
            self.learningRate = learningRate
            self.iterations = iterations
            self.l2Strength = l2Strength
            self.tolerance = tolerance
        }
    }

    private(set) var model: LogistischesModell
    var configuration: Configuration

    init(model: LogistischesModell? = nil, featureCount: Int = AnalysisConfig.featureVectorSize, configuration: Configuration = Configuration()) {
        if let model {
            self.model = model
        } else {
            self.model = LogistischesModell(
                gewichte: Array(repeating: 0.0, count: featureCount),
                bias: 0.0,
                trainingsZeit: Date(),
                anzahlBeispiele: 0,
                kreuzvalidierungsGenauigkeit: 0.0
            )
        }
        self.configuration = configuration
    }

    /// Trainiert das Modell anhand von Proben.
    /// - Returns: Die trainierte Modellinstanz.
    @discardableResult
    func train(samples: [TrainingsProbe]) -> LogistischesModell {
        guard !samples.isEmpty else { return model }
        let featureCount = samples[0].merkmalsvektor.count
        var weights = Array(repeating: 0.0, count: featureCount)
        var bias = 0.0
        let n = Double(samples.count)
        var previousLoss = Double.greatestFiniteMagnitude

        for _ in 0..<configuration.iterations {
            var gradientW = Array(repeating: 0.0, count: featureCount)
            var gradientB = 0.0
            var loss = 0.0

            for sample in samples where sample.merkmalsvektor.count == featureCount {
                let z = dot(weights, sample.merkmalsvektor) + bias
                let prediction = sigmoid(z)
                let y = Double(sample.label.rawValue)
                let error = prediction - y
                loss += binaryCrossEntropy(prediction: prediction, label: y)
                for i in 0..<featureCount { gradientW[i] += error * sample.merkmalsvektor[i] }
                gradientB += error
            }

            for i in 0..<featureCount {
                gradientW[i] = gradientW[i] / n + configuration.l2Strength * weights[i]
                weights[i] -= configuration.learningRate * gradientW[i]
            }
            bias -= configuration.learningRate * (gradientB / n)

            let regularization = 0.5 * configuration.l2Strength * dot(weights, weights)
            let totalLoss = loss / n + regularization
            if abs(previousLoss - totalLoss) < configuration.tolerance { break }
            previousLoss = totalLoss
        }

        model = LogistischesModell(
            gewichte: weights,
            bias: bias,
            trainingsZeit: Date(),
            anzahlBeispiele: samples.count,
            kreuzvalidierungsGenauigkeit: evaluateAccuracy(samples: samples, weights: weights, bias: bias)
        )
        return model
    }

    /// Gibt eine Wahrscheinlichkeit für das Label „KI-Musik“ zurück.
    func predictProbability(features: [Double]) -> Double {
        guard features.count == model.gewichte.count else { return 0.5 }
        return model.vorhersage(merkmale: features)
    }

    /// Klassifiziert anhand eines Schwellwerts.
    func predict(features: [Double], threshold: Double = 0.5) -> TrainingsProbe.TrainingsLabel {
        predictProbability(features: features) >= threshold ? .ki : .echt
    }

    func update(with samples: [TrainingsProbe]) {
        _ = train(samples: samples)
    }

    // MARK: - Intern

    private func evaluateAccuracy(samples: [TrainingsProbe], weights: [Double], bias: Double) -> Double {
        guard !samples.isEmpty else { return 0.0 }
        var correct = 0
        for sample in samples where sample.merkmalsvektor.count == weights.count {
            let p = sigmoid(dot(weights, sample.merkmalsvektor) + bias)
            let predicted = p >= 0.5 ? 1 : 0
            if predicted == sample.label.rawValue { correct += 1 }
        }
        return Double(correct) / Double(samples.count)
    }

    private func binaryCrossEntropy(prediction: Double, label: Double) -> Double {
        let p = min(max(prediction, 1e-12), 1.0 - 1e-12)
        return -(label * log(p) + (1.0 - label) * log(1.0 - p))
    }

    private func sigmoid(_ x: Double) -> Double {
        if x >= 0 { return 1.0 / (1.0 + exp(-x)) }
        let z = exp(x)
        return z / (1.0 + z)
    }

    private func dot(_ a: [Double], _ b: [Double]) -> Double {
        zip(a, b).reduce(0.0) { $0 + $1.0 * $1.1 }
    }
}
