import Foundation

public struct ChatParticipant: Decodable {
    public let id: Int?
    public let name: String?
    public let role: String?
}

public struct ChatSummary: Decodable, Identifiable {
    public let id: Int
    public let subject: String?
    public let last_message: String?
    public let updated_at: String?
    public let participants: [ChatParticipant]?
    public let unread_count: Int?
}

public struct ChatMessageSender: Decodable {
    public let id: Int?
    public let name: String?
    public let role: String?
}

public struct ChatMessage: Decodable, Identifiable {
    public let id: Int
    public let chat_id: Int?
    public let sender: ChatMessageSender?
    public let type: String?
    public let body: String?
    public let created_at: String?
}

private struct ChatListResponse: Decodable {
    let data: [ChatSummary]
}

private struct ChatMessagesResponse: Decodable {
    let data: [ChatMessage]
}

private struct ApiMessageResponse: Decodable {
    let message: String?
}

private struct ChatCreateResponse: Decodable {
    let chat_id: Int
}

public enum ChatServiceError: LocalizedError {
    case server(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .server(let message):
            return message
        case .invalidResponse:
            return "تعذر الاتصال بالخادم"
        }
    }
}

/// Chat REST: thread list, messages (optional since), send text/image, create thread.
public final class ChatService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func list(token: String) async throws -> [ChatSummary] {
        var req = URLRequest(url: base.appendingPathComponent("v1/chats"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ChatServiceError.invalidResponse
        }
        return try JSONDecoder().decode(ChatListResponse.self, from: data).data
    }

    public func messages(chatId: Int, since: String?, token: String) async throws -> [ChatMessage] {
        var url = base.appendingPathComponent("v1/chats/\(chatId)/messages")
        if let since = since, !since.isEmpty {
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            comps?.queryItems = [URLQueryItem(name: "since", value: since)]
            if let updated = comps?.url { url = updated }
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ChatServiceError.invalidResponse
        }
        return try JSONDecoder().decode(ChatMessagesResponse.self, from: data).data
    }

    public func create(participantIds: [Int], subject: String?, token: String) async throws -> Int {
        var req = URLRequest(url: base.appendingPathComponent("v1/chats"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = ["participant_ids": participantIds]
        if let subject, !subject.isEmpty {
            payload["subject"] = subject
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ChatServiceError.invalidResponse
        }
        return try JSONDecoder().decode(ChatCreateResponse.self, from: data).chat_id
    }

    public func send(chatId: Int, type: String, body: String, token: String) async throws -> ChatMessage {
        var req = URLRequest(url: base.appendingPathComponent("v1/chats/\(chatId)/messages"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = [
            "type": type,
            "body": body
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw ChatServiceError.invalidResponse
        }
        if (200..<300).contains(http.statusCode) {
            return try JSONDecoder().decode(ChatMessage.self, from: data)
        }
        if let api = try? JSONDecoder().decode(ApiMessageResponse.self, from: data),
           let message = api.message {
            throw ChatServiceError.server(message)
        }
        throw ChatServiceError.invalidResponse
    }
}
