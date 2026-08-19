using System.Windows.Controls;
using TotallyHuman.ViewModels;

namespace TotallyHuman.Views;

public partial class SettingsView : UserControl
{
    private bool _initialisiert;

    public SettingsView()
    {
        InitializeComponent();
        DataContextChanged += (_, _) => SetzeSprachAuswahl();
    }

    private AppState? State => DataContext as AppState;

    private void SetzeSprachAuswahl()
    {
        if (State == null) return;
        _initialisiert = false;
        LangBox.SelectedIndex = State.SelectedLanguage == "en" ? 1 : 0;
        _initialisiert = true;
    }

    private void LangBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (!_initialisiert || State == null) return;
        if (LangBox.SelectedItem is ComboBoxItem item && item.Tag is string lang)
            State.SelectedLanguage = lang;
    }

    private void OpenFolder_Click(object sender, System.Windows.RoutedEventArgs e) => State?.SpeicherordnerOeffnen();
    private void Reseed_Click(object sender, System.Windows.RoutedEventArgs e) => State?.SeedDatenNeuImportieren();
}
