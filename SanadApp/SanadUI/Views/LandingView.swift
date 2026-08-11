import SwiftUI

public struct LandingView: View {
    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
            SanadTheme.surface.ignoresSafeArea()

            TopWave()
                .frame(height: 220)
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .trailing, spacing: 16) {
                Text("app_name_upper")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.top, 18)
                    .padding(.trailing, 22)

                Text("landing_supporters")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                    .padding(.top, 40)
                    .padding(.horizontal, 20)

                HStack(alignment: .center, spacing: 16) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(SanadTheme.primary.opacity(0.2))
                        .frame(width: 70, height: 85)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("landing_name_placeholder")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(SanadTheme.onBg)
                        Text("landing_role_placeholder")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }

                    Spacer(minLength: 12)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(SanadTheme.primary)
                        .frame(width: 60, height: 48)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(SanadTheme.card)
                        .shadow(color: SanadTheme.subtleShadow, radius: 6, y: 4)
                )
                .padding(.horizontal, 20)

                Button(action: {}) {
                    Text("landing_emergency")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(SanadTheme.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(SanadTheme.primary)
                        )
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
        }
    }
}

#Preview { LandingView() }
