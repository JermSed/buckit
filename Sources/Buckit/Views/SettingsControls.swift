import AppKit
import SwiftUI

/// Light, Apple-system tokens for the settings window. Deliberately separate
/// from `Theme`, which dresses the dark HUD panel.
enum Chrome {
    static let ground = dynamic(light: (0.961, 0.961, 0.968), dark: (0.118, 0.118, 0.125))
    static let card = dynamic(light: (1, 1, 1), dark: (0.165, 0.165, 0.176))
    static let sidebar = dynamic(light: (0.925, 0.925, 0.937), dark: (0.145, 0.145, 0.153))
    static let label = dynamic(light: (0.114, 0.114, 0.122), dark: (0.949, 0.949, 0.961))
    static let secondary = dynamic(light: (0.541, 0.561, 0.600), dark: (0.588, 0.604, 0.639))
    static let accent = Color(nsColor: .srgb(0.161, 0.490, 0.941))

    static let hairline = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1, alpha: 0.09) : NSColor(white: 0, alpha: 0.08)
    })

    static let cardRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8

    private static func dynamic(
        light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let c = appearance.isDark ? dark : light
            return .srgb(c.0, c.1, c.2)
        })
    }
}

/// An uppercase group heading above a card, as in System Settings.
struct GroupLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(Chrome.secondary)
            .padding(.leading, 2)
            .padding(.bottom, 6)
    }
}

/// White (or near-black) rounded container holding a group of rows.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: Chrome.cardRadius, style: .continuous).fill(Chrome.card))
            .overlay(
                RoundedRectangle(cornerRadius: Chrome.cardRadius, style: .continuous)
                    .strokeBorder(Chrome.hairline, lineWidth: 1)
            )
    }
}

/// One line inside a Card: title, optional explanation, trailing control.
struct SettingRow<Trailing: View>: View {
    let title: String
    var detail: String?
    var showsDivider = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(Chrome.label)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(Chrome.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if showsDivider {
                Rectangle().fill(Chrome.hairline).frame(height: 1).padding(.leading, 14)
            }
        }
    }
}

// MARK: - Colour picker

/// The Space's colour as a dot; click for the palette.
struct ColorDotPicker: View {
    let selected: SpaceColor
    let onPick: (SpaceColor) -> Void

    @State private var open = false

    private let columns = Array(repeating: GridItem(.fixed(26), spacing: 6), count: 5)

    var body: some View {
        Button { open.toggle() } label: {
            ZStack {
                Circle().fill(selected.color).frame(width: 13, height: 13)
                Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5).frame(width: 13, height: 13)
            }
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(selected.name) — click to change")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(SpaceColor.allCases) { c in
                    Button {
                        onPick(c)
                        open = false
                    } label: {
                        ZStack {
                            Circle().fill(c.color).frame(width: 18, height: 18)
                            if c == selected {
                                Circle()
                                    .strokeBorder(Chrome.label.opacity(0.55), lineWidth: 1.5)
                                    .frame(width: 24, height: 24)
                            }
                        }
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(c.name)
                }
            }
            .padding(12)
        }
    }
}

// MARK: - Shortcut recorder

/// Click, then press a combination. Escape cancels, Delete clears back to nothing.
struct ShortcutRecorder: View {
    let shortcut: Shortcut
    /// The global hotkey is useless without a modifier; in-panel keys are fine bare.
    var requiresModifier = false
    let onRecord: (Shortcut) -> Void

    @State private var recording = false
    @State private var monitor: Any?
    @State private var rejected = false
    @State private var hovering = false

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "Press keys…" : shortcut.display)
                .font(.system(size: 12, weight: .medium, design: recording ? .default : .rounded))
                .foregroundStyle(recording ? Chrome.accent : Chrome.label)
                .frame(minWidth: 74)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: Chrome.controlRadius, style: .continuous)
                        .fill(recording ? Chrome.accent.opacity(0.1)
                                        : Chrome.label.opacity(hovering ? 0.1 : 0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Chrome.controlRadius, style: .continuous)
                        .strokeBorder(
                            rejected ? Color.red.opacity(0.7)
                                     : (recording ? Chrome.accent.opacity(0.8) : .clear),
                            lineWidth: 1
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .onDisappear(perform: stop)
        .animation(.easeOut(duration: 0.12), value: recording)
        .animation(.easeOut(duration: 0.12), value: rejected)
    }

    private func start() {
        recording = true
        rejected = false
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape backs out without changing anything.
            if event.keyCode == 53 {
                stop()
                return nil
            }
            guard let candidate = Shortcut.from(event: event),
                  !(requiresModifier && candidate.flags.isEmpty)
            else {
                flashRejection()
                return nil
            }
            onRecord(candidate)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }

    private func flashRejection() {
        rejected = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            rejected = false
        }
    }
}
