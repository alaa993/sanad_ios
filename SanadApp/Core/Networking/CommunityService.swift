import Foundation

public struct CommunitySummary: Decodable, Identifiable {
    public let id: Int
    public let slug: String?
    public let name: String?
    public let about: String?
    public let visibility: String?
    public let kind: String?
    public let category: String?
    public var members_count: Int?
    public var joined: Bool?
    public var organization_owned: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, slug, name, about, visibility, kind, category, members_count, joined, organization_owned
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        name = decodeLocalizedString(container, key: .name)
        about = decodeLocalizedString(container, key: .about)
        visibility = try container.decodeIfPresent(String.self, forKey: .visibility)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        members_count = try container.decodeIfPresent(Int.self, forKey: .members_count)
        joined = try container.decodeIfPresent(Bool.self, forKey: .joined)
        organization_owned = try container.decodeIfPresent(Bool.self, forKey: .organization_owned)
    }
}

private struct LocalizedValue: Decodable {
    let value: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
            return
        }
        if let map = try? container.decode([String: String].self) {
            value = localizedValue(map)
            return
        }
        value = nil
    }
}

private func decodeLocalizedString<T: CodingKey>(_ container: KeyedDecodingContainer<T>, key: T) -> String? {
    if let string = try? container.decodeIfPresent(String.self, forKey: key) {
        return string
    }
    if let localized = try? container.decodeIfPresent(LocalizedValue.self, forKey: key) {
        return localized.value
    }
    return nil
}

private func localizedValue(_ map: [String: String]) -> String? {
    let lang = AppLanguage.currentCode
    if let value = map[lang] { return value }
    if let value = map["ar"] { return value }
    if let value = map["en"] { return value }
    return map.values.first
}

public enum CommunityServiceError: Error {
    case unauthorized
    case forbidden
    case invalidStatus(code: Int)
    case decoding(Error)
}

private struct CommunityListResponse: Decodable { let data: [CommunitySummary] }
public struct CommunityJoinLeaveResponse: Decodable { let joined: Bool?; let members_count: Int? }

public struct CommunityPost: Identifiable, Decodable {
    public let id: Int
    public let body: String
    public let media_url: String?
    public let type: String?
    public let post_kind: String?
    public let question_id: Int?
    public let accepted_at: String?
    public let author: Author
    public let created_at: String?
    public let likes_count: Int?
    public let liked: Bool?
    public let comments: [Comment]?
    public let answers: [CommunityPost]?
    public let answers_count: Int?
    public let accepted_answer_id: Int?

    public struct Author: Decodable {
        public let id: Int?
        public let name: String?
    }

    public struct Comment: Identifiable, Decodable {
        public let id: Int
        public let body: String
        public let author: Author
        public let created_at: String?
    }
}

public struct CommunityFeedResponse: Decodable {
    public let data: [CommunityPost]
    public let kind: String?
}

/// Community REST: list, join, feed, post, like, comment, accept-answer (mirrors Android CommunityRepository).
public final class CommunityService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func list(token: String, category: String? = nil) async throws -> [CommunitySummary] {
        var components = URLComponents(url: base.appendingPathComponent("v1/community"), resolvingAgainstBaseURL: false)
        if let category, !category.isEmpty {
            components?.queryItems = [URLQueryItem(name: "category", value: category)]
        }
        guard let url = components?.url else { throw CommunityServiceError.invalidStatus(code: 0) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let http = resp as? HTTPURLResponse
        if let status = http?.statusCode, !(200..<300).contains(status) {
            switch status {
            case 401: throw CommunityServiceError.unauthorized
            case 403: throw CommunityServiceError.forbidden
            default: throw CommunityServiceError.invalidStatus(code: status)
            }
        }
        do {
            let decoded = try JSONDecoder().decode(CommunityListResponse.self, from: data)
            return decoded.data
        } catch {
            throw CommunityServiceError.decoding(error)
        }
    }

    public func join(communityId: Int, token: String) async throws -> CommunityJoinLeaveResponse {
        return try await postMembership(path: "v1/community/\(communityId)/join", token: token)
    }

    public func leave(communityId: Int, token: String) async throws -> CommunityJoinLeaveResponse {
        return try await postMembership(path: "v1/community/\(communityId)/leave", token: token)
    }

