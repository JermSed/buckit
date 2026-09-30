import AppKit
import SwiftUI

/// A small fixed palette. Spaces get an identity colour without letting the
/// panel turn into a paint box, and every value is picked to read on both the
/// dark HUD and the light settings window.
enum SpaceColor: String, Codable, CaseIterable, Identifiable {
    case graphite, blue, indigo, violet, pink, red, orange, yellow, green, teal

    var id: String { rawValue }

    var name: String {
        switch self {
        case .graphite: return "Graphite"
        case .blue: return "Blue"
        case .indigo: return "Indigo"
        case .violet: return "Violet"
        case .pink: return "Pink"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .teal: return "Teal"
        }
    }

    var color: Color { Color(nsColor: nsColor) }

    var nsColor: NSColor {
        switch self {
        // The neutral default has to follow the appearance it sits in.
        case .graphite:
            return NSColor(name: nil) { appearance in
                appearance.isDark
                    ? NSColor(srgbRed: 0.72, green: 0.74, blue: 0.78, alpha: 1)
                    : NSColor(srgbRed: 0.54, green: 0.56, blue: 0.60, alpha: 1)
            }
        case .blue: return .srgb(0.36, 0.56, 0.98)
        case .indigo: return .srgb(0.48, 0.47, 0.90)
        case .violet: return .srgb(0.70, 0.50, 0.93)
        case .pink: return .srgb(0.94, 0.49, 0.68)
        case .red: return .srgb(0.92, 0.39, 0.42)
        case .orange: return .srgb(0.98, 0.59, 0.39)
        case .yellow: return .srgb(0.94, 0.77, 0.35)
        case .green: return .srgb(0.40, 0.77, 0.60)
        case .teal: return .srgb(0.35, 0.75, 0.78)
        }
    }
}

extension NSColor {
    static func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}
