import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case ar
    case en
    case tr

    static let storageKey = "app_language"
    static let defaultLanguage: AppLanguage = .ar

    static var current: AppLanguage {
        let stored = UserDefaults.standard.string(forKey: storageKey)
        if stored == nil || stored?.isEmpty == true { return .system }
        return AppLanguage(rawValue: stored ?? "") ?? defaultLanguage
    }

    static var currentCode: String {
        switch current {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "ar"
            if preferred.hasPrefix("ar") { return "ar" }
            if preferred.hasPrefix("tr") { return "tr" }
            if preferred.hasPrefix("en") { return "en" }
            return "ar"
        default:
            return current.rawValue
        }
    }

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            return Locale(identifier: AppLanguage.currentCode)
        default:
            return Locale(identifier: rawValue)
        }
    }

    var layoutDirection: LayoutDirection {
        let code = self == .system ? AppLanguage.currentCode : rawValue
        return code == "ar" ? .rightToLeft : .leftToRight
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: return "language_system"
        case .ar: return "language_ar"
        case .en: return "language_en"
        case .tr: return "language_tr"
        }
    }
}
