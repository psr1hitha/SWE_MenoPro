//
//  Theme.swift
//  SWE_Menopro_UI
//

import SwiftUI

extension Color {
    // ── Backgrounds ──
    static let menoCream      = Color(red: 0.98, green: 0.95, blue: 0.91)
    static let menoCard       = Color.white
    static let menoMuted      = Color(red: 0.95, green: 0.94, blue: 0.91)
    static let menoLoginPink  = Color(red: 0.984, green: 0.851, blue: 0.898) // #FBD9E5

    // ── Brand magentas ──
    static let menoMagenta     = Color(red: 0.659, green: 0.141, blue: 0.369)
    static let menoMagentaDark = Color(red: 0.294, green: 0.082, blue: 0.157)
    static let menoMagentaSoft = Color(red: 0.957, green: 0.753, blue: 0.820)
    static let menoHeartPink   = Color(red: 0.769, green: 0.212, blue: 0.439) // #C43670

    // ── Risk-level colors ──
    static let menoRiskLow      = Color(red: 0.592, green: 0.769, blue: 0.349)
    static let menoRiskModerate = Color(red: 0.937, green: 0.624, blue: 0.153)
    static let menoRiskSoon     = Color(red: 0.847, green: 0.353, blue: 0.188)
    static let menoRiskImminent = Color(red: 0.886, green: 0.294, blue: 0.290)

    // ── Text ──
    static let menoTextPrimary   = Color(red: 0.294, green: 0.082, blue: 0.157)
    static let menoTextSecondary = Color(red: 0.373, green: 0.369, blue: 0.353)
    static let menoTextTertiary  = Color(red: 0.706, green: 0.698, blue: 0.663)
}

// ── Corner radius scale ──
enum MenoRadius {
    static let small: CGFloat   = 14
    static let medium: CGFloat  = 18
    static let large: CGFloat   = 24
    static let xlarge: CGFloat  = 32
}

// ── Reusable card style ──
struct MenoCardStyle: ViewModifier {
    var background: Color = .menoCard
    var radius: CGFloat = MenoRadius.medium
    var padding: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(background)
            .cornerRadius(radius)
    }
}

extension View {
    func menoCard(background: Color = .menoCard,
                  radius: CGFloat = MenoRadius.medium,
                  padding: CGFloat = 14) -> some View {
        modifier(MenoCardStyle(background: background, radius: radius, padding: padding))
    }
}

extension Color {
    static func forRiskLevel(_ level: String) -> Color {
        switch level {
        case "Imminent": return .menoRiskImminent
        case "Soon":     return .menoRiskSoon
        case "Moderate": return .menoRiskModerate
        default:         return .menoRiskLow
        }
    }
}
