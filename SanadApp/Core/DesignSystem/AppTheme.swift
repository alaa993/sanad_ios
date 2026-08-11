import SwiftUI

struct ThemePalette {
    let primary: Color
    let primaryDark: Color
    let secondary: Color
    let secondaryDark: Color
    let neutral: Color
    let pinkPrimary: Color
    let pinkPrimaryDark: Color
    let grayPrimary: Color
    let grayPrimaryDark: Color

    let surface: Color
    let surfaceAlt: Color
    let onPrimary: Color
    let onBg: Color
    let inputHint: Color
    let placeholder: Color

    let auraStart: Color
    let auraMid: Color
    let auraEnd: Color

    let card: Color
    let shadow: Color
    let subtleShadow: Color
    let fieldBg: Color
    let fieldStroke: Color
    let success: Color
    let error: Color
    let accentSoft: Color
    let specialistSoft: Color

    let chipBg: Color
    let chipText: Color

    let buttonBg: Color
    let buttonStroke: Color
    let buttonSoft: Color
    let buttonDisabled: Color
    let buttonTextDisabled: Color

    let tabBarBackground: Color
    let tabBarActive: Color
    let tabBarInactive: Color
    let tabBarShadow: Color
    let tabBarBorder: Color
    let toastBackground: Color
    let toastText: Color
}

enum AppTheme: String, CaseIterable, Identifiable {
    case sanad
    case rose
    case graphite

    static let storageKey = "app_theme"
    static let defaultTheme: AppTheme = .sanad

