import AppKit
import ServiceManagement
import SwiftUI

/// The one ordinary window Buckit has. It follows the system appearance rather
/// than forcing dark like the panel — settings are a place you sit and read.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let store: Store
    private let prefs: Prefs
    private var window: NSWindow?

    init(store: Store, prefs: Prefs) {
        self.store = store
        self.prefs = prefs
        super.init()
    }

    func show() {
        if window == nil { window = makeWindow() }
        // An accessory app has no menu bar; become a regular app while the
        // window is up so ⌘W, ⌘Q and window cycling behave normally.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.center()
    }

    private func makeWindow() -> NSWindow {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 560),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.title = "Buckit Settings"
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.minSize = NSSize(width: 620, height: 420)
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.contentView = NSHostingView(
            rootView: SettingsRootView()
                .environment(store)
                .environment(prefs)
        )
        return w
    }

    func windowWillClose(_ notification: Notification) {
        // Back to a menu bar-only app.
        NSApp.setActivationPolicy(.accessory)
        store.saveNow()
    }
}

// MARK: - Root

private enum Pane: String, CaseIterable, Identifiable {
    case general, spaces, shortcuts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .spaces: return "Spaces"
        case .shortcuts: return "Shortcuts"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .spaces: return "square.stack"
        case .shortcuts: return "command"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "How Buckit starts up and behaves."
        case .spaces: return "Choose a theme for each Space."
        case .shortcuts: return "Click a shortcut, then press the keys you want."
        }
    }
}

struct SettingsRootView: View {
    @Environment(Store.self) private var store
    @State private var pane: Pane = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Chrome.hairline).frame(width: 1)
            detail
        }
        .frame(minWidth: 620, minHeight: 420)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Pane.allCases) { p in
                SidebarRow(pane: p, isSelected: p == pane, accent: store.accent) { pane = p }
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 40)
        .padding(.bottom, 12)
        .frame(width: 176)
        .background {
            Chrome.sidebar
                .overlay(alignment: .topLeading) {
                    LinearGradient(colors: [store.accent.opacity(0.14), .clear],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
        }
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(pane.title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Chrome.label)
                    Text(pane.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Chrome.secondary)
                }

                switch pane {
                case .general: GeneralPane()
                case .spaces: SpacesPane()
                case .shortcuts: ShortcutsPane()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.top, 34)
            .padding(.bottom, 26)
        }
        .background(Chrome.ground)
    }
}

private struct SidebarRow: View {
    let pane: Pane
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: pane.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? accent : Chrome.secondary)
                    .frame(width: 16)
                Text(pane.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(Chrome.label)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: Chrome.controlRadius, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.18) : (hovering ? Chrome.label.opacity(0.06) : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - General

private struct GeneralPane: View {
    @Environment(Prefs.self) private var prefs
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                GroupLabel("Appearance")
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Window background opacity")
                                .font(.system(size: 13))
                                .foregroundStyle(Chrome.label)
                            Spacer()
                            Text("\(Int((prefs.windowOpacity * 100).rounded()))%")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Chrome.secondary)
                        }
                        Slider(value: Binding(
                            get: { prefs.windowOpacity },
                            set: { prefs.windowOpacity = min(max($0, 0.45), 1) }
                        ), in: 0.45...1)
                        .accessibilityLabel("Window background opacity")
                        Text("Makes the panel more see-through while its blur and controls stay clear.")
                            .font(.system(size: 11))
                            .foregroundStyle(Chrome.secondary)
                    }
                    .padding(14)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                GroupLabel("Startup")
                Card {
                    SettingRow(
                        title: "Launch at Login",
                        detail: loginError ?? "Buckit lives in the menu bar with no Dock icon.",
                        showsDivider: false
                    ) {
                        Toggle("", isOn: $launchAtLogin)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                GroupLabel("Data")
                Card {
                    SettingRow(
                        title: "Spaces file",
                        detail: "~/Library/Application Support/Buckit/buckit.json",
                        showsDivider: false
                    ) {
                        Button("Show in Finder") { revealData() }
                            .controlSize(.small)
                    }
                }
            }
        }
        .onChange(of: launchAtLogin) { _, wanted in
            applyLaunchAtLogin(wanted)
        }
    }

    private func applyLaunchAtLogin(_ wanted: Bool) {
        guard (SMAppService.mainApp.status == .enabled) != wanted else { return }
        do {
            wanted ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister()
            loginError = nil
        } catch {
            // Only works from a real app bundle, so say so instead of silently failing.
            loginError = "Couldn't change this — Buckit needs to run as an app bundle (make install)."
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func revealData() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Buckit", isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([dir.appendingPathComponent("buckit.json")])
    }
}

