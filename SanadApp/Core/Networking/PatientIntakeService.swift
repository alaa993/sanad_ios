import Foundation

public struct PatientIntakeForm: Codable {
    public var full_name: String?
    public var age: Int?
    public var occupation: String?
    public var issue_duration: String?
    public var severity_level: String?
    public var impact_level: String?
    public var preferred_session_mode: String?
    public var risk_flags: [String]?
    public var primary_issue: String?
    public var benefit_score: Int?
    public var previous_consult: Bool?
    public var consult_notes: String?
    public var notes: String?

    enum CodingKeys: String, CodingKey {
        case full_name, age, occupation, issue_duration, severity_level, impact_level,
             preferred_session_mode, risk_flags, primary_issue, benefit_score,
             previous_consult, consult_notes, notes
    }
}

public final class PatientIntakeService {
    private let base: URL

    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func load(token: String) async throws -> PatientIntakeForm {
        var req = URLRequest(url: base.appendingPathComponent("v1/patient/intake"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PatientIntakeForm.self, from: data)
    }

    public func save(_ form: PatientIntakeForm, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/patient/intake"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(form)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
