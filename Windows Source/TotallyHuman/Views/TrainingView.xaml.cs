using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Win32;
using TotallyHuman.Models;
using TotallyHuman.ViewModels;

namespace TotallyHuman.Views;

public partial class TrainingView : UserControl
{
    public TrainingView()
    {
        InitializeComponent();
    }

    private AppState? State => DataContext as AppState;

    private void Drop_DragOver(object sender, DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None;
        e.Handled = true;
    }

    private void DropReal_Drop(object sender, DragEventArgs e) => Importiere(e, TrainingsLabel.Echt);
    private void DropKi_Drop(object sender, DragEventArgs e) => Importiere(e, TrainingsLabel.Ki);

    private void Importiere(DragEventArgs e, TrainingsLabel label)
    {
        if (State == null) return;
        if (e.Data.GetData(DataFormats.FileDrop) is string[] pfade && pfade.Length > 0)
            State.ImportiereTrainingsdaten(pfade, label);
    }

    private void DropReal_Click(object sender, MouseButtonEventArgs e) => WaehleUndImportiere(TrainingsLabel.Echt);
    private void DropKi_Click(object sender, MouseButtonEventArgs e) => WaehleUndImportiere(TrainingsLabel.Ki);
    private void AddReal_Click(object sender, RoutedEventArgs e) => WaehleUndImportiere(TrainingsLabel.Echt);
    private void AddKi_Click(object sender, RoutedEventArgs e) => WaehleUndImportiere(TrainingsLabel.Ki);

    private void WaehleUndImportiere(TrainingsLabel label)
    {
        if (State == null) return;
        var dlg = new OpenFileDialog
        {
            Multiselect = true,
            Title = "Trainingsdateien auswählen",
            Filter = "Audiodateien|*.mp3;*.wav;*.aiff;*.aif;*.m4a;*.flac;*.ogg;*.opus;*.wma;*.alac|Alle Dateien|*.*"
        };
        if (dlg.ShowDialog() == true && dlg.FileNames.Length > 0)
            State.ImportiereTrainingsdaten(dlg.FileNames, label);
    }

    private void Train_Click(object sender, RoutedEventArgs e) => State?.StarteTraining();
    private void Reseed_Click(object sender, RoutedEventArgs e) => State?.SeedDatenNeuImportieren();
    private void OpenFolder_Click(object sender, RoutedEventArgs e) => State?.SpeicherordnerOeffnen();
    private void Clear_Click(object sender, RoutedEventArgs e) => State?.LoescheAlleTrainingsdaten();
}
