import AppKit
import SwiftUI

struct ResourceRow: View {
    @Environment(Store.self) private var store
    let resource: Resource
    let spaceID: UUID
    var isSelected = false

    @State private var hovering = false
    @State private var editName = ""
    @State private var editValue = ""
    @FocusState private var editFocused: Bool

    private var isEditing: Bool { store.editingResourceID == resource.id }
    private var isCopied: Bool { store.copiedID == resource.id }
    private var isFlashing: Bool { store.flashID == resource.id }

    var body: some View {
        Group {
            if isEditing {
                editor
            } else {
                row
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.rowRadius, style: .continuous)
                .fill(background)
        )
    }

    private var background: Color {
        if isFlashing { return Color.accentColor.opacity(0.22) }
        if isSelected { return Theme.selected }
        if hovering || isEditing { return Theme.hover }
        return .clear
    }

    // MARK: Row

    private var row: some View {
        HStack(spacing: 10) {
            ResourceIcon(resource: resource)
                .frame(width: 20, height: 20)

            HStack(spacing: 6) {
                Text(resource.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(resource.kind == .file && !resource.fileExists ? Theme.tertiary : Theme.primary)
                    .lineLimit(1)
                    .layoutPriority(1)
                Text(resource.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 6)

            trailing
        }
        .padding(.horizontal, 8)
        .frame(height: Theme.rowHeight)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
        .onTapGesture { store.open(resource) }
        .onDrag { dragProvider() }
        .contextMenu { menu }
        .help(resource.value)
    }

    @ViewBuilder
    private var trailing: some View {
        if isCopied {
            HStack(spacing: 4) {
                Image(systemName: "checkmark").font(.system(size: 9.5, weight: .bold))
                Text("Copied").font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Theme.success)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else if hovering {
            HStack(spacing: 6) {
                switch resource.kind {
                case .link:
                    PillButton(title: "Copy", systemImage: "doc.on.doc") { store.copy(resource) }
                case .file:
                    PillButton(title: "Open") { store.open(resource) }
                }
            }
            .transition(.opacity)
        } else if isSelected {
            KeyHint(text: "↩")
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button("Open") { store.open(resource) }
        Button(resource.kind == .link ? "Copy URL" : "Copy") { store.copy(resource) }
        if resource.kind == .file {
            Button("Show in Finder") { store.revealInFinder(resource) }
        }
        Divider()
        Button("Edit…") { beginEditing() }
        let others = store.spaces.filter { $0.id != spaceID }
        if !others.isEmpty {
            Menu("Move to") {
                ForEach(others) { s in
                    Button(s.name) { store.move(resource, toSpace: s.id) }
                }
            }
        }
        Divider()
        Button("Remove", role: .destructive) { store.remove(resource) }
    }

    private func dragProvider() -> NSItemProvider {
        guard let url = resource.url else { return NSItemProvider() }
        if resource.kind == .file {
            return NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url as NSURL)
        }
        return NSItemProvider(object: url as NSURL)
    }

    // MARK: Editing

    private func beginEditing() {
        editName = resource.name
        editValue = resource.value
        store.editingResourceID = resource.id
        editFocused = true
    }

    private func commit() {
        var r = resource
        let name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { r.name = name }
        let value = editValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            if r.kind == .link, let url = Resource.parseLink(value) {
                r.value = url.absoluteString
            } else if r.kind == .file {
                r.value = (value as NSString).expandingTildeInPath
            }
        }
        store.update(r)
        store.editingResourceID = nil
    }

    private var editor: some View {
        VStack(spacing: 4) {
            TextField("Name", text: $editName)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .focused($editFocused)
                .onSubmit(commit)
            TextField(resource.kind == .link ? "URL" : "Path", text: $editValue)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .onSubmit(commit)
            HStack {
                Text("↩ save · esc cancel")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.tertiary)
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onAppear { editFocused = true }
    }
}

// MARK: - Icon

struct ResourceIcon: View {
    let resource: Resource

    var body: some View {
        switch resource.kind {
        case .file:
            Image(nsImage: NSWorkspace.shared.icon(forFile: resource.value))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        case .link:
            if let host = resource.url?.host,
               let favicon = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64") {
                AsyncImage(url: favicon) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .frame(width: 20, height: 20)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.9)))
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
    }

    private var fallback: some View {
        Image(systemName: resource.url?.scheme == "mailto" ? "envelope" : "globe")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.secondary)
            .frame(width: 20, height: 20)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
    }
}
