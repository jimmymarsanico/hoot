import AppKit
import SwiftUI

/// A volume-HUD-style overlay confirming a shortcut press. No notification
/// permissions, nothing lands in Notification Center — it just fades away.
final class HUD {
    static let shared = HUD()
    static let displayDuration: TimeInterval = 1.6

    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    /// - Parameters:
    ///   - steps: optional labels shown beneath the text (the shortcut's cycle),
    ///     with `currentStep` highlighted.
    func show(awake: Bool, text: String, steps: [String] = [], currentStep: Int? = nil) {
        hideWork?.cancel()
        panel?.orderOut(nil)
        panel = nil

        let view = NSHostingView(rootView: HUDView(awake: awake, text: text,
                                                   steps: steps, currentStep: currentStep))
        view.setFrameSize(view.fittingSize)

        let panel = NSPanel(contentRect: view.frame,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.contentView = view

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.midX - view.frame.width / 2,
                                         y: visible.minY + 140))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
        self.panel = panel

        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.displayDuration, execute: work)
    }

    private func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.35
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            if self?.panel === panel { self?.panel = nil }
        })
    }
}

private struct HUDView: View {
    let awake: Bool
    let text: String
    let steps: [String]
    let currentStep: Int?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(nsImage: awake ? StatusIcon.awake : StatusIcon.asleep)
                    .resizable()
                    .frame(width: 24, height: 24)
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            }
            if !steps.isEmpty {
                HStack(spacing: 10) {
                    ForEach(steps.indices, id: \.self) { index in
                        Text(steps[index])
                            .font(.system(size: 11, weight: index == currentStep ? .bold : .regular))
                            .foregroundColor(index == currentStep ? .primary : .secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
