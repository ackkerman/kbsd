// This file guarantees read-only physical-key observation without accessing typed characters.
import AppKit
import ApplicationServices
import KbsdCore

@MainActor
final class KeyboardMonitor {
  private var global: Any?
  private var local: Any?
  private var decoder = MacInputDecoder()
  private var handler: ((PhysicalInput) -> Void)?
  private let mask: NSEvent.EventTypeMask = [
    .keyDown, .keyUp, .flagsChanged, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
  ]

  var isTrusted: Bool { AXIsProcessTrusted() }
  func start(handler: @escaping (PhysicalInput) -> Void) {
    stop()
    self.handler = handler
    // Global and local monitors cover disjoint event streams, avoiding duplicate playback.
    global = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
      self?.receive(event)
    }
    local = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
      self?.receive(event)
      return event
    }
  }
  func stop() {
    if let global { NSEvent.removeMonitor(global) }
    if let local { NSEvent.removeMonitor(local) }
    global = nil
    local = nil
    decoder = MacInputDecoder()
  }
  private func receive(_ event: NSEvent) {
    if let input = decoder.decode(event) { handler?(input) }
  }
}
