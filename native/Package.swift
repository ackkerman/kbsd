// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "KbsdDesktop",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "kbsd", targets: ["KbsdDesktop"])],
  targets: [
    .target(name: "KbsdCore"),
    .target(name: "KbsdAudio", dependencies: ["KbsdCore"]),
    .executableTarget(name: "KbsdDesktop", dependencies: ["KbsdCore", "KbsdAudio"]),
    .testTarget(name: "KbsdCoreTests", dependencies: ["KbsdCore"]),
    .testTarget(name: "KbsdAudioTests", dependencies: ["KbsdCore", "KbsdAudio"]),
  ],
  swiftLanguageModes: [.v5]
)
