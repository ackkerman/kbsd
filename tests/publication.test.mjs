import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

test("the landing page and repository link to each other and the release download", () => {
  const html = readFileSync("index.html", "utf8");
  const readme = readFileSync("README.md", "utf8");
  assert.ok(html.includes("https://github.com/ackkerman/kbsd"));
  assert.ok(html.includes('rel="canonical" href="https://kbsd.0xdope.com/"'));
  assert.ok(
    html.includes("/releases/latest/download/kbsd-v1.0.0-macos-arm64.zip"),
  );
  assert.ok(
    html.includes("/releases/latest/download/kbsd-v1.0.0-windows-x64.zip"),
  );
  assert.ok(
    html.includes(
      "/releases/latest/download/kbsd-v1.0.0-windows-x64-setup.exe",
    ),
  );
  assert.ok(
    readme.includes(
      "/releases/download/v1.0.0/kbsd-v1.0.0-windows-x64-setup.exe",
    ),
  );
  assert.ok(
    readme.includes("/releases/download/v1.0.0/kbsd-v1.0.0-windows-x64.zip"),
  );
  assert.ok(!html.includes("A Windows download has not been published yet"));
  assert.ok(readme.includes("https://kbsd.0xdope.com"));
  assert.ok(!html.includes("buy.stripe.com"));
  assert.ok(!html.includes("original keyboard sounds"));
});
test("the app bundle has the final public identity and version", () => {
  const plist = readFileSync("native/Info.plist", "utf8");
  assert.match(plist, /<key>CFBundleDisplayName<\/key><string>kbsd<\/string>/);
  assert.match(
    plist,
    /<key>CFBundleIdentifier<\/key><string>com.ackkerman.kbsd<\/string>/,
  );
  assert.match(
    plist,
    /<key>CFBundleShortVersionString<\/key><string>1.0.0<\/string>/,
  );
});
