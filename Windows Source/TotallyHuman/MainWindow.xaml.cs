using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using TotallyHuman.ViewModels;
using TotallyHuman.Views;

namespace TotallyHuman;

public partial class MainWindow : Window
{
    private readonly AppState _state = new();

    private readonly AnalysisView _analysis = new();
    private readonly BatchAnalysisView _batch = new();
    private readonly TrainingView _training = new();
    private readonly VisualizationView _viz = new();
    private readonly SettingsView _settings = new();

    private bool _syncingNav;

    public MainWindow()
    {
        InitializeComponent();
        DataContext = _state;

        _state.PropertyChanged += OnStatePropertyChanged;

        NavAnalyse.Checked += Nav_Checked;
        NavBatch.Checked += Nav_Checked;
        NavTraining.Checked += Nav_Checked;
        NavViz.Checked += Nav_Checked;
        NavSettings.Checked += Nav_Checked;

        ZeigeAuswahl(_state.SidebarSelection);
    }

    private void Nav_Checked(object sender, RoutedEventArgs e)
    {
        if (_syncingNav) return;
        if (sender is RadioButton rb && rb.Tag is string tag)
        {
            var sel = tag switch
            {
                "Batch" => SidebarSelection.Batch,
                "Training" => SidebarSelection.Training,
                "Visualisierung" => SidebarSelection.Visualisierung,
                "Einstellungen" => SidebarSelection.Einstellungen,
                _ => SidebarSelection.Analyse
            };
            _state.SidebarSelection = sel;
            SetzeInhalt(sel);
        }
    }

    private void OnStatePropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(AppState.SidebarSelection))
            Dispatcher.Invoke(() => ZeigeAuswahl(_state.SidebarSelection));
    }

    private void ZeigeAuswahl(SidebarSelection sel)
    {
        _syncingNav = true;
        switch (sel)
        {
            case SidebarSelection.Batch: NavBatch.IsChecked = true; break;
            case SidebarSelection.Training: NavTraining.IsChecked = true; break;
            case SidebarSelection.Visualisierung: NavViz.IsChecked = true; break;
            case SidebarSelection.Einstellungen: NavSettings.IsChecked = true; break;
            default: NavAnalyse.IsChecked = true; break;
        }
        _syncingNav = false;
        SetzeInhalt(sel);
    }

    private void SetzeInhalt(SidebarSelection sel)
    {
        ContentHost.Content = sel switch
        {
            SidebarSelection.Batch => _batch,
            SidebarSelection.Training => _training,
            SidebarSelection.Visualisierung => _viz,
            SidebarSelection.Einstellungen => _settings,
            _ => _analysis
        };
    }
}
