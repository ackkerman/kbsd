import { test } from "node:test";
import assert from "node:assert/strict";
import { PreviewPlayer, clampVolume } from "../src/audio-preview.ts";

function audioStub(load = async () => ({})) {
  const calls = [];
  return {
    calls,
    resume: async () => {},
    load,
    play: (...args) => calls.push(args),
    stop: () => {},
  };
}
test("a loaded preview schedules all down and up strokes at the selected volume", async () => {
  const audio = audioStub();
  const player = new PreviewPlayer(audio);
  player.volume = 25;
  assert.equal(await player.start("cream"), true);
  assert.equal(audio.calls.length, 30);
  assert.ok(audio.calls.every((call) => call[2] === 0.25));
});
test("a cancelled preview never starts after pending sound loads finish", async () => {
  let release;
  const waiting = new Promise((resolve) => {
    release = resolve;
  });
  const audio = audioStub(async () => {
    await waiting;
    return {};
  });
  const player = new PreviewPlayer(audio);
  const result = player.start("cream");
  await Promise.resolve();
  player.stop();
  release();
  assert.equal(await result, false);
  assert.equal(audio.calls.length, 0);
});
test("unavailable audio rejects so the UI can reset and report failure", async () => {
  const player = new PreviewPlayer(
    audioStub(async () => {
      throw new Error("missing");
    }),
  );
  await assert.rejects(player.start("cream"), /missing/);
});
test("volume stays within the supported range", () => {
  assert.equal(clampVolume(-10), 0);
  assert.equal(clampVolume(120), 100);
  assert.equal(clampVolume(NaN), 70);
});
