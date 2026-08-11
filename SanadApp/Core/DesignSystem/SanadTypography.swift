import SwiftUI

enum SanadFont {
    static func display(_ size: CGFloat = 28) -> Font {
        .custom("Tajawal-ExtraBold", size: size)
    }

    static func title(_ size: CGFloat = 22) -> Font {
        .custom("Tajawal-Bold", size: size)
    }

    static func body(_ size: CGFloat = 15) -> Font {
        .custom("Tajawal-Regular", size: size)
    }

    static func bodyMedium(_ size: CGFloat = 15) -> Font {
        .custom("Tajawal-Medium", size: size)
    }

    static func caption(_ size: CGFloat = 12) -> Font {
        .custom("Tajawal-Regular", size: size)
    }

    static func button(_ size: CGFloat = 15) -> Font {
        .custom("Tajawal-Bold", size: size)
    }
}

struct SanadTypographyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.font, SanadFont.body())
    }
}

extension View {
    func sanadTypography() -> some View {
        modifier(SanadTypographyModifier())
    }
}
