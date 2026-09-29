import SwiftUI

enum Theme {
    static let primary = Color.white.opacity(0.92)
    static let secondary = Color.white.opacity(0.52)
    static let tertiary = Color.white.opacity(0.32)
    static let hairline = Color.white.opacity(0.08)
    static let border = Color.white.opacity(0.12)
    static let hover = Color.white.opacity(0.06)
    static let selected = Color.white.opacity(0.10)
    static let control = Color.white.opacity(0.10)
    static let success = Color(red: 0.42, green: 0.85, blue: 0.56)
    static let note = Color(red: 1.0, green: 0.86, blue: 0.45)

    static let rowHeight: CGFloat = 34
    static let rowRadius: CGFloat = 8
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
            .background(Capsule().fill(Color.white.opacity(hovering ? 0.18 : 0.11)))
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
