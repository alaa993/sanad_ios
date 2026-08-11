import Foundation
import UserNotifications

public final class TaskReminderManager {
    public static let shared = TaskReminderManager()

    private let center = UNUserNotificationCenter.current()
    private var scheduledIdentifiers: [String] = []
    private var authorizationRequested = false

    private init() {}

    public func requestAuthorizationIfNeeded() {
        guard !authorizationRequested else { return }
        authorizationRequested = true
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func sync(upcoming: [TaskItem]) {
        requestAuthorizationIfNeeded()
        let identifiers = upcoming.map { reminderIdentifier(for: $0) }
        center.removePendingNotificationRequests(withIdentifiers: scheduledIdentifiers)
        scheduledIdentifiers = identifiers

        for task in upcoming {
            guard let due = parseDate(task.due_at) else { continue }
            let triggerDate = max(due.addingTimeInterval(-1800), Date().addingTimeInterval(5))
            guard triggerDate > Date() else { continue }
            let identifier = reminderIdentifier(for: task)
            let content = UNMutableNotificationContent()
            content.title = task.title
            let description = task.description ?? "موعد مهمة علاجية"
            content.body = description
            content.sound = .default
            let interval = max(triggerDate.timeIntervalSinceNow, 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func reminderIdentifier(for task: TaskItem) -> String {
        return "task-\(task.id)"
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw = raw else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
}
