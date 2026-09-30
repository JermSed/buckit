import Foundation

/// Finder exposes tag names as URL resource values. Keep other tags intact.
enum FinderTags {
    static func names(on url: URL) -> [String] {
        (try? url.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []
    }

    static func add(_ tag: String, to url: URL) throws {
        var names = names(on: url)
        guard !names.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) else { return }
        names.append(tag)
        try (url as NSURL).setResourceValue(names, forKey: .tagNamesKey)
    }

    static func remove(_ tag: String, from url: URL) throws {
        let names = names(on: url)
        let remaining = names.filter { $0.caseInsensitiveCompare(tag) != .orderedSame }
        guard remaining.count != names.count else { return }
        try (url as NSURL).setResourceValue(remaining, forKey: .tagNamesKey)
    }
}

/// Keeps Buckit's tagged files in step with Finder/Spotlight changes.
@MainActor
final class FinderTagMonitor {
    private let query = NSMetadataQuery()
    private let store: Store
    private var observers: [NSObjectProtocol] = []

    init(store: Store) {
        self.store = store
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        query.predicate = NSPredicate(format: "%K LIKE %@", "kMDItemUserTags", "*")
        let center = NotificationCenter.default
        for name in [Notification.Name.NSMetadataQueryDidFinishGathering,
                     Notification.Name.NSMetadataQueryDidUpdate] {
            observers.append(center.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        query.start()
    }

    deinit {
        query.stop()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    private func refresh() {
        query.disableUpdates()
        let items = query.results.compactMap { $0 as? NSMetadataItem }
        var pathsByTag: [String: Set<String>] = [:]
        for item in items {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }
            let url = URL(fileURLWithPath: path)
            for tag in FinderTags.names(on: url) {
                pathsByTag[tag.lowercased(), default: []].insert(url.path)
            }
        }
        query.enableUpdates()
        store.syncFinderTaggedFiles(pathsByTag)
    }
}
