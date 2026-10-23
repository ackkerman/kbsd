/** This file guarantees OS-specific download links with accessible alternatives and a neutral fallback. */

/** Low-entropy browser hints select downloads locally without storing or transmitting device information. */
export interface PlatformHints {
  userAgentData?: { platform?: string };
  platform?: string;
  userAgent?: string;
  maxTouchPoints?: number; // iPad desktop mode reports a Mac platform despite being a touch device.
}

/** Returns null for mobile, unsupported or unknown systems, which retain the neutral download chooser. */
export function desktopPlatform(
  hints: PlatformHints,
): "mac" | "windows" | null {
  const platform =
    hints.userAgentData?.platform || hints.platform || hints.userAgent || "";
  // iPads can identify as Macs; mobile visitors must still choose a desktop download explicitly.
  if (
    /Android|iPhone|iPad|iPod/i.test(hints.userAgent || platform) ||
    (/Mac/i.test(platform) && (hints.maxTouchPoints || 0) > 1)
  ) {
    return null;
  }
  if (/Windows|Win32|Win64/i.test(platform)) return "windows";
  if (/Mac/i.test(platform)) return "mac";
  return null;
}

/** Known desktops share one download across the page; all other clients keep the server-rendered chooser. */
export function configureDownloads(root: Document, hints: PlatformHints): void {
  const platform = desktopPlatform(hints);
  if (!platform) return;
  const selected = root.querySelector<HTMLAnchorElement>(
    `[data-download-platform="${platform}"]`,
  );
  // Missing markup must leave the usable static links intact rather than guessing a download.
  if (!selected) return;
  for (const link of root.querySelectorAll<HTMLAnchorElement>(
    "[data-primary-download]",
  )) {
    link.href = selected.href;
  }
  root.querySelector("#download-label")!.textContent = selected
    .querySelector("[data-download-title]")!
    .textContent!.trim();
  root.querySelector("#download-requirements")!.textContent =
    `v1.0.0 · ${selected.querySelector("[data-download-requirements]")!.textContent!.trim()}`;
  root.querySelector("#download-alternatives-label")!.textContent =
    "Other downloads";
  for (const option of root.querySelectorAll<HTMLElement>(
    "[data-download-option]",
  )) {
    option.hidden = option.dataset.downloadOption === platform;
  }
}