    private func postMembership(path: String, token: String) async throws -> CommunityJoinLeaveResponse {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let http = resp as? HTTPURLResponse
        if let status = http?.statusCode, !(200..<300).contains(status) {
            switch status {
            case 401: throw CommunityServiceError.unauthorized
            case 403: throw CommunityServiceError.forbidden
            default: throw CommunityServiceError.invalidStatus(code: status)
            }
        }
        do {
            return try JSONDecoder().decode(CommunityJoinLeaveResponse.self, from: data)
        } catch {
            throw CommunityServiceError.decoding(error)
        }
    }

    public func feed(communityId: Int, token: String) async throws -> (posts: [CommunityPost], kind: String?) {
        var req = URLRequest(url: base.appendingPathComponent("v1/community/\(communityId)/feed"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let http = resp as? HTTPURLResponse
        if let status = http?.statusCode, !(200..<300).contains(status) {
            switch status {
            case 401: throw CommunityServiceError.unauthorized
            case 403: throw CommunityServiceError.forbidden
            default: throw CommunityServiceError.invalidStatus(code: status)
            }
        }
        do {
            let decoded = try JSONDecoder().decode(CommunityFeedResponse.self, from: data)
            return (decoded.data, decoded.kind)
        } catch {
            throw CommunityServiceError.decoding(error)
        }
    }

    public func post(communityId: Int, body: String, type: String?, mediaUrl: String? = nil, postKind: String? = nil, questionId: Int? = nil, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/community/\(communityId)/post"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = ["body": body]
        if let t = type { payload["type"] = t }
        if let media = mediaUrl, !media.isEmpty { payload["media_url"] = media }
        if let pk = postKind { payload["post_kind"] = pk }
        if let q = questionId { payload["question_id"] = q }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        let http = resp as? HTTPURLResponse
        if let status = http?.statusCode, !(200..<300).contains(status) {
            switch status {
            case 401: throw CommunityServiceError.unauthorized
            case 403: throw CommunityServiceError.forbidden
            default: throw CommunityServiceError.invalidStatus(code: status)
            }
        }
    }

    public func acceptAnswer(communityId: Int, questionId: Int, answerId: Int, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/community/\(communityId)/question/\(questionId)/accept/\(answerId)"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        let http = resp as? HTTPURLResponse
        if let status = http?.statusCode, !(200..<300).contains(status) {
            throw CommunityServiceError.invalidStatus(code: status)
        }
    }

    public func like(communityId: Int, postId: Int, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/community/\(communityId)/post/\(postId)/like"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        let http = resp as? HTTPURLResponse
        if let status = http?.statusCode, !(200..<300).contains(status) {
            switch status {
            case 401: throw CommunityServiceError.unauthorized
            case 403: throw CommunityServiceError.forbidden
            default: throw CommunityServiceError.invalidStatus(code: status)
            }
        }
    }

    public func comment(communityId: Int, postId: Int, text: String, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/community/\(communityId)/post/\(postId)/comment"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["body": text])
        let (_, resp) = try await URLSession.shared.data(for: req)
        let http = resp as? HTTPURLResponse
        if let status = http?.statusCode, !(200..<300).contains(status) {
            switch status {
            case 401: throw CommunityServiceError.unauthorized
            case 403: throw CommunityServiceError.forbidden
            default: throw CommunityServiceError.invalidStatus(code: status)
            }
        }
    }

    public func create(slug: String, nameAr: String, nameEn: String?, about: String?, visibility: String, kind: String, token: String) async throws -> Int {
        var req = URLRequest(url: base.appendingPathComponent("v1/community"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var name: [String: String] = ["ar": nameAr]
        if let nameEn, !nameEn.isEmpty { name["en"] = nameEn }
        var payload: [String: Any] = [
            "slug": slug,
            "name": name,
            "visibility": visibility,
            "kind": kind
        ]
        if let about, !about.isEmpty {
            payload["about"] = ["ar": about]
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let http = resp as? HTTPURLResponse
        if let status = http?.statusCode, !(200..<300).contains(status) {
            throw CommunityServiceError.invalidStatus(code: status)
        }
        struct CreateResponse: Decodable { let id: Int }
        return try JSONDecoder().decode(CreateResponse.self, from: data).id
    }
}
