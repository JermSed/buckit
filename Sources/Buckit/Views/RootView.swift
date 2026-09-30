import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Prefs.self) private var prefs

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
        .background {
            SpaceSurface(color: store.accent, colorIntensity: store.active.colorIntensity,
                         windowOpacity: prefs.windowOpacity,
                         radius: Metrics.cornerRadius)
        }
        .overlay(alignment: .topLeading) {
            if store.showSelector {
                SpaceSelector()
            }
        }
        .overlay {
            if store.isDropTargeted {
                DropOverlay(spaceName: store.active.name, accent: store.accent)
                    .transition(.opacity)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.18), value: store.isDropTargeted)
        .animation(.easeInOut(duration: 0.28), value: store.activeIndex)
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
            HStack(spacing: 6) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { store.showSelector.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(store.accent)
                            .frame(width: 7, height: 7)
                        Text(store.active.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .contentTransition(.opacity)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(Theme.tertiary)
                            .rotationEffect(.degrees(store.showSelector ? 180 : 0))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 27)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .floatingControl(tint: store.accent, radius: 9)

                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        store.isSearchOpen.toggle()
                        if !store.isSearchOpen { store.query = "" }
                    }
                    if store.isSearchOpen { store.focusRequest += 1 }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 27, height: 27)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .floatingControl(tint: store.accent, radius: 9)
                .help(store.isSearchOpen ? "Close search" : "Search this Space")

                if store.isSearchOpen {
                    HStack(spacing: 4) {
                        TextField("", text: $store.query, prompt: Text("Search").foregroundColor(Theme.tertiary))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.primary)
                        .focused($searchFocused)
                        .onSubmit { store.submitSearch() }
                        if !store.query.isEmpty {
                            Button { store.query = ""; searchFocused = true } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 7)
                    .frame(minWidth: 80, maxWidth: 145, minHeight: 22)
                    .background(RoundedRectangle(cornerRadius: 8).fill(store.accent.opacity(0.11)))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Theme.border, lineWidth: 0.7))
                    .onAppear { searchFocused = true }
                    .onDisappear { store.searchFocused = false }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 13)
        .padding(.bottom, 12)
        .onChange(of: store.focusRequest) { _, _ in
            if store.isSearchOpen { searchFocused = true }
        }
        .onChange(of: searchFocused) { _, focused in
            store.searchFocused = focused
        }
        .onChange(of: store.query) { _, _ in
            store.selectedResult = 0
        }
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
                        Capsule()
                            .fill(i == store.activeIndex ? space.color.color : Color.white.opacity(0.22))
                            .frame(width: i == store.activeIndex ? 16 : 6, height: 6)
                            .padding(4)
                            .contentShape(Rectangle())
                            .onTapGesture { store.switchTo(i) }
                            .help("\(space.name)  ⌘\(i + 1)")
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .floatingControl(tint: store.accent, radius: 12)
                .animation(.easeInOut(duration: 0.2), value: store.activeIndex)
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
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.07))
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accent.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            VStack(spacing: 10) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(accent.opacity(0.15)))
                Text("Drop into \(spaceName)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
        .padding(10)
        .allowsHitTesting(false)
    }
}
