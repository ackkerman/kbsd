// This file guarantees stable identifiers and sample selection for all bundled switch sets.
import Foundation

/// A selectable recording set. Its raw value is the on-disk resource directory.
public enum SwitchSet: String, CaseIterable, Codable, Identifiable {
  case japaneseBlack = "slate"
  case crystalPurple = "violet"
  case oreo = "pebble"
  case cardboard = "paper"
  case milkyYellow = "honey"
  case superRed = "ruby"
  case cream

  public var id: String { rawValue }
  public var name: String {
    switch self {
    case .japaneseBlack: "Japanese Black"
    case .crystalPurple: "Crystal Purple"
    case .oreo: "Oreo"
    case .cardboard: "Cardboard"
    case .milkyYellow: "Milky Yellow"
    case .superRed: "Super Red"
    case .cream: "Cream"
    }
  }
  public var brand: String {
    switch self {
    case .japaneseBlack: "Linear"
    case .crystalPurple, .oreo: "Tactile"
    case .cardboard: "Textured"
    case .milkyYellow: "Balanced"
    case .superRed: "Deep"
    case .cream: "Soft"
    }
  }
  public var colorHex: UInt32 {
    switch self {
    case .japaneseBlack: 0x878078
    case .crystalPurple: 0xD68AF0
    case .oreo: 0x9C9690
    case .cardboard: 0xF3AC87
    case .milkyYellow: 0xF4E49C
    case .superRed: 0xEF627B
    case .cream: 0xF4CF9F
    }
  }
}

/// Key phases select independent press and release recordings without retaining typed text.
public enum KeyPhase: String, Codable { case down, up }
public enum InputCategory { case keyboard, modifier, mouse }

/// A physical input contains no characters, text, application names, or window contents.
public struct PhysicalInput {
  public let keyCode: UInt16
  public let phase: KeyPhase
  public let category: InputCategory
  public let isRepeat: Bool
  public init(
    keyCode: UInt16, phase: KeyPhase, category: InputCategory = .keyboard, isRepeat: Bool = false
  ) {
    self.keyCode = keyCode
    self.phase = phase
    self.category = category
    self.isRepeat = isRepeat
  }
}

/// A sound request identifies a local recording and a stereo position, never a text character.
public struct SoundRequest: Equatable {
  public let file: String
  public let pan: Float
  public init(file: String, pan: Float) {
    self.file = file
    self.pan = pan
  }
}

public enum KeySoundMapping {
  public static let sampleCodes = [37, 38, 30, 46, 57, 25, 19, 18, 47, 23, 17, 3675, 28]
  private static let exact: [UInt16: Int] = [
    40: 37, 37: 38, 0: 30, 8: 46, 49: 57, 35: 25, 15: 19, 14: 18, 9: 47, 34: 23, 13: 17, 55: 3675,
    54: 3675, 36: 28, 76: 28,
  ]
  private static let rows: [[UInt16]] = [
    [50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24, 51],
    [48, 12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30, 42],
    [57, 0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 36], [56, 6, 7, 8, 9, 11, 45, 46, 43, 47, 44, 60],
  ]

  public static func sampleCode(for code: UInt16) -> Int {
    // Unrecorded keys reuse letter samples from the same switch, preserving its timbre.
    exact[code] ?? sampleCodes[Int(code) % 11]
  }
  public static func stereoPosition(for code: UInt16) -> Float {
    for row in rows {
      if let index = row.firstIndex(of: code) {
        return Float(index) / Float(row.count - 1) * 1.2 - 0.6
      }
    }
    return 0
  }
  public static func request(for input: PhysicalInput, settings: AppSettings, locked: Bool)
    -> SoundRequest?
  {
    // Disabled and locked states never produce sound, including modifier and mouse events.
    guard settings.enabled, !locked, !input.isRepeat else { return nil }
    if input.category == .modifier && !settings.modifierSounds { return nil }
    if input.category == .mouse && !settings.mouseSounds { return nil }
    let code = input.category == .mouse ? 37 : sampleCode(for: input.keyCode)
    return SoundRequest(
      file: "\(settings.switchSet.rawValue)/\(code)-\(input.phase.rawValue).wav",
      pan: settings.spatialAudio ? stereoPosition(for: input.keyCode) : 0)
  }
}
