// This file guarantees atomic, local persistence of preferences and aggregate counts only.
using System.Text.Json;

namespace Kbsd.Core;

/// <summary>Only daily and lifetime totals survive a restart; keys and event timestamps are never persisted.</summary>
public sealed record UsageStatistics(long Total = 0, long Today = 0, string Day = "")
{
    public UsageStatistics Refresh(DateOnly day) => Day == day.ToString("yyyy-MM-dd")
        ? this : this with { Today = 0, Day = day.ToString("yyyy-MM-dd") };

    public UsageStatistics Record(DateOnly day)
    {
        var current = Refresh(day);
        return current with { Total = current.Total + 1, Today = current.Today + 1 };
    }
}

/// <summary>The persisted schema excludes launch registration, permissions and all physical input identifiers.</summary>
public sealed record SavedState(SoundSettings Settings, UsageStatistics Statistics);

public sealed class PreferenceStore(string directory)
{
    private readonly string path = Path.Combine(directory, "state.json");

    /// <summary>Missing, malformed or inaccessible state recovers to validated defaults.</summary>
    public SavedState Load()
    {
        try
        {
            var saved = JsonSerializer.Deserialize<SavedState>(File.ReadAllText(path));
            if (saved?.Settings is null || saved.Statistics is null) return Defaults();
            var counts = saved.Statistics;
            if (counts.Total < 0 || counts.Today < 0 || counts.Today > counts.Total) counts = new();
            return new(saved.Settings.Validate(), counts.Refresh(DateOnly.FromDateTime(DateTime.Now)));
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException)
        {
            return Defaults();
        }
    }

    public void Save(SoundSettings settings, UsageStatistics statistics)
    {
        Directory.CreateDirectory(directory);
        var temporary = path + ".tmp";
        File.WriteAllText(temporary, JsonSerializer.Serialize(new SavedState(settings.Validate(), statistics)));
        File.Move(temporary, path, overwrite: true);
    }

    private static SavedState Defaults() => new(new(), new UsageStatistics().Refresh(DateOnly.FromDateTime(DateTime.Now)));
}