    static var current: AppTheme {
        let stored = UserDefaults.standard.string(forKey: storageKey)
        if let stored, let theme = AppTheme(rawValue: stored) { return theme }
        switch stored {
        case "blue": return .sanad
        case "pink": return .rose
        case "gray": return .graphite
        default: return defaultTheme
        }
    }

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .sanad: return "theme_sanad"
        case .rose: return "theme_rose"
        case .graphite: return "theme_graphite"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .sanad:
            return ThemePalette(
                primary: Color(hex: "#2F55A5"),
                primaryDark: Color(hex: "#1B2F63"),
                secondary: Color(hex: "#2F55A5"),
                secondaryDark: Color(hex: "#1B2F63"),
                neutral: Color(hex: "#5E5F5F"),
                pinkPrimary: Color(hex: "#ED228B"),
                pinkPrimaryDark: Color(hex: "#C51B73"),
                grayPrimary: Color(hex: "#5E5F5F"),
                grayPrimaryDark: Color(hex: "#3E3F3F"),
                surface: Color(hex: "#FFFFFF"),
                surfaceAlt: Color(hex: "#F5F7FC"),
                onPrimary: Color.white,
                onBg: Color(hex: "#1A1A1A"),
                inputHint: Color(hex: "#9AA4B2"),
                placeholder: Color(hex: "#9AA4B2"),
                auraStart: Color(hex: "#2F55A5", alpha: 0.40),
                auraMid: Color(hex: "#2F55A5", alpha: 0.20),
                auraEnd: Color(hex: "#1B2F63", alpha: 0.0),
                card: Color.white,
                shadow: Color.black.opacity(0.10),
                subtleShadow: Color.black.opacity(0.03),
                fieldBg: Color.white,
                fieldStroke: Color(hex: "#D8DEEF"),
                success: Color(hex: "#2EAD5B"),
                error: Color(hex: "#E53935"),
                accentSoft: Color(hex: "#E8ECFF"),
                specialistSoft: Color(hex: "#E9F2FF"),
                chipBg: Color(hex: "#F5F6FA"),
                chipText: Color(hex: "#263056"),
                buttonBg: Color(hex: "#F3F0FF"),
                buttonStroke: Color(hex: "#F5F6FA"),
                buttonSoft: Color(hex: "#E6F8FA"),
                buttonDisabled: Color(hex: "#BFEDEE"),
                buttonTextDisabled: Color(hex: "#7BBEC2"),
                tabBarBackground: Color(hex: "#FDFEFF"),
                tabBarActive: Color(hex: "#2F55A5"),
                tabBarInactive: Color(hex: "#8F99B2"),
                tabBarShadow: Color(hex: "#000000", alpha: 0.08),
                tabBarBorder: Color(hex: "#E5E9F3"),
                toastBackground: Color(hex: "#1A1A1A", alpha: 0.85),
                toastText: Color.white
            )
        case .rose:
            return ThemePalette(
                primary: Color(hex: "#C83B7C"),
                primaryDark: Color(hex: "#7A1F4A"),
                secondary: Color(hex: "#C83B7C"),
                secondaryDark: Color(hex: "#7A1F4A"),
                neutral: Color(hex: "#5E5F5F"),
                pinkPrimary: Color(hex: "#C83B7C"),
                pinkPrimaryDark: Color(hex: "#7A1F4A"),
                grayPrimary: Color(hex: "#5E5F5F"),
                grayPrimaryDark: Color(hex: "#3E3F3F"),
                surface: Color(hex: "#FFFFFF"),
                surfaceAlt: Color(hex: "#FDF5F9"),
                onPrimary: Color.white,
                onBg: Color(hex: "#1A1A1A"),
                inputHint: Color(hex: "#9AA4B2"),
                placeholder: Color(hex: "#9AA4B2"),
                auraStart: Color(hex: "#C83B7C", alpha: 0.35),
                auraMid: Color(hex: "#C83B7C", alpha: 0.18),
                auraEnd: Color(hex: "#7A1F4A", alpha: 0.0),
                card: Color.white,
                shadow: Color.black.opacity(0.10),
                subtleShadow: Color.black.opacity(0.03),
                fieldBg: Color.white,
                fieldStroke: Color(hex: "#E8D6E2"),
                success: Color(hex: "#2EAD5B"),
                error: Color(hex: "#E53935"),
                accentSoft: Color(hex: "#FCE7F1"),
                specialistSoft: Color(hex: "#FBEFF6"),
                chipBg: Color(hex: "#F7F2F5"),
                chipText: Color(hex: "#3B2A34"),
                buttonBg: Color(hex: "#F9EAF2"),
                buttonStroke: Color(hex: "#F3E1EB"),
                buttonSoft: Color(hex: "#F6E4EE"),
                buttonDisabled: Color(hex: "#EAC8D7"),
                buttonTextDisabled: Color(hex: "#B07393"),
                tabBarBackground: Color(hex: "#FFFBFD"),
                tabBarActive: Color(hex: "#C83B7C"),
                tabBarInactive: Color(hex: "#A48A97"),
                tabBarShadow: Color(hex: "#000000", alpha: 0.08),
                tabBarBorder: Color(hex: "#F0DCE6"),
                toastBackground: Color(hex: "#1A1A1A", alpha: 0.85),
                toastText: Color.white
            )
        case .graphite:
            return ThemePalette(
                primary: Color(hex: "#2E3A46"),
                primaryDark: Color(hex: "#151B21"),
                secondary: Color(hex: "#2E3A46"),
                secondaryDark: Color(hex: "#151B21"),
                neutral: Color(hex: "#5E5F5F"),
                pinkPrimary: Color(hex: "#ED228B"),
                pinkPrimaryDark: Color(hex: "#C51B73"),
                grayPrimary: Color(hex: "#5E5F5F"),
                grayPrimaryDark: Color(hex: "#3E3F3F"),
                surface: Color(hex: "#FFFFFF"),
                surfaceAlt: Color(hex: "#F5F6F7"),
                onPrimary: Color.white,
                onBg: Color(hex: "#1A1A1A"),
                inputHint: Color(hex: "#8F99B2"),
                placeholder: Color(hex: "#8F99B2"),
                auraStart: Color(hex: "#2E3A46", alpha: 0.35),
                auraMid: Color(hex: "#2E3A46", alpha: 0.18),
                auraEnd: Color(hex: "#151B21", alpha: 0.0),
                card: Color.white,
                shadow: Color.black.opacity(0.10),
                subtleShadow: Color.black.opacity(0.03),
                fieldBg: Color.white,
                fieldStroke: Color(hex: "#D6DDE6"),
                success: Color(hex: "#2EAD5B"),
                error: Color(hex: "#E53935"),
                accentSoft: Color(hex: "#E9EDF2"),
                specialistSoft: Color(hex: "#EEF2F6"),
                chipBg: Color(hex: "#F3F5F7"),
                chipText: Color(hex: "#2B323A"),
                buttonBg: Color(hex: "#EDF1F5"),
                buttonStroke: Color(hex: "#EEF1F4"),
                buttonSoft: Color(hex: "#E6EEF2"),
                buttonDisabled: Color(hex: "#CAD4DD"),
                buttonTextDisabled: Color(hex: "#7A8A99"),
                tabBarBackground: Color(hex: "#FBFCFD"),
                tabBarActive: Color(hex: "#2E3A46"),
                tabBarInactive: Color(hex: "#8693A1"),
                tabBarShadow: Color(hex: "#000000", alpha: 0.08),
                tabBarBorder: Color(hex: "#E1E6EC"),
                toastBackground: Color(hex: "#1A1A1A", alpha: 0.85),
                toastText: Color.white
            )
        }
    }
}
