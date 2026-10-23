// This file guarantees physical-input decoding without translating keys into text.
namespace Kbsd.Core;

public enum InputPhase { Down, Up }
public enum InputCategory { Keyboard, Modifier, Mouse }

/// <summary>A transient input contains only a physical scan code, phase, kind and repeat flag.</summary>
public readonly record struct PhysicalInput(ushort Code, InputPhase Phase, InputCategory Category, bool IsRepeat = false);

/// <summary>Tracks held physical keys in memory solely to suppress repeat sounds.</summary>
public sealed class WindowsInputDecoder
{
    private readonly HashSet<ushort> pressed = [];

    /// <summary>Returns null for invalid or synthetic prefix packets; never reads character data.</summary>
    public PhysicalInput? Keyboard(ushort makeCode, ushort flags, ushort virtualKey)
    {
        // Overruns and fake extended Shift packets do not represent physical key transitions.
        if (makeCode is 0 or 255 || virtualKey == 255 || ((flags & 2) != 0 && makeCode is 42 or 54))
            return null;
        var code = (ushort)(makeCode | ((flags & 2) != 0 ? 0x100 : 0) | ((flags & 4) != 0 ? 0x200 : 0));
        var phase = (flags & 1) != 0 ? InputPhase.Up : InputPhase.Down;
        var repeat = phase == InputPhase.Down && !pressed.Add(code);
        if (phase == InputPhase.Up)
        {
            // Discard releases for keys already held before startup or session resume.
            if (!pressed.Remove(code)) return null;
        }
        var category = code is 29 or 42 or 54 or 56 or 58 or 0x11d or 0x138 or 0x15b or 0x15c
            ? InputCategory.Modifier : InputCategory.Keyboard;
        return new PhysicalInput(code, phase, category, repeat);
    }

    /// <summary>Mouse button flags have no keyboard fields; movement and wheel packets produce no events.</summary>
    public static IEnumerable<PhysicalInput> Mouse(ushort buttonFlags)
    {
        for (ushort button = 0; button < 5; button++)
        {
            if ((buttonFlags & (1 << (button * 2))) != 0)
                yield return new PhysicalInput(button, InputPhase.Down, InputCategory.Mouse);
            if ((buttonFlags & (2 << (button * 2))) != 0)
                yield return new PhysicalInput(button, InputPhase.Up, InputCategory.Mouse);
        }
    }

    public void Reset() => pressed.Clear();
}

/// <summary>A request identifies a bundled recording and its horizontal position, without any typed text.</summary>
public readonly record struct SoundRequest(string File, float Pan);

public static class KeySoundMapping
{
    private static readonly ushort[][] Rows =
    [
        [41, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 43],
        [58, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 28],
        [42, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54]
    ];

    /// <summary>Null means disabled, locked, repeating, or excluded by the user's input preferences.</summary>
    public static SoundRequest? Request(PhysicalInput input, SoundSettings settings, bool locked)
    {
        if (!settings.Enabled || locked || input.IsRepeat) return null;
        if (input.Category == InputCategory.Modifier && !settings.ModifierSounds) return null;
        if (input.Category == InputCategory.Mouse && !settings.MouseSounds) return null;
        var code = input.Category == InputCategory.Mouse ? 37 : input.Code switch
        {
            0x15b or 0x15c => 3675,
            0x11c => 28,
            _ when SoundBank.SampleCodes.Contains(input.Code) => input.Code,
            _ => SoundBank.SampleCodes[input.Code % 11]
        };
        float pan = 0;
        if (settings.Stereo && input.Category != InputCategory.Mouse)
        {
            foreach (var row in Rows)
            {
                var index = Array.IndexOf(row, input.Code);
                if (index >= 0) pan = (float)index / (row.Length - 1) * 1.2f - 0.6f;
            }
        }
        return new SoundRequest($"{settings.SwitchSet}/{code}-{input.Phase.ToString().ToLowerInvariant()}.wav", pan);
    }
}
