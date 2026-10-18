import AppKit
import KbsdAudio
// This file guarantees a menu-bar-only app and an explicit bundled-audio diagnostic mode.
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = AppModel()
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    model.start()
    model.showSettings()
  }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    model.showSettings()
    return true
  }
  func applicationWillTerminate(_ notification: Notification) { model.shutdown() }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct KbsdDesktopApp: App {
  init() {
    if CommandLine.arguments.contains("--diagnose") {
      do {
        let root = Bundle.main.resourceURL!.appendingPathComponent("Sounds")
        let audio = try KeyboardAudioEngine(root: root, offline: true)
        let rendered = try audio.verifyAllRecordings()
        print(
          "{\"decodedSounds\":\(audio.loadedCount),\"renderedSounds\":\(rendered),\"status\":\"passed\"}"
        )
        exit(0)
      } catch {
        fputs("Audio diagnostic failed: \(error.localizedDescription)\n", stderr)
        exit(1)
      }
    }
  }

  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  var body: some Scene {
    MenuBarExtra {
      MenuPanel(model: delegate.model)
    } label: {
      Image(systemName: "k.square.fill").accessibilityLabel("kbsd")
    }.menuBarExtraStyle(.window)
  }
}
