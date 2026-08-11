import SwiftUI

struct SanadPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SanadFont.button())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SanadTheme.primary.opacity(configuration.isPressed ? 0.88 : 1))
            )
            .foregroundColor(SanadTheme.onPrimary)
    }
}

struct SanadSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SanadFont.button())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(SanadTheme.primary, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(SanadTheme.accentSoft.opacity(configuration.isPressed ? 0.7 : 1))
                    )
            )
            .foregroundColor(SanadTheme.primary)
    }
}