// MARK: - Spaces

private struct SpacesPane: View {
    @Environment(Store.self) private var store

    @State private var newName = ""
    @State private var selectedID: UUID?
    @State private var name = ""
    @State private var showingDeleteConfirmation = false
    @FocusState private var editingName: Bool

    private var selected: Space {
        store.spaces.first { $0.id == selectedID } ?? store.active
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                GroupLabel("Spaces")
                Card {
                    List {
                        ForEach(store.spaces) { space in
                            Button {
                                commitName()
                                selectedID = space.id
                                name = space.name
                            } label: {
                                HStack(spacing: 10) {
                                    Circle().fill(space.color.color).frame(width: 12, height: 12)
                                    Text(space.name)
                                        .font(.system(size: 13, weight: selected.id == space.id ? .semibold : .regular))
                                    Spacer()
                                    Text("\(space.resources.count) item\(space.resources.count == 1 ? "" : "s")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Chrome.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Chrome.secondary)
                                }
                                .foregroundStyle(Chrome.label)
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(RoundedRectangle(cornerRadius: 8)
                                    .fill(selected.id == space.id ? space.color.color.opacity(0.16) : .clear))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        .onMove { from, to in store.moveSpace(from: from, to: to) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(height: CGFloat(store.spaces.count) * 38 + 8)
                    .padding(.vertical, 4)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                GroupLabel("Theme")
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        SpaceThemePreview(space: selected)

                        TextField("Space name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .focused($editingName)
                            .onSubmit(commitName)

                        VStack(alignment: .leading, spacing: 9) {
                            Text("Color").font(.system(size: 12, weight: .medium))
                            HStack(spacing: 10) {
                                ForEach(SpaceColor.allCases) { color in
                                    Button { store.setColor(color, for: selected.id) } label: {
                                        Circle()
                                            .fill(color.color)
                                            .frame(width: 22, height: 22)
                                            .padding(3)
                                            .overlay(Circle().strokeBorder(
                                                selected.color == color ? Chrome.label.opacity(0.8) : .clear,
                                                lineWidth: 1.5))
                                    }
                                    .buttonStyle(.plain)
                                    .help(color.name)
                                    .accessibilityLabel("\(color.name) theme")
                                    .accessibilityAddTraits(selected.color == color ? .isSelected : [])
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("Color intensity").font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text("\(Int((selected.colorIntensity * 100).rounded()))%")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Chrome.secondary)
                            }
                            Slider(value: Binding(
                                get: { selected.colorIntensity },
                                set: { store.setColorIntensity($0, for: selected.id) }
                            ), in: 0...1)
                            .tint(selected.color.color)
                            .accessibilityLabel("Color intensity")
                            Text("Adjusts how strongly this Space's color appears.")
                                .font(.system(size: 11))
                                .foregroundStyle(Chrome.secondary)
                        }

                        Rectangle().fill(Chrome.hairline).frame(height: 1)

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Space", systemImage: "trash")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(store.spaces.count <= 1 ? Chrome.secondary : Color.red)
                        .disabled(store.spaces.count <= 1)
                        .help(store.spaces.count <= 1 ? "Keep at least one Space" : "Delete \(selected.name)")
                    }
                    .padding(14)
                }
            }

            Text("Each Space uses a Finder tag with the same name. Files tagged in Finder appear here, and files added here receive the tag. Drag Spaces to reorder them for ⌘1 … ⌘9.")
                .font(.system(size: 11))
                .foregroundStyle(Chrome.secondary)
                .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 0) {
                GroupLabel("Add a Space")
                Card {
                    SettingRow(title: "Create a Space", detail: "Added to the end of the list.", showsDivider: false) {
                        HStack(spacing: 8) {
                            TextField("Name", text: $newName)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)
                                .frame(width: 150)
                                .onSubmit(create)
                            Button("Add", action: create)
                                .controlSize(.small)
                                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }
        }
        .onAppear {
            selectedID = store.active.id
            name = store.active.name
        }
        .onChange(of: editingName) { wasEditing, isEditing in
            if wasEditing && !isEditing { commitName() }
        }
        .onDisappear(perform: commitName)
        .confirmationDialog("Delete \(selected.name)?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Space", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the Space and its resources from Buckit. Files remain on disk.")
        }
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        store.addSpace(named: name)
        selectedID = store.active.id
        self.name = store.active.name
        newName = ""
    }

    private func commitName() {
        guard let selectedID else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            name = selected.name
            return
        }
        store.renameSpace(selectedID, to: trimmed)
    }

    private func deleteSelected() {
        guard store.spaces.count > 1 else { return }
        let id = selected.id
        store.deleteSpace(id)
        selectedID = store.active.id
        name = store.active.name
    }
}

private struct SpaceThemePreview: View {
    @Environment(Prefs.self) private var prefs
    let space: Space

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Circle().fill(space.color.color).frame(width: 8, height: 8)
                Text(space.name).font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: "magnifyingglass").font(.system(size: 12))
            }
            .foregroundStyle(.white)
            RoundedRectangle(cornerRadius: 6)
                .fill(.white.opacity(0.11))
                .frame(height: 24)
                .overlay(alignment: .leading) {
                    HStack(spacing: 7) {
                        Image(systemName: "link").font(.system(size: 9))
                        Text("Resources").font(.system(size: 10))
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.leading, 9)
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .background(SpaceSurface(color: space.color.color, colorIntensity: space.colorIntensity,
                                 windowOpacity: prefs.windowOpacity, radius: 13))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.16)))
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Shortcuts

