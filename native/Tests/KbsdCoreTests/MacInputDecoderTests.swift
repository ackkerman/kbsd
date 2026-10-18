// This file guarantees real AppKit mouse events cannot break normal click dispatch.
import AppKit
import XCTest

@testable import KbsdCore

final class MacInputDecoderTests: XCTestCase {
  func testMousePressAndReleaseNeverAccessKeyboardOnlyProperties() throws {
    // Given actual NSEvent mouse objects, when decoded, then no AppKit exception is raised.
    for (type, code, phase) in [
      (NSEvent.EventType.leftMouseDown, UInt16(0), KeyPhase.down),
      (.leftMouseUp, 0, .up), (.rightMouseDown, 1, .down), (.rightMouseUp, 1, .up),
    ] {
      var decoder = MacInputDecoder()
      let event = try XCTUnwrap(
        NSEvent.mouseEvent(
          with: type, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
          context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
      let input = try XCTUnwrap(decoder.decode(event))
      XCTAssertEqual(input.keyCode, code)
      XCTAssertEqual(input.phase, phase)
      XCTAssertTrue(input.category == .mouse)
      XCTAssertFalse(input.isRepeat)
    }
  }
  func testUnrelatedMouseEventsAreIgnored() throws {
    var decoder = MacInputDecoder()
    let event = try XCTUnwrap(
      NSEvent.mouseEvent(
        with: .mouseMoved, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
        context: nil, eventNumber: 1, clickCount: 0, pressure: 0))
    XCTAssertNil(decoder.decode(event))
  }
  func testReleasingOneShiftWhileOtherIsHeldProducesARelease() throws {
    var decoder = MacInputDecoder()
    func event(_ code: UInt16, flags: NSEvent.ModifierFlags) throws -> NSEvent {
      try XCTUnwrap(
        NSEvent.keyEvent(
          with: .flagsChanged, location: .zero, modifierFlags: flags, timestamp: 0,
          windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
          isARepeat: false, keyCode: code))
    }
    XCTAssertEqual(decoder.decode(try event(56, flags: .shift))?.phase, .down)
    XCTAssertEqual(decoder.decode(try event(60, flags: .shift))?.phase, .down)
    XCTAssertEqual(decoder.decode(try event(56, flags: .shift))?.phase, .up)
    XCTAssertEqual(decoder.decode(try event(60, flags: []))?.phase, .up)
  }
  func testKeyboardEventsKeepPhysicalCodeAndRepeatState() throws {
    var decoder = MacInputDecoder()
    let event = try XCTUnwrap(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
        windowNumber: 0, context: nil, characters: "a", charactersIgnoringModifiers: "a",
        isARepeat: true, keyCode: 0))
    let input = try XCTUnwrap(decoder.decode(event))
    XCTAssertEqual(input.keyCode, 0)
    XCTAssertEqual(input.phase, .down)
    XCTAssertTrue(input.isRepeat)
  }
}
