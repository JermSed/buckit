import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class Store {
    // MARK: Persistent state
    var spaces: [Space]
    var activeIndex: Int

    // MARK: Transient UI state
    var query = ""
    var isSearchOpen = false
    var selectedResult = 0
    var searchFocused = false
    var focusRequest = 0
    var showSelector = false
    var isAddingResource = false
    var editingResourceID: UUID?
    var copiedID: UUID?
    var flashID: UUID?
    var toast: String?
    var isDropTargeted = false
    /// Raw horizontal trackpad travel for the in-progress swipe.
    var rawDrag: CGFloat = 0

    // MARK: Hooks set by the panel controller
    @ObservationIgnored var requestChooseFiles: () -> Void = {}

    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var lastDragDelta: CGFloat = 0
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored let prefs: Prefs

    init(prefs: Prefs) {
        self.prefs = prefs
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = support.appendingPathComponent("Buckit", isDirectory: true).appendingPathComponent("buckit.json")
        if let data = try? Data(contentsOf: fileURL),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data),
           !snap.spaces.isEmpty {
            spaces = snap.spaces
            activeIndex = min(max(snap.activeIndex, 0), snap.spaces.count - 1)
        } else {
            spaces = Snapshot.seed.spaces
            activeIndex = 0
        }
        assignInitialColorsIfNeeded()
        linkExistingFilesToFinderTags()
    }

    private func linkExistingFilesToFinderTags() {
        var changed = false
        for i in spaces.indices {
            for j in spaces[i].resources.indices where spaces[i].resources[j].kind == .file {
                guard !spaces[i].resources[j].fromFinderTag,
                      let url = spaces[i].resources[j].url,
                      FileManager.default.fileExists(atPath: url.path) else { continue }
                do {
                    try FinderTags.add(spaces[i].finderTag, to: url)
                    spaces[i].resources[j].fromFinderTag = true
                    changed = true
                } catch {
                    NSLog("Buckit: could not tag %@ — %@", url.path, error.localizedDescription)
                }
            }
        }
        if changed { scheduleSave() }
    }

    /// Spaces saved before colours existed all decode as graphite. Hand them
    /// distinct ones once, so the palette shows itself instead of waiting to be
    /// discovered. Skipped the moment anyone has actually picked a colour.
    private func assignInitialColorsIfNeeded() {
        let key = "didAssignSpaceColors"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        guard spaces.allSatisfy({ $0.color == .graphite }) else { return }
        for i in spaces.indices { spaces[i].color = Self.rotation[i % Self.rotation.count] }
        scheduleSave()
    }

    /// The order new Spaces pick from.
    private static let rotation: [SpaceColor] = [.blue, .orange, .green, .violet, .pink, .teal, .yellow, .red, .indigo]

    // MARK: Derived

    var active: Space { spaces[activeIndex] }
    /// The active Space's identity colour, used for every accent in the panel.
    var accent: Color { active.color.color }
    var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    func index(of spaceID: UUID) -> Int? { spaces.firstIndex { $0.id == spaceID } }

    /// Resources in the active space ranked against the query.
    var results: [Resource] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return active.resources }
        return active.resources
            .compactMap { r -> (Resource, Int)? in
                let s = Self.score(r, q)
                return s > 0 ? (r, s) : nil
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    private static func score(_ r: Resource, _ q: String) -> Int {
        let name = r.name.lowercased()
        if name.hasPrefix(q) { return 100 }
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if words.contains(where: { $0.hasPrefix(q) }) { return 80 }
        if name.contains(q) { return 60 }
        if r.value.lowercased().contains(q) { return 40 }
        // Loose subsequence match ("rsm" → "Resume.pdf").
        var it = name.makeIterator()
        for ch in q {
            var found = false
            while let c = it.next() { if c == ch { found = true; break } }
            if !found { return 0 }
        }
        return 10
    }

    /// When searching with no matches, a typed link can be added directly.
    var pendingLinkFromQuery: Resource? {
        guard isSearching, results.isEmpty else { return nil }
        return Resource.from(text: query)
    }

    // MARK: Panel lifecycle

    func prepareForShow() {
        query = ""
        isSearchOpen = false
        selectedResult = 0
        showSelector = false
        isAddingResource = false
        editingResourceID = nil
        rawDrag = 0
    }

    /// Returns true if Escape was consumed by an inner state; false means "close the panel".
    func handleEscape() -> Bool {
        if editingResourceID != nil { editingResourceID = nil; return true }
        if showSelector { withAnimation(.easeOut(duration: 0.15)) { showSelector = false }; return true }
        if isAddingResource { isAddingResource = false; return true }
        if !query.isEmpty { query = ""; focusRequest += 1; return true }
        if isSearchOpen { isSearchOpen = false; searchFocused = false; return true }
        return false
    }

    // MARK: Search

    func moveSelection(_ delta: Int) {
        let count = results.count
        guard count > 0 else { return }
        selectedResult = (selectedResult + delta + count) % count
    }

    func submitSearch() {
        let r = results
        if !r.isEmpty {
            open(r[min(selectedResult, r.count - 1)])
        } else if let res = pendingLinkFromQuery {
            add([res])
            query = ""
        }
    }

    func copySelected() {
        let r = results
        guard !r.isEmpty else { return }
        copy(r[min(selectedResult, r.count - 1)])
    }

    func revealSelected() {
        let r = results
        guard !r.isEmpty else { return }
        revealInFinder(r[min(selectedResult, r.count - 1)])
    }

    // MARK: Resource actions

    func open(_ r: Resource) {
        guard let url = r.url else { return }
        NSWorkspace.shared.open(url)
    }

    func copy(_ r: Resource) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch r.kind {
        case .link:
            pb.setString(r.value, forType: .string)
        case .file:
            if let url = r.url { pb.writeObjects([url as NSURL]) }
            pb.setString(r.value, forType: .string)
        }
        withAnimation(.easeOut(duration: 0.18)) { copiedID = r.id }
        let id = r.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            if self.copiedID == id {
                withAnimation(.easeOut(duration: 0.2)) { self.copiedID = nil }
            }
        }
    }

    func revealInFinder(_ r: Resource) {
        guard r.kind == .file, let url = r.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: Resource collection

    func add(_ items: [Resource], to spaceID: UUID? = nil) {
        guard !items.isEmpty else { return }
        let i = spaceID.flatMap { self.index(of: $0) } ?? activeIndex
        var taggedItems = items
        for j in taggedItems.indices where taggedItems[j].kind == .file {
            guard let url = taggedItems[j].url else { continue }
            do {
                try FinderTags.add(spaces[i].finderTag, to: url)
                taggedItems[j].fromFinderTag = true
            } catch {
                showToast("Could not tag \(taggedItems[j].name) in Finder")
            }
        }
        // Skip exact duplicates already in the space.
        let existing = Set(spaces[i].resources.map(\.value))
        let fresh = taggedItems.filter { !existing.contains($0.value) }
        guard !fresh.isEmpty else {
            showToast("Already in \(spaces[i].name)")
            return
        }
        withAnimation(.snappy(duration: 0.24)) {
            spaces[i].resources.append(contentsOf: fresh)
        }
        flash(fresh.last!.id)
        showToast(fresh.count == 1 ? "\(fresh[0].name) added" : "\(fresh.count) items added")
        scheduleSave()
    }

    @discardableResult
    func addFromText(_ text: String) -> Bool {
        guard let r = Resource.from(text: text) else { return false }
        add([r])
        return true
    }

    func update(_ r: Resource) {
        for i in spaces.indices {
            if let j = spaces[i].resources.firstIndex(where: { $0.id == r.id }) {
                spaces[i].resources[j] = r
            }
        }
        scheduleSave()
    }

    func remove(_ r: Resource) {
        if r.fromFinderTag, let i = spaces.firstIndex(where: { $0.resources.contains(where: { $0.id == r.id }) }),
           let url = r.url {
            do {
                try FinderTags.remove(spaces[i].finderTag, from: url)
            } catch {
                showToast("Could not remove Finder tag")
                return
            }
        }
        withAnimation(.snappy(duration: 0.22)) {
            for i in spaces.indices { spaces[i].resources.removeAll { $0.id == r.id } }
        }
        scheduleSave()
    }

    func move(_ r: Resource, toSpace target: UUID) {
        guard let t = index(of: target) else { return }
        if r.fromFinderTag, let url = r.url {
            do {
                try FinderTags.add(spaces[t].finderTag, to: url)
                if let source = spaces.first(where: { $0.resources.contains(where: { $0.id == r.id }) }) {
                    try FinderTags.remove(source.finderTag, from: url)
                }
            } catch {
                showToast("Could not update Finder tags")
                return
            }
        }
        withAnimation(.snappy(duration: 0.22)) {
            for i in spaces.indices { spaces[i].resources.removeAll { $0.id == r.id } }
            spaces[t].resources.append(r)
        }
        showToast("Moved to \(spaces[t].name)")
        scheduleSave()
    }

    func moveResources(in spaceID: UUID, from: IndexSet, to: Int) {
        guard let i = index(of: spaceID) else { return }
        spaces[i].resources.move(fromOffsets: from, toOffset: to)
        scheduleSave()
    }

    // MARK: Drag & drop

    func handleDrop(_ providers: [NSItemProvider]) {
        Task { @MainActor in
            var urls: [URL] = []
            for p in providers {
                if let u = await Self.loadURL(from: p) { urls.append(u) }
            }
            self.add(urls.map(Resource.from(url:)))
        }
    }

    nonisolated static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data {
                        cont.resume(returning: URL(dataRepresentation: data, relativeTo: nil))
                    } else if let url = item as? URL {
                        cont.resume(returning: url)
                    } else {
                        cont.resume(returning: nil)
                    }
                }
            } else if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    cont.resume(returning: url)
                }
            } else if provider.canLoadObject(ofClass: String.self) {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    cont.resume(returning: text.flatMap { Resource.parseLink($0) })
                }
            } else {
                cont.resume(returning: nil)
            }
        }
    }

    // MARK: Spaces

    func switchTo(_ i: Int) {
        guard spaces.indices.contains(i) else { return }
        query = ""
        isSearchOpen = false
        selectedResult = 0
        isAddingResource = false
        editingResourceID = nil
        withAnimation(.snappy(duration: 0.24)) {
            showSelector = false
            activeIndex = i
            rawDrag = 0
        }
        scheduleSave()
    }

    func next() { switchTo(min(activeIndex + 1, spaces.count - 1)) }
    func previous() { switchTo(max(activeIndex - 1, 0)) }

    func addSpace(named name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        spaces.append(Space(name: n, color: nextColor()))
        switchTo(spaces.count - 1)
    }

    /// First colour nobody is using, falling back to the rotation.
    private func nextColor() -> SpaceColor {
        let taken = Set(spaces.map(\.color))
        return Self.rotation.first { !taken.contains($0) } ?? Self.rotation[spaces.count % Self.rotation.count]
    }

    func setColor(_ color: SpaceColor, for id: UUID) {
        guard let i = index(of: id), spaces[i].color != color else { return }
        withAnimation(.easeOut(duration: 0.2)) { spaces[i].color = color }
        scheduleSave()
    }

    func setColorIntensity(_ intensity: Double, for id: UUID) {
        guard let i = index(of: id) else { return }
        let value = min(max(intensity, 0), 1)
        guard spaces[i].colorIntensity != value else { return }
        spaces[i].colorIntensity = value
        scheduleSave()
    }

    func renameSpace(_ id: UUID, to name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, let i = index(of: id) else { return }
        let oldTag = spaces[i].finderTag
        if oldTag != n {
            for resource in spaces[i].resources where resource.fromFinderTag {
                guard let url = resource.url else { continue }
                do {
                    try FinderTags.add(n, to: url)
                    try FinderTags.remove(oldTag, from: url)
                } catch {
                    showToast("Could not update a Finder tag")
                }
            }
            spaces[i].finderTag = n
        }
        spaces[i].name = n
        scheduleSave()
    }

    /// Spotlight's current tagged-file set is authoritative for Finder-sourced rows.
    func syncFinderTaggedFiles(_ pathsByTag: [String: Set<String>]) {
        var changed = false
        for i in spaces.indices {
            let paths = pathsByTag[spaces[i].finderTag.lowercased()] ?? []
            let before = spaces[i].resources.count
            let tag = spaces[i].finderTag
            spaces[i].resources.removeAll { resource in
                guard resource.fromFinderTag, let url = resource.url else { return false }
                return !FinderTags.names(on: url).contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
            }
            if spaces[i].resources.count != before { changed = true }
            let existing = Set(spaces[i].resources.filter { $0.kind == .file }.map(\.value))
            for path in paths.subtracting(existing).sorted() {
                var resource = Resource.from(url: URL(fileURLWithPath: path))
                resource.fromFinderTag = true
                spaces[i].resources.append(resource)
                changed = true
            }
        }
        if changed { scheduleSave() }
    }

    func deleteSpace(_ id: UUID) {
        guard spaces.count > 1, let i = index(of: id) else { return }
        let activeID = active.id
        withAnimation(.snappy(duration: 0.22)) {
            spaces.remove(at: i)
            activeIndex = index(of: activeID) ?? min(i, spaces.count - 1)
        }
        scheduleSave()
    }

    func moveSpace(from: IndexSet, to: Int) {
        let activeID = active.id
        spaces.move(fromOffsets: from, toOffset: to)
        activeIndex = index(of: activeID) ?? 0
        scheduleSave()
    }

    // MARK: Swipe

    /// On-screen offset for the pager, with rubber-banding past the first/last space.
    var dragOffset: CGFloat {
        let pastStart = activeIndex == 0 && rawDrag > 0
        let pastEnd = activeIndex == spaces.count - 1 && rawDrag < 0
        return (pastStart || pastEnd) ? rawDrag * 0.25 : rawDrag
    }

    func dragBy(_ dx: CGFloat, width: CGFloat) {
        lastDragDelta = dx
        rawDrag = max(-width, min(width, rawDrag + dx))
        if showSelector { showSelector = false }
    }

    func endDrag(width: CGFloat) {
        let threshold = width * 0.22
        let flick = abs(lastDragDelta) > 6
        var target = activeIndex
        if (rawDrag < -threshold || (flick && lastDragDelta < 0 && rawDrag < 0)) && activeIndex < spaces.count - 1 {
            target += 1
        } else if (rawDrag > threshold || (flick && lastDragDelta > 0 && rawDrag > 0)) && activeIndex > 0 {
            target -= 1
        }
        lastDragDelta = 0
        if target != activeIndex {
            switchTo(target)
        } else {
            withAnimation(.snappy(duration: 0.22)) { rawDrag = 0 }
        }
    }

    // MARK: Feedback

    func showToast(_ text: String) {
        toastTask?.cancel()
        withAnimation(.snappy(duration: 0.22)) { toast = text }
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.toast = nil }
        }
    }

    private func flash(_ id: UUID) {
        flashID = id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            if self.flashID == id {
                withAnimation(.easeOut(duration: 0.4)) { self.flashID = nil }
            }
        }
    }

    // MARK: Persistence

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self.saveNow()
        }
    }

    func saveNow() {
        let snap = Snapshot(spaces: spaces, activeIndex: activeIndex)
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(snap).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Buckit: failed to save — \(error.localizedDescription)")
        }
    }
}
