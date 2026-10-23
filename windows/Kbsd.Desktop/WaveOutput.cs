// This file guarantees prepared native buffers, bounded output latency and deterministic audio cleanup.
using System.Runtime.InteropServices;
using Kbsd.Core;

namespace Kbsd.Desktop;

internal sealed class WaveOutput : IDisposable
{
    /// <summary>Each native header owns a prepared, pinned-lifetime PCM block until output is reset.</summary>
    private sealed class Block
    {
        public nint Header;
        public nint Data;
        public bool Prepared;
    }

    private readonly RecordingMixer mixer;
    private readonly Action<string> failed;
    private readonly object gate = new();
    private readonly List<Block> blocks = [];
    private readonly float[] samples = new float[960];
    private readonly uint headerSize = (uint)Marshal.SizeOf<WaveHeader>();
    private nint device;
    private Thread? thread;
    private volatile bool running;
    private bool disposed;
    private long submittedFrames;
    public long SubmittedFrames => Interlocked.Read(ref submittedFrames);
    private long nonSilentBlocks;
    public long NonSilentBlocks => Interlocked.Read(ref nonSilentBlocks);

    public WaveOutput(RecordingMixer mixer, Action<string> failed)
    {
        this.mixer = mixer;
        this.failed = failed;
        try
        {
            var format = new WaveFormat { Tag = 3, Channels = 2, Rate = PcmRecording.SampleRate, BytesPerSecond = PcmRecording.SampleRate * 8, Align = 8, Bits = 32 };
            Check(waveOutOpen(out device, uint.MaxValue, ref format, nint.Zero, nint.Zero, 0), "open stereo 48kHz Float32 output");
            for (var i = 0; i < 3; i++)
            {
                var block = new Block();
                blocks.Add(block);
                block.Data = Marshal.AllocHGlobal(samples.Length * sizeof(float));
                block.Header = Marshal.AllocHGlobal((int)headerSize);
                Marshal.StructureToPtr(new WaveHeader { Data = block.Data, Length = (uint)(samples.Length * sizeof(float)) }, block.Header, false);
                Check(waveOutPrepareHeader(device, block.Header, headerSize), "prepare audio buffer");
                block.Prepared = true;
                Submit(block);
            }
            running = true;
            thread = new Thread(Pump) { IsBackground = true, Name = "kbsd audio" };
            thread.Start();
        }
        catch { Dispose(); throw; }
    }

    private void Pump()
    {
        try
        {
            while (running)
            {
                lock (gate)
                {
                    foreach (var block in blocks)
                    {
                        if ((Marshal.PtrToStructure<WaveHeader>(block.Header).Flags & 1) != 0) Submit(block);
                    }
                }
                Thread.Sleep(2);
            }
        }
        catch (InvalidOperationException error)
        {
            running = false;
            failed(error.Message);
        }
    }

    private void Submit(Block block)
    {
        mixer.Render(samples);
        Marshal.Copy(samples, 0, block.Data, samples.Length);
        Check(waveOutWrite(device, block.Header, headerSize), "schedule PCM output");
        Interlocked.Add(ref submittedFrames, samples.Length / 2);
        if (samples.Any(sample => sample != 0)) Interlocked.Increment(ref nonSilentBlocks);
    }

    public void Silence()
    {
        lock (gate)
        {
            mixer.Stop();
            if (device != nint.Zero) Check(waveOutReset(device), "reset audio output");
        }
    }

    public void Dispose()
    {
        if (disposed) return;
        disposed = true;
        running = false;
        thread?.Join();
        if (device != nint.Zero) waveOutReset(device);
        foreach (var block in blocks)
        {
            if (block.Prepared) waveOutUnprepareHeader(device, block.Header, headerSize);
            if (block.Header != nint.Zero) Marshal.FreeHGlobal(block.Header);
            if (block.Data != nint.Zero) Marshal.FreeHGlobal(block.Data);
        }
        if (device != nint.Zero) waveOutClose(device);
        device = nint.Zero;
    }

    private static void Check(uint result, string action)
    {
        if (result != 0) throw new InvalidOperationException($"Could not {action}: Windows multimedia error {result}. Check the output device and retry.");
    }

    /// <summary>Native PCM format is explicitly packed to match WAVEFORMATEX.</summary>
    [StructLayout(LayoutKind.Sequential, Pack = 2)]
    private struct WaveFormat { public ushort Tag, Channels; public uint Rate, BytesPerSecond; public ushort Align, Bits, Extra; }
    /// <summary>The native audio driver owns a submitted header until WHDR_DONE or waveOutReset.</summary>
    [StructLayout(LayoutKind.Sequential)]
    private struct WaveHeader { public nint Data; public uint Length, Recorded; public nuint User; public uint Flags, Loops; public nint Next; public nuint Reserved; }

    [DllImport("winmm.dll")] private static extern uint waveOutOpen(out nint device, uint id, ref WaveFormat format, nint callback, nint instance, uint flags);
    [DllImport("winmm.dll")] private static extern uint waveOutPrepareHeader(nint device, nint header, uint size);
    [DllImport("winmm.dll")] private static extern uint waveOutWrite(nint device, nint header, uint size);
    [DllImport("winmm.dll")] private static extern uint waveOutReset(nint device);
    [DllImport("winmm.dll")] private static extern uint waveOutUnprepareHeader(nint device, nint header, uint size);
    [DllImport("winmm.dll")] private static extern uint waveOutClose(nint device);
}
