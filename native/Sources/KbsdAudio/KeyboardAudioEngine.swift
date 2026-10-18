// This file guarantees a common PCM format and verified rendering for all bundled key recordings.
@preconcurrency import AVFoundation
import KbsdCore

@MainActor
public final class KeyboardAudioEngine {
  private let engine = AVAudioEngine()
  private var voices: [(AVAudioPlayerNode, AVAudioUnitVarispeed, AVAudioMixerNode)] = []
  private var buffers: [String: AVAudioPCMBuffer] = [:]
  private var nextVoice = 0
  public private(set) var loadedCount = 0
  private let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!

  public init(root: URL, offline: Bool = false) throws {
    for set in SwitchSet.allCases {
      for code in KeySoundMapping.sampleCodes {
        for phase in [KeyPhase.down, .up] {
          let path = "\(set.rawValue)/\(code)-\(phase.rawValue).wav"
          buffers[path] = try Self.readNormalized(root.appendingPathComponent(path), format: format)
        }
      }
    }
    loadedCount = buffers.count
    for _ in 0..<24 {
      let player = AVAudioPlayerNode()
      let speed = AVAudioUnitVarispeed()
      let mixer = AVAudioMixerNode()
      engine.attach(player)
      engine.attach(speed)
      engine.attach(mixer)
      engine.connect(player, to: speed, format: format)
      engine.connect(speed, to: mixer, format: format)
      engine.connect(mixer, to: engine.mainMixerNode, format: format)
      voices.append((player, speed, mixer))
    }
    if offline {
      try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
    }
    engine.prepare()
  }

  private static func readNormalized(_ url: URL, format: AVAudioFormat) throws -> AVAudioPCMBuffer {
    let file = try AVAudioFile(forReading: url)
    guard
      let input = AVAudioPCMBuffer(
        pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
    else {
      throw AudioFailure.invalidBuffer(url.lastPathComponent)
    }
    try file.read(into: input)
    guard let converter = AVAudioConverter(from: input.format, to: format),
      let output = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: AVAudioFrameCount(
          ceil(Double(input.frameLength) * format.sampleRate / input.format.sampleRate)) + 64)
    else { throw AudioFailure.invalidBuffer(url.lastPathComponent) }
    var supplied = false
    var error: NSError?
    let status = converter.convert(to: output, error: &error) { _, state in
      // Each source is supplied once. A second request signals the end instead of replaying input.
      if supplied {
        state.pointee = .endOfStream
        return nil
      }
      supplied = true
      state.pointee = .haveData
      return input
    }
    guard status != .error, output.frameLength > 0 else {
      throw error ?? AudioFailure.invalidBuffer(url.lastPathComponent)
    }
    return output
  }

  public func start() throws {
    if !engine.isRunning { try engine.start() }
  }
  public func play(_ request: SoundRequest, settings: AppSettings) throws {
    guard let buffer = buffers[request.file] else { throw AudioFailure.missingSample(request.file) }
    try start()
    engine.mainMixerNode.outputVolume = Float(settings.volume)
    let (player, speed, mixer) = voices[nextVoice]
    nextVoice = (nextVoice + 1) % voices.count
    player.stop()
    let variation = settings.randomPitch ? Double.random(in: -0.3...0.3) : 0
    speed.rate = Float(pow(2, (settings.pitch + variation) / 12))
    mixer.pan = request.pan
    player.scheduleBuffer(buffer)
    player.play()
  }
  public func setVolume(_ volume: Double) { engine.mainMixerNode.outputVolume = Float(volume) }
  public func stop() {
    for (player, _, _) in voices { player.stop() }
    engine.pause()
  }
  public var isRunning: Bool { engine.isRunning }
  public var normalizedFormats: [AVAudioFormat] { buffers.values.map(\.format) }

  /// Exercises the actual player/effect/mixer graph without sending sound to the speakers.
  public func verifyAllRecordings() throws -> Int {
    guard engine.isInManualRenderingMode else { throw AudioFailure.offlineRequired }
    var settings = AppSettings()
    settings.randomPitch = false
    var verified = 0
    for path in buffers.keys.sorted() {
      stop()
      try play(SoundRequest(file: path, pan: 0), settings: settings)
      var energy: Float = 0
      let output = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096)!
      for _ in 0..<4 {
        let status = try engine.renderOffline(4096, to: output)
        guard status == .success, let channels = output.floatChannelData else {
          throw AudioFailure.renderFailed(path)
        }
        for channel in 0..<Int(output.format.channelCount) {
          for frame in 0..<Int(output.frameLength) {
            let sample = channels[channel][frame]
            guard sample.isFinite else { throw AudioFailure.renderFailed(path) }
            energy += abs(sample)
          }
        }
      }
      guard energy > 0 else { throw AudioFailure.renderFailed(path) }
      verified += 1
    }
    stop()
    return verified
  }

  public enum AudioFailure: LocalizedError {
    case invalidBuffer(String)
    case missingSample(String)
    case renderFailed(String)
    case offlineRequired
    public var errorDescription: String? {
      switch self {
      case .invalidBuffer(let path):
        "Could not convert the bundled sound to stereo 48kHz PCM: \(path)."
      case .missingSample(let path): "The requested keyboard recording is missing: \(path)."
      case .renderFailed(let path): "Keyboard sound failed to render non-silent PCM: \(path)."
      case .offlineRequired: "Audio verification requires an offline rendering engine."
      }
    }
  }
}
