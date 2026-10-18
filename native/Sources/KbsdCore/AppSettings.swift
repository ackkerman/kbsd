// This file guarantees validated preferences and aggregate-only usage statistics.
import Foundation

/// User preferences contain only sound configuration. Permission and login status come from macOS.
public struct AppSettings: Codable, Equatable {
  public var enabled = true
  public var switchSet: SwitchSet = .japaneseBlack
  public var volume: Double = 0.7
  public var pitch: Double = 0
  public var randomPitch = true
  public var spatialAudio = true
  public var modifierSounds = true
  public var mouseSounds = false
  public init() {}
  public mutating func validate() {
    volume = volume.isFinite ? min(1, max(0, volume)) : 0.7
    pitch = pitch.isFinite ? min(6, max(-6, pitch)) : 0
  }
}

/// Persisted counts intentionally exclude key identities and input histories.
public struct UsageStatistics: Codable, Equatable {
  public private(set) var total = 0
  public private(set) var today = 0
  public private(set) var day = ""
  public init() {}
  public mutating func record(on date: Date = Date(), calendar: Calendar = .current) {
    refreshDay(on: date, calendar: calendar)
    total += 1
    today += 1
  }
  public mutating func refreshDay(on date: Date = Date(), calendar: Calendar = .current) {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    let key = "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    if key != day {
      day = key
      today = 0
    }
  }
}

/// Stores configuration and counts under a dedicated namespace, without any event log.
public struct PreferenceStore {
  private let defaults: UserDefaults
  public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
  public func loadSettings() -> AppSettings {
    guard let data = defaults.data(forKey: "sound-settings"),
      var settings = try? JSONDecoder().decode(AppSettings.self, from: data)
    else { return AppSettings() }
    settings.validate()
    return settings
  }
  public func save(_ settings: AppSettings) {
    var value = settings
    value.validate()
    defaults.set(try? JSONEncoder().encode(value), forKey: "sound-settings")
  }
  public func loadStatistics() -> UsageStatistics {
    guard let data = defaults.data(forKey: "usage-counts"),
      let value = try? JSONDecoder().decode(UsageStatistics.self, from: data)
    else { return UsageStatistics() }
    return value
  }
  public func save(_ statistics: UsageStatistics) {
    defaults.set(try? JSONEncoder().encode(statistics), forKey: "usage-counts")
  }
}
