// This file guarantees that bundled WAV recordings become finite stereo 48kHz Float32 PCM.
using System.Buffers.Binary;
using System.Text;

namespace Kbsd.Core;

/// <summary>Interleaved stereo frames always use 48kHz finite Float32 samples.</summary>
public sealed class PcmRecording
{
    public const int SampleRate = 48_000;
    public float[] Samples { get; }
    public int Frames => Samples.Length / 2;

    private PcmRecording(float[] samples) => Samples = samples;

    public static PcmRecording Read(string path)
    {
        try
        {
            return Decode(File.ReadAllBytes(path));
        }
        catch (Exception error) when (error is IOException or ArgumentException or OverflowException)
        {
            throw new InvalidDataException($"Could not normalize recording '{Path.GetFileName(path)}' to stereo 48kHz PCM: {error.Message}", error);
        }
    }

    /// <summary>Rejects truncated, compressed, non-finite or unsupported recordings instead of playing invalid memory.</summary>
    public static PcmRecording Decode(ReadOnlySpan<byte> wav)
    {
        if (wav.Length < 12 || Encoding.ASCII.GetString(wav[..4]) != "RIFF" || Encoding.ASCII.GetString(wav[8..12]) != "WAVE")
            throw new InvalidDataException("Expected a RIFF/WAVE recording.");
        var riffEnd = 8L + BinaryPrimitives.ReadUInt32LittleEndian(wav[4..]);
        if (riffEnd > wav.Length || riffEnd < 12) throw new InvalidDataException("Truncated RIFF container.");
        ReadOnlySpan<byte> format = default, data = default;
        for (long offset = 12; offset + 8 <= riffEnd;)
        {
            var start = checked((int)offset);
            var length = BinaryPrimitives.ReadUInt32LittleEndian(wav[(start + 4)..]);
            if (offset + 8 + length > riffEnd) throw new InvalidDataException("Truncated WAV chunk.");
            var chunk = wav.Slice(start + 8, checked((int)length));
            var name = Encoding.ASCII.GetString(wav.Slice(start, 4));
            if (name == "fmt ") format = chunk;
            if (name == "data") data = chunk;
            offset += 8L + length + (length & 1);
        }
        if (format.Length < 16 || data.IsEmpty) throw new InvalidDataException("Expected format and non-empty audio data chunks.");
        var tag = BinaryPrimitives.ReadUInt16LittleEndian(format);
        var channels = BinaryPrimitives.ReadUInt16LittleEndian(format[2..]);
        var rate = BinaryPrimitives.ReadUInt32LittleEndian(format[4..]);
        var block = BinaryPrimitives.ReadUInt16LittleEndian(format[12..]);
        var bits = BinaryPrimitives.ReadUInt16LittleEndian(format[14..]);
        // Extensible WAV identifies PCM/IEEE float in its subformat GUID.
        if (tag == 0xfffe && format.Length >= 40)
        {
            var subformat = new Guid(format.Slice(24, 16));
            tag = subformat == new Guid("00000001-0000-0010-8000-00aa00389b71") ? (ushort)1
                : subformat == new Guid("00000003-0000-0010-8000-00aa00389b71") ? (ushort)3 : (ushort)0;
        }
        if (channels is < 1 or > 2 || rate is < 8000 or > 192000 ||
            !(tag == 1 && bits is 8 or 16 or 24 or 32 || tag == 3 && bits == 32) ||
            block != channels * (bits / 8) || data.Length % block != 0)
            throw new InvalidDataException($"Unsupported WAV format: tag={tag}, channels={channels}, rate={rate}, bits={bits}.");
        var sourceFrames = data.Length / block;
        var source = new float[sourceFrames * 2];
        for (var frame = 0; frame < sourceFrames; frame++)
        {
            for (var channel = 0; channel < 2; channel++)
            {
                var at = frame * block + Math.Min(channel, channels - 1) * (bits / 8);
                var sample = data[at..];
                var value = tag == 3 ? BitConverter.Int32BitsToSingle(BinaryPrimitives.ReadInt32LittleEndian(sample)) : bits switch
                {
                    8 => (sample[0] - 128) / 128f,
                    16 => BinaryPrimitives.ReadInt16LittleEndian(sample) / 32768f,
                    24 => ((sample[0] | sample[1] << 8 | sample[2] << 16) << 8 >> 8) / 8388608f,
                    32 => (float)(BinaryPrimitives.ReadInt32LittleEndian(sample) / 2147483648.0),
                    _ => throw new InvalidDataException("Unsupported PCM depth.")
                };
                if (!float.IsFinite(value)) throw new InvalidDataException("Recording contains non-finite PCM.");
                source[frame * 2 + channel] = Math.Clamp(value, -1, 1);
            }
        }
        var frames = checked((int)Math.Ceiling(sourceFrames * (double)SampleRate / rate));
        var output = new float[frames * 2];
        for (var frame = 0; frame < frames; frame++)
        {
            var position = frame * (double)rate / SampleRate;
            var first = Math.Min((int)position, sourceFrames - 1);
            var next = Math.Min(first + 1, sourceFrames - 1);
            var fraction = (float)(position - first);
            for (var channel = 0; channel < 2; channel++)
                output[frame * 2 + channel] = source[first * 2 + channel] * (1 - fraction) + source[next * 2 + channel] * fraction;
        }
        return new PcmRecording(output);
    }
}
