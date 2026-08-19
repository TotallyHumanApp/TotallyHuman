using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Win32;
using TotallyHuman.ViewModels;

namespace TotallyHuman.Views;

public partial class AnalysisView : UserControl
{
    public AnalysisView()
    {
        InitializeComponent();
    }

    private AppState? State => DataContext as AppState;

    private void DropZone_DragOver(object sender, DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None;
        e.Handled = true;
    }

    private void DropZone_Drop(object sender, DragEventArgs e)
    {
        if (State == null) return;
        if (e.Data.GetData(DataFormats.FileDrop) is string[] pfade && pfade.Length > 0)
            State.Analysiere(pfade);
    }

    private void DropZone_Click(object sender, MouseButtonEventArgs e) => WaehleDatei();

    private void ChooseBtn_Click(object sender, RoutedEventArgs e) => WaehleDatei();

    private void WaehleDatei()
    {
        if (State == null) return;
        var dlg = new OpenFileDialog
        {
            Multiselect = true,
            Title = "Audiodatei(en) auswählen",
            Filter = "Audiodateien|*.mp3;*.wav;*.aiff;*.aif;*.m4a;*.flac;*.ogg;*.opus;*.wma;*.alac|Alle Dateien|*.*"
        };
        if (dlg.ShowDialog() == true && dlg.FileNames.Length > 0)
            State.Analysiere(dlg.FileNames);
    }
}
