import AppKit
import ServiceManagement
import SwiftUI

@main
struct BuckitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // SwiftUI can open its own Settings scene through the system menu;
        // the menu bar command uses the AppKit controller below.
        Settings {
            SettingsRootView()
                .environment(appDelegate.store)
                .environment(appDelegate.prefs)
        }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { appDelegate.openSettings() }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let prefs = Prefs()
    lazy var store = Store(prefs: prefs)
    private var panel: PanelController!
    private var settings: SettingsWindowController!
    private var hotKey: HotKey?
    private var finderTagMonitor: FinderTagMonitor?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        panel = PanelController(store: store)
        settings = SettingsWindowController(store: store, prefs: prefs)
        finderTagMonitor = FinderTagMonitor(store: store)
        _ = BrowserTabSuggestion.shared

        HotKey.handler = { [weak self] in self?.panel.toggle() }
        hotKey = HotKey(prefs.shortcuts.toggle)
        // Re-register as soon as the shortcut is changed in Settings.
        prefs.onShortcutsChange = { [weak self] in
            guard let self else { return }
            self.hotKey?.register(self.prefs.shortcuts.toggle)
        }

        setUpStatusItem()

        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "hasLaunched") {
            defaults.set(true, forKey: "hasLaunched")
            panel.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = Bundle.main.path(forResource: "buckit-menu", ofType: "png")
                .flatMap { NSImage(contentsOfFile: $0) }
                ?? NSImage(systemSymbolName: "square.stack", accessibilityDescription: "Buckit")
            image?.isTemplate = true
            image?.size = NSSize(width: 18, height: 18)
            button.image = image
            button.imagePosition = .imageOnly
            button.toolTip = "Buckit — open Settings from this menu"
        }

        let menu = NSMenu()

        let open = NSMenuItem(title: "Open Buckit", action: #selector(openPanel), keyEquivalent: " ")
        open.keyEquivalentModifierMask = [.option]
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        // Launch at Login now lives in Settings → General, so it isn't duplicated here.
        let prefsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let reveal = NSMenuItem(title: "Show Data in Finder", action: #selector(revealData), keyEquivalent: "")
        reveal.target = self
        menu.addItem(reveal)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Buckit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    @objc private func openPanel() {
        panel.show()
    }

    @objc func openSettings() {
        panel.hide(restoreFocus: false)
        settings.show()
    }

    @objc private func revealData() {
        store.saveNow()
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Buckit", isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([dir.appendingPathComponent("buckit.json")])
    }
}
