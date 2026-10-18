import KbsdCore
import ServiceManagement
// This file guarantees a persistent native settings window with switch previews and transparent permission state.
import SwiftUI

struct SettingsView: View {
  @ObservedObject var model: AppModel
  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 10) {
          AppIcon(size: 38)
          VStack(alignment: .leading, spacing: 2) {
            Text("kbsd").font(.title2.bold())
            Text("Every keystroke.").font(.caption).foregroundStyle(.secondary)
          }
        }.padding(.horizontal, 18).padding(.top, 26).padding(.bottom, 30)
        ForEach(SettingsPage.allCases) { page in
          Button {
            model.selectedPage = page
          } label: {
            Label(page.rawValue, systemImage: page.icon)
              .font(.system(size: 13, weight: .medium))
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 10).padding(.horizontal, 12)
              .background(
                model.selectedPage == page ? Color.teal.opacity(0.15) : .clear,
                in: RoundedRectangle(cornerRadius: 8)
              )
              .foregroundStyle(model.selectedPage == page ? .teal : .primary)
          }.buttonStyle(.plain).padding(.horizontal, 10).padding(.bottom, 4)
        }
        Spacer()
        HStack(spacing: 6) {
          Circle().fill(
            !model.accessibilityGranted ? .orange : model.settings.enabled ? .teal : .secondary
          ).frame(width: 6, height: 6)
          Text(
            !model.accessibilityGranted
              ? "Preview only" : model.settings.enabled ? "Sound is on" : "Sound is paused"
          ).font(.caption)
            .foregroundStyle(.secondary)
        }.padding(20)
      }.frame(width: 184).background(.regularMaterial)
      Divider()
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 5) {
            Text(model.selectedPage.rawValue).font(.system(size: 28, weight: .bold))
            Text(model.selectedPage.subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
          }
          Spacer()
          Toggle("Enable kbsd", isOn: $model.settings.enabled).labelsHidden().toggleStyle(.switch)
            .controlSize(.small).padding(.top, 5)
        }.padding(.horizontal, 30).padding(.top, 28).padding(.bottom, 24)
        if let error = model.errorMessage {
          HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(error).font(.caption)
            Spacer()
            Button {
              model.errorMessage = nil
            } label: {
              Image(systemName: "xmark")
            }.buttonStyle(.plain).accessibilityLabel("Dismiss error")
          }.padding(12).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
            .padding(.horizontal, 30).padding(.bottom, 12)
        }
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            switch model.selectedPage {
            case .switches: switches
            case .sound: sound
            case .general: general
            case .statistics: statistics
            }
          }.padding(.horizontal, 30).padding(.bottom, 24)
        }
        Spacer(minLength: 0)
      }.frame(maxWidth: .infinity, maxHeight: .infinity).background(
        Color(nsColor: .windowBackgroundColor))
    }.frame(minWidth: 740, minHeight: 560).tint(.teal)
      .onAppear { model.refreshPermission() }
  }

  private var switches: some View {
    VStack(alignment: .leading, spacing: 18) {
      if !model.accessibilityGranted {
        HStack(spacing: 10) {
          Image(systemName: "hand.raised").font(.title3).foregroundStyle(.orange)
          VStack(alignment: .leading, spacing: 3) {
            Text("Enable sounds in your other apps.").font(.system(size: 12, weight: .semibold))
            Text("Enable keyboard access to hear sounds in other apps.").font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Button("Set up") { model.selectedPage = .general }.controlSize(.small)
        }.padding(13).background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
      }
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        ForEach(SwitchSet.allCases) { set in switchCard(set) }
      }
      KeyboardTestPanel()
    }
  }
  private func switchCard(_ set: SwitchSet) -> some View {
    let selected = model.settings.switchSet == set
    return HStack(spacing: 12) {
      Button {
        model.settings.switchSet = set
      } label: {
        HStack(spacing: 12) {
          SwitchChip(set: set, size: 32)
          VStack(alignment: .leading, spacing: 4) {
            Text(set.brand).font(.system(size: 10, weight: .medium)).foregroundStyle(
              .secondary)
            Text(set.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
          }
          Spacer(minLength: 0)
        }.contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityLabel("Select \(set.name)")
      Button {
        model.preview(set)
      } label: {
        Image(systemName: model.previewing == set ? "stop.circle.fill" : "play.circle.fill")
          .font(.system(size: 24)).foregroundStyle(selected ? .teal : .secondary)
      }.buttonStyle(.plain).accessibilityLabel("Preview \(set.name)")
    }.padding(14).frame(height: 47)
      .background(
        selected ? Color.teal.opacity(0.07) : Color(nsColor: .controlBackgroundColor),
        in: RoundedRectangle(cornerRadius: 12)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12).strokeBorder(
          selected ? Color.teal.opacity(0.65) : Color.primary.opacity(0.07),
          lineWidth: selected ? 1.5 : 1))
  }
  private var sound: some View {
    VStack(alignment: .leading, spacing: 20) {
      settingsCard {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Label("Volume", systemImage: "speaker.wave.2")
            Spacer()
            Text("\(Int(model.settings.volume * 100))%").foregroundStyle(.secondary)
              .monospacedDigit()
          }
          Slider(value: $model.settings.volume, in: 0...1).accessibilityLabel("Sound volume")
          Divider().padding(.vertical, 4)
          HStack {
            Label("Pitch", systemImage: "waveform.path")
            Spacer()
            Text(String(format: "%+.1f", model.settings.pitch)).foregroundStyle(.secondary)
              .monospacedDigit()
          }
          Slider(value: $model.settings.pitch, in: -6...6, step: 0.5).accessibilityLabel("Pitch")
        }
      }
      settingsCard {
        VStack(spacing: 16) {
          preferenceToggle(
            "Randomized pitching", detail: "A subtle variation with every press.", icon: "dice",
            value: $model.settings.randomPitch)
          Divider()
          preferenceToggle(
            "Spatial sound", detail: "Let the sound follow the left and right of your keyboard.",
            icon: "hifispeaker.2", value: $model.settings.spatialAudio)
          Divider()
          preferenceToggle(
            "Modifier keys", detail: "Include Shift, Command, Option, and Control.",
            icon: "command", value: $model.settings.modifierSounds)
          Divider()
          preferenceToggle(
            "Mouse clicks", detail: "A little extra feedback for your clicks.",
            icon: "computermouse", value: $model.settings.mouseSounds)
        }
      }
      HStack {
        Text("Press and release sounds are always paired.").font(.caption).foregroundStyle(
          .secondary)
        Spacer()
        Button(model.previewing == nil ? "Preview sound" : "Stop preview") {
          model.preview(model.settings.switchSet)
        }
      }
    }
  }
  private var general: some View {
    VStack(alignment: .leading, spacing: 20) {
      settingsCard {
        VStack(alignment: .leading, spacing: 14) {
          HStack(spacing: 12) {
            Image(
              systemName: model.accessibilityGranted ? "checkmark.shield.fill" : "hand.raised.fill"
            ).font(.system(size: 26)).foregroundStyle(model.accessibilityGranted ? .teal : .orange)
            VStack(alignment: .leading, spacing: 4) {
              Text(
                model.accessibilityGranted ? "Keyboard access is enabled" : "Enable keyboard access"
              ).font(.headline)
              Text(
                model.accessibilityGranted
                  ? "kbsd is ready to play in your other apps."
                  : "Until enabled, sound only plays inside kbsd. Allow kbsd in System Settings → Privacy & Security → Accessibility."
              ).font(.caption).foregroundStyle(.secondary).fixedSize(
                horizontal: false, vertical: true)
            }
          }
          Text(
            "kbsd uses physical key events to play sounds. It never reads typed text, records your keystrokes, or sends input anywhere."
          )
          .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(
            horizontal: false, vertical: true)
          HStack {
            Button("Open System Settings") { model.openPermissionSettings() }.buttonStyle(
              .borderedProminent)
            Button("Check again") { model.refreshPermission() }
          }.controlSize(.small)
        }
      }
      settingsCard {
        HStack(spacing: 12) {
          Image(systemName: "sunrise").font(.title3).frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text("Launch at login").font(.system(size: 13, weight: .medium))
            Text(
              model.loginStatus == .requiresApproval
                ? "Allow kbsd in System Settings → Login Items." : "Ready when you start your day."
            ).font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
          Toggle(
            "Launch at login",
            isOn: Binding(
              get: { model.loginStatus == .enabled || model.loginStatus == .requiresApproval },
              set: { model.setLaunchAtLogin($0) })
          ).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
      }
      KeyboardTestPanel()
      HStack(spacing: 12) {
        AppIcon(size: 40)
        VStack(alignment: .leading, spacing: 3) {
          Text("kbsd").font(.headline)
          Text("Version 1.0.0 · Native for Mac").font(.caption).foregroundStyle(.secondary)
        }
      }.padding(.top, 8)
    }
  }
  private var statistics: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 14) {
        countCard(value: model.statistics.today, label: "Keystrokes today", icon: "sun.max")
        countCard(value: model.statistics.total, label: "All-time keystrokes", icon: "keyboard")
      }
      settingsCard {
        VStack(alignment: .leading, spacing: 10) {
          Label("Just the numbers.", systemImage: "lock.shield").font(.headline)
          Text(
            "Only your daily and total counts are saved on this Mac. Your actual keystrokes and typed text are never stored. Sound previews are not counted."
          )
          .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(
            horizontal: false, vertical: true)
        }
      }
    }
  }
  private func countCard(value: Int, label: String, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Image(systemName: icon).font(.title2).foregroundStyle(.teal)
      Text(value.formatted()).font(.system(size: 35, weight: .bold, design: .rounded))
        .monospacedDigit()
      Text(label).font(.caption).foregroundStyle(.secondary)
    }.frame(maxWidth: .infinity, alignment: .leading).padding(22).background(
      Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
  }
  private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content().padding(18).frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06)))
  }
  private func preferenceToggle(_ title: String, detail: String, icon: String, value: Binding<Bool>)
    -> some View
  {
    HStack(spacing: 12) {
      Image(systemName: icon).font(.system(size: 17)).frame(width: 24).foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.system(size: 13, weight: .medium))
        Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
      }
      Spacer()
      Toggle(title, isOn: value).labelsHidden().toggleStyle(.switch).controlSize(.small)
    }
  }
}

struct KeyboardTestPanel: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("TRY IT OUT").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(
        .secondary)
      KeyboardTestView().frame(height: 62)
    }
  }
}
struct KeyboardTestView: View {
  @FocusState private var focused: Bool
  var body: some View {
    Button {
      focused = true
    } label: {
      Text(focused ? "Type anything. Enjoy the sound." : "Click here, then start typing…")
        .font(.system(size: 13)).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(
          .horizontal, 18
        )
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
          RoundedRectangle(cornerRadius: 10).strokeBorder(
            focused ? Color.teal : Color.primary.opacity(0.1), lineWidth: focused ? 2 : 1))
    }.buttonStyle(.plain).focusable().focused($focused).focusEffectDisabled()
      .onKeyPress(phases: [.down, .up]) { _ in .handled }
      .accessibilityLabel("Keyboard sound test. Click and type; no text is recorded.")
  }
}
