import Carbon.HIToolbox
import Foundation

/// A system-wide keyboard shortcut via Carbon's RegisterEventHotKey.
/// Unlike an NSEvent global monitor, this needs no Accessibility permission
/// and swallows the keystroke so the frontmost app never sees it.
final class HotKey {
    static var handler: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(keyCode: UInt32 = UInt32(kVK_Space), modifiers: UInt32 = UInt32(optionKey)) {
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

        let id = EventHotKeyID(signature: OSType(0x424B_4954), id: 1) // "BKIT"
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Buckit: couldn't register ⌥Space (status \(status)) — another app may own it.")
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}
