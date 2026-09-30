import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let controller: CaffeinateController

    @AppStorage(DefaultsKey.keepDisplayAwake) private var keepDisplayAwake = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                ShortcutRecorder()
                Text("Tap to turn on for 15m; keep tapping to step through 30m, 1h, 2h, 4h. Tap again later to turn off. Double-tap to stay awake indefinitely.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Keep the display awake too", isOn: $keepDisplayAwake)
                    .onChange(of: keepDisplayAwake) { _ in
                        controller.applyDisplaySetting()
                    }
                Text("When off, your screen can still turn off while Hoot keeps the system awake.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Toggle("Launch Hoot at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { enabled in
                    setLaunchAtLogin(enabled)
                }
        }
        .padding(20)
        .frame(width: 340)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Hoot: launch at login change failed: \(error.localizedDescription)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
