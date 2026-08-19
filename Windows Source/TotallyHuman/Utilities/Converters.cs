using System;
using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;
using TotallyHuman.Models;

namespace TotallyHuman.Utilities;

/// <summary>bool -> Visibility (true = Visible, false = Collapsed).</summary>
public sealed class BoolToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object? parameter, CultureInfo culture)
    {
        bool b = value is bool v && v;
        if (parameter is string s && s == "invert") b = !b;
        return b ? Visibility.Visible : Visibility.Collapsed;
    }
    public object ConvertBack(object value, Type targetType, object? parameter, CultureInfo culture)
        => value is Visibility vis && vis == Visibility.Visible;
}

/// <summary>null -> Collapsed, sonst Visible.</summary>
public sealed class NullToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object? parameter, CultureInfo culture)
    {
        bool hasValue = value != null;
        if (parameter is string s && s == "invert") hasValue = !hasValue;
        return hasValue ? Visibility.Visible : Visibility.Collapsed;
    }
    public object ConvertBack(object value, Type targetType, object? parameter, CultureInfo culture)
        => Binding.DoNothing;
}

/// <summary>Empfehlung -> Farbbrush (rot/grün/orange/lila).</summary>
public sealed class EmpfehlungToBrushConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is Empfehlung e)
        {
            return e switch
            {
                Empfehlung.KlarKiGeneriert => new SolidColorBrush(Color.FromRgb(0xFF, 0x45, 0x3A)),
                Empfehlung.KlarMenschlich => new SolidColorBrush(Color.FromRgb(0x35, 0xC7, 0x59)),
                Empfehlung.Verschleierungsverdacht => new SolidColorBrush(Color.FromRgb(0xBF, 0x5A, 0xF2)),
                _ => new SolidColorBrush(Color.FromRgb(0xFF, 0x8C, 0x1A)),
            };
        }
        return new SolidColorBrush(Color.FromRgb(0xFF, 0x8C, 0x1A));
    }
    public object ConvertBack(object value, Type targetType, object? parameter, CultureInfo culture)
        => Binding.DoNothing;
}

/// <summary>Label (0/1) -> Text via Loc.</summary>
public sealed class LabelToTextConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is TrainingsLabel l)
            return l == TrainingsLabel.Ki ? Loc.Get("training.ki") : Loc.Get("training.real");
        return "";
    }
    public object ConvertBack(object value, Type targetType, object? parameter, CultureInfo culture)
        => Binding.DoNothing;
}
