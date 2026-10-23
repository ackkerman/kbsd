// This file guarantees bounded overlapping playback through the same PCM mixer used by diagnostics.
namespace Kbsd.Core;

public sealed class RecordingMixer
{
    /// <summary>A voice retains only its audio buffer and playback position, never input events.</summary>
    private sealed class Voice(PcmRecording recording, double speed, float left, float right)
    {
        public PcmRecording Recording { get; } = recording;
        public double Position { get; set; }
        public double Speed { get; } = speed;
        public float Left { get; } = left;
        public float Right { get; } = right;
    }

    private readonly object gate = new();
    private readonly Dictionary<string, PcmRecording> recordings;
    private readonly List<Voice> voices = [];
    private double volume = 0.7;
    public int LoadedCount => recordings.Count;

    public RecordingMixer(string root) => recordings = SoundBank.Paths.ToDictionary(path => path,
        path => PcmRecording.Read(Path.Combine(root, path)));

    public void Play(SoundRequest request, SoundSettings settings)
    {
        if (!recordings.TryGetValue(request.File, out var recording))
            throw new InvalidDataException($"Bundled keyboard recording is missing: {request.File}.");
        var valid = settings.Validate();
        var variation = valid.RandomPitch ? Random.Shared.NextDouble() * 0.6 - 0.3 : 0;
        var pan = float.IsFinite(request.Pan) ? Math.Clamp(request.Pan, -1, 1) : 0;
        lock (gate)
        {
            volume = valid.Volume;
            // Reuse the oldest slot at capacity so rapid input cannot grow memory without bound.
            if (voices.Count == 24) voices.RemoveAt(0);
            voices.Add(new Voice(recording, Math.Pow(2, (valid.Pitch + variation) / 12),
                pan > 0 ? 1 - pan : 1, pan < 0 ? 1 + pan : 1));
        }
    }

    public void SetVolume(double value) { lock (gate) volume = Math.Clamp(value, 0, 1); }
    public void Stop() { lock (gate) voices.Clear(); }

    public void Render(Span<float> output)
    {
        output.Clear();
        lock (gate)
        {
            foreach (var voice in voices)
            {
                for (var frame = 0; frame < output.Length / 2 && voice.Position < voice.Recording.Frames; frame++)
                {
                    var first = (int)voice.Position;
                    var next = Math.Min(first + 1, voice.Recording.Frames - 1);
                    var fraction = (float)(voice.Position - first);
                    for (var channel = 0; channel < 2; channel++)
                    {
                        var samples = voice.Recording.Samples;
                        var value = samples[first * 2 + channel] * (1 - fraction) + samples[next * 2 + channel] * fraction;
                        output[frame * 2 + channel] += value * (channel == 0 ? voice.Left : voice.Right) * (float)volume;
                    }
                    voice.Position += voice.Speed;
                }
            }
            voices.RemoveAll(voice => voice.Position >= voice.Recording.Frames);
        }
        for (var i = 0; i < output.Length; i++) output[i] = Math.Clamp(output[i], -1, 1);
    }

    /// <summary>Schedules every recording through the real mixer and checks its complete finite, non-silent output.</summary>
    public int VerifyAllRecordings()
    {
        var verified = 0;
        var buffer = new float[960];
        var settings = new SoundSettings { RandomPitch = false };
        foreach (var (path, recording) in recordings)
        {
            Stop();
            Play(new SoundRequest(path, 0), settings);
            double energy = 0;
            for (var frame = 0; frame < recording.Frames; frame += buffer.Length / 2)
            {
                Render(buffer);
                foreach (var sample in buffer)
                {
                    if (!float.IsFinite(sample)) throw new InvalidDataException($"Non-finite PCM rendered: {path}.");
                    energy += Math.Abs(sample);
                }
            }
            if (energy <= 0) throw new InvalidDataException($"Recording rendered silence: {path}.");
            verified++;
        }
        Stop();
        return verified;
    }
}
