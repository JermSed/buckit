import AppKit
import Carbon.HIToolbox
import Observation

/// One key combination. The key's label is stored alongside its code so the
/// display stays correct on non-US layouts without translating key codes back.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt16
    /// `NSEvent.ModifierFlags` raw value, already masked to the device-independent flags.
    var modifiers: UInt
    var keyLabel: String

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = [], keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(.relevant).rawValue
        self.keyLabel = keyLabel
    }

    var flags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers).intersection(.relevant)
    }

    /// e.g. "⇧↩", "⌥Space", "⌘⌥C".
    var display: String { flags.symbols + keyLabel }

    func matches(_ event: NSEvent) -> Bool {
        event.keyCode == keyCode
            && event.modifierFlags.intersection(.relevant) == flags
    }

    /// Carbon wants its own modifier bit field for `RegisterEventHotKey`.
    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    /// Builds a shortcut from a recorded key press, or nil if it isn't usable.
    static func from(event: NSEvent) -> Shortcut? {
        guard let label = label(for: event) else { return nil }
        return Shortcut(keyCode: event.keyCode, modifiers: event.modifierFlags, keyLabel: label)
    }

    private static func label(for event: NSEvent) -> String? {
        if let named = namedKeys[Int(event.keyCode)] { return named }
        guard let chars = event.charactersIgnoringModifiers, let first = chars.first,
              !first.isWhitespace, first.isLetter || first.isNumber || first.isPunctuation || first.isSymbol
        else { return nil }
        return String(first).uppercased()
    }

    /// Keys whose glyph can't come from `charactersIgnoringModifiers`.
    private static let namedKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_ANSI_KeypadEnter: "⌤", kVK_Tab: "⇥",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}

extension NSEvent.ModifierFlags {
    /// The four modifiers a shortcut may use.
    static let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    var symbols: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

// MARK: - The configurable set

struct Shortcuts: Codable, Equatable {
    /// System-wide; everything else only applies while the panel is open.
    var toggle = Shortcut(keyCode: UInt16(kVK_Space), modifiers: .option, keyLabel: "Space")
    var open = Shortcut(keyCode: UInt16(kVK_Return), keyLabel: "↩")
    var copy = Shortcut(keyCode: UInt16(kVK_Return), modifiers: .command, keyLabel: "↩")
    var reveal = Shortcut(keyCode: UInt16(kVK_ANSI_R), modifiers: [.command, .shift], keyLabel: "R")

    /// Every action, in the order the settings window lists them.
    static let actions: [(name: String, detail: String, key: WritableKeyPath<Shortcuts, Shortcut>)] = [
        ("Show Buckit", "Works anywhere on your Mac", \.toggle),
        ("Open", "Open the selected resource", \.open),
        ("Copy", "Copy the selected link or file", \.copy),
        ("Show in Finder", "Reveal the selected file", \.reveal),
    ]

    /// Names of the actions a shortcut collides with, ignoring the one being edited.
    func conflicts(with shortcut: Shortcut, excluding path: WritableKeyPath<Shortcuts, Shortcut>) -> [String] {
        Self.actions.compactMap { action in
            guard action.key != path, self[keyPath: action.key] == shortcut else { return nil }
            return action.name
        }
    }

    // Decoded key by key so a snapshot written by an older build still loads.
    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        toggle = try c.decodeIfPresent(Shortcut.self, forKey: .toggle) ?? toggle
        open = try c.decodeIfPresent(Shortcut.self, forKey: .open) ?? open
        copy = try c.decodeIfPresent(Shortcut.self, forKey: .copy) ?? copy
        reveal = try c.decodeIfPresent(Shortcut.self, forKey: .reveal) ?? reveal
    }
}

// MARK: - Preferences

/// App configuration, kept in UserDefaults — separate from `buckit.json`, which
/// holds what you put in your Spaces.
@MainActor
@Observable
final class Prefs {
    var shortcuts: Shortcuts { didSet { save(); onShortcutsChange?() } }
    var windowOpacity: Double { didSet { save() } }

    @ObservationIgnored var onShortcutsChange: (() -> Void)?

    private static let key = "prefs"

    private struct Stored: Codable {
        var shortcuts = Shortcuts()
        var windowOpacity = 1.0

        init() {}

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.init()
            shortcuts = try c.decodeIfPresent(Shortcuts.self, forKey: .shortcuts) ?? shortcuts
            windowOpacity = try c.decodeIfPresent(Double.self, forKey: .windowOpacity) ?? windowOpacity
        }
    }

    init() {
        let stored = UserDefaults.standard.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(Stored.self, from: $0) } ?? Stored()
        shortcuts = stored.shortcuts
        windowOpacity = min(max(stored.windowOpacity, 0.45), 1)
    }

    func resetShortcuts() { shortcuts = Shortcuts() }

    private func save() {
        var stored = Stored()
        stored.shortcuts = shortcuts
        stored.windowOpacity = windowOpacity
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
