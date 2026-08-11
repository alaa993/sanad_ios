
import SwiftUI

public enum SanadTheme {
    private static var palette: ThemePalette { AppTheme.current.palette }

    public static var primary: Color { palette.primary }
    public static var primaryDark: Color { palette.primaryDark }
    public static var secondary: Color { palette.secondary }
    public static var secondaryDark: Color { palette.secondaryDark }
    public static var neutral: Color { palette.neutral }
    public static var pinkPrimary: Color { palette.pinkPrimary }
    public static var pinkPrimaryDark: Color { palette.pinkPrimaryDark }
    public static var grayPrimary: Color { palette.grayPrimary }
    public static var grayPrimaryDark: Color { palette.grayPrimaryDark }

    public static var surface: Color { palette.surface }
    public static var surfaceAlt: Color { palette.surfaceAlt }
    public static var onPrimary: Color { palette.onPrimary }
    public static var onBg: Color { palette.onBg }
    public static var inputHint: Color { palette.inputHint }
    public static var placeholder: Color { palette.placeholder }

    public static var auraStart: Color { palette.auraStart }
    public static var auraMid: Color { palette.auraMid }
    public static var auraEnd: Color { palette.auraEnd }

    public static var card: Color { palette.card }
    public static var shadow: Color { palette.shadow }
    public static var subtleShadow: Color { palette.subtleShadow }
    public static var fieldBg: Color { palette.fieldBg }
    public static var fieldStroke: Color { palette.fieldStroke }
    public static var success: Color { palette.success }
    public static var error: Color { palette.error }
    public static var accentSoft: Color { palette.accentSoft }
    public static var specialistSoft: Color { palette.specialistSoft }

    public static var chipBg: Color { palette.chipBg }
    public static var chipText: Color { palette.chipText }

    public static var buttonBg: Color { palette.buttonBg }
    public static var buttonStroke: Color { palette.buttonStroke }
    public static var buttonSoft: Color { palette.buttonSoft }
    public static var buttonDisabled: Color { palette.buttonDisabled }
    public static var buttonTextDisabled: Color { palette.buttonTextDisabled }

    public static var tabBarBackground: Color { palette.tabBarBackground }
    public static var tabBarActive: Color { palette.tabBarActive }
    public static var tabBarInactive: Color { palette.tabBarInactive }
    public static var tabBarShadow: Color { palette.tabBarShadow }
    public static var tabBarBorder: Color { palette.tabBarBorder }
    public static var toastBackground: Color { palette.toastBackground }
    public static var toastText: Color { palette.toastText }

    public static func logoName(background: Bool) -> String {
        switch AppTheme.current {
        case .sanad:
            return background ? "logo_blue" : "logo_blue_nobg"
        case .rose:
            return background ? "logo_rose" : "logo_rose_nobg"
        case .graphite:
            return background ? "logo_gray" : "logo_gray_nobg"
        }
    }
}

public extension Color {
    init(hex: String, alpha: Double = 1.0) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
