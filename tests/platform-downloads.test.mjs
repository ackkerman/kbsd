import { test } from "node:test";
import assert from "node:assert/strict";
import { desktopPlatform } from "../src/platform-downloads.ts";

test("Windows client hints take priority over legacy browser values", () => {
  assert.equal(
    desktopPlatform({
      userAgentData: { platform: "Windows" },
      platform: "MacIntel",
    }),
    "windows",
  );
  assert.equal(desktopPlatform({ platform: "Win32" }), "windows");
  assert.equal(
    desktopPlatform({ userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }),
    "windows",
  );
});

test("Mac browsers work with client hints, legacy platform and user-agent fallback", () => {
  assert.equal(
    desktopPlatform({ userAgentData: { platform: "macOS" } }),
    "mac",
  );
  assert.equal(
    desktopPlatform({ platform: "MacIntel", maxTouchPoints: 0 }),
    "mac",
  );
  assert.equal(
    desktopPlatform({
      userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
    }),
    "mac",
  );
});

test("mobile clients, including iPads in desktop mode, keep a neutral desktop download chooser", () => {
  for (const hints of [
    { platform: "MacIntel", maxTouchPoints: 5 },
    { platform: "iPhone" },
    {
      userAgentData: { platform: "Android" },
      userAgent: "Mozilla/5.0 (Linux; Android 14)",
    },
    { userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)" },
  ]) {
    assert.equal(desktopPlatform(hints), null);
  }
});

test("unsupported, absent and unrecognized hints do not guess a desktop installer", () => {
  assert.equal(desktopPlatform({}), null);
  assert.equal(desktopPlatform({ platform: "Linux x86_64" }), null);
  assert.equal(
    desktopPlatform({
      userAgentData: { platform: "Linux" },
      platform: "Win32",
    }),
    null,
  );
});
