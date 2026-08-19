using System;
using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using OxyPlot;
using OxyPlot.Axes;
using OxyPlot.Legends;
using OxyPlot.Series;
using TotallyHuman.Models;
using TotallyHuman.Utilities;
using TotallyHuman.ViewModels;

namespace TotallyHuman.Views;

public partial class VisualizationView : UserControl
{
    private AppState? _state;
    private static readonly OxyColor Orange = OxyColor.FromRgb(0xFF, 0x8C, 0x1A);
    private static readonly OxyColor Muted = OxyColor.FromRgb(0xB0, 0xB0, 0xB0);
    private static readonly OxyColor Text = OxyColor.FromRgb(0xF2, 0xF2, 0xF2);
    private static readonly OxyColor Green = OxyColor.FromRgb(0x35, 0xC7, 0x59);
    private static readonly OxyColor Purple = OxyColor.FromRgb(0xBF, 0x5A, 0xF2);

    public VisualizationView()
    {
        InitializeComponent();
        DataContextChanged += (_, _) =>
        {
            if (_state != null) _state.PropertyChanged -= OnStateChanged;
            _state = DataContext as AppState;
            if (_state != null) _state.PropertyChanged += OnStateChanged;
            Loc.LanguageChanged += (_, _) => Neuzeichnen();
            Neuzeichnen();
        };
    }

    private void OnStateChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(AppState.CurrentAnalysisResult))
            Dispatcher.Invoke(Neuzeichnen);
    }

    private void Neuzeichnen()
    {
        var r = _state?.CurrentAnalysisResult;
        bool hat = r != null && r.SpektrumWerte.Length > 0;
        EmptyCard.Visibility = hat ? Visibility.Collapsed : Visibility.Visible;
        ChartsHost.Visibility = hat ? Visibility.Visible : Visibility.Collapsed;
        if (!hat || r == null) return;

        SpectrumPlot.Model = BaueSpektrumModell(r);
        SegmentPlot.Model = BaueSegmentModell(r);
    }

    private PlotModel BaueSpektrumModell(DetektionsErgebnis r)
    {
        var pm = NeuesModell();
        var xAxis = new LinearAxis
        {
            Position = AxisPosition.Bottom,
            Title = Loc.Get("axis.freq"),
            TitleColor = Muted, TextColor = Muted, AxislineColor = Muted,
            TicklineColor = Muted, MajorGridlineColor = OxyColor.FromArgb(0x22, 0xFF, 0xFF, 0xFF),
            MajorGridlineStyle = LineStyle.Solid
        };
        var yAxis = new LinearAxis
        {
            Position = AxisPosition.Left,
            Title = Loc.Get("axis.db"),
            TitleColor = Muted, TextColor = Muted, AxislineColor = Muted,
            TicklineColor = Muted, MajorGridlineColor = OxyColor.FromArgb(0x22, 0xFF, 0xFF, 0xFF),
            MajorGridlineStyle = LineStyle.Solid
        };
        pm.Axes.Add(xAxis);
        pm.Axes.Add(yAxis);
        pm.Legends.Add(new Legend
        {
            LegendTextColor = Text,
            LegendPosition = LegendPosition.TopRight,
            LegendBackground = OxyColor.FromArgb(0x66, 0x1A, 0x1A, 0x1A)
        });

        var freq = r.SpektrumFrequenzen;
        pm.Series.Add(Linie(freq, r.SpektrumWerte, Loc.Get("viz.spectrum.line"), Orange, 1.6));
        if (r.GrundlinieWerte.Length == freq.Length)
            pm.Series.Add(Linie(freq, r.GrundlinieWerte, Loc.Get("viz.baseline.line"), Muted, 1.0, LineStyle.Dash));
        if (r.FingerprintWerte.Length == freq.Length)
            pm.Series.Add(Linie(freq, r.FingerprintWerte, Loc.Get("viz.fingerprint.line"), Purple, 1.2));
        return pm;
    }

    private PlotModel BaueSegmentModell(DetektionsErgebnis r)
    {
        var pm = NeuesModell();
        var cat = new CategoryAxis
        {
            Position = AxisPosition.Bottom,
            Title = Loc.Get("viz.segments.axis"),
            TitleColor = Muted, TextColor = Muted, AxislineColor = Muted, TicklineColor = Muted
        };
        for (int i = 0; i < r.SegmentStaerken.Length; i++) cat.Labels.Add((i + 1).ToString());
        var val = new LinearAxis
        {
            Position = AxisPosition.Left,
            Title = Loc.Get("viz.strength"),
            TitleColor = Muted, TextColor = Muted, AxislineColor = Muted, TicklineColor = Muted,
            MajorGridlineColor = OxyColor.FromArgb(0x22, 0xFF, 0xFF, 0xFF), MajorGridlineStyle = LineStyle.Solid,
            Minimum = 0
        };
        pm.Axes.Add(cat);
        pm.Axes.Add(val);

        var bars = new BarSeries { FillColor = Orange, StrokeThickness = 0 };
        foreach (var s in r.SegmentStaerken)
            bars.Items.Add(new BarItem { Value = s, Color = s > 1.0 ? Green : Orange });
        pm.Series.Add(bars);
        return pm;
    }

    private static LineSeries Linie(double[] x, double[] y, string titel, OxyColor farbe, double dicke, LineStyle stil = LineStyle.Solid)
    {
        var ls = new LineSeries { Title = titel, Color = farbe, StrokeThickness = dicke, LineStyle = stil };
        int n = Math.Min(x.Length, y.Length);
        for (int i = 0; i < n; i++) ls.Points.Add(new DataPoint(x[i], y[i]));
        return ls;
    }

    private static PlotModel NeuesModell()
    {
        return new PlotModel
        {
            Background = OxyColors.Transparent,
            PlotAreaBorderColor = OxyColor.FromArgb(0x22, 0xFF, 0xFF, 0xFF),
            TextColor = Text,
            TitleColor = Text,
        };
    }
}
