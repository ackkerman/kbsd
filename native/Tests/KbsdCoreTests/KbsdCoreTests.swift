// This file guarantees executable contracts for input suppression, sample selection, and local persistence.
import XCTest

@testable import KbsdCore

final class KbsdCoreTests: XCTestCase {
  func testAllSwitchesHaveStableResourceIdentifiers() {
    XCTAssertEqual(SwitchSet.allCases.count, 7)
    XCTAssertEqual(Set(SwitchSet.allCases.map(\.rawValue)).count, 7)
  }
  func testPressAndReleaseSelectDifferentRecordingsForEverySwitch() {
    // Given each switch, when the same physical key changes phase, then recordings differ.
    for set in SwitchSet.allCases {
      var settings = AppSettings()
      settings.switchSet = set
      let down = KeySoundMapping.request(
        for: PhysicalInput(keyCode: 40, phase: .down), settings: settings, locked: false)
      let up = KeySoundMapping.request(
        for: PhysicalInput(keyCode: 40, phase: .up), settings: settings, locked: false)
      XCTAssertEqual(down?.file, "\(set.rawValue)/37-down.wav")
      XCTAssertEqual(up?.file, "\(set.rawValue)/37-up.wav")
    }
  }
  func testDisabledLockedAndRepeatedInputsNeverProduceSound() {
    let input = PhysicalInput(keyCode: 40, phase: .down)
    var settings = AppSettings()
    settings.enabled = false
    XCTAssertNil(KeySoundMapping.request(for: input, settings: settings, locked: false))
    settings.enabled = true
    XCTAssertNil(KeySoundMapping.request(for: input, settings: settings, locked: true))
    XCTAssertNil(
      KeySoundMapping.request(
        for: PhysicalInput(keyCode: 40, phase: .down, isRepeat: true), settings: settings,
        locked: false))
  }
  func testMouseAndModifierInputsRespectIndividualPreferences() {
    var settings = AppSettings()
    settings.modifierSounds = false
    let modifier = PhysicalInput(keyCode: 55, phase: .down, category: .modifier)
    let mouse = PhysicalInput(keyCode: 0, phase: .down, category: .mouse)
    XCTAssertNil(KeySoundMapping.request(for: modifier, settings: settings, locked: false))
    XCTAssertNil(KeySoundMapping.request(for: mouse, settings: settings, locked: false))
    settings.mouseSounds = true
    settings.modifierSounds = true
    XCTAssertNotNil(KeySoundMapping.request(for: mouse, settings: settings, locked: false))
    XCTAssertEqual(
      KeySoundMapping.request(for: modifier, settings: settings, locked: false)?.file,
      "slate/3675-down.wav")
  }
  func testEveryMacKeyCodeResolvesToABundledSample() {
    for key in UInt16(0)...UInt16(127) {
      XCTAssertTrue(KeySoundMapping.sampleCodes.contains(KeySoundMapping.sampleCode(for: key)))
    }
  }
  func testStereoPositionsFollowPhysicalKeyboardAndCanBeDisabled() {
    var settings = AppSettings()
    let left = PhysicalInput(keyCode: 0, phase: .down)
    let right = PhysicalInput(keyCode: 36, phase: .down)
    XCTAssertLessThan(KeySoundMapping.request(for: left, settings: settings, locked: false)!.pan, 0)
    XCTAssertGreaterThan(
      KeySoundMapping.request(for: right, settings: settings, locked: false)!.pan, 0)
    settings.spatialAudio = false
    XCTAssertEqual(KeySoundMapping.request(for: left, settings: settings, locked: false)?.pan, 0)
  }
  func testInvalidPreferenceValuesAreClamped() {
    var settings = AppSettings()
    settings.volume = 2
    settings.pitch = -40
    settings.validate()
    XCTAssertEqual(settings.volume, 1)
    XCTAssertEqual(settings.pitch, -6)
    settings.volume = .nan
    settings.pitch = .infinity
    settings.validate()
    XCTAssertEqual(settings.volume, 0.7)
    XCTAssertEqual(settings.pitch, 0)
  }
  func testSettingsAndCountsSurviveReloadWithoutSavingInputEvents() throws {
    let name = "kbsdTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let store = PreferenceStore(defaults: defaults)
    var settings = AppSettings()
    settings.switchSet = .cream
    settings.volume = 0.25
    settings.enabled = false
    store.save(settings)
    XCTAssertEqual(PreferenceStore(defaults: defaults).loadSettings(), settings)
    var statistics = UsageStatistics()
    statistics.record()
    statistics.record()
    store.save(statistics)
    XCTAssertEqual(store.loadStatistics().total, 2)
    let saved = try XCTUnwrap(defaults.data(forKey: "usage-counts"))
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
    XCTAssertEqual(Set(object.keys), ["total", "today", "day"])
  }
  func testDailyStatisticsRollOverWithoutResettingLifetimeCount() {
    var statistics = UsageStatistics()
    let day = Date(timeIntervalSince1970: 1_700_000_000)
    statistics.record(on: day)
    statistics.record(on: day)
    statistics.record(on: day.addingTimeInterval(86_400))
    XCTAssertEqual(statistics.today, 1)
    XCTAssertEqual(statistics.total, 3)
  }
  func testCorruptPreferencesRecoverToDefaults() {
    let name = "kbsdTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(Data("broken".utf8), forKey: "sound-settings")
    XCTAssertEqual(PreferenceStore(defaults: defaults).loadSettings(), AppSettings())
  }
}
