import SwiftUI

/// مطابق لـ `LanguageSettingsFragment`.
struct LanguageSettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.defaultLanguage.rawValue

    var body: some View {
        Form {
            Picker("language_settings", selection: $appLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.titleKey).tag(language.rawValue)
                }
            }
            .pickerStyle(.inline)
        }
        .navigationTitle("language_settings")
    }
}
