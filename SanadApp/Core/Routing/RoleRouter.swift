import Foundation

/// مطابق لـ `RoleRouter.java` — التبويب الافتراضي هو واجهة الاختصارات (سند).
enum RoleRouter {
    static func defaultTab(for rawRole: String?) -> TabKind {
        .shortcuts
    }
}
