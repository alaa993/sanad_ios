import Foundation

public struct CatalogCaseType: Decodable, Identifiable {
    public let id: String
    public let label_ar: String?
    public let label_en: String?
    public let specialist: String?

    public func label(for languageCode: String) -> String {
        if languageCode == "ar", let ar = label_ar, !ar.isEmpty { return ar }
        if let en = label_en, !en.isEmpty { return en }
        return label_ar ?? label_en ?? id
    }
}

public struct CatalogTaskTemplate: Decodable, Identifiable {
    public let id: String
    public let title_ar: String?
    public let title_en: String?
    public let description_ar: String?
    public let description_en: String?
}

public struct CatalogResponse: Decodable {
    public let case_types: [CatalogCaseType]?
    public let community_categories: [CatalogCaseType]?
    public let group_age_categories: [CatalogCaseType]?
    public let group_disorder_tags: [CatalogCaseType]?
    public let task_templates: [CatalogTaskTemplate]?
    public let pre_session_questions: [PreSessionQuestion]?
}

public final class CatalogService {
    private let base: URL
    private let session: URLSession
    private var cached: CatalogResponse?

    public init(baseURL: URL? = nil, session: URLSession = .shared) {
        self.base = baseURL ?? AppConfig.BASE_URL
        self.session = session
    }

    public func load(token: String, forceRefresh: Bool = false) async throws -> CatalogResponse {
        if !forceRefresh, let cached { return cached }
        var req = URLRequest(url: base.appendingPathComponent("v1/catalog"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(CatalogResponse.self, from: data)
        cached = decoded
        return decoded
    }
}
