import Foundation

public struct DirectorySpecialist: Identifiable, Decodable {
    public let id: Int
    public let name: String?
    public let avatar: String?
    public let specialty: String?
    public let category: String?
    public let tags: [String]?
    public let languages: [String]?
    public let yearsExperience: Int?
    public let rating: Double?
    public let sessionTypes: [String]?
    public let bio: [String: String]?
    public let acceptingNew: DirectoryAcceptance?

    enum CodingKeys: String, CodingKey {
        case id, name, avatar, specialty, category, tags, languages, bio
        case yearsExperience = "years_exp"
        case sessionTypes = "session_types"
        case acceptingNew = "accepting_new"
        case rating
    }
}

public enum DirectoryAcceptance: Decodable {
    case bool(Bool)
    case number(Int)
    case text(String)

    public var isAccepting: Bool {
        switch self {
        case .bool(let value): return value
        case .number(let value): return value != 0
        case .text(let value):
            let lowered = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return lowered == "1" || lowered == "true" || lowered == "yes"
        }
    }

    public var description: String {
        switch self {
        case .bool(let value): return value ? "يقبل حالات جديدة" : "لا يقبل حالياً"
        case .number(let value): return value != 0 ? "يقبل حالات جديدة" : "مغلق مؤقتاً"
        case .text(let value):
            let lowered = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if lowered == "1" || lowered == "true" || lowered == "yes" {
                return "يقبل حالات جديدة"
            } else if lowered == "0" || lowered == "false" || lowered == "no" {
                return "لا يقبل حالياً"
            }
            return value
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
            return
        }
        if let int = try? container.decode(Int.self) {
            self = .number(int)
            return
        }
        if let text = try? container.decode(String.self) {
            self = .text(text)
            return
        }
        self = .text("")
    }
}

public struct DirectoryOrganization: Identifiable, Decodable {
    public let id: Int
    public let name: String?
    public let avatar: String?
}

private struct DirectorySpecialistsResponse: Decodable {
    let data: [DirectorySpecialist]
}

private struct DirectoryOrganizationsResponse: Decodable {
    let data: [DirectoryOrganization]
}

private struct DirectorySpecialistDetailResponse: Decodable {
    let data: DirectorySpecialist
}

public final class DirectoryService {
    private let base: URL
    private let session: URLSession

    public init(baseURL: URL? = nil, session: URLSession = .shared) {
        self.base = baseURL ?? AppConfig.BASE_URL
        self.session = session
    }

    public func specialists(
        query: String? = nil,
        specialty: String? = nil,
        language: String? = nil,
        minRating: Double? = nil,
        page: Int = 1,
        token: String
    ) async throws -> [DirectorySpecialist] {
        var comps = URLComponents(url: base.appendingPathComponent("v1/specialists"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = []
        if let query = query, !query.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(URLQueryItem(name: "search", value: query))
        }
        if let specialty = specialty, !specialty.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(URLQueryItem(name: "specialty", value: specialty))
        }
        if let language = language, !language.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(URLQueryItem(name: "language", value: language))
        }
        if let minRating = minRating, minRating > 0 {
            items.append(URLQueryItem(name: "min_rating", value: String(format: "%.1f", minRating)))
        }
        items.append(URLQueryItem(name: "page", value: "\(max(page, 1))"))
        comps.queryItems = items
        let request = buildRequest(url: comps.url!, token: token)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        let decoded = try JSONDecoder().decode(DirectorySpecialistsResponse.self, from: data)
        return decoded.data
    }

    public func specialistDetail(id: Int, token: String) async throws -> DirectorySpecialist {
        let url = base.appendingPathComponent("v1/specialists/\(id)")
        let request = buildRequest(url: url, token: token)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        let decoded = try JSONDecoder().decode(DirectorySpecialistDetailResponse.self, from: data)
        return decoded.data
    }

    public func organizations(query: String? = nil, page: Int = 1, token: String) async throws -> [DirectoryOrganization] {
        var comps = URLComponents(url: base.appendingPathComponent("v1/organizations"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = []
        if let query = query, !query.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(URLQueryItem(name: "search", value: query))
        }
        items.append(URLQueryItem(name: "page", value: "\(max(page, 1))"))
        comps.queryItems = items
        let request = buildRequest(url: comps.url!, token: token)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        let decoded = try JSONDecoder().decode(DirectoryOrganizationsResponse.self, from: data)
        return decoded.data
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func buildRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        return request
    }
}
