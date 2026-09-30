import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controller = CaffeinateController()

    private var statusItem: NSStatusItem!
    private lazy var shortcutActions = ShortcutActions(controller: controller)
    private lazy var settingsWindowController = SettingsWindowController(controller: controller)

    private let statusLine = NSMenuItem()
    private let toggleItem = NSMenuItem()
    private let appWatchMenu = NSMenu()
    private var appearanceObservation: NSKeyValueObservation?

    private static let durations: [(title: String, seconds: TimeInterval)] = [
        ("5 Minutes", 5 * 60),
        ("15 Minutes", 15 * 60),
        ("30 Minutes", 30 * 60),
        ("1 Hour", 1 * 3600),
        ("2 Hours", 2 * 3600),
        ("3 Hours", 3 * 3600),
        ("4 Hours", 4 * 3600),
        ("8 Hours", 8 * 3600),
        ("12 Hours", 12 * 3600)
    ]

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [DefaultsKey.keepDisplayAwake: true])

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = StatusIcon.asleep
        statusItem.button?.toolTip = "Hoot"
        statusItem.menu = buildMenu()
        // The awake owl draws its own light/dark silhouette, so redraw it when
        // the menu bar's appearance changes (wallpaper, Dark Mode).
        appearanceObservation = statusItem.button?.observe(\.effectiveAppearance) { button, _ in
            button.needsDisplay = true
        }

        controller.onChange = { [weak self] in self?.refresh() }

        HotkeyCenter.shared.handler = { [weak self] in
            self?.shortcutActions.hotkeyPressed()
        }
        _ = HotkeyStore.shared // loads and registers any saved shortcut

        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.letSleep()
    }

    // MARK: - Menu construction

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(statusLine)
        menu.addItem(.separator())

        toggleItem.target = self
        toggleItem.action = #selector(toggleAwake)
        menu.addItem(toggleItem)

        let durationsItem = NSMenuItem(title: "Keep Awake For", action: nil, keyEquivalent: "")
        let durationsMenu = NSMenu()
        for duration in Self.durations {
            let item = NSMenuItem(title: duration.title, action: #selector(keepAwakeFor(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = duration.seconds
            durationsMenu.addItem(item)
        }
        durationsMenu.addItem(.separator())
        let indefinitely = NSMenuItem(title: "Indefinitely", action: #selector(keepAwakeIndefinitely), keyEquivalent: "")
        indefinitely.target = self
        durationsMenu.addItem(indefinitely)
        durationsItem.submenu = durationsMenu
        menu.addItem(durationsItem)

        let appWatchItem = NSMenuItem(title: "While an App Is Running", action: nil, keyEquivalent: "")
        appWatchMenu.delegate = self
        appWatchItem.submenu = appWatchMenu
        menu.addItem(appWatchItem)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let about = NSMenuItem(title: "About Hoot", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Hoot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    /// Rebuilds the "While an App Is Running" submenu each time it opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === appWatchMenu else { return }
        menu.removeAllItems()

        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }

        guard !running.isEmpty else {
            menu.addItem(NSMenuItem(title: "No Running Apps", action: nil, keyEquivalent: ""))
            return
        }

        for app in running {
            let item = NSMenuItem(title: app.localizedName ?? "Unknown", action: #selector(watchApp(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = app
            if let icon = app.icon, let small = icon.copy() as? NSImage {
                small.size = NSSize(width: 16, height: 16)
                item.image = small
            }
            if case .whileAppRuns(let pid, _) = controller.mode, pid == app.processIdentifier {
                item.state = .on
            }
            menu.addItem(item)
        }
    }

    // MARK: - Actions

    @objc private func toggleAwake() {
        controller.toggle()
    }

    @objc private func keepAwakeIndefinitely() {
        controller.keepAwake(for: nil)
    }

    @objc private func keepAwakeFor(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        controller.keepAwake(for: seconds)
    }

    @objc private func watchApp(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? NSRunningApplication else { return }
        controller.keepAwake(while: app)
    }

    @objc private func openSettings() {
        settingsWindowController.show()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    // MARK: - State display

    private func refresh() {
        switch controller.mode {
        case .off:
            statusLine.title = "Hoot is asleep — normal sleep rules apply"
            toggleItem.title = "Keep Awake"
        case .indefinite:
            statusLine.title = "Keeping your Mac awake"
            toggleItem.title = "Let My Mac Sleep"
        case .timed:
            statusLine.title = "Awake — \(Self.format(controller.remaining ?? 0)) left"
            toggleItem.title = "Let My Mac Sleep"
        case .whileAppRuns(_, let appName):
            statusLine.title = "Awake while \(appName) is running"
            toggleItem.title = "Let My Mac Sleep"
        }
        statusItem.button?.image = controller.isActive ? StatusIcon.awake : StatusIcon.asleep
    }

    private static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
