#!/bin/bash
# This file guarantees a reproducible release layout and a checksum for the app archive.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
release_dir="$repo_root/dist/release"
mkdir -p "$release_dir"
bash "$repo_root/native/scripts/package-app.sh"
archive="kbsd-v1.0.0-macos-arm64.zip"
ditto -c -k --norsrc --noextattr --keepParent "$repo_root/dist/kbsd.app" "$release_dir/$archive"
(cd "$release_dir" && shasum -a 256 "$archive" > SHA256SUMS.txt)
printf 'Release archive: %s/%s\n' "$release_dir" "$archive"
