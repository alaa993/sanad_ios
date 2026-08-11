import Foundation

public struct PushPreferences: Decodable {
    public let push_enabled: Bool?
}

public final class PushDeviceService {
    let base: URL

    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func register(token: String, platform: String, authToken: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/devices"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + authToken, forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = ["token": token, "platform": platform]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func unregister(deviceToken: String, authToken: String) async {
        var req = URLRequest(url: base.appendingPathComponent("v1/devices"))
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + authToken, forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["token": deviceToken])
        _ = try? await URLSession.shared.data(for: req)
    }

    public func preferences(token: String) async throws -> Bool {
        var req = URLRequest(url: base.appendingPathComponent("v1/push-preferences"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(PushPreferences.self, from: data)
        return decoded.push_enabled ?? true
    }

    public func updatePreferences(enabled: Bool, token: String) async throws -> Bool {
        var req = URLRequest(url: base.appendingPathComponent("v1/push-preferences"))
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["push_enabled": enabled])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(PushPreferences.self, from: data)
        return decoded.push_enabled ?? enabled
    }
}
