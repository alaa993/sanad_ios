import Foundation

public struct JournalEntry: Identifiable, Decodable {
    public let id: Int
    public let entry: String
    public let created_at: String?
}

public struct JournalListResponse: Decodable {
    public let data: [JournalEntry]
}

public struct JournalCreateResponse: Decodable {
    public let id: Int
    public let created_at: String?
}

public enum JournalServiceError: Error {
    case locked
}

public final class JournalService {
    let base: URL

    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func list(token: String) async throws -> [JournalEntry] {
        var req = URLRequest(url: base.appendingPathComponent("v1/journal"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 403 {
            throw JournalServiceError.locked
        }
        guard (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(JournalListResponse.self, from: data)
        return decoded.data
    }

    public func create(entry: String, token: String) async throws -> JournalCreateResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/journal"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["entry": entry])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 403 {
            throw JournalServiceError.locked
        }
        guard (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(JournalCreateResponse.self, from: data)
    }

    public func delete(id: Int, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/journal/\(id)"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
