import SwiftUI

/// Shared hero header matching Android wave screens — title stays inside the blue band.
struct SanadHeroHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var showLogo: Bool = false
    var showsBackButton: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

    /// Visual wave height (content below the status bar).
    private let waveHeight: CGFloat = 148

    init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        showLogo: Bool = false,
        showsBackButton: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showLogo = showLogo
        self.showsBackButton = showsBackButton
    }

    /// Dynamic titles (e.g. user name) that should not go through localization lookup.
    init(
        plainTitle: String,
        subtitle: LocalizedStringKey? = nil,
        showLogo: Bool = false,
        showsBackButton: Bool = false
    ) {
        self.title = LocalizedStringKey(plainTitle)
        self.subtitle = subtitle
        self.showLogo = showLogo
        self.showsBackButton = showsBackButton
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TopWave()
                .frame(height: waveHeight)
                // Path cutout is on the left. Flip in LTR so cutout stays opposite the title (leading).
                .scaleEffect(x: layoutDirection == .leftToRight ? -1 : 1, anchor: .center)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 6) {
                if showsBackButton {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            (layoutDirection == .rightToLeft ? SanadIcon.chevronRight.image : SanadIcon.chevronLeft.image)
                                .font(.system(size: 13, weight: .semibold))
                            Text("back")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(SanadTheme.onPrimary)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 4)
                }

                if showLogo {
                    Image(SanadTheme.logoName(background: true))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
                }

                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(SanadTheme.onPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(SanadTheme.onPrimary.opacity(0.9))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)
            }
            // Keep title in the solid upper blue band (away from the bottom cutout).
            .padding(.horizontal, 22)
            .padding(.top, 6)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: waveHeight)
        .frame(maxWidth: .infinity)
    }
}

struct SanadSearchField: View {
    @Binding var text: String
    var prompt: LocalizedStringKey = "community_search_hint"

    var body: some View {
        TextField(prompt, text: $text)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SanadTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SanadTheme.fieldStroke, lineWidth: 1)
            )
    }
}

/// Inline status / error / info banner — replaces raw red `Text(err)` alerts.
struct SanadInlineBanner: View {
    enum Style {
        case error
        case info
        case success
        case warning

        var tint: Color {
            switch self {
            case .error: return SanadTheme.error
            case .info: return SanadTheme.primary
            case .success: return SanadTheme.success
            case .warning: return Color(red: 0.78, green: 0.52, blue: 0.12)
            }
        }

        var sanadIcon: SanadIcon {
            switch self {
            case .error: return .error
            case .info: return .info
            case .success: return .success
            case .warning: return .warning
            }
        }
    }

    private let message: String
    private let style: Style

    init(_ message: String, style: Style = .error) {
        self.message = message
        self.style = style
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            style.sanadIcon.view(size: 16)
                .foregroundColor(style.tint)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(SanadTheme.onBg)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(style.tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(style.tint.opacity(0.22), lineWidth: 1)
        )
    }
}

struct SanadEmptyState: View {
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(SanadTheme.primary.opacity(0.08))
                    .frame(width: 64, height: 64)
                SanadIcon.empty.view(size: 28)
                    .foregroundColor(SanadTheme.primary.opacity(0.7))
            }
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(SanadTheme.placeholder)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                        .foregroundColor(SanadTheme.primary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct SanadListCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SanadTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SanadTheme.fieldStroke, lineWidth: 1)
        )
        .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 2)
    }
}

struct SanadScreenContainer<Content: View>: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var showLogo: Bool = false
    var showsBackButton: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(
                    title: title,
                    subtitle: subtitle,
                    showLogo: showLogo,
                    showsBackButton: showsBackButton
                )
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

/// Isolates screens that push via `NavigationLink` so they do not corrupt a parent typed `NavigationStack` path.
struct NestedNavigationHost<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            content()
        }
    }
}
