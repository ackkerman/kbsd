import KbsdCore
// This file guarantees a compact native menu with sound controls and an accessible preview for each switch.
import SwiftUI

struct SwitchChip: View {
  let set: SwitchSet
  var size: CGFloat = 22
  var body: some View {
    Image(systemName: "plus")
      .font(.system(size: size * 0.5, weight: .medium))
      .foregroundStyle(.black.opacity(0.5))
      .frame(width: size, height: size)
      .background(
        LinearGradient(
          colors: [set.color, set.color.opacity(0.65)], startPoint: .top, endPoint: .bottom),
        in: RoundedRectangle(cornerRadius: size * 0.27)
      )
      .overlay(
        RoundedRectangle(cornerRadius: size * 0.27).strokeBorder(.white.opacity(0.25), lineWidth: 1)
      )
  }
}
extension SwitchSet {
  var color: Color {
    Color(
      red: Double((colorHex >> 16) & 255) / 255, green: Double((colorHex >> 8) & 255) / 255,
      blue: Double(colorHex & 255) / 255)
  }
}

struct MenuPanel: View {
  @ObservedObject var model: AppModel
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 10) {
        AppIcon(size: 28)
        Text("kbsd").font(.headline)
        Spacer()
        Toggle("Enable kbsd", isOn: $model.settings.enabled).labelsHidden().toggleStyle(.switch)
          .controlSize(.small)
      }.padding(.bottom, 14)
      if !model.accessibilityGranted {
        Button {
          model.showSettings(page: .general)
        } label: {
          Label("Enable keyboard access", systemImage: "hand.raised.fill")
            .font(.system(size: 12, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(9)
        }.buttonStyle(.plain).background(
          .orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8)
        ).padding(.bottom, 12)
      }
      Text("Sound").font(.caption).foregroundStyle(.secondary)
      HStack {
        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
        Slider(value: $model.settings.volume, in: 0...1).accessibilityLabel("Sound volume")
        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
      }.padding(.top, 3).padding(.bottom, 12)
      Divider().padding(.bottom, 10)
      Text("Switches").font(.caption).foregroundStyle(.secondary).padding(.bottom, 5)
      ForEach(SwitchSet.allCases) { set in
        HStack(spacing: 9) {
          Button {
            model.settings.switchSet = set
          } label: {
            HStack(spacing: 9) {
              SwitchChip(set: set, size: 19)
              Text(set.name).font(.system(size: 13))
              Spacer()
              if model.settings.switchSet == set {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
              }
            }.contentShape(Rectangle())
          }.buttonStyle(.plain).accessibilityLabel("Select \(set.name)")
          Button {
            model.preview(set)
          } label: {
            Image(systemName: model.previewing == set ? "stop.circle.fill" : "play.circle.fill")
              .font(.system(size: 19)).foregroundStyle(.secondary)
          }.buttonStyle(.plain).accessibilityLabel(
            "Preview \(set.name)")
        }.padding(.vertical, 6)
      }
      Divider().padding(.vertical, 10)
      HStack {
        Text(
          model.locked
            ? "Sleeping · Screen locked"
            : !model.accessibilityGranted
              ? "Preview only · Keyboard access needed"
              : model.settings.enabled ? "Ready to type" : "Sound paused")
        Spacer()
        Text("1.0.0")
      }.font(.caption).foregroundStyle(.secondary).padding(.bottom, 9)
      Button("kbsd Settings…") { model.showSettings() }.buttonStyle(MenuActionStyle())
      Button("Quit kbsd") { NSApp.terminate(nil) }.buttonStyle(MenuActionStyle())
    }
    .padding(16).frame(width: 310).tint(.teal)
    .onAppear { model.refreshPermission() }
  }
}
struct MenuActionStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 7).padding(.horizontal, 5)
      .background(
        configuration.isPressed ? Color.primary.opacity(0.08) : .clear,
        in: RoundedRectangle(cornerRadius: 6))
  }
}
struct AppIcon: View {
  var size: CGFloat
  var body: some View {
    Group {
      if let image = NSImage(
        contentsOf: Bundle.main.url(forResource: "app-icon", withExtension: "png")
          ?? URL(fileURLWithPath: "/"))
      {
        Image(nsImage: image).resizable().interpolation(.high)
      } else {
        Image(systemName: "keyboard").resizable().scaledToFit()
      }
    }.frame(width: size, height: size).accessibilityHidden(true)
  }
}
