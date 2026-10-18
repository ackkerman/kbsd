import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";

test("every displayed image and stylesheet resolves locally and tracking is absent", () => {
  const html = readFileSync("index.html", "utf8");
  assert.ok(!html.includes("cloudflareinsights"));
  assert.ok(!html.includes("https://cdn."));
  for (const path of html.matchAll(/(?:src|srcset|href)="(\/assets\/[^"?]+)"/g))
    assert.ok(existsSync(`public${path[1]}`), path[1]);
});
test("all seven switch sets contain the complete preview recordings", () => {
  const root = "public/assets/sounds/preview";
  assert.equal(readdirSync(root).length, 7);
  for (const slug of readdirSync(root)) {
    const files = readdirSync(`${root}/${slug}`);
    assert.equal(files.length, 26);
    for (const file of files)
      assert.equal(
        readFileSync(`${root}/${slug}/${file}`).toString("ascii", 0, 4),
        "RIFF",
      );
  }
});
