import Foundation

public struct ArticleSummary: Decodable, Identifiable {
    public let id: Int
    public let slug: String?
    public let title: [String: String]?
    public let tags: [String]?
    public let created_at: String?
}

private struct ArticleListResponse: Decodable {
    let data: [ArticleSummary]
}

private struct ArticleDetailResponse: Decodable {
    let data: ArticleSummary
}

private struct FavoriteResponse: Decodable {
    let favorited: Bool?
}

public final class ArticlesService {
    let base: URL

    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func list(tag: String? = nil, token: String) async throws -> [ArticleSummary] {
        var components = URLComponents(url: base.appendingPathComponent("v1/articles"), resolvingAgainstBaseURL: false)
        if let tag, !tag.isEmpty {
            components?.queryItems = [URLQueryItem(name: "tag", value: tag)]
        }
        guard let url = components?.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ArticleListResponse.self, from: data).data
    }

    public func favorite(id: Int, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/articles/\(id)"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func unfavorite(id: Int, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/articles/\(id)"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
