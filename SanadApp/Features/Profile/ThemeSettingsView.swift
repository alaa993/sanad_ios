import SwiftUI

/// مطابق لـ `ThemeSettingsFragment`.
struct ThemeSettingsView: View {
    @AppStorage(AppTheme.storageKey) private var appTheme = AppTheme.defaultTheme.rawValue

    var body: some View {
        Form {
            Picker("theme_settings", selection: $appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.titleKey).tag(theme.rawValue)
                }
            }
            .pickerStyle(.inline)
        }
        .navigationTitle("theme_settings")
    }
}
