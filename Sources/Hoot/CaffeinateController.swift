import AppKit
import Foundation

enum DefaultsKey {
    static let keepDisplayAwake = "keepDisplayAwake"
}

/// What Hoot is currently doing.
enum AwakeMode: Equatable {
    case off
    case indefinite
    case timed(until: Date)
    case whileAppRuns(pid: pid_t, appName: String)
}

/// Owns the `caffeinate` child process and the state machine around it.
final class CaffeinateController {
    private(set) var mode: AwakeMode = .off

    /// Called on the main thread whenever the mode (or the countdown) changes.
    var onChange: (() -> Void)?

    private var process: Process?
    private var tickTimer: Timer?

    var isActive: Bool { mode != .off }

    var caffeinatePID: pid_t? { process?.processIdentifier }

    var remaining: TimeInterval? {
        guard case .timed(let until) = mode else { return nil }
        return max(0, until.timeIntervalSinceNow)
    }

    // MARK: - Public API

    /// Keep the Mac awake for `duration` seconds, or indefinitely when nil.
    func keepAwake(for duration: TimeInterval?) {
        guard startCaffeinate(watching: ProcessInfo.processInfo.processIdentifier) else { return }
        if let duration {
            mode = .timed(until: Date().addingTimeInterval(duration))
            startTicking()
        } else {
            mode = .indefinite
            stopTicking()
        }
        notify()
    }

    /// Keep the Mac awake until the given app quits.
    func keepAwake(while app: NSRunningApplication) {
        guard startCaffeinate(watching: app.processIdentifier) else { return }
        stopTicking()
        mode = .whileAppRuns(pid: app.processIdentifier, appName: app.localizedName ?? "that app")
        notify()
    }

    /// Back to normal sleep behavior.
    func letSleep() {
        stopCaffeinate()
        stopTicking()
        mode = .off
        notify()
    }

    func toggle() {
        isActive ? letSleep() : keepAwake(for: nil)
    }

    /// Re-spawn caffeinate with fresh flags after the display setting changed.
    func applyDisplaySetting() {
        switch mode {
        case .off:
            break
        case .indefinite, .timed:
            _ = startCaffeinate(watching: ProcessInfo.processInfo.processIdentifier)
        case .whileAppRuns(let pid, _):
            _ = startCaffeinate(watching: pid)
        }
    }

    // MARK: - caffeinate process

    private func startCaffeinate(watching pid: pid_t) -> Bool {
        stopCaffeinate()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")

        // -i prevents idle system sleep; -d also keeps the display awake.
        // -w ties the assertion to a pid, so caffeinate can never outlive the
        // watched process (or Hoot itself), even if Hoot crashes.
        var arguments = UserDefaults.standard.bool(forKey: DefaultsKey.keepDisplayAwake) ? ["-d", "-i"] : ["-i"]
        arguments += ["-w", String(pid)]
        process.arguments = arguments

        process.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async { self?.caffeinateExited(finished) }
        }

        do {
            try process.run()
            self.process = process
            return true
        } catch {
            NSLog("Hoot: could not launch caffeinate: \(error.localizedDescription)")
            self.process = nil
            return false
        }
    }

    private func stopCaffeinate() {
        guard let process else { return }
        self.process = nil
        process.terminationHandler = nil
        if process.isRunning { process.terminate() }
    }

    /// caffeinate exited on its own — the watched app quit, or someone killed
    /// it externally. Either way, we are no longer keeping the Mac awake.
    private func caffeinateExited(_ finished: Process) {
        guard finished === process else { return }
        process = nil
        stopTicking()
        mode = .off
        notify()
    }

    // MARK: - Countdown

    private func startTicking() {
        stopTicking()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common keeps the countdown live while the menu is open.
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func tick() {
        guard case .timed(let until) = mode else {
            stopTicking()
            return
        }
        if Date() >= until {
            letSleep()
        } else {
            notify()
        }
    }

    private func notify() {
        onChange?()
    }
}
