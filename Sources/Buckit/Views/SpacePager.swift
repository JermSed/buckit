import AppKit
import SwiftUI

/// All Spaces laid side by side; only the active one is in view.
/// The outer panel never moves — content slides horizontally beneath it.
struct SpacePager: View {
    @Environment(Store.self) private var store

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: 0) {
                ForEach(Array(store.spaces.enumerated()), id: \.element.id) { i, space in
                    SpaceContent(spaceID: space.id, isActive: i == store.activeIndex)
                        .frame(width: w, height: geo.size.height)
                }
            }
            .frame(width: w, height: geo.size.height, alignment: .leading)
            .offset(x: -CGFloat(store.activeIndex) * w + store.dragOffset)
        }
        .clipped()
    }
}

struct SpaceContent: View {
    @Environment(Store.self) private var store
    let spaceID: UUID
    let isActive: Bool

    var body: some View {
        if let i = store.index(of: spaceID) {
            let space = store.spaces[i]
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if isActive && store.isSearching {
                        SearchResults()
                    } else {
                        ResourcesSection(space: space)
                        TodoSection(space: space)
                        NoteSection(space: space)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Resources

struct ResourcesSection: View {
    @Environment(Store.self) private var store
    let space: Space
    @State private var draft = ""
    @FocusState private var draftFocused: Bool

    private var adding: Bool { store.isAddingResource && store.active.id == space.id }

    var body: some View {
        SectionLabel("Resources")

        if space.resources.isEmpty && !adding {
            Text("Drop files or links here, or add one below.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.tertiary)
                .padding(.horizontal, 8)
                .frame(height: Theme.rowHeight, alignment: .leading)
        }

        ForEach(space.resources) { r in
            ResourceRow(resource: r, spaceID: space.id)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }

        if adding {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.tertiary)
                    .frame(width: 20)
                TextField("", text: $draft, prompt: Text("Paste a link or file path").foregroundColor(Theme.tertiary))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($draftFocused)
                    .onSubmit {
                        if store.addFromText(draft) {
                            draft = ""
                            store.isAddingResource = false
                        }
                    }
                PillButton(title: "Choose…") { store.requestChooseFiles() }
            }
            .padding(.horizontal, 8)
            .frame(height: Theme.rowHeight)
            .background(RoundedRectangle(cornerRadius: Theme.rowRadius).fill(Theme.hover))
            .onAppear {
                draftFocused = true
                if draft.isEmpty, let clip = NSPasteboard.general.string(forType: .string),
                   Resource.parseLink(clip) != nil {
                    draft = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } else {
            AddButton(title: "Add") {
                store.isAddingResource = true
            }
        }
    }
}

struct AddButton: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 10.5, weight: .semibold))
                    .frame(width: 20)
                Text(title).font(.system(size: 12.5))
                Spacer()
            }
            .foregroundStyle(hovering ? Theme.secondary : Theme.tertiary)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Search

struct SearchResults: View {
    @Environment(Store.self) private var store

    var body: some View {
        let results = store.results
        SectionLabel(results.isEmpty ? "No matches" : "Results") {
            if !results.isEmpty {
                HStack(spacing: 4) {
                    KeyHint(text: "↩")
                    Text("open").font(.system(size: 10.5)).foregroundStyle(Theme.tertiary)
                    KeyHint(text: "⌘↩").padding(.leading, 4)
                    Text("copy").font(.system(size: 10.5)).foregroundStyle(Theme.tertiary)
                }
            }
        }

        ForEach(Array(results.enumerated()), id: \.element.id) { i, r in
            ResourceRow(resource: r, spaceID: store.active.id, isSelected: i == store.selectedResult)
        }

        if let pending = store.pendingLinkFromQuery {
            Button {
                store.submitSearch()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 20)
                    Text("Add \(pending.name)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.primary)
                    Text(pending.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    KeyHint(text: "↩")
                }
                .padding(.horizontal, 8)
                .frame(height: Theme.rowHeight)
                .background(RoundedRectangle(cornerRadius: Theme.rowRadius).fill(Theme.selected))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
