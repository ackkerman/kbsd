/** This file guarantees local sound previews and a single cancellable playback selection. */
import {
  PreviewPlayer,
  createBrowserAudio,
  clampVolume,
} from "./audio-preview";
import "./interaction.css";

const sounds = [
  ["slate", "Japanese Black", "A crisp, grounded click.", "#929b9a"],
  ["violet", "Crystal Purple", "Bright and a little playful.", "#b6a1dd"],
  ["pebble", "Oreo", "A soft, rounded pop.", "#a8aca6"],
  ["paper", "Cardboard", "Dry, textured, satisfying.", "#e1ae8d"],
  ["honey", "Milky Yellow", "Warm and nicely balanced.", "#ddc16c"],
  ["ruby", "Super Red", "Low, rich, and full-bodied.", "#d88487"],
  ["cream", "Cream", "Gentle on the ears.", "#dcc5a2"],
] as const;
const player = new PreviewPlayer(createBrowserAudio());
const list = document.querySelector<HTMLDivElement>("#sound-list")!;
const status = document.querySelector<HTMLParagraphElement>("#preview-status")!;
let active: HTMLButtonElement | undefined;
let timer: ReturnType<typeof setTimeout> | undefined;
function stop(): void {
  player.stop();
  clearTimeout(timer);
  active?.setAttribute("aria-pressed", "false");
  active = undefined;
}
for (const [slug, name, description, color] of sounds) {
  const button = document.createElement("button");
  button.className = "sound-row";
  button.type = "button";
  button.setAttribute("aria-label", `Preview ${name}`);
  button.setAttribute("aria-pressed", "false");
  const swatch = document.createElement("span");
  swatch.className = "sound-swatch";
  swatch.style.setProperty("--swatch", color);
  const copy = document.createElement("span");
  copy.className = "sound-copy";
  const title = document.createElement("strong");
  title.textContent = name;
  const detail = document.createElement("span");
  detail.textContent = description;
  copy.append(title, detail);
  const mark = document.createElement("span");
  mark.className = "play-mark";
  mark.setAttribute("aria-hidden", "true");
  button.append(swatch, copy, mark);

  button.addEventListener("click", async () => {
    const same = active === button;
    stop();
    if (same) {
      status.textContent = "Preview stopped.";
      return;
    }
    active = button;
    button.setAttribute("aria-pressed", "true");
    status.textContent = `Loading ${name}…`;
    try {
      const started = await player.start(slug);
      if (!started || active !== button) return;
      status.textContent = `Playing ${name}.`;
      timer = setTimeout(() => {
        stop();
        status.textContent = `That was ${name}. Find your favorite.`;
      }, 4750);
    } catch {
      if (active === button) {
        stop();
        status.textContent = "Could not load this sound. Please try again.";
      }
    }
  });
  list.append(button);
}
const volume = document.querySelector<HTMLInputElement>("#volume")!;
volume.addEventListener("input", () => {
  player.volume = clampVolume(Number(volume.value));
  document.querySelector("#volume-value")!.textContent = `${player.volume}%`;
});
window.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    stop();
    status.textContent = "Preview stopped.";
  }
});
document.addEventListener("visibilitychange", () => {
  if (document.hidden) stop();
});
