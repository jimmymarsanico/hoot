import AppKit
import Carbon.HIToolbox

/// A recorded global keyboard shortcut.
struct Hotkey: Codable, Equatable {
    let keyCode: UInt32
    let carbonModifiers: UInt32
    let display: String

    /// Builds a hotkey from a keyDown event, or nil if the combination is not
    /// suitable (a bare letter with no real modifier, for example).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let isFunctionKey = Self.functionKeyNames[event.keyCode] != nil
        let hasRealModifier = !flags.intersection([.command, .option, .control]).isEmpty
        guard hasRealModifier || isFunctionKey else { return nil }

        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }

        keyCode = UInt32(event.keyCode)
        carbonModifiers = carbon

        var symbols = ""
        if flags.contains(.control) { symbols += "⌃" }
        if flags.contains(.option) { symbols += "⌥" }
        if flags.contains(.shift) { symbols += "⇧" }
        if flags.contains(.command) { symbols += "⌘" }
        display = symbols + Self.keyName(for: event)
    }

    private static func keyName(for event: NSEvent) -> String {
        if let special = specialKeyNames[event.keyCode] ?? functionKeyNames[event.keyCode] {
            return special
        }
        return event.charactersIgnoringModifiers?.uppercased() ?? "?"
    }

    private static let specialKeyNames: [UInt16: String] = [
        UInt16(kVK_Return): "↩", UInt16(kVK_Tab): "⇥", UInt16(kVK_Space): "Space",
        UInt16(kVK_ForwardDelete): "⌦", UInt16(kVK_LeftArrow): "←",
        UInt16(kVK_RightArrow): "→", UInt16(kVK_DownArrow): "↓", UInt16(kVK_UpArrow): "↑",
        UInt16(kVK_Home): "↖", UInt16(kVK_End): "↘", UInt16(kVK_PageUp): "⇞",
        UInt16(kVK_PageDown): "⇟"
    ]

    private static let functionKeyNames: [UInt16: String] = [
        UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
        UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
        UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9",
        UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12"
    ]
}

/// Persists the toggle shortcut and keeps the system registration in sync.
final class HotkeyStore: ObservableObject {
    static let shared = HotkeyStore()
    private static let defaultsKey = "toggleShortcut"

    @Published var hotkey: Hotkey? {
        didSet {
            if let hotkey, let data = try? JSONEncoder().encode(hotkey) {
                UserDefaults.standard.set(data, forKey: Self.defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
            }
            HotkeyCenter.shared.register(hotkey)
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(Hotkey.self, from: data) {
            hotkey = saved
            HotkeyCenter.shared.register(saved)
        }
    }
}

/// Registers the shortcut system-wide via Carbon. RegisterEventHotKey needs
/// no accessibility permission and has been stable since time immemorial.
final class HotkeyCenter {
    static let shared = HotkeyCenter()

    var handler: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let center = Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
            center.handler?()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandlerRef)
    }

    func register(_ hotkey: Hotkey?) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        guard let hotkey else { return }
        let hotKeyID = EventHotKeyID(signature: OSType(0x484F_4F54), id: 1) // 'HOOT'
        RegisterEventHotKey(hotkey.keyCode, hotkey.carbonModifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
