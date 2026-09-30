import SwiftUI

enum Theme {
    static let primary = Color.white.opacity(0.95)
    static let secondary = Color.white.opacity(0.64)
    static let tertiary = Color.white.opacity(0.43)
    static let hairline = Color.white.opacity(0.10)
    static let border = Color.white.opacity(0.20)
    static let hover = Color.white.opacity(0.075)
    static let selected = Color.white.opacity(0.13)
    static let control = Color.white.opacity(0.12)
    static let success = Color(red: 0.42, green: 0.85, blue: 0.56)

    static let rowHeight: CGFloat = 34
    static let rowRadius: CGFloat = 10
}

/// System glass on macOS 26, with a translucent material on older macOS.
private struct FloatingControl: ViewModifier {
    let tint: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.tint(tint.opacity(0.20)).interactive(),
                                in: .rect(cornerRadius: radius))
        } else {
            content
                .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 0.75))
        }
    }
}

extension View {
    func floatingControl(tint: Color = .clear, radius: CGFloat = 10) -> some View {
        modifier(FloatingControl(tint: tint, radius: radius))
    }
}

/// One Space's soft color wash over the system's blurred panel material.
struct SpaceSurface: View {
    let color: Color
    let colorIntensity: Double
    let windowOpacity: Double
    let radius: CGFloat

    private var backdropStrength: Double {
        0.15 + 0.85 * min(max((windowOpacity - 0.45) / 0.55, 0), 1)
    }

    var body: some View {
        ZStack {
            Color(red: 0.045, green: 0.055, blue: 0.085)
                .opacity(0.70 * backdropStrength)
            RadialGradient(colors: [color.opacity(0.38 * colorIntensity * backdropStrength), .clear],
                           center: .topLeading, startRadius: 10, endRadius: 350)
            RadialGradient(colors: [color.opacity(0.17 * colorIntensity * backdropStrength), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 300)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// Small uppercase section heading.
struct SectionLabel<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.tertiary)
            Spacer()
            trailing
        }
        .padding(.horizontal, 8)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }
}

extension SectionLabel where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

/// Compact capsule action that appears on hover.
struct PillButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 9.5, weight: .semibold))
                }
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(Capsule().fill(Color.white.opacity(hovering ? 0.20 : 0.10)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Key-cap style hint, e.g. "↩".
struct KeyHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 17)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08)))
    }
}
