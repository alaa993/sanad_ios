import Foundation
import Combine

public enum RealtimeEvent {
    case chatMessage(chatId: Int, message: ChatMessage)
    case communityPost(communityId: Int, post: CommunityPost)
    case communityComment(communityId: Int, postId: Int, comment: CommunityPost.Comment)
    case communityLike(communityId: Int, postId: Int, likesCount: Int?, liked: Bool?)
    case sessionStatus(sessionId: Int, status: String, meta: [String: Any]?)
    case notification(type: String, data: [String: Any]?)
    case groupPresence(groupId: Int, count: Int)
}

/// Shared Socket.IO client for chat, sessions, community, library, and notifications.
/// Uses Engine.IO long-poll by default (`usePolling`); screens join rooms after REST loads via AuthGate.
@MainActor
public final class RealtimeSocket {
    public static let shared = RealtimeSocket()

    public let events = PassthroughSubject<RealtimeEvent, Never>()
    @Published public private(set) var isConnected = false

    private var task: URLSessionWebSocketTask?
    private var pollTask: Task<Void, Never>?
    private var socketReady = false
    private var retryCount = 0
    private var engineSid: String?
    private var usePolling = true

    private var userId: String?
    private var role: String?
    private var token: String?
    private var joinedRooms: Set<String> = []
    private var pendingRooms: Set<String> = []
    private var pendingSessions: Set<Int> = []
    private var pendingGroups: Set<Int> = []

    private init() {}

    public func connect(userId: String, role: String?, token: String) {
        disconnect()
        self.userId = userId
        self.role = role
        self.token = token
        self.retryCount = 0
        usePolling = true
        pollTask = Task { await beginPollingTransport() }
    }

    public func disconnect() {
        pollTask?.cancel()
        pollTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        engineSid = nil
        socketReady = false
        isConnected = false
        joinedRooms.removeAll()
        pendingRooms.removeAll()
        pendingSessions.removeAll()
        pendingGroups.removeAll()
    }

