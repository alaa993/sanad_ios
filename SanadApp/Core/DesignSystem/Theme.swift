import SwiftUI

/// Legacy alias — prefer `SanadTheme` / `AppTheme`.
enum Theme {
    static var primary: Color { SanadTheme.primary }
    static var surface: Color { Color(hex: "#F5F7FC") }
    static var onPrimary: Color { SanadTheme.onPrimary }
    static var onBackground: Color { SanadTheme.onBg }
}
