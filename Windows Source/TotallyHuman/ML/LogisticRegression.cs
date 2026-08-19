using System;
using System.Collections.Generic;
using System.Linq;
using TotallyHuman.Models;

namespace TotallyHuman.ML;

/// <summary>
/// Logistischer Klassifikator mit Gradient Descent und L2-Regularisierung.
/// 1:1 Port von LogisticRegression.swift (learningRate=0.05, iterations=1500,
/// l2Strength=0.001, tolerance=1e-6).
/// </summary>
public sealed class LogisticRegression
{
    public struct Configuration
    {
        public double LearningRate;
        public int Iterations;
        public double L2Strength;
        public double Tolerance;

        public static Configuration Default => new()
        {
            LearningRate = 0.05,
            Iterations = 1500,
            L2Strength = 0.001,
            Tolerance = 1e-6
        };
    }

    public LogistischesModell Model { get; private set; }
    public Configuration Config;

    public LogisticRegression(LogistischesModell? model = null,
                              int featureCount = AnalysisConfig.FeatureVectorSize,
                              Configuration? configuration = null)
    {
        Config = configuration ?? Configuration.Default;
        if (model != null)
        {
            Model = model;
        }
        else
        {
            Model = new LogistischesModell
            {
                Gewichte = new double[featureCount],
                Bias = 0.0,
                TrainingsZeit = DateTime.Now,
                AnzahlBeispiele = 0,
                KreuzvalidierungsGenauigkeit = 0.0
            };
        }
    }

    /// <summary>Trainiert das Modell anhand von Proben.</summary>
    public LogistischesModell Train(IReadOnlyList<TrainingsProbe> samples)
    {
        if (samples.Count == 0) return Model;
        int featureCount = samples[0].Merkmalsvektor.Length;
        var weights = new double[featureCount];
        double bias = 0.0;
        double n = samples.Count;
        double previousLoss = double.MaxValue;

        for (int iter = 0; iter < Config.Iterations; iter++)
        {
            var gradientW = new double[featureCount];
            double gradientB = 0.0;
            double loss = 0.0;

            foreach (var sample in samples)
            {
                if (sample.Merkmalsvektor.Length != featureCount) continue;
                double z = Dot(weights, sample.Merkmalsvektor) + bias;
                double prediction = Sigmoid(z);
                double y = (int)sample.Label;
                double error = prediction - y;
                loss += BinaryCrossEntropy(prediction, y);
                for (int i = 0; i < featureCount; i++)
                    gradientW[i] += error * sample.Merkmalsvektor[i];
                gradientB += error;
            }

            for (int i = 0; i < featureCount; i++)
            {
                gradientW[i] = gradientW[i] / n + Config.L2Strength * weights[i];
                weights[i] -= Config.LearningRate * gradientW[i];
            }
            bias -= Config.LearningRate * (gradientB / n);

            double regularization = 0.5 * Config.L2Strength * Dot(weights, weights);
            double totalLoss = loss / n + regularization;
            if (Math.Abs(previousLoss - totalLoss) < Config.Tolerance) break;
            previousLoss = totalLoss;
        }

        Model = new LogistischesModell
        {
            Gewichte = weights,
            Bias = bias,
            TrainingsZeit = DateTime.Now,
            AnzahlBeispiele = samples.Count,
            KreuzvalidierungsGenauigkeit = EvaluateAccuracy(samples, weights, bias)
        };
        return Model;
    }

    public double PredictProbability(double[] features)
    {
        if (features.Length != Model.Gewichte.Length) return 0.5;
        return Model.Vorhersage(features);
    }

    public TrainingsLabel Predict(double[] features, double threshold = 0.5)
        => PredictProbability(features) >= threshold ? TrainingsLabel.Ki : TrainingsLabel.Echt;

    // MARK: - Intern

    private static double EvaluateAccuracy(IReadOnlyList<TrainingsProbe> samples, double[] weights, double bias)
    {
        if (samples.Count == 0) return 0.0;
        int correct = 0;
        foreach (var sample in samples)
        {
            if (sample.Merkmalsvektor.Length != weights.Length) continue;
            double p = Sigmoid(Dot(weights, sample.Merkmalsvektor) + bias);
            int predicted = p >= 0.5 ? 1 : 0;
            if (predicted == (int)sample.Label) correct++;
        }
        return (double)correct / samples.Count;
    }

    private static double BinaryCrossEntropy(double prediction, double label)
    {
        double p = Math.Min(Math.Max(prediction, 1e-12), 1.0 - 1e-12);
        return -(label * Math.Log(p) + (1.0 - label) * Math.Log(1.0 - p));
    }

    private static double Sigmoid(double x)
    {
        if (x >= 0) return 1.0 / (1.0 + Math.Exp(-x));
        double z = Math.Exp(x);
        return z / (1.0 + z);
    }

    private static double Dot(double[] a, double[] b)
    {
        double s = 0.0;
        int len = Math.Min(a.Length, b.Length);
        for (int i = 0; i < len; i++) s += a[i] * b[i];
        return s;
    }
}
