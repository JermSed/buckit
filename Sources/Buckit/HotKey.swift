import Carbon.HIToolbox
import Foundation

/// A system-wide keyboard shortcut via Carbon's RegisterEventHotKey.
/// Unlike an NSEvent global monitor, this needs no Accessibility permission
/// and swallows the keystroke so the frontmost app never sees it.
final class HotKey {
    static var handler: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    /// Set when registration failed, so the UI can say so.
    private(set) var lastError: OSStatus = noErr

    init(_ shortcut: Shortcut) {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ -> OSStatus in
                Task { @MainActor in HotKey.handler?() }
                return noErr
            },
            1, &spec, nil, &eventHandlerRef
        )
        register(shortcut)
    }

    /// Swaps in a new combination; the event handler stays installed.
    func register(_ shortcut: Shortcut) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        let id = EventHotKeyID(signature: OSType(0x424B_4954), id: 1) // "BKIT"
        lastError = RegisterEventHotKey(
            UInt32(shortcut.keyCode), shortcut.carbonModifiers,
            id, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        if lastError != noErr {
            NSLog("Buckit: couldn't register \(shortcut.display) (status \(lastError)) — another app may own it.")
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}
