import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            HeaderView()
            Rectangle().fill(Theme.hairline).frame(height: 1)
            SpacePager()
                .scaleEffect(store.isDropTargeted ? 0.985 : 1)
                .opacity(store.isDropTargeted ? 0.35 : 1)
            FooterView()
        }
        .frame(width: Metrics.width, height: Metrics.height)
        .overlay(alignment: .topLeading) {
            if store.showSelector {
                SpaceSelector()
            }
        }
        .overlay {
            if store.isDropTargeted {
                DropOverlay(spaceName: store.active.name)
                    .transition(.opacity)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.18), value: store.isDropTargeted)
        .onDrop(of: [.fileURL, .url, .plainText], isTargeted: $store.isDropTargeted) { providers in
            store.handleDrop(providers)
            return true
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Header

struct HeaderView: View {
    @Environment(Store.self) private var store
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { store.showSelector.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Text(store.active.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .contentTransition(.opacity)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(Theme.tertiary)
                            .rotationEffect(.degrees(store.showSelector ? 180 : 0))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(store.showSelector ? Theme.selected : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, -6)

                Spacer()

                Text("⌥ Space")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.tertiary.opacity(0.8))
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                TextField("", text: $store.query, prompt: Text("Search \(store.active.name)").foregroundColor(Theme.tertiary))
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.primary)
                    .focused($searchFocused)
                    .onSubmit { store.submitSearch() }
                if !store.query.isEmpty {
                    Button { store.query = ""; searchFocused = true } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 26)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .onChange(of: store.focusRequest) { _, _ in
            searchFocused = true
        }
        .onChange(of: searchFocused) { _, focused in
            store.searchFocused = focused
        }
        .onChange(of: store.query) { _, _ in
            store.selectedResult = 0
        }
        .onAppear { searchFocused = true }
    }
}

// MARK: - Footer

struct FooterView: View {
    @Environment(Store.self) private var store

    var body: some View {
        ZStack {
            if let toast = store.toast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Theme.success)
                    Text(toast)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(height: 22)
                .background(Capsule().fill(Color.white.opacity(0.1)))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                HStack(spacing: 2) {
                    ForEach(Array(store.spaces.enumerated()), id: \.element.id) { i, space in
                        Circle()
                            .fill(i == store.activeIndex ? Color.white.opacity(0.85) : Color.white.opacity(0.22))
                            .frame(width: 6, height: 6)
                            .padding(4)
                            .contentShape(Rectangle())
                            .onTapGesture { store.switchTo(i) }
                            .help("\(space.name)  ⌘\(i + 1)")
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
    }
}

// MARK: - Drop overlay

struct DropOverlay: View {
    let spaceName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.07))
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            VStack(spacing: 10) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.accentColor.opacity(0.15)))
                Text("Drop into \(spaceName)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
        .padding(10)
        .allowsHitTesting(false)
    }
}
