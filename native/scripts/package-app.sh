#!/bin/bash
# This file guarantees a Finder-launchable kbsd bundle with only first-party assets.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
app_path="${KBSD_APP_PATH:-$repo_root/dist/kbsd.app}"
bash "$repo_root/native/scripts/sign-app.sh" "$app_path" --preflight
icon_path="$repo_root/native/.build/kbsd.iconset"
swift build --package-path "$repo_root/native" -c release
binary_path="$(swift build --package-path "$repo_root/native" -c release --show-bin-path)"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$icon_path"
cp "$binary_path/kbsd" "$app_path/Contents/MacOS/kbsd"
cp "$repo_root/public/assets/images/app-icon.png" "$app_path/Contents/Resources/app-icon.png"
for icon_size in 16 32 128 256 512; do
  sips -z "$icon_size" "$icon_size" "$repo_root/public/assets/images/app-icon.png" --out "$icon_path/icon_${icon_size}x${icon_size}.png" >/dev/null
  double_size=$((icon_size * 2))
  sips -z "$double_size" "$double_size" "$repo_root/public/assets/images/app-icon.png" --out "$icon_path/icon_${icon_size}x${icon_size}@2x.png" >/dev/null
done
iconutil -c icns "$icon_path" -o "$app_path/Contents/Resources/AppIcon.icns"
mkdir -p "$app_path/Contents/Resources/Sounds"
cp -R "$repo_root/public/assets/sounds/preview/." "$app_path/Contents/Resources/Sounds/"
cp "$repo_root/native/Info.plist" "$app_path/Contents/Info.plist"
cp "$repo_root/ATTRIBUTION.md" "$app_path/Contents/Resources/ATTRIBUTION.md"
bash "$repo_root/native/scripts/sign-app.sh" "$app_path"
plutil -lint "$app_path/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$app_path"
"$app_path/Contents/MacOS/kbsd" --diagnose
printf 'Packaged: %s\n' "$app_path"