    private func beginPollingTransport() async {
        guard let url = buildTransportURL(transport: "polling") else {
            scheduleReconnect()
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let text = String(data: data, encoding: .utf8) else {
                scheduleReconnect()
                return
            }
            let packets = parsePollingResponse(text)
            guard let sid = packets.compactMap(parseSid).first else {
                scheduleReconnect()
                return
            }
            engineSid = sid
            packets.forEach(processPacket)
            if !socketReady {
                try await postPollingPacket("40")
            }
            if !socketReady {
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            socketReady = true
            isConnected = true
            flushPendingRooms()
            startPollingLoop()
        } catch {
            scheduleReconnect()
        }
    }

    private func startPollingLoop() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled, socketReady, let sid = engineSid {
                guard let url = buildTransportURL(transport: "polling", sid: sid) else { break }
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if Task.isCancelled { break }
                    if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                        parsePollingResponse(text).forEach(processPacket)
                    }
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run { self.scheduleReconnect() }
                    }
                    break
                }
            }
        }
    }

    private func buildTransportURL(transport: String, sid: String? = nil) -> URL? {
        guard var comps = URLComponents(url: AppConfig.REALTIME_URL, resolvingAgainstBaseURL: false) else { return nil }
        if comps.scheme == "https" { comps.scheme = transport == "websocket" ? "wss" : "https" }
        if comps.scheme == "http" { comps.scheme = transport == "websocket" ? "ws" : "http" }
        comps.path = "/socket/"
        var items = [
            URLQueryItem(name: "EIO", value: "4"),
            URLQueryItem(name: "transport", value: transport),
            URLQueryItem(name: "userId", value: userId ?? ""),
            URLQueryItem(name: "role", value: role ?? ""),
            URLQueryItem(name: "token", value: token ?? "")
        ]
        if let sid { items.append(URLQueryItem(name: "sid", value: sid)) }
        comps.queryItems = items
        return comps.url
    }

    private func postPollingPacket(_ packet: String) async throws {
        guard let sid = engineSid, let url = buildTransportURL(transport: "polling", sid: sid) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = packet.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            parsePollingResponse(text).forEach(processPacket)
        }
    }

    private func parsePollingResponse(_ text: String) -> [String] {
        var packets: [String] = []
        var remaining = Substring(text)
        while !remaining.isEmpty {
            guard let colon = remaining.firstIndex(of: ":"),
                  let length = Int(remaining[..<colon]),
                  length >= 0 else {
                packets.append(String(remaining))
                break
            }
            let start = remaining.index(after: colon)
            guard let end = remaining.index(start, offsetBy: length, limitedBy: remaining.endIndex) else {
                packets.append(String(remaining))
                break
            }
            packets.append(String(remaining[start..<end]))
            remaining = remaining[end...]
        }
        return packets
    }

    private func parseSid(from packet: String) -> String? {
        guard packet.first == "0" else { return nil }
        let json = String(packet.dropFirst())
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sid = obj["sid"] as? String else { return nil }
        return sid
    }

    private func processPacket(_ text: String) {
        guard !text.isEmpty else { return }
        let type = text.first
        switch type {
        case "0":
            if let sid = parseSid(from: text) { engineSid = sid }
        case "2":
            Task { try? await postPollingPacket("3") }
        case "4":
            handleSocketIO(String(text.dropFirst()))
        default:
            break
        }
    }

    private func handleSocketIO(_ payload: String) {
        if payload.hasPrefix("0") {
            socketReady = true
            isConnected = true
            flushPendingRooms()
            return
        }
        if payload.hasPrefix("2") {
            processEvent(String(payload.dropFirst()))
        }
    }

    public func reconnectIfNeeded(userId: String, role: String?, token: String) {
        if socketReady, engineSid != nil { return }
        connect(userId: userId, role: role, token: token)
    }

    private func processEvent(_ body: String) {
        guard let data = body.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let name = arr.first as? String else { return }
        let payload = arr.count > 1 ? arr[1] : nil
        switch name {
        case "socket:ready":
            socketReady = true
            isConnected = true
            flushPendingRooms()
        case "chat:message":
            if let dict = payload as? [String: Any],
               let chatId = extractChatId(from: dict),
               let message = decodeChatMessage(from: dict) {
                events.send(.chatMessage(chatId: chatId, message: message))
            }
        case "community:post":
            if let dict = payload as? [String: Any],
               let communityId = extractInt(from: dict["communityId"]) ?? extractInt(from: dict["community_id"]),
               let postDict = dict["post"] as? [String: Any],
               let post = decodeCommunityPost(from: postDict) {
                events.send(.communityPost(communityId: communityId, post: post))
            }
        case "community:comment":
            if let dict = payload as? [String: Any],
               let communityId = extractInt(from: dict["communityId"]) ?? extractInt(from: dict["community_id"]),
               let postId = extractInt(from: dict["postId"]) ?? extractInt(from: dict["post_id"]),
               let commentDict = dict["comment"] as? [String: Any],
               let comment = decodeCommunityComment(from: commentDict) {
                events.send(.communityComment(communityId: communityId, postId: postId, comment: comment))
            }
        case "community:like":
            if let dict = payload as? [String: Any],
               let communityId = extractInt(from: dict["communityId"]) ?? extractInt(from: dict["community_id"]),
               let postId = extractInt(from: dict["postId"]) ?? extractInt(from: dict["post_id"]) {
                let likesCount = extractInt(from: dict["likesCount"])
                let liked = dict["liked"] as? Bool
                events.send(.communityLike(communityId: communityId, postId: postId, likesCount: likesCount, liked: liked))
            }
        case "session:status":
            if let dict = payload as? [String: Any],
               let sessionId = extractInt(from: dict["sessionId"]) {
                let status = dict["status"] as? String ?? ""
                let meta = dict["meta"] as? [String: Any]
                events.send(.sessionStatus(sessionId: sessionId, status: status, meta: meta))
            }
        case "group:presence":
            if let dict = payload as? [String: Any],
               let groupId = extractInt(from: dict["groupId"]),
               let count = extractInt(from: dict["count"]) {
                events.send(.groupPresence(groupId: groupId, count: count))
            }
        case "library:updated":
            if let dict = payload as? [String: Any] {
                events.send(.notification(type: "library:updated", data: dict))
            } else {
                events.send(.notification(type: "library:updated", data: nil))
            }
        case "notify:event":
            if let dict = payload as? [String: Any],
               let type = dict["type"] as? String {
                let data = dict["data"] as? [String: Any]
                events.send(.notification(type: type, data: data))
            }
        default:
            break
        }
    }

    private func decodeChatMessage(from dict: [String: Any]) -> ChatMessage? {
        if let meta = dict["meta"] as? [String: Any],
           let message = meta["message"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: message) {
            return try? JSONDecoder().decode(ChatMessage.self, from: data)
        }
        var normalized = dict
        if normalized["body"] == nil, let content = dict["content"] {
            normalized["body"] = content
        }
        if let data = try? JSONSerialization.data(withJSONObject: normalized) {
            return try? JSONDecoder().decode(ChatMessage.self, from: data)
        }
        return nil
    }

    private func decodeCommunityPost(from dict: [String: Any]) -> CommunityPost? {
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            return try? JSONDecoder().decode(CommunityPost.self, from: data)
        }
        return nil
    }

    private func decodeCommunityComment(from dict: [String: Any]) -> CommunityPost.Comment? {
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            return try? JSONDecoder().decode(CommunityPost.Comment.self, from: data)
        }
        return nil
    }

    private func extractChatId(from dict: [String: Any]) -> Int? {
        if let id = extractInt(from: dict["chat_id"] ?? dict["chatId"]) { return id }
        if let meta = dict["meta"] as? [String: Any],
           let id = extractInt(from: meta["chatId"] ?? meta["chat_id"]) { return id }
        if let room = dict["room"] as? String, room.hasPrefix("chat_") {
            return Int(room.replacingOccurrences(of: "chat_", with: ""))
        }
        return nil
    }

    private func extractInt(from value: Any?) -> Int? {
        if let num = value as? Int { return num }
        if let str = value as? String { return Int(str) }
        return nil
    }

    private func sendEngineIO(_ payload: String) {
        Task { try? await postPollingPacket(payload) }
    }

    private func sendSocketIOEvent(_ event: String, payload: [String: Any]? = nil) {
        let arr: [Any] = payload == nil ? [event] : [event, payload!]
        guard let data = try? JSONSerialization.data(withJSONObject: arr),
              let json = String(data: data, encoding: .utf8) else { return }
        sendEngineIO("42" + json)
    }

    private func flushPendingRooms() {
        guard socketReady else { return }
        let rooms = pendingRooms
        pendingRooms.removeAll()
        for room in rooms {
            sendSocketIOEvent("join", payload: ["room": room])
            joinedRooms.insert(room)
        }
        if !pendingSessions.isEmpty {
            for id in pendingSessions {
                sendSocketIOEvent("session:join", payload: ["sessionId": id])
            }
            pendingSessions.removeAll()
        }
        if !pendingGroups.isEmpty {
            for id in pendingGroups {
                sendSocketIOEvent("group:join", payload: ["groupId": id])
            }
            pendingGroups.removeAll()
        }
    }

    /// Join a named room now, or queue until socket:ready (chat_/session_/community_).
    public func join(room: String) {
        guard !room.isEmpty else { return }
        if socketReady {
            sendSocketIOEvent("join", payload: ["room": room])
            joinedRooms.insert(room)
        } else {
            pendingRooms.insert(room)
        }
    }

    public func leave(room: String) {
        guard !room.isEmpty else { return }
        pendingRooms.remove(room)
        if socketReady {
            sendSocketIOEvent("leave", payload: ["room": room])
        }
        joinedRooms.remove(room)
    }

    public func joinChat(chatId: Int) { join(room: "chat_\(chatId)") }
    public func leaveChat(chatId: Int) { leave(room: "chat_\(chatId)") }

    public func joinSession(sessionId: Int) {
        join(room: "session_\(sessionId)")
        if socketReady {
            sendSocketIOEvent("session:join", payload: ["sessionId": sessionId])
        } else {
            pendingSessions.insert(sessionId)
        }
    }

    public func leaveSession(sessionId: Int) {
        leave(room: "session_\(sessionId)")
        pendingSessions.remove(sessionId)
        if socketReady {
            sendSocketIOEvent("session:leave", payload: ["sessionId": sessionId])
        }
    }

    public func joinGroup(groupId: Int) {
        if socketReady {
            sendSocketIOEvent("group:join", payload: ["groupId": groupId])
        } else {
            pendingGroups.insert(groupId)
        }
    }

    public func leaveGroup(groupId: Int) {
        pendingGroups.remove(groupId)
        if socketReady {
            sendSocketIOEvent("group:leave", payload: ["groupId": groupId])
        }
    }

    public func emitChatMessage(chatId: Int, content: String, type: String) {
        guard socketReady else { return }
        sendSocketIOEvent("chat:message", payload: ["room": "chat_\(chatId)", "content": content, "type": type])
    }

    /// Exponential-ish reconnect (2s * attempt, max 8) after poll/socket failure; re-queues joined rooms.
    private func scheduleReconnect() {
        guard retryCount < 8, let userId = userId, let token = token else { return }
        retryCount += 1
        let delay = Double(retryCount) * 2
        pollTask?.cancel()
        engineSid = nil
        socketReady = false
        isConnected = false
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.pendingRooms.formUnion(self.joinedRooms)
            self.joinedRooms.removeAll()
            self.connect(userId: userId, role: self.role, token: token)
        }
    }
}
