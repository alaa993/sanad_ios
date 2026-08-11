import Foundation

public struct LibraryCategory: Decodable, Identifiable {
    public let id: Int
    public let title: [String: String]?
    public let articles: [LibraryArticleItem]?
}

public struct LibraryArticleItem: Decodable, Identifiable {
    public let id: Int
    public let title: [String: String]?
    public let image: String?
    public let type: String?
    public let duration: String?
    public let author_name: String?
    public let author_title: String?
    public let author_avatar: String?
    public let category_id: Int?
    public let video_url: String?
    public let thumbnail: String?
    public let tags: [String]?
}

public struct LibraryArticleDetail: Decodable, Identifiable {
    public let id: Int
    public let title: [String: String]?
    public let body: [String: String]?
    public let image: String?
    public let type: String?
    public let duration: String?
    public let author_name: String?
    public let author_title: String?
    public let author_avatar: String?
    public let category_id: Int?
    public let video_url: String?
    public let thumbnail: String?
    public let tags: [String]?
    public let favorited: Bool?
}

private struct LibraryFavoriteResponse: Decodable {
    let favorited: Bool?
}

public struct LibraryDailyTip: Decodable {
    public let title: String?
    public let body: String?
    public let article_id: Int?
    public let author_name: String?
}

private struct ArticleCreateResponse: Decodable {
    let data: LibraryArticleDetail?
}

/// Library categories, articles, daily tip, tags, and curated Syria/Europe lists.
public final class LibraryService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func curatedSyriaEurope(token: String) async throws -> [LibraryArticleItem] {
        var req = URLRequest(url: base.appendingPathComponent("v1/library/curated/syria-europe"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        struct CuratedResponse: Decodable { let data: [LibraryArticleItem]? }
        return try JSONDecoder().decode(CuratedResponse.self, from: data).data ?? []
    }

    public func listLibrary(token: String, tag: String? = nil) async throws -> [LibraryCategory] {
        var components = URLComponents(url: base.appendingPathComponent("v1/library"), resolvingAgainstBaseURL: false)!
        if let tag = tag, !tag.isEmpty {
            components.queryItems = [URLQueryItem(name: "tag", value: tag)]
        }
        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([LibraryCategory].self, from: data)
    }

    public func listTags(token: String) async throws -> [String] {
        var req = URLRequest(url: base.appendingPathComponent("v1/library/tags"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        struct TagsResponse: Decodable { let data: [String]? }
        return try JSONDecoder().decode(TagsResponse.self, from: data).data ?? []
    }

    public func dailyTip(token: String) async throws -> LibraryDailyTip {
        var req = URLRequest(url: base.appendingPathComponent("v1/library/daily-tip"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(LibraryDailyTip.self, from: data)
    }

    public func getArticle(id: Int, token: String) async throws -> LibraryArticleDetail {
        var req = URLRequest(url: base.appendingPathComponent("v1/library/\(id)"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(LibraryArticleDetail.self, from: data)
    }

    @discardableResult
    public func favorite(id: Int, token: String) async throws -> Bool {
        var req = URLRequest(url: base.appendingPathComponent("v1/library/\(id)/favorite"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return (try? JSONDecoder().decode(LibraryFavoriteResponse.self, from: data).favorited) ?? true
    }

    @discardableResult
    public func unfavorite(id: Int, token: String) async throws -> Bool {
        var req = URLRequest(url: base.appendingPathComponent("v1/library/\(id)/favorite"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return (try? JSONDecoder().decode(LibraryFavoriteResponse.self, from: data).favorited) ?? false
    }

    public func createArticle(title: String, body: String, publish: Bool, categoryId: Int?, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/library/articles"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = [
            "title": ["ar": title],
            "body": ["ar": body],
            "active": publish
        ]
        if let categoryId = categoryId, categoryId > 0 {
            payload["category_id"] = categoryId
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func updateArticle(id: Int, title: String?, body: String?, publish: Bool?, token: String) async throws -> LibraryArticleDetail? {
        var req = URLRequest(url: base.appendingPathComponent("v1/articles/\(id)"))
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = [:]
        if let title = title { payload["title"] = ["ar": title] }
        if let body = body { payload["body"] = ["ar": body] }
        if let publish = publish { payload["published"] = publish }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try? JSONDecoder().decode(ArticleCreateResponse.self, from: data).data
    }

    private func slugify(_ title: String) -> String {
        let lower = title.lowercased()
        let pattern = "[^a-z0-9]+"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: lower.utf16.count)
        let slug = regex?.stringByReplacingMatches(in: lower, options: [], range: range, withTemplate: "-") ?? "article"
        let trimmed = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = trimmed.isEmpty ? "article" : trimmed
        return base + "-" + String(Int(Date().timeIntervalSince1970))
    }
}
