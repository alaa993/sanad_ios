import Foundation

public struct AnonymousMatchData: Decodable {
    public let id: Int
    public let status: String?
    public let mode: String?
    public let chat_id: Int?
    public let alias_self: String?
    public let alias_partner: String?
}

private struct AnonymousStatusResponse: Decodable {
    let data: AnonymousMatchData?
}

public final class AnonymousMatchService {
    let base: URL
    public init(baseURL: URL? = nil) { self.base = baseURL ?? AppConfig.BASE_URL }

    public func status(token: String) async throws -> AnonymousMatchData? {
        var req = URLRequest(url: base.appendingPathComponent("v1/anonymous/status"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AnonymousStatusResponse.self, from: data).data
    }

    public func join(gender: String, matchGender: String, mode: String, token: String) async throws -> AnonymousMatchData? {
        var req = URLRequest(url: base.appendingPathComponent("v1/anonymous/join"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "gender": gender, "match_gender": matchGender, "mode": mode
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AnonymousStatusResponse.self, from: data).data
    }

    public func leave(token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/anonymous/leave"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func report(id: Int, reason: String? = nil, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/anonymous/\(id)/report"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        if let reason {
            req.httpBody = try JSONSerialization.data(withJSONObject: ["reason": reason])
        }
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func end(id: Int, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/anonymous/\(id)/end"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
