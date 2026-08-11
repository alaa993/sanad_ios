import SwiftUI

public struct SplashView: View {
    public init(onDone: (() -> Void)? = nil) { self.onDone = onDone }
    @State private var animate = false
    private var onDone: (() -> Void)?

    public var body: some View {
        ZStack {
            SanadAtmosphereBackground()

            RadialGradient(
                gradient: Gradient(colors: [
                    SanadTheme.auraStart,
                    SanadTheme.auraMid,
                    SanadTheme.auraEnd
                ]),
                center: .center,
                startRadius: 20,
                endRadius: 260
            )
            .frame(height: 420)
            .opacity(0.9)

            VStack(spacing: 18) {
                Image(SanadTheme.logoName(background: false))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .scaleEffect(animate ? 1.04 : 0.96)
                    .shadow(color: SanadTheme.primary.opacity(0.18), radius: 18, y: 8)

                Text("app_name")
                    .font(SanadFont.display(32))
                    .foregroundColor(SanadTheme.primary)
                    .opacity(animate ? 1 : 0)

                Text("login_brand_tagline")
                    .font(SanadFont.body(14))
                    .foregroundColor(SanadTheme.placeholder)
                    .opacity(animate ? 1 : 0)
            }
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)
        }
        .preferredColorScheme(.light)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { animate = true }
            // Optional callback for previews / legacy callers — AuthGate owns dismiss timing.
            if onDone != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                    withAnimation(.easeInOut) { onDone?() }
                }
            }
        }
    }
}
