import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum SanadButtonKind {
    case primary
    case soft
    case destructive
}

struct SanadButton: View {
    let title: LocalizedStringKey
    var kind: SanadButtonKind = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(SanadFont.button())
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foreground))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(background)
            .foregroundColor(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: kind == .soft ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.55 : 1)
    }

    private var background: Color {
        switch kind {
        case .primary: return SanadTheme.primary
        case .soft: return SanadTheme.accentSoft
        case .destructive: return SanadTheme.error.opacity(0.12)
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return SanadTheme.onPrimary
        case .soft: return SanadTheme.primary
        case .destructive: return SanadTheme.error
        }
    }

    private var borderColor: Color {
        kind == .soft ? SanadTheme.fieldStroke : .clear
    }
}

struct SanadField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(SanadFont.caption(13))
                .foregroundColor(SanadTheme.placeholder)
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboard)
                }
            }
            .font(SanadFont.body())
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SanadTheme.fieldBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SanadTheme.fieldStroke, lineWidth: 1)
            )
        }
    }
}

struct SanadScreen<Content: View>: View {
    var title: LocalizedStringKey? = nil
    var subtitle: LocalizedStringKey? = nil
    var showsBackButton: Bool = false
    var useSoftAura: Bool = true
    @ViewBuilder var content: Content

    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#F5F7FC").ignoresSafeArea()

            if useSoftAura {
                LinearGradient(
                    colors: [
                        SanadTheme.primary.opacity(0.16),
                        SanadTheme.primary.opacity(0.04),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottom
                )
                .frame(height: 220)
                .ignoresSafeArea(edges: .top)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if showsBackButton || title != nil || subtitle != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            if showsBackButton {
                                Button {
                                    dismiss()
                                } label: {
                                    HStack(spacing: 4) {
                                        (layoutDirection == .rightToLeft ? SanadIcon.chevronRight.image : SanadIcon.chevronLeft.image)
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("back")
                                            .font(SanadFont.bodyMedium())
                                    }
                                    .foregroundColor(SanadTheme.primary)
                                }
                                .buttonStyle(.plain)
                            }
                            if let title {
                                Text(title)
                                    .font(SanadFont.title())
                                    .foregroundColor(SanadTheme.onBg)
                            }
                            if let subtitle {
                                Text(subtitle)
                                    .font(SanadFont.body())
                                    .foregroundColor(SanadTheme.placeholder)
                            }
                        }
                        .padding(.top, 8)
                    }
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .navigationBarHidden(true)
    }
}

struct SanadAtmosphereBackground: View {
    var body: some View {
        ZStack {
            SanadTheme.surfaceAlt
            LinearGradient(
                colors: [
                    SanadTheme.primary.opacity(0.14),
                    SanadTheme.surfaceAlt,
                    SanadTheme.pinkPrimary.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

/// Light status bar + themed window / home-indicator chrome (dark system icons).
enum SanadSystemChrome {
    static func apply(tabBarTint: Color = SanadTheme.tabBarBackground) {
        #if canImport(UIKit)
        let chrome = UIColor(tabBarTint)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { window in
                window.backgroundColor = chrome
                window.overrideUserInterfaceStyle = .light
            }
        #endif
    }
}

struct SanadCareLinkRow: View {
    let icon: SanadIcon
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    init(icon: SanadIcon, title: LocalizedStringKey, subtitle: LocalizedStringKey) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    /// Backward-compatible initializer from legacy SF Symbol / shortcut ids.
    init(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) {
        self.icon = SanadIcon.forShortcut(id: icon)
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(SanadTheme.primary.opacity(0.10))
                    .frame(width: 48, height: 48)
                icon.view(size: 22)
                    .foregroundColor(SanadTheme.primary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SanadFont.bodyMedium(16))
                    .foregroundColor(SanadTheme.onBg)
                Text(subtitle)
                    .font(SanadFont.caption(12))
                    .foregroundColor(SanadTheme.placeholder)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            SanadIcon.chevronRight.view(size: 12)
                .foregroundColor(SanadTheme.placeholder)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SanadTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SanadTheme.fieldStroke.opacity(0.7), lineWidth: 1)
        )
    }
}
