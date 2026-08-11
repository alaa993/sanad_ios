import Foundation

/// Canonical session lifecycle phase for CTA visibility (patient + specialist).
enum SessionPhase: Equatable {
    case pending
    case waitingWindow
    case joinable
    case inProgress
    case completed
    case rejected
    case cancelled
    case unknown
}

/// Shared rules: accept / reject / join / complete / cancel + T−5 early join window.
struct SessionActionGate: Equatable {
    static let earlyJoinSeconds: TimeInterval = 5 * 60

    let phase: SessionPhase
    let canJoin: Bool
    let canAccept: Bool
    let canReject: Bool
    let canComplete: Bool
    let canCancel: Bool
    /// Localization key for join status hint under the primary CTA.
    let joinHintKey: String
    /// Seconds until join opens; 0 when already open or N/A.
    let secondsUntilJoin: TimeInterval

    static func evaluate(
        status: String?,
        scheduledAt: Date?,
        isSpecialist: Bool,
        now: Date = Date()
    ) -> SessionActionGate {
        let key = (status ?? "").lowercased()
        let closedRejected = key.contains("rejected")
        let closedCancelled = key.contains("cancel")
        let closedCompleted = key.contains("completed")
        let pending = key.contains("pending") || key.contains("requested")
        let inProgress = key.contains("in_progress") || key.contains("started")
        let acceptedLike = key.contains("accepted")
            || key.contains("confirmed")
            || key.contains("scheduled")
            || key.contains("upcoming")
            || inProgress

        if closedCompleted {
            return SessionActionGate(
                phase: .completed,
                canJoin: false,
                canAccept: false,
                canReject: false,
                canComplete: false,
                canCancel: false,
                joinHintKey: "session_join_unavailable",
                secondsUntilJoin: 0
            )
        }
        if closedRejected {
            return SessionActionGate(
                phase: .rejected,
                canJoin: false,
                canAccept: false,
                canReject: false,
                canComplete: false,
                canCancel: false,
                joinHintKey: "session_join_unavailable",
                secondsUntilJoin: 0
            )
        }
        if closedCancelled {
            return SessionActionGate(
                phase: .cancelled,
                canJoin: false,
                canAccept: false,
                canReject: false,
                canComplete: false,
                canCancel: false,
                joinHintKey: "session_join_unavailable",
                secondsUntilJoin: 0
            )
        }
        if pending {
            return SessionActionGate(
                phase: .pending,
                canJoin: false,
                canAccept: isSpecialist,
                canReject: isSpecialist,
                canComplete: false,
                canCancel: !isSpecialist,
                joinHintKey: "session_join_wait_accept",
                secondsUntilJoin: 0
            )
        }

        let withinWindow: Bool
        var secondsUntil: TimeInterval = 0
        if let scheduledAt {
            let openAt = scheduledAt.addingTimeInterval(-earlyJoinSeconds)
            withinWindow = now >= openAt
            secondsUntil = max(0, openAt.timeIntervalSince(now))
        } else {
            withinWindow = true
        }

        if inProgress {
            return SessionActionGate(
                phase: .inProgress,
                canJoin: true,
                canAccept: false,
                canReject: false,
                canComplete: isSpecialist,
                canCancel: false,
                joinHintKey: "session_join_available_now",
                secondsUntilJoin: 0
            )
        }

        if acceptedLike {
            if withinWindow {
                return SessionActionGate(
                    phase: .joinable,
                    canJoin: true,
                    canAccept: false,
                    canReject: false,
                    canComplete: isSpecialist,
                    canCancel: !isSpecialist,
                    joinHintKey: "session_join_available_now",
                    secondsUntilJoin: 0
                )
            }
            return SessionActionGate(
                phase: .waitingWindow,
                canJoin: false,
                canAccept: false,
                canReject: false,
                canComplete: false,
                canCancel: !isSpecialist,
                joinHintKey: "session_join_wait",
                secondsUntilJoin: secondsUntil
            )
        }

        return SessionActionGate(
            phase: .unknown,
            canJoin: false,
            canAccept: false,
            canReject: false,
            canComplete: false,
            canCancel: false,
            joinHintKey: "session_join_unavailable",
            secondsUntilJoin: 0
        )
    }

    static func parseIsoDate(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFrac.date(from: iso) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: iso)
    }

    static func normalizeBucket(_ status: String?) -> String {
        let key = (status ?? "").lowercased()
        if key.contains("pending") || key.contains("requested") { return "pending" }
        if key.contains("completed") { return "completed" }
        if key.contains("canceled") || key.contains("cancelled") || key.contains("rejected") { return "canceled" }
        if key.contains("scheduled") || key.contains("upcoming") || key.contains("confirmed")
            || key.contains("in_progress") || key.contains("started") || key.contains("accepted") {
            return "accepted"
        }
        return "pending"
    }
}
