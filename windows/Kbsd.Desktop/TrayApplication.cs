// This file guarantees tray lifetime, cancellable previews, count-only persistence and visible failures.
using System.ComponentModel;
using System.Runtime.InteropServices;
using Kbsd.Core;

namespace Kbsd.Desktop;

internal sealed class TrayApplication : ApplicationContext
{
    private readonly PreferenceStore store = new(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "kbsd"));
    private readonly string soundRoot;
    private readonly SettingsForm form;
    private readonly NotifyIcon tray;
    private readonly Icon icon;
    private readonly RawInputMonitor monitor;
    private readonly System.Windows.Forms.Timer saveTimer = new() { Interval = 3000 };
    private readonly System.Windows.Forms.Timer statusTimer = new() { Interval = 1000 };
    private RecordingMixer? mixer;
    private WaveOutput? output;
    private CancellationTokenSource? preview;
    private bool dirty;
    private bool exiting;
    public SoundSettings Settings { get; private set; }
    public UsageStatistics Statistics { get; private set; }
    public string? Error { get; private set; }
    public bool Locked { get; private set; }
    public bool Previewing => preview is not null;
    public bool CanMonitor => monitor.IsMonitoring;
    public string Status => Locked ? "Muted while the session is locked or suspended."
        : Error is not null ? "Needs attention — check the message below."
        : !monitor.IsMonitoring ? "Preview only — input monitoring is unavailable."
        : Settings.Enabled ? "Keyboard access is enabled · listening for physical input." : "Keyboard sounds are paused.";

    public TrayApplication(string soundRoot, bool background)
    {
        this.soundRoot = soundRoot;
        var saved = store.Load();
        Settings = saved.Settings;
        Statistics = saved.Statistics;
        icon = CreateIcon();
        form = new SettingsForm(this) { Icon = icon };
        _ = form.Handle; // Audio failures can always be marshalled back to the UI thread.
        monitor = new RawInputMonitor(HandleInput, SessionChanged, Fail);
        var menu = new ContextMenuStrip();
        var enabled = new ToolStripMenuItem("Enable keyboard sounds") { CheckOnClick = true };
        enabled.Click += (_, _) => Update(Settings with { Enabled = enabled.Checked });
        menu.Items.Add(enabled);
        foreach (var set in SoundBank.Sets)
        {
            var item = new ToolStripMenuItem(set.Name) { Tag = set.Slug };
            item.Click += (_, _) => Update(Settings with { SwitchSet = set.Slug });
            menu.Items.Add(item);
        }
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Settings…", null, (_, _) => ShowSettings());
        menu.Items.Add("Quit kbsd", null, (_, _) => ExitThread());
        menu.Opening += (_, _) =>
        {
            enabled.Checked = Settings.Enabled;
            foreach (var item in menu.Items.OfType<ToolStripMenuItem>().Where(item => item.Tag is string))
                item.Checked = (string)item.Tag! == Settings.SwitchSet;
        };
        tray = new NotifyIcon { Icon = icon, Text = "kbsd", ContextMenuStrip = menu, Visible = true };
        tray.DoubleClick += (_, _) => ShowSettings();
        saveTimer.Tick += (_, _) => Save();
        saveTimer.Start();
        statusTimer.Tick += (_, _) =>
        {
            var refreshed = Statistics.Refresh(DateOnly.FromDateTime(DateTime.Now));
            if (refreshed != Statistics) { Statistics = refreshed; dirty = true; }
            form.RefreshStatus();
        };
        statusTimer.Start();
        Retry();
        if (!background) ShowSettings();
    }

    public void ShowSettings()
    {
        form.RefreshSettings();
        form.Show();
        form.WindowState = FormWindowState.Normal;
        form.Activate();
    }

    public void Update(SoundSettings settings)
    {
        if (settings.SwitchSet != Settings.SwitchSet) CancelPreview(silence: true);
        Settings = settings.Validate();
        dirty = true;
        mixer?.SetVolume(Settings.Volume);
        if (!Settings.Enabled) CancelPreview(silence: true);
        form.RefreshSettings();
        Save();
    }

    public void Retry()
    {
        CancelPreview(silence: false);
        output?.Dispose();
        output = null;
        mixer = null;
        Error = null;
        try
        {
            mixer = new RecordingMixer(soundRoot);
            output = new WaveOutput(mixer, message =>
            {
                if (!exiting) form.BeginInvoke(() => Fail(message));
            });
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or InvalidOperationException)
        {
            Fail(error.Message);
        }
        try { monitor.Start(); }
        catch (Win32Exception error) { Fail($"Preview only. {error.Message}"); }
        form.RefreshStatus();
    }

    private void HandleInput(PhysicalInput input)
    {
        if (output is null || mixer is null || Error is not null) return;
        var request = KeySoundMapping.Request(input, Settings, Locked);
        if (request is not { } value) return;
        mixer.Play(value, Settings);
        if (input.Category == InputCategory.Keyboard && input.Phase == InputPhase.Down)
        {
            Statistics = Statistics.Record(DateOnly.FromDateTime(DateTime.Now));
            dirty = true;
        }
    }

    private void SessionChanged(bool locked)
    {
        Locked = locked;
        if (locked)
        {
            CancelPreview(silence: true);
            Save();
        }
        form.RefreshStatus();
    }

    public async void TogglePreview()
    {
        var wasPlaying = Previewing;
        CancelPreview(silence: true);
        if (wasPlaying || Locked || mixer is null || output is null) return;
        using var source = new CancellationTokenSource();
        preview = source;
        form.RefreshStatus();
        try
        {
            foreach (ushort code in new ushort[] { 37, 38, 30, 46, 37, 57, 25, 19, 18, 47, 23, 18, 17, 28 })
            {
                foreach (var phase in new[] { InputPhase.Down, InputPhase.Up })
                {
                    source.Token.ThrowIfCancellationRequested();
                    var settings = Settings with { Enabled = true };
                    var request = KeySoundMapping.Request(new PhysicalInput(code, phase, InputCategory.Keyboard), settings, Locked);
                    if (request is { } value) mixer.Play(value, settings);
                    await Task.Delay(phase == InputPhase.Down ? 95 : 130, source.Token);
                }
            }
        }
        catch (OperationCanceledException) { /* A replacement preview owns the status after cancellation. */ }
        catch (InvalidOperationException error) { Fail(error.Message); }
        finally
        {
            if (ReferenceEquals(preview, source)) preview = null;
            if (!exiting) form.RefreshStatus();
        }
    }

    private void CancelPreview(bool silence)
    {
        preview?.Cancel();
        preview = null;
        if (silence)
        {
            try { output?.Silence(); }
            catch (InvalidOperationException error) { Fail(error.Message); }
        }
    }

    public bool GetStartup()
    {
        try { return StartupRegistration.Enabled; }
        catch (Exception error) when (error is UnauthorizedAccessException or System.Security.SecurityException or IOException)
        { Fail($"Could not read login startup: {error.Message}"); return false; }
    }

    public void SetStartup(bool enabled)
    {
        try { StartupRegistration.Set(enabled); }
        catch (Exception error) when (error is UnauthorizedAccessException or System.Security.SecurityException or IOException)
        { Fail($"Could not change login startup: {error.Message}"); }
        form.RefreshSettings();
    }

    private void Fail(string message)
    {
        Error = message;
        mixer?.Stop();
        form.RefreshStatus();
    }

    private void Save()
    {
        if (!dirty) return;
        try { store.Save(Settings, Statistics); dirty = false; }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        { Fail($"Could not save local settings and counts: {error.Message}"); }
    }

    protected override void ExitThreadCore()
    {
        exiting = true;
        CancelPreview(silence: false);
        Save();
        saveTimer.Stop();
        statusTimer.Stop();
        monitor.Dispose();
        output?.Dispose();
        tray.Visible = false;
        form.AllowClose = true;
        form.Close();
        base.ExitThreadCore();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            tray.Dispose();
            tray.ContextMenuStrip?.Dispose();
            form.Dispose();
            saveTimer.Dispose();
            statusTimer.Dispose();
            icon.Dispose();
        }
        base.Dispose(disposing);
    }

    private static Icon CreateIcon()
    {
        var resource = System.Windows.Application.GetResourceStream(new Uri("/kbsd;component/Brand.png", UriKind.Relative));
        using var stream = resource.Stream;
        using var original = new Bitmap(stream);
        using var image = new Bitmap(original, 32, 32);
        var handle = image.GetHicon();
        try { return (Icon)Icon.FromHandle(handle).Clone(); }
        finally { DestroyIcon(handle); }
    }

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DestroyIcon(nint handle);
}