private struct ShortcutsPane: View {
    @Environment(Prefs.self) private var prefs

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                GroupLabel("Global")
                Card {
                    row(Shortcuts.actions[0], requiresModifier: true, showsDivider: false)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                GroupLabel("In the panel")
                Card {
                    ForEach(Array(Shortcuts.actions.dropFirst().enumerated()), id: \.element.name) { i, action in
                        row(action, requiresModifier: false, showsDivider: i < Shortcuts.actions.count - 2)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                GroupLabel("Fixed")
                Card {
                    SettingRow(title: "Move the selection", detail: "Not configurable.", showsDivider: true) {
                        KeyCaps(["↑", "↓"])
                    }
                    SettingRow(title: "Jump to a Space", detail: "Not configurable.", showsDivider: true) {
                        KeyCaps(["⌘1", "…", "⌘9"])
                    }
                    SettingRow(title: "Cycle Spaces", detail: "Not configurable.", showsDivider: true) {
                        KeyCaps(["⌃⇥", "⌃⇧⇥"])
                    }
                    SettingRow(title: "Clear search, then close", detail: "Not configurable.", showsDivider: false) {
                        KeyCaps(["⎋"])
                    }
                }
            }

            Button("Restore Defaults") { prefs.resetShortcuts() }
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private func row(
        _ action: (name: String, detail: String, key: WritableKeyPath<Shortcuts, Shortcut>),
        requiresModifier: Bool,
        showsDivider: Bool
    ) -> some View {
        let current = prefs.shortcuts[keyPath: action.key]
        let clashes = prefs.shortcuts.conflicts(with: current, excluding: action.key)

        SettingRow(
            title: action.name,
            detail: clashes.isEmpty ? action.detail : "Also assigned to \(clashes.joined(separator: ", ")).",
            showsDivider: showsDivider
        ) {
            ShortcutRecorder(shortcut: current, requiresModifier: requiresModifier) { recorded in
                var updated = prefs.shortcuts
                updated[keyPath: action.key] = recorded
                prefs.shortcuts = updated
            }
        }
    }
}

private struct KeyCaps: View {
    let keys: [String]

    init(_ keys: [String]) { self.keys = keys }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { k in
                Text(k)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Chrome.secondary)
                    .padding(.horizontal, 5)
                    .frame(minHeight: 19)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Chrome.label.opacity(0.06))
                    )
            }
        }
    }
}
