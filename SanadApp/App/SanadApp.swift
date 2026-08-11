import SwiftUI
import UserNotifications

@main
struct SanadApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.defaultLanguage.rawValue
    @AppStorage(AppTheme.storageKey) private var appTheme = AppTheme.defaultTheme.rawValue

    init() {
        applySemanticDirection(for: AppLanguage.current)
    }

    var body: some Scene {
        WindowGroup {
            let language = AppLanguage(rawValue: appLanguage) ?? AppLanguage.defaultLanguage
            AuthGate()  // من الدفعة الثالثة
                .environment(\.locale, language.locale)
                .environment(\.layoutDirection, language.layoutDirection)
                .preferredColorScheme(.light)
                .dismissKeyboardOnTap()
                .onAppear {
                    applySemanticDirection(for: language)
                    SanadSystemChrome.apply(tabBarTint: SanadTheme.tabBarBackground)
                }
                .onChange(of: appLanguage) {
                    let updated = AppLanguage(rawValue: appLanguage) ?? AppLanguage.defaultLanguage
                    applySemanticDirection(for: updated)
                }
                .onChange(of: appTheme) {
                    SanadSystemChrome.apply(tabBarTint: SanadTheme.tabBarBackground)
                }
                .id("\(appLanguage)-\(appTheme)")
        }
    }

    private func applySemanticDirection(for language: AppLanguage) {
        #if canImport(UIKit)
        let code = language == .system ? AppLanguage.currentCode : language.rawValue
        let isRTL = code == "ar"
        UIView.appearance().semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        UITextField.appearance().textAlignment = isRTL ? .right : .left
        UITextView.appearance().textAlignment = isRTL ? .right : .left
        #endif
    }
}
