import SwiftUI

struct AuthGate: View {
    @StateObject var vm = AuthViewModel()
    @State private var showSplash = true
    @AppStorage("onboarding_done") private var onboardingDone = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if showSplash {
                // Single in-app splash — continues the UILaunchScreen scene (same canvas + logo).
                SplashView()
            } else if vm.isAuthenticated {
                if onboardingDone {
                    RootTabView()
                } else {
                    OnboardingView()
                }
            } else {
                LoginView()
            }
        }
        .preferredColorScheme(.light)
        .background(SanadTheme.surfaceAlt.ignoresSafeArea())
        .task {
            do {
                let started = Date()
                await vm.bootstrap()
                // Keep splash visible briefly so launch → bootstrap feels continuous (not a second flash).
                let remaining = 0.35 - Date().timeIntervalSince(started)
                if remaining > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                }
            } catch {
                // Never leave the user stuck on splash if bootstrap throws unexpectedly.
                await MainActor.run { vm.isBootstrapping = false }
            }
            withAnimation(.easeInOut(duration: 0.25)) { showSplash = false }
        }
        .onChange(of: vm.isAuthenticated) { _, authenticated in
            if authenticated {
                PushNotificationManager.shared.registerIfNeeded()
                Task { await PushNotificationManager.shared.uploadPendingToken() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, vm.isAuthenticated {
                vm.reconnectRealtime()
            }
        }
        .environmentObject(vm)
        .onAppear {
            SanadSystemChrome.apply(tabBarTint: SanadTheme.tabBarBackground)
        }
        .onChange(of: showSplash) { _, visible in
            if !visible {
                SanadSystemChrome.apply(tabBarTint: SanadTheme.tabBarBackground)
            }
        }
    }
}
