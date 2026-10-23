// This file guarantees executable scenarios for privacy, physical input, persistence and actual PCM rendering.
using System.Text;
using Kbsd.Core;

var root = args.Length == 1 ? args[0] : Path.GetFullPath("public/assets/sounds/preview");
var tests = new (string Name, Action Run)[]
{
    ("Given invalid preferences, when validated, then sound values recover within bounds", () =>
    {
        var valid = new SoundSettings { Volume = double.NaN, Pitch = double.PositiveInfinity, SwitchSet = "../outside" }.Validate();
        Equal(0.7, valid.Volume); Equal(0.0, valid.Pitch); Equal("slate", valid.SwitchSet);
        Equal(1.0, new SoundSettings { Volume = 8 }.Validate().Volume);
        Equal(-6.0, new SoundSettings { Pitch = -40 }.Validate().Pitch);
    }),
    ("Given locked, disabled or repeating input, then no recording is requested", () =>
    {
        var input = new PhysicalInput(30, InputPhase.Down, InputCategory.Keyboard);
        Equal<SoundRequest?>(null, KeySoundMapping.Request(input, new() { Enabled = false }, false));
        Equal<SoundRequest?>(null, KeySoundMapping.Request(input, new(), true));
        Equal<SoundRequest?>(null, KeySoundMapping.Request(input with { IsRepeat = true }, new(), false));
    }),
    ("Given a held key, when repeats and a release arrive, then only physical transitions sound", () =>
    {
        var decoder = new WindowsInputDecoder();
        Equal(false, decoder.Keyboard(30, 0, 65)!.Value.IsRepeat);
        Equal(true, decoder.Keyboard(30, 0, 65)!.Value.IsRepeat);
        Equal(InputPhase.Up, decoder.Keyboard(30, 1, 65)!.Value.Phase);
        Equal(false, decoder.Keyboard(30, 0, 65)!.Value.IsRepeat);
        decoder.Reset();
        Equal<PhysicalInput?>(null, decoder.Keyboard(30, 1, 65));
        Equal(false, decoder.Keyboard(30, 0, 65)!.Value.IsRepeat);
    }),
    ("Given both modifier sides, then releasing one does not repeat or release the other", () =>
    {
        var decoder = new WindowsInputDecoder();
        Equal(InputCategory.Modifier, decoder.Keyboard(29, 0, 17)!.Value.Category);
        Equal((ushort)0x11d, decoder.Keyboard(29, 2, 17)!.Value.Code);
        Equal(InputPhase.Up, decoder.Keyboard(29, 1, 17)!.Value.Phase);
        Equal(InputPhase.Up, decoder.Keyboard(29, 3, 17)!.Value.Phase);
        Equal(false, decoder.Keyboard(42, 0, 16)!.Value.IsRepeat);
        Equal(false, decoder.Keyboard(54, 0, 16)!.Value.IsRepeat);
        Equal(InputPhase.Up, decoder.Keyboard(42, 1, 16)!.Value.Phase);
        Equal(InputPhase.Up, decoder.Keyboard(54, 1, 16)!.Value.Phase);
        Equal<PhysicalInput?>(null, decoder.Keyboard(42, 2, 16));
        Equal<PhysicalInput?>(null, decoder.Keyboard(255, 0, 255));
    }),
    ("Given mouse movement or button flags, then only independent button phases are decoded", () =>
    {
        Equal(0, WindowsInputDecoder.Mouse(0).Count());
        Equal(0, WindowsInputDecoder.Mouse(0x400).Count());
        Equal(InputPhase.Down, WindowsInputDecoder.Mouse(1).Single().Phase);
        Equal(InputPhase.Up, WindowsInputDecoder.Mouse(2).Single().Phase);
        Equal((ushort)1, WindowsInputDecoder.Mouse(4).Single().Code);
        Equal(4, WindowsInputDecoder.Mouse(0xf).Count());
        var input = WindowsInputDecoder.Mouse(1).Single();
        Equal<SoundRequest?>(null, KeySoundMapping.Request(input, new(), false));
        Equal("slate/37-down.wav", KeySoundMapping.Request(input, new() { MouseSounds = true }, false)!.Value.File);
        Equal<SoundRequest?>(null, KeySoundMapping.Request(new(29, InputPhase.Down, InputCategory.Modifier), new() { ModifierSounds = false }, false));
    }),
    ("Given Windows keys and keypad Enter, then the intended dedicated samples are selected", () =>
    {
        Equal("slate/3675-down.wav", Request(0x15b).File);
        Equal("slate/28-down.wav", Request(0x11c).File);
        Equal("slate/30-down.wav", Request(30).File);
        Check(Request(30).Pan < 0, "Left-hand key must pan left.");
        Check(Request(38).Pan > 0, "Right-hand key must pan right.");
        Equal(0f, KeySoundMapping.Request(new(38, InputPhase.Down, InputCategory.Keyboard), new() { Stereo = false }, false)!.Value.Pan);
        foreach (var set in SoundBank.Sets)
            foreach (var phase in Enum.GetValues<InputPhase>())
                for (ushort code = 1; code < 512; code++)
                    Check(File.Exists(Path.Combine(root, KeySoundMapping.Request(new(code, phase, InputCategory.Keyboard), new() { SwitchSet = set.Slug }, false)!.Value.File)), "Every physical key must select an existing recording.");
    }),
    ("Given a new day, when recording, then only the daily total resets", () =>
    {
        var day = new DateOnly(2026, 10, 23);
        var stats = new UsageStatistics().Record(day).Record(day).Record(day.AddDays(1));
        Equal(3L, stats.Total); Equal(1L, stats.Today);
        Equal(0L, stats.Refresh(day.AddDays(2)).Today);
    }),
    ("Given corrupt or partial state, then validated defaults load and only aggregate data is saved", () =>
    {
        var directory = Path.Combine(Path.GetTempPath(), "kbsd-tests-" + Guid.NewGuid());
        Directory.CreateDirectory(directory);
        try
        {
            var store = new PreferenceStore(directory);
            var file = Path.Combine(directory, "state.json");
            File.WriteAllText(file, "{broken");
            Equal("slate", store.Load().Settings.SwitchSet);
            File.WriteAllText(file, "{}");
            Equal(0L, store.Load().Statistics.Total);
            var settings = new SoundSettings { SwitchSet = "ruby", Pitch = 5, Volume = 0.3, MouseSounds = true };
            store.Save(settings, new UsageStatistics().Record(DateOnly.FromDateTime(DateTime.Now)));
            var saved = store.Load();
            Equal(settings, saved.Settings); Equal(1L, saved.Statistics.Total);
            var json = File.ReadAllText(file);
            foreach (var forbidden in new[] { "keyCode", "scanCode", "characters", "history", "process", "window", "events" })
                Check(!json.Contains(forbidden, StringComparison.OrdinalIgnoreCase), "Persisted state contains input data.");
        }
        finally { Directory.Delete(directory, recursive: true); }
    }),
    ("Given mono PCM with metadata and a different sample rate, then it normalizes to stereo 48kHz", () =>
    {
        var wav = Wav([0, 0, 0xff, 0x7f, 0, 0x80, 0, 0], 24000);
        var recording = PcmRecording.Decode(wav);
        Equal(8, recording.Frames);
        Check(recording.Samples.All(float.IsFinite), "Normalized output must be finite.");
        for (var i = 0; i < recording.Frames; i++) Equal(recording.Samples[i * 2], recording.Samples[i * 2 + 1]);
        Throws<InvalidDataException>(() => PcmRecording.Decode(wav.AsSpan(0, wav.Length - 1)));
        Throws<InvalidDataException>(() => PcmRecording.Decode(new byte[44]));
        Throws<InvalidDataException>(() => PcmRecording.Decode(Wav([0, 0, 0xc0, 0x7f], 48000, 3, 32)));
    }),
    ("Given all 182 original recordings, when scheduled through the real mixer, then each renders finite nonzero PCM", () =>
    {
        var mixer = new RecordingMixer(root);
        Equal(182, mixer.LoadedCount);
        Equal(182, mixer.VerifyAllRecordings());
        var buffer = new float[48000];
        mixer.Play(Request(30), new() { Volume = 0, RandomPitch = false });
        mixer.Render(buffer);
        Check(buffer.All(value => value == 0), "Muted playback must be silent.");
        foreach (var pitch in new[] { -6.0, 6.0 })
        {
            for (var i = 0; i < 100; i++) mixer.Play(Request(30), new() { Pitch = pitch, RandomPitch = false });
            mixer.Render(buffer);
            Check(buffer.All(value => float.IsFinite(value) && Math.Abs(value) <= 1), "Overlapping pitch-shifted playback must stay bounded.");
            Check(buffer.Any(value => value != 0), "Pitch-shifted output must be nonzero.");
            mixer.Stop(); mixer.Render(buffer);
            Check(buffer.All(value => value == 0), "Stop must discard every active voice.");
        }
        Throws<InvalidDataException>(() => mixer.Play(new("missing.wav", 0), new()));
    })
};
var failures = 0;
foreach (var test in tests)
{
    try { test.Run(); Console.WriteLine("PASS " + test.Name); }
    catch (Exception error) { failures++; Console.Error.WriteLine($"FAIL {test.Name}\n{error}"); }
}
Console.WriteLine($"{tests.Length - failures}/{tests.Length} scenarios passed.");
return failures == 0 ? 0 : 1;

