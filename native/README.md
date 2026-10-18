# kbsd native app

SwiftUI/AppKit/AVFoundation menu-bar app for Apple Silicon and macOS 14+.

Run `make native-run` from the repository root. The app is produced at `dist/kbsd.app`; release archives are produced by `make release`.

Source modules:

- `KbsdCore`: validated preferences, aggregate statistics, physical-input decoding, and sample mapping.
- `KbsdAudio`: common-format conversion, overlapping playback, and offline rendering diagnostics.
- `KbsdDesktop`: menu bar, settings, permission-aware input monitoring, and login-item integration.

Keyboard access must be granted by the user in macOS System Settings. It is never granted programmatically. Rebuilding an ad-hoc signed app may require removing its old permission entry and adding the current app again.

Bundled recordings are distributed with permission; see ATTRIBUTION.md. The native process does not read typed characters, store a keystroke history, or make network requests.

Developer ID signing, notarization, Intel packaging, and automatic updates are not included in v1.0.0.
