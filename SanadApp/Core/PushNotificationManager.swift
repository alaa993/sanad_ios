import Foundation
import UserNotifications
import UIKit

public enum PushDeepLink: Equatable {
    case sessionDetail(id: Int)
    case bookSpecialist(id: Int?)
    case specialists
}

extension Notification.Name {
    static let sanadPushDeepLink = Notification.Name("sanad.pushDeepLink")
}

public final class PushNotificationManager: NSObject {
    public static let shared = PushNotificationManager()

    private let service = PushDeviceService()
    private var pendingToken: String?

    private override init() {
        super.init()
    }

    public func registerIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    public func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        pendingToken = token
        Task { await uploadPendingToken() }
    }

    public func handleRegistrationFailure(_ error: Error) {
        NSLog("APNs registration failed: %@", error.localizedDescription)
    }

    public func uploadPendingToken() async {
        guard let token = pendingToken,
              let auth = KeychainHelper.getToken() else { return }
        do {
            try await service.register(token: token, platform: "ios", authToken: auth)
        } catch {
            NSLog("Push token upload failed: %@", error.localizedDescription)
        }
    }

    public func loadPreferences() async -> Bool {
        guard let auth = KeychainHelper.getToken() else { return true }
        return (try? await service.preferences(token: auth)) ?? true
    }

    public func updatePreferences(_ enabled: Bool) async -> Bool {
        guard let auth = KeychainHelper.getToken() else { return enabled }
        return (try? await service.updatePreferences(enabled: enabled, token: auth)) ?? enabled
    }

    public func unregisterBeforeLogout(authToken: String) async {
        guard let token = pendingToken else { return }
        await service.unregister(deviceToken: token, authToken: authToken)
        pendingToken = nil
    }

    public func handleNotificationResponse(_ userInfo: [AnyHashable: Any]) {
        guard let route = parseDeepLink(from: userInfo) else { return }
        NotificationCenter.default.post(name: .sanadPushDeepLink, object: route)
    }

    private func parseDeepLink(from userInfo: [AnyHashable: Any]) -> PushDeepLink? {
        let payload = flattenedPayload(from: userInfo)
        let type = stringValue(payload["type"])?.lowercased()
        switch type {
        case "session", "transfer", "session_reminder", "appointment_reminder":
            if let sessionId = intValue(payload["session_id"]) {
                return .sessionDetail(id: sessionId)
            }
        case "physician_referral":
            let specialistId = intValue(payload["specialist_id"])
            return .bookSpecialist(id: specialistId)
        default:
            // Fallback: session_id alone should still open the session.
            if let sessionId = intValue(payload["session_id"]) {
                return .sessionDetail(id: sessionId)
            }
        }
        return nil
    }

    /// APNs may nest custom fields under `data`; FCM/Android usually sends them top-level.
    private func flattenedPayload(from userInfo: [AnyHashable: Any]) -> [String: Any] {
        var payload: [String: Any] = [:]
        for (key, value) in userInfo {
            guard let key = key as? String else { continue }
            payload[key] = value
        }
        if let nested = userInfo["data"] as? [String: Any] {
            for (key, value) in nested {
                if payload[key] == nil { payload[key] = value }
            }
        } else if let nested = userInfo["data"] as? [AnyHashable: Any] {
            for (key, value) in nested {
                guard let key = key as? String else { continue }
                if payload[key] == nil { payload[key] = value }
            }
        }
        return payload
    }

    private func stringValue(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let text = value as? String { return Int(text) }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }
}
