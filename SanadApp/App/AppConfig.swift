import Foundation

enum AppConfig {
    public static let BASE_URL = URL(string: "https://dashboard.sanadhub.cloud/api/")!
    public static let REALTIME_URL = URL(string: "https://dashboard.sanadhub.cloud")!
    private static let siteRoot = "https://dashboard.sanadhub.cloud"

    public static var privacyPolicyURL: URL { URL(string: siteRoot + "/privacy")! }
    public static var deleteAccountURL: URL { URL(string: siteRoot + "/delete-account")! }
    public static var termsURL: URL { URL(string: siteRoot + "/terms")! }
    public static var contactURL: URL { URL(string: siteRoot + "/contact")! }

    public static func storageURL(for path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return URL(string: trimmed)
        }
        if trimmed.hasPrefix("/") {
            return URL(string: siteRoot + trimmed)
        }
        let clean = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if clean.lowercased().hasPrefix("storage/") {
            return URL(string: siteRoot + "/" + clean)
        }
        return URL(string: siteRoot + "/storage/" + clean)
    }
}
