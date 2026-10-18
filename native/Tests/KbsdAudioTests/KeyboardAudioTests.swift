// This file guarantees every real recording survives scheduling and rendering in the native audio graph.
import AVFoundation
import XCTest

@testable import KbsdAudio

final class KeyboardAudioTests: XCTestCase {
  func testAllMixedSourceFormatsNormalizeAndRenderNonSilentOutput() async throws {
    try await MainActor.run {
      let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("public/assets/sounds/preview")
      let audio = try KeyboardAudioEngine(root: root, offline: true)
      XCTAssertEqual(audio.loadedCount, 182)
      for format in audio.normalizedFormats {
        XCTAssertEqual(format.sampleRate, 48_000)
        XCTAssertEqual(format.channelCount, 2)
        XCTAssertEqual(format.commonFormat, .pcmFormatFloat32)
      }
      XCTAssertEqual(try audio.verifyAllRecordings(), 182)
    }
  }
}
