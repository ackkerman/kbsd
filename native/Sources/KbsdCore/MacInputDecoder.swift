// This file guarantees that only event-compatible NSEvent properties are accessed.
import AppKit

/// Converts AppKit events without reading text. Mouse events never expose keyboard-only properties.
public struct MacInputDecoder {
  private var pressedModifiers: Set<UInt16> = []
  public init() {}

  public mutating func decode(_ event: NSEvent) -> PhysicalInput? {
    switch event.type {
    case .keyDown, .keyUp:
      return PhysicalInput(
        keyCode: event.keyCode, phase: event.type == .keyDown ? .down : .up,
        isRepeat: event.isARepeat)
    case .flagsChanged:
      let code = event.keyCode
      let flag: NSEvent.ModifierFlags
      switch code {
      case 54, 55: flag = .command
      case 56, 60: flag = .shift
      case 58, 61: flag = .option
      case 59, 62: flag = .control
      case 57: flag = .capsLock
      case 63: flag = .function
      default: return nil
      }
      let phase: KeyPhase
      if flag == .capsLock {
        // Caps Lock reports its latched state rather than ordinary physical press/release.
        phase = event.modifierFlags.contains(flag) ? .down : .up
      } else if pressedModifiers.remove(code) != nil {
        // Releasing one Shift/Command key can leave the shared modifier flag active.
        phase = .up
      } else if event.modifierFlags.contains(flag) {
        pressedModifiers.insert(code)
        phase = .down
      } else {
        phase = .up
      }
      return PhysicalInput(keyCode: code, phase: phase, category: .modifier)
    case .leftMouseDown, .leftMouseUp:
      // keyCode and isARepeat raise AppKit exceptions for mouse events, blocking their delivery.
      return PhysicalInput(
        keyCode: 0, phase: event.type == .leftMouseDown ? .down : .up, category: .mouse)
    case .rightMouseDown, .rightMouseUp:
      return PhysicalInput(
        keyCode: 1, phase: event.type == .rightMouseDown ? .down : .up, category: .mouse)
    default:
      return nil
    }
  }
}
