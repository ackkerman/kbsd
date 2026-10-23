// This file guarantees that subsequent launches activate the existing tray process instead of starting another.
namespace Kbsd.Desktop;

/// <summary>Owns the session's tray identity and a payload-free request to show Settings.</summary>
internal sealed class SingleInstanceActivation : IDisposable
{
    private readonly Mutex mutex;
    private readonly EventWaitHandle activation;
    private RegisteredWaitHandle? listener;
    public bool IsFirstInstance { get; }

    public SingleInstanceActivation(string name = "kbsd-desktop")
    {
        activation = new EventWaitHandle(false, EventResetMode.AutoReset, $@"Local\{name}-activate");
        mutex = new Mutex(false, $@"Local\{name}", out var first);
        IsFirstInstance = first;
    }

    public void RequestSettings() => activation.Set();

    public void Listen(Action showSettings)
    {
        listener = ThreadPool.RegisterWaitForSingleObject(activation, (_, _) => showSettings(), null, Timeout.Infinite, executeOnlyOnce: false);
    }

    public void Dispose()
    {
        listener?.Unregister(null);
        activation.Dispose();
        mutex.Dispose();
    }
}
