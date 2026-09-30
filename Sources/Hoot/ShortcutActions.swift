import Foundation

/// Turns presses of the global shortcut into keep-awake changes, with HUD feedback.
///
/// - Single tap: turns Hoot on for 15m; further taps while the HUD is still
///   showing step through 30m → 1h → 2h → 4h → off. Once the choice has
///   settled (or from any other mode), a single tap turns Hoot off.
/// - Double tap: keep awake indefinitely (or off, if already indefinite).
final class ShortcutActions {
    static let cycle: [(label: String, title: String, seconds: TimeInterval)] = [
        ("15m", "15 minutes", 15 * 60),
        ("30m", "30 minutes", 30 * 60),
        ("1h", "1 hour", 1 * 3600),
        ("2h", "2 hours", 2 * 3600),
        ("4h", "4 hours", 4 * 3600)
    ]

    /// How long to wait for a second press before treating the first as a single tap.
    private static let doubleTapWindow: TimeInterval = 0.3

    /// How long after a cycle step the next tap still advances the cycle.
    /// Matches how long the HUD stays up.
    private static let cycleWindow: TimeInterval = HUD.displayDuration

    private let controller: CaffeinateController
    private var pendingSingleTap: DispatchWorkItem?

    /// The cycle step we last applied, when, and the deadline it produced — so
    /// we can tell whether the current timed session is still ours to advance.
    private var lastStep: (index: Int, until: Date, at: Date)?

    init(controller: CaffeinateController) {
        self.controller = controller
    }

    func hotkeyPressed() {
        if let pending = pendingSingleTap {
            pending.cancel()
            pendingSingleTap = nil
            doubleTap()
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.pendingSingleTap = nil
            self?.singleTap()
        }
        pendingSingleTap = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.doubleTapWindow, execute: work)
    }

    private func singleTap() {
        let next: Int?
        switch controller.mode {
        case .off:
            next = 0
        case .timed(let until) where lastStep?.until == until
                                  && Date().timeIntervalSince(lastStep!.at) < Self.cycleWindow:
            let following = lastStep!.index + 1
            next = following < Self.cycle.count ? following : nil
        default:
            next = nil
        }

        guard let next else {
            turnOff()
            return
        }

        let step = Self.cycle[next]
        controller.keepAwake(for: step.seconds)
        guard case .timed(let until) = controller.mode else { return } // caffeinate failed to launch
        lastStep = (next, until, Date())
        HUD.shared.show(awake: true, text: "Awake for \(step.title)",
                        steps: Self.cycle.map(\.label), currentStep: next)
    }

    private func doubleTap() {
        if controller.mode == .indefinite {
            turnOff()
            return
        }
        controller.keepAwake(for: nil)
        guard controller.mode == .indefinite else { return }
        lastStep = nil
        HUD.shared.show(awake: true, text: "Awake indefinitely")
    }

    private func turnOff() {
        controller.letSleep()
        lastStep = nil
        HUD.shared.show(awake: false, text: "Hoot is asleep")
    }
}
