/** This file guarantees a single cancellable preview with locally stored key sounds. */
export const sequence = [
  37,
  38,
  30,
  46,
  37,
  null,
  57,
  25,
  19,
  18,
  47,
  23,
  18,
  17,
  null,
  3675,
  28,
] as const;

/** A playback adapter lets cancellation and failures be verified without audio hardware. */
export interface PreviewAudio {
  resume(): Promise<void>;
  load(path: string): Promise<AudioBuffer>;
  play(buffer: AudioBuffer, delay: number, volume: number): void;
  stop(): void;
}

export function clampVolume(value: number): number {
  return Number.isFinite(value) ? Math.max(0, Math.min(100, value)) : 70;
}

/** Cancels pending loads as well as playing sounds when another preview is selected. */
export class PreviewPlayer {
  private generation = 0;
  private audio: PreviewAudio;
  volume = 70;
  constructor(audio: PreviewAudio) {
    this.audio = audio;
  }
  stop(): void {
    this.generation++;
    this.audio.stop();
  }
  async start(slug: string): Promise<boolean> {
    this.stop();
    const generation = this.generation;
    await this.audio.resume();
    const keys = [...new Set(sequence.filter((key) => key !== null))];
    const buffers = await Promise.all(
      keys.flatMap((key) =>
        ["down", "up"].map(async (phase) => ({
          key: `${key}-${phase}`,
          buffer: await this.audio.load(
            `/assets/sounds/preview/${slug}/${key}-${phase}.wav`,
          ),
        })),
      ),
    );
    // A replaced request must never begin playing when its asynchronous load finishes.
    if (generation !== this.generation) return false;
    const byKey = new Map(buffers.map((item) => [item.key, item.buffer]));
    let delay = 0;
    for (const key of sequence) {
      if (key === null) {
        delay += 0.5;
        continue;
      }
      this.audio.play(byKey.get(`${key}-down`)!, delay, this.volume / 100);
      this.audio.play(
        byKey.get(`${key}-up`)!,
        delay + 0.125,
        this.volume / 100,
      );
      delay += 0.25;
    }
    return true;
  }
}

export function createBrowserAudio(): PreviewAudio {
  let context: AudioContext | undefined;
  const sources = new Set<AudioBufferSourceNode>();
  const buffers = new Map<string, AudioBuffer>();
  return {
    async resume() {
      context ??= new AudioContext();
      await context.resume();
    },
    async load(path) {
      const cached = buffers.get(path);
      if (cached) return cached;
      const response = await fetch(path);
      if (!response.ok)
        throw new Error(
          `Preview sound unavailable: ${path}, status=${response.status}`,
        );
      const buffer = await context!.decodeAudioData(
        await response.arrayBuffer(),
      );
      buffers.set(path, buffer);
      return buffer;
    },
    play(buffer, delay, volume) {
      const source = context!.createBufferSource();
      const gain = context!.createGain();
      source.buffer = buffer;
      gain.gain.value = volume;
      source.connect(gain);
      gain.connect(context!.destination);
      source.onended = () => {
        sources.delete(source);
        gain.disconnect();
      };
      sources.add(source);
      source.start(context!.currentTime + delay + 0.01);
    },
    stop() {
      for (const source of sources) {
        source.stop();
        source.disconnect();
      }
      sources.clear();
    },
  };
}
