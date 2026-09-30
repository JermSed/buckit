import AppKit

/// Remembers which supported browser the user last brought forward. The URL is
/// read only when Add is clicked, so opening Buckit never inspects a tab.
@MainActor
final class BrowserTabSuggestion {
    static let shared = BrowserTabSuggestion()

    private var lastBrowserID: String?
    private var observer: NSObjectProtocol?

    private static let chromiumIDs: Set<String> = [
        "com.google.Chrome", "company.thebrowser.Browser", "com.microsoft.edgemac",
        "com.brave.Browser", "com.vivaldi.Vivaldi"
    ]
    private static let safariIDs: Set<String> = ["com.apple.Safari", "com.apple.SafariTechnologyPreview"]

    private init() {
        remember(NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor in self?.remember(app) }
        }
    }

    private func remember(_ app: NSRunningApplication?) {
        guard let id = app?.bundleIdentifier,
              Self.chromiumIDs.contains(id) || Self.safariIDs.contains(id) else { return }
        lastBrowserID = id
    }

    func currentURL() -> String? {
        guard let id = lastBrowserID,
              NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { !$0.isTerminated }) else {
            return nil
        }
        let expression = Self.safariIDs.contains(id)
            ? "URL of current tab of front window"
            : "URL of active tab of front window"
        let script = "tell application id \"\(id)\" to get \(expression)"
        var error: NSDictionary?
        guard let text = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue,
              let url = Resource.parseLink(text),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url.absoluteString
    }
}
