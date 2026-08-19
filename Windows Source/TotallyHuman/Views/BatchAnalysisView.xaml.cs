using System.Collections.Specialized;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using Microsoft.Win32;
using TotallyHuman.Models;
using TotallyHuman.ViewModels;

namespace TotallyHuman.Views;

public partial class BatchAnalysisView : UserControl
{
    private AppState? _state;

    public BatchAnalysisView()
    {
        InitializeComponent();
        DataContextChanged += (_, _) =>
        {
            if (_state != null) _state.BatchResults.CollectionChanged -= OnResultsChanged;
            _state = DataContext as AppState;
            if (_state != null) _state.BatchResults.CollectionChanged += OnResultsChanged;
            Aktualisiere();
        };
    }

    private void OnResultsChanged(object? sender, NotifyCollectionChangedEventArgs e) => Aktualisiere();

    private void Aktualisiere()
    {
        if (_state == null) return;
        int ki = _state.BatchResults.Count(r => r.Empfehlung == Empfehlung.KlarKiGeneriert);
        int human = _state.BatchResults.Count(r => r.Empfehlung == Empfehlung.KlarMenschlich);
        KiCount.Text = ki.ToString();
        HumanCount.Text = human.ToString();
        EmptyHint.Visibility = _state.BatchResults.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    private void Choose_Click(object sender, RoutedEventArgs e)
    {
        if (_state == null) return;
        var dlg = new OpenFileDialog
        {
            Multiselect = true,
            Title = "Dateien auswählen",
            Filter = "Audiodateien|*.mp3;*.wav;*.aiff;*.aif;*.m4a;*.flac;*.ogg;*.opus;*.wma;*.alac|Alle Dateien|*.*"
        };
        if (dlg.ShowDialog() == true && dlg.FileNames.Length > 0)
            _state.Analysiere(dlg.FileNames);
    }

    private void Clear_Click(object sender, RoutedEventArgs e) => _state?.LeereBatch();
}
