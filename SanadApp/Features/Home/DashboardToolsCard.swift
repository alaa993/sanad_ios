import SwiftUI

/// بطاقة الأدوات في لوحة التحكم — مطابق لـ `HomeFragment` (guide / accessibility / support).
struct DashboardToolsCard: View {
    var onGuide: () -> Void
    var onAccessibility: () -> Void
    var onSupport: () -> Void

    init(
        onGuide: @escaping () -> Void = {},
        onAccessibility: @escaping () -> Void = {},
        onSupport: @escaping () -> Void = {}
    ) {
        self.onGuide = onGuide
        self.onAccessibility = onAccessibility
        self.onSupport = onSupport
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard_tools_title")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
            HStack(spacing: 10) {
                Button(action: onGuide) {
                    toolLabel("dashboard_tool_guide", icon: "book")
                }
                .buttonStyle(.plain)

                Button(action: onAccessibility) {
                    toolLabel("dashboard_tool_accessibility", icon: "figure.roll")
                }
                .buttonStyle(.plain)

                Button(action: onSupport) {
                    toolLabel("dashboard_tool_support", icon: "lifepreserver")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 6, y: 4)
    }

    private func toolLabel(_ titleKey: LocalizedStringKey, icon: String) -> some View {
        VStack(spacing: 6) {
            SanadIcon.forShortcut(id: icon).image
                .font(.system(size: 18))
                .foregroundColor(SanadTheme.primary)
            Text(titleKey)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(SanadTheme.onBg)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.surface))
    }
}
