using System.ComponentModel;

namespace TotallyHuman.Utilities;

/// <summary>
/// Bindbarer Proxy für die Lokalisierung. Nutzung in XAML:
///   Text="{Binding [analysis.title], Source={x:Static util:LocProxy.Instance}}"
/// Beim Sprachwechsel wird der Indexer als geändert gemeldet, sodass die gesamte
/// UI automatisch neu übersetzt wird — ohne Neustart.
/// </summary>
public sealed class LocProxy : INotifyPropertyChanged
{
    public static LocProxy Instance { get; } = new();

    public event PropertyChangedEventHandler? PropertyChanged;

    private LocProxy()
    {
        Loc.LanguageChanged += (_, _) =>
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs("Item[]"));
    }

    /// <summary>Liefert den übersetzten Text für einen Schlüssel.</summary>
    public string this[string key] => Loc.Get(key);
}
