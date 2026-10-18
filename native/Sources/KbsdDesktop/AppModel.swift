// This file guarantees persistent sound settings, permission-aware monitoring, and count-only statistics.
import AppKit
import ApplicationServices
import Combine
import KbsdAudio
import KbsdCore
import ServiceManagement
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
  @Published var settings: AppSettings {
    didSet {
      store.save(settings)
      audio?.setVolume(settings.volume)
      if !settings.enabled {
        cancelPreview()
        audio?.stop()
      }
    }
  }
  @Published private(set) var statistics: UsageStatistics
  @Published private(set) var accessibilityGranted = false
  @Published private(set) var loginStatus = SMAppService.mainApp.status
  @Published private(set) var previewing: SwitchSet?
  @Published private(set) var locked = false
  @Published var errorMessage: String?
  @Published var selectedPage: SettingsPage = .switches

  private let store = PreferenceStore()
  private let monitor = KeyboardMonitor()
  private var audio: KeyboardAudioEngine?
  private var previewTask: Task<Void, Never>?
  private var saveTask: Task<Void, Never>?
  private var settingsWindow: NSWindow?
  private var observers: [NSObjectProtocol] = []
  private var workspaceObservers: [NSObjectProtocol] = []
  private var distributedObservers: [NSObjectProtocol] = []

  init() {
    settings = store.loadSettings()
    statistics = store.loadStatistics()
    statistics.refreshDay()
  }
  func start() {
    do {
      let root = Bundle.main.resourceURL!.appendingPathComponent("Sounds")
      audio = try KeyboardAudioEngine(root: root)
      if settings.enabled { try audio?.start() }
    } catch { errorMessage = error.localizedDescription }
    refreshPermission()
    monitor.start { [weak self] input in self?.handle(input) }
    workspaceObservers.append(
      NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in self?.refreshPermission() }
      })
    let center = DistributedNotificationCenter.default()
    for (name, value) in [
      ("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false),
    ] {
      distributedObservers.append(
        center.addObserver(forName: NSNotification.Name(name), object: nil, queue: .main) {
          [weak self] _ in
          Task { @MainActor [weak self] in
            self?.locked = value
            if value {
              self?.cancelPreview()
              self?.audio?.stop()
            }
          }
        })
    }
    observers.append(
      NotificationCenter.default.addObserver(
        forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in self?.refreshPermission() }
      })
  }
  func shutdown() {
    monitor.stop()
    cancelPreview()
    audio?.stop()
    saveTask?.cancel()
    store.save(statistics)
    for observer in workspaceObservers {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    for observer in distributedObservers {
      DistributedNotificationCenter.default().removeObserver(observer)
    }
  }
  func refreshPermission() {
    let trusted = monitor.isTrusted
    if trusted != accessibilityGranted {
      accessibilityGranted = trusted
      monitor.start { [weak self] input in self?.handle(input) }
    }
    statistics.refreshDay()
    loginStatus = SMAppService.mainApp.status
  }
  func openPermissionSettings() {
    // Only this explicit user action opens the OS permission controls; the app never grants itself access.
    let options =
      [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    NSWorkspace.shared.open(
      URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
  }
  func handle(_ input: PhysicalInput) {
    guard let request = KeySoundMapping.request(for: input, settings: settings, locked: locked)
    else { return }
    do {
      try audio?.play(request, settings: settings)
      if input.category == .keyboard, input.phase == .down {
        statistics.record()
        // Store counts in a batch, rather than writing preferences on every keystroke.
        if saveTask == nil {
          saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            self.store.save(self.statistics)
            self.saveTask = nil
          }
        }
      }
    } catch { errorMessage = error.localizedDescription }
  }
  func preview(_ set: SwitchSet) {
    let wasPlaying = previewing == set
    cancelPreview()
    if wasPlaying { return }
    previewing = set
    previewTask = Task { [weak self] in
      guard let self else { return }
      var preferences = self.settings
      preferences.enabled = true
      preferences.switchSet = set
      let codes: [UInt16] = [40, 37, 0, 8, 40, 49, 35, 15, 14, 9, 34, 14, 13, 36]
      do {
        for code in codes {
          try Task.checkCancellation()
          guard !self.locked else { break }
          let input = PhysicalInput(keyCode: code, phase: .down)
          if let request = KeySoundMapping.request(for: input, settings: preferences, locked: false)
          {
            try self.audio?.play(request, settings: preferences)
          }
          try await Task.sleep(for: .milliseconds(95))
          try Task.checkCancellation()
          let release = PhysicalInput(keyCode: code, phase: .up)
          if let request = KeySoundMapping.request(
            for: release, settings: preferences, locked: false)
          {
            try self.audio?.play(request, settings: preferences)
          }
          try await Task.sleep(for: .milliseconds(130))
        }
        self.previewing = nil
      } catch is CancellationError {
        // A replacement preview owns the indicator after cancellation.
      } catch {
        self.errorMessage = error.localizedDescription
        self.previewing = nil
      }
    }
  }
  func cancelPreview() {
    previewTask?.cancel()
    previewTask = nil
    previewing = nil
  }
  func setLaunchAtLogin(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch { errorMessage = "Could not update login item: \(error.localizedDescription)" }
    loginStatus = SMAppService.mainApp.status
  }
  func showSettings(page: SettingsPage? = nil) {
    if let page { selectedPage = page }
    refreshPermission()
    if settingsWindow == nil {
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 790, height: 610),
        styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
        defer: false)
      window.title = "kbsd — Settings"
      window.minSize = NSSize(width: 740, height: 560)
      window.isReleasedWhenClosed = false
      window.titlebarAppearsTransparent = true
      window.contentView = NSHostingView(rootView: SettingsView(model: self))
      window.center()
      settingsWindow = window
    }
    settingsWindow?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}

/// Settings destinations stay stable while the same window remains open.
enum SettingsPage: String, CaseIterable, Identifiable {
  case switches = "Switches"
  case sound = "Sound"
  case general = "General"
  case statistics = "Statistics"
  var id: String { rawValue }
  var icon: String {
    switch self {
    case .switches: "keyboard"
    case .sound: "waveform"
    case .general: "gearshape"
    case .statistics: "chart.bar"
    }
  }
  var subtitle: String {
    switch self {
    case .switches: "Find your favorite feeling."
    case .sound: "Make every keystroke your own."
    case .general: "Quietly at home in your menu bar."
    case .statistics: "A little appreciation for all that typing."
    }
  }
}
