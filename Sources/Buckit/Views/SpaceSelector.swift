import SwiftUI

/// Compact dropdown that appears under the Space name.
struct SpaceSelector: View {
    @Environment(Store.self) private var store
    @State private var creating = false
    @State private var newName = ""
    @State private var renamingID: UUID?
    @State private var renameText = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Click-away catcher.
            Color.black.opacity(0.001)
                .onTapGesture {
                    withAnimation(.snappy(duration: 0.18)) { store.showSelector = false }
                }

            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(store.spaces.enumerated()), id: \.element.id) { i, space in
                    if renamingID == space.id {
                        TextField("Space name", text: $renameText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .focused($fieldFocused)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.selected))
                            .onSubmit {
                                store.renameSpace(space.id, to: renameText)
                                renamingID = nil
                            }
                    } else {
                        SelectorRow(
                            title: space.name,
                            dot: space.color.color,
                            shortcut: i < 9 ? "⌘\(i + 1)" : nil,
                            isActive: i == store.activeIndex
                        ) {
                            store.switchTo(i)
                        }
                        .contextMenu {
                            Button("Rename…") {
                                renameText = space.name
                                renamingID = space.id
                                fieldFocused = true
                            }
                            Button("Delete Space", role: .destructive) {
                                store.deleteSpace(space.id)
                            }
                            .disabled(store.spaces.count <= 1)
                        }
                    }
                }

                Rectangle().fill(Theme.hairline).frame(height: 1).padding(.vertical, 4)

                if creating {
                    TextField("New Space", text: $newName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($fieldFocused)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.selected))
                        .onSubmit {
                            store.addSpace(named: newName)
                            newName = ""
                            creating = false
                        }
                } else {
                    SelectorRow(title: "New Space", systemImage: "plus", isActive: false, muted: true) {
                        creating = true
                        fieldFocused = true
                    }
                }
            }
            .padding(5)
            .frame(width: 210)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.30), radius: 22, y: 9)
            .padding(.leading, 10)
            .padding(.top, 36)
            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topLeading)))
        }
    }
}

private struct SelectorRow: View {
    @Environment(Store.self) private var store
    let title: String
    var systemImage: String?
    var dot: Color?
    var shortcut: String?
    let isActive: Bool
    var muted = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10.5, weight: .semibold))
                        .frame(width: 12)
                } else if let dot {
                    Circle()
                        .fill(dot)
                        .frame(width: 7, height: 7)
                        .frame(width: 12)
                        .opacity(isActive ? 1 : 0.55)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .frame(width: 12)
                        .opacity(isActive ? 1 : 0)
                }
                Text(title)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.tertiary)
                }
            }
            .foregroundStyle(muted ? Theme.secondary : Theme.primary)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? store.accent.opacity(0.18) : (hovering ? Theme.selected : .clear)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
