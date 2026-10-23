// This file guarantees passive physical-input observation and session-aware muting.
using System.ComponentModel;
using System.Runtime.InteropServices;
using Kbsd.Core;

namespace Kbsd.Desktop;

internal sealed class RawInputMonitor : NativeWindow, IDisposable
{
    private readonly WindowsInputDecoder decoder = new();
    private readonly Action<PhysicalInput> receive;
    private readonly Action<bool> sessionChanged;
    private readonly Action<string> failed;
    private bool registered;
    private bool sessionRegistered;
    private bool suspended;
    private bool locked;
    public bool IsLocked => locked || suspended;
    public bool IsMonitoring => registered && sessionRegistered;

    public RawInputMonitor(Action<PhysicalInput> receive, Action<bool> sessionChanged, Action<string> failed)
    {
        this.receive = receive;
        this.sessionChanged = sessionChanged;
        this.failed = failed;
        CreateHandle(new CreateParams { Caption = "kbsd input receiver" });
    }

    public void Start()
    {
        decoder.Reset();
        if (!sessionRegistered)
        {
            if (!WTSRegisterSessionNotification(Handle, 0)) throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not register session-lock monitoring.");
            sessionRegistered = true;
        }
        var devices = Devices(0x100, Handle); // INPUTSINK preserves legacy input delivery to other applications.
        if (!RegisterRawInputDevices(devices, (uint)devices.Length, (uint)Marshal.SizeOf<RawInputDevice>()))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not register keyboard and mouse Raw Input.");
        registered = true;
    }

    protected override void WndProc(ref Message message)
    {
        try
        {
            if (message.Msg == 0x00ff && registered && !IsLocked) Read(message.LParam);
            if (message.Msg == 0x02b1)
            {
                var reason = message.WParam.ToInt32();
                // Remote/console disconnect, lock and logoff all silence the current session.
                if (reason is 2 or 4 or 6 or 7) locked = true;
                if (reason is 1 or 3 or 5 or 8) locked = false;
                decoder.Reset();
                sessionChanged(IsLocked);
            }
            if (message.Msg == 0x0218)
            {
                var reason = message.WParam.ToInt32();
                if (reason == 4) suspended = true;
                if (reason is 7 or 18) suspended = false;
                decoder.Reset();
                sessionChanged(IsLocked);
            }
        }
        catch (Exception error) when (error is Win32Exception or InvalidDataException)
        {
            failed(error.Message);
        }
        // WM_INPUT always reaches DefWindowProc so Windows can release its input packet.
        base.WndProc(ref message);
    }

    private void Read(nint handle)
    {
        uint size = 0;
        var headerSize = (uint)(8 + IntPtr.Size * 2);
        if (GetRawInputData(handle, 0x10000003, nint.Zero, ref size, headerSize) == uint.MaxValue)
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read Raw Input packet size.");
        if (size < headerSize || size > 4096) return;
        var memory = Marshal.AllocHGlobal((int)size);
        try
        {
            var copied = GetRawInputData(handle, 0x10000003, memory, ref size, headerSize);
            if (copied == uint.MaxValue) throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read Raw Input packet.");
            if (copied < headerSize) return;
            var body = memory + (int)headerSize;
            var kind = Marshal.ReadInt32(memory);
            if (kind == 1 && copied >= headerSize + 16)
            {
                var input = decoder.Keyboard((ushort)Marshal.ReadInt16(body), (ushort)Marshal.ReadInt16(body, 2), (ushort)Marshal.ReadInt16(body, 6));
                if (input is { } value) receive(value);
            }
            if (kind == 0 && copied >= headerSize + 24)
            {
                foreach (var input in WindowsInputDecoder.Mouse((ushort)Marshal.ReadInt16(body, 4))) receive(input);
            }
        }
        finally { Marshal.FreeHGlobal(memory); }
    }

    public void Dispose()
    {
        if (registered)
        {
            var devices = Devices(1, nint.Zero); // REMOVE requires a null target window.
            RegisterRawInputDevices(devices, (uint)devices.Length, (uint)Marshal.SizeOf<RawInputDevice>());
            registered = false;
        }
        if (sessionRegistered) WTSUnRegisterSessionNotification(Handle);
        DestroyHandle();
    }

    private static RawInputDevice[] Devices(uint flags, nint target) =>
        [new() { Page = 1, Usage = 6, Flags = flags, Target = target }, new() { Page = 1, Usage = 2, Flags = flags, Target = target }];

    /// <summary>Native HID registration includes no flags that suppress or replace application input.</summary>
    [StructLayout(LayoutKind.Sequential)]
    private struct RawInputDevice { public ushort Page, Usage; public uint Flags; public nint Target; }

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool RegisterRawInputDevices([In] RawInputDevice[] devices, uint count, uint size);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetRawInputData(nint handle, uint command, nint data, ref uint size, uint headerSize);
    [DllImport("wtsapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool WTSRegisterSessionNotification(nint handle, uint flags);
    [DllImport("wtsapi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool WTSUnRegisterSessionNotification(nint handle);
}
