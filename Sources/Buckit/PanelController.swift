import AppKit
import SwiftUI

enum Metrics {
    static let width: CGFloat = 380
    static let height: CGFloat = 468
    static let cornerRadius: CGFloat = 22
}

/// Borderless floating panel that can take keyboard focus without
/// activating Buckit, so the app underneath stays frontmost.
final class BuckitPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Metrics.width, height: Metrics.height),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        appearance = NSAppearance(named: .darkAqua)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    let store: Store
    let panel = BuckitPanel()

    private var keyMonitor: Any?
    private var scrollMonitor: Any?
    private var isHiding = false
    private var restoreFocusAfterHide = true

    private enum SwipeAxis { case undecided, horizontal, vertical }
    private var swipeAxis: SwipeAxis = .undecided
    private var swallowMomentum = false

    init(store: Store) {
        self.store = store
        super.init()

        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: Metrics.width, height: Metrics.height))
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.maskImage = .roundedMask(radius: Metrics.cornerRadius)
        effect.autoresizingMask = [.width, .height]

        let host = NSHostingView(rootView: RootView().environment(store).environment(store.prefs))
        host.frame = effect.bounds
        host.autoresizingMask = [.width, .height]
        effect.addSubview(host)

        panel.contentView = effect
        panel.delegate = self

        store.requestChooseFiles = { [weak self] in self?.chooseFiles() }

        installMonitors()
    }

    // MARK: Show / hide

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        isHiding = false
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let vf = screen?.visibleFrame {
            let x = vf.midX - Metrics.width / 2
            // Sit a little above center, like Spotlight.
            let y = vf.minY + vf.height * 0.56 - Metrics.height / 2
            panel.setFrame(NSRect(x: x.rounded(), y: y.rounded(), width: Metrics.width, height: Metrics.height), display: false)
        }

        store.prepareForShow()

        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide(restoreFocus: Bool = true) {
        // A Settings request can arrive while a previous hide animation runs.
        // Let it cancel that animation's pending app hide as well.
        if !restoreFocus { restoreFocusAfterHide = false }
        guard panel.isVisible, !isHiding else { return }
        restoreFocusAfterHide = restoreFocus
        isHiding = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 130_000_000)
            guard let self, self.isHiding else { return }
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
            self.isHiding = false
            self.store.saveNow()
            // If we had to activate (e.g. for the file picker), hand focus back.
            if self.restoreFocusAfterHide && NSApp.isActive { NSApp.hide(nil) }
        }
    }

    // MARK: File picker

    private func chooseFiles() {
        let open = NSOpenPanel()
        open.canChooseFiles = true
        open.canChooseDirectories = true
        open.allowsMultipleSelection = true
        open.prompt = "Add to \(store.active.name)"
        NSApp.activate(ignoringOtherApps: true)
        let response = open.runModal()
        if response == .OK {
            store.add(open.urls.map(Resource.from(url:)))
            store.isAddingResource = false
        }
        panel.makeKeyAndOrderFront(nil)
    }

    // MARK: Keyboard & trackpad

    private func installMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handleKey(event) ? nil : event
        }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handleScroll(event) ? nil : event
        }
    }

    private func handleKey(_ e: NSEvent) -> Bool {
        let mods = e.modifierFlags.intersection(.deviceIndependentFlagsMask)

        switch Int(e.keyCode) {
        case 53: // Escape
            if !store.handleEscape() { hide() }
            return true
        case 125 where store.searchFocused && mods.isDisjoint(with: [.command, .option, .control]): // ↓
            store.moveSelection(1)
            return true
        case 126 where store.searchFocused && mods.isDisjoint(with: [.command, .option, .control]): // ↑
            store.moveSelection(-1)
            return true
        default:
            break
        }

        // The configurable actions. A plain ↩ has to reach a text field it's
        // being typed into, so these only fire from search or outside any field.
        if store.searchFocused || !(panel.firstResponder is NSText) {
            let keys = store.prefs.shortcuts
            if keys.copy.matches(e) {
                store.copySelected()
                return true
            }
            if keys.reveal.matches(e) {
                store.revealSelected()
                return true
            }
            // "Open" is the search field's own submit action when it's a plain ↩.
            if keys.open.matches(e), !(store.searchFocused && keys.open.flags.isEmpty) {
                store.submitSearch()
                return true
            }
        }

        // ⌘1 … ⌘9 jump to a Space.
        if mods == .command, let ch = e.charactersIgnoringModifiers, let n = Int(ch), (1...9).contains(n) {
            store.switchTo(n - 1)
            return true
        }
        // ⌃Tab / ⌃⇧Tab cycle Spaces.
        if e.keyCode == 48, mods.contains(.control) {
            mods.contains(.shift) ? store.previous() : store.next()
            return true
        }
        // ⌘W closes, like any window.
        if mods == .command, e.charactersIgnoringModifiers == "w" {
            hide()
            return true
        }

        // Typing anywhere (outside a text field) goes to search.
        if !(panel.firstResponder is NSText),
           mods.isDisjoint(with: [.command, .control, .option]),
           let chars = e.characters, !chars.isEmpty,
           chars.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(.punctuationCharacters).union(.symbols).union(.whitespaces).contains($0) }) {
            store.isSearchOpen = true
            store.query += chars
            store.focusRequest += 1
            return true
        }
        return false
    }

    /// Two-finger horizontal swipes page between Spaces; vertical scrolls pass through.
    private func handleScroll(_ e: NSEvent) -> Bool {
        // Momentum after a horizontal swipe shouldn't leak into the scroll view.
        if !e.momentumPhase.isEmpty {
            if e.momentumPhase.contains(.ended) || e.momentumPhase.contains(.cancelled) {
                let swallow = swallowMomentum
                swallowMomentum = false
                return swallow
            }
            return swallowMomentum
        }
        guard e.hasPreciseScrollingDeltas, !e.phase.isEmpty else { return false }

        let dx = e.scrollingDeltaX
        let dy = e.scrollingDeltaY

        if e.phase.contains(.began) || e.phase.contains(.mayBegin) {
            swipeAxis = .undecided
            swallowMomentum = false
        }

        if e.phase.contains(.changed) || e.phase.contains(.began) {
            if swipeAxis == .undecided, abs(dx) + abs(dy) > 0.5 {
                swipeAxis = abs(dx) > abs(dy) * 1.2 ? .horizontal : .vertical
            }
            if swipeAxis == .horizontal {
                store.dragBy(dx, width: Metrics.width)
                return true
            }
            return false
        }

        if e.phase.contains(.ended) || e.phase.contains(.cancelled) {
            let wasHorizontal = swipeAxis == .horizontal
            swipeAxis = .undecided
            if wasHorizontal {
                store.endDrag(width: Metrics.width)
                swallowMomentum = true
                return true
            }
        }
        return false
    }
}

extension NSImage {
    /// Stretchable rounded-rect mask so NSVisualEffectView gets real rounded corners.
    static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