static SoundRequest Request(ushort code) => KeySoundMapping.Request(new(code, InputPhase.Down, InputCategory.Keyboard), new(), false)!.Value;
static void Check(bool condition, string message) { if (!condition) throw new InvalidOperationException(message); }
static void Equal<T>(T expected, T actual) => Check(EqualityComparer<T>.Default.Equals(expected, actual), $"Expected {expected}, got {actual}.");
static void Throws<T>(Action action) where T : Exception
{
    try { action(); } catch (T) { return; }
    throw new InvalidOperationException($"Expected {typeof(T).Name}.");
}
static byte[] Wav(byte[] data, int rate, ushort tag = 1, ushort bits = 16)
{
    using var memory = new MemoryStream();
    using var writer = new BinaryWriter(memory);
    writer.Write(Encoding.ASCII.GetBytes("RIFF")); writer.Write(48 + data.Length);
    writer.Write(Encoding.ASCII.GetBytes("WAVEJUNK")); writer.Write(3); writer.Write(new byte[4]);
    writer.Write(Encoding.ASCII.GetBytes("fmt ")); writer.Write(16); writer.Write(tag); writer.Write((ushort)1);
    writer.Write(rate); writer.Write(rate * bits / 8); writer.Write((ushort)(bits / 8)); writer.Write(bits);
    writer.Write(Encoding.ASCII.GetBytes("data")); writer.Write(data.Length); writer.Write(data);
    return memory.ToArray();
}
