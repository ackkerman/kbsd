// This file guarantees validated sound preferences and stable recording identifiers.
namespace Kbsd.Core;

/// <summary>Preferences contain sound configuration only, never input history or OS state.</summary>
public sealed record SoundSettings
{
    public bool Enabled { get; init; } = true;
    public string SwitchSet { get; init; } = "slate";
    public double Volume { get; init; } = 0.7;
    public double Pitch { get; init; }
    public bool RandomPitch { get; init; } = true;
    public bool Stereo { get; init; } = true;
    public bool ModifierSounds { get; init; } = true;
    public bool MouseSounds { get; init; }

    public SoundSettings Validate() => this with
    {
        SwitchSet = SoundBank.Sets.Any(set => set.Slug == SwitchSet) ? SwitchSet : "slate",
        Volume = double.IsFinite(Volume) ? Math.Clamp(Volume, 0, 1) : 0.7,
        Pitch = double.IsFinite(Pitch) ? Math.Clamp(Pitch, -6, 6) : 0
    };
}

/// <summary>A sound set uses the same resource slug, display name and color on every platform.</summary>
public sealed record SwitchSet(string Slug, string Name, int Color)
{
    public string Kind => Slug switch
    {
        "slate" => "Linear",
        "violet" or "pebble" => "Tactile",
        "paper" => "Textured",
        "honey" => "Balanced",
        "ruby" => "Deep",
        _ => "Soft"
    };
}

public static class SoundBank
{
    public static IReadOnlyList<SwitchSet> Sets { get; } = Array.AsReadOnly(new[]
    {
        new SwitchSet("slate", "Japanese Black", 0x878078),
        new SwitchSet("violet", "Crystal Purple", 0xD68AF0),
        new SwitchSet("pebble", "Oreo", 0x9C9690),
        new SwitchSet("paper", "Cardboard", 0xF3AC87),
        new SwitchSet("honey", "Milky Yellow", 0xF4E49C),
        new SwitchSet("ruby", "Super Red", 0xEF627B),
        new SwitchSet("cream", "Cream", 0xF4CF9F)
    });
    public static IReadOnlyList<int> SampleCodes { get; } = Array.AsReadOnly(new[]
        { 37, 38, 30, 46, 57, 25, 19, 18, 47, 23, 17, 3675, 28 });
    public static IEnumerable<string> Paths => from set in Sets
                                               from code in SampleCodes
                                               from phase in new[] { "down", "up" }
                                               select $"{set.Slug}/{code}-{phase}.wav";
}
