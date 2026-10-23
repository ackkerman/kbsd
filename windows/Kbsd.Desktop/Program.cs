// This file guarantees one tray process per session and opt-in, local-only diagnostics.
using System.Text.Json;
using Kbsd.Core;

namespace Kbsd.Desktop;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        ApplicationConfiguration.Initialize();
        var root = Path.Combine(AppContext.BaseDirectory, "Sounds");
        if (args.Contains("--diagnose"))
        {
            try
            {
                var mixer = new RecordingMixer(root);
                var verified = mixer.VerifyAllRecordings();
                var submitted = 0L;
                var nonSilent = 0L;
                var inputRegistered = false;
                if (args.Contains("--input"))
                {
                    using var monitor = new RawInputMonitor(_ => { }, _ => { }, error => throw new InvalidOperationException(error));
                    monitor.Start();
                    inputRegistered = monitor.IsMonitoring;
                }
                if (args.Contains("--output"))
                {
                    string? outputError = null;
                    using var output = new WaveOutput(mixer, error => outputError = error);
                    mixer.Play(new SoundRequest("slate/30-down.wav", 0), new SoundSettings { RandomPitch = false });
                    Thread.Sleep(500);
                    if (outputError is not null) throw new InvalidOperationException(outputError);
                    submitted = output.SubmittedFrames;
                    nonSilent = output.NonSilentBlocks;
                    if (submitted < 4800 || nonSilent == 0) throw new InvalidOperationException("Audio device did not accept the expected non-silent PCM buffers.");
                }
                WriteDiagnostic(args, new { loaded = mixer.LoadedCount, verified, sampleRate = 48000, channels = 2, submittedFrames = submitted, nonSilentBlocks = nonSilent, inputRegistered });
                return 0;
            }
            catch (Exception error)
            {
                WriteDiagnostic(args, new { error = error.Message });
                return 1;
            }
        }
        using var instance = new SingleInstanceActivation();
        if (!instance.IsFirstInstance)
        {
            // A login launch stays quiet; a Start-menu launch opens the existing Settings window.
            if (!args.Contains("--background")) instance.RequestSettings();
            return 0;
        }
        using var context = new TrayApplication(root, args.Contains("--background"));
        instance.Listen(context.RequestSettings);
        Application.Run(context);
        return 0;
    }

    private static void WriteDiagnostic(string[] args, object result)
    {
        var json = JsonSerializer.Serialize(result);
        var index = Array.IndexOf(args, "--report");
        if (index >= 0 && index + 1 < args.Length) File.WriteAllText(args[index + 1], json);
        Console.WriteLine(json);
    }
}
