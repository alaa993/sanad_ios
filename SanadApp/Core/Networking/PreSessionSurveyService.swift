import Foundation

public struct PreSessionQuestion: Decodable, Identifiable {
    public let id: String
    public let label_ar: String?
    public let label_en: String?
    public let type: String?

    public func label(for languageCode: String) -> String {
        if languageCode == "ar", let ar = label_ar, !ar.isEmpty { return ar }
        if let en = label_en, !en.isEmpty { return en }
        return label_ar ?? label_en ?? id
    }
}

public struct PreSessionSurveyResponse: Decodable {
    public let questions: [PreSessionQuestion]?
    public let completed: Bool?
    public let answers: [String: String]?
}

public struct PreSessionSurveySubmitResponse: Decodable {
    public let saved: Bool?
    public let completed_at: String?
}

public final class PreSessionSurveyService {
    private let base: URL
    private let session: URLSession

    public init(baseURL: URL? = nil, session: URLSession = .shared) {
        self.base = baseURL ?? AppConfig.BASE_URL
        self.session = session
    }

    public func fetch(token: String) async throws -> PreSessionSurveyResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/patient/pre-session-survey"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PreSessionSurveyResponse.self, from: data)
    }

    public func submit(answers: [String: String], token: String) async throws -> PreSessionSurveySubmitResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/patient/pre-session-survey"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["answers": answers])
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PreSessionSurveySubmitResponse.self, from: data)
    }
}
