import Foundation
import UserNotifications

/// The optional daily reminder. Each day is its own one-off notification,
/// scheduled 30 days ahead, so today's can be dropped once it's solved and
/// each one can say how hard that day's puzzle is. The app tops the list up
/// whenever it's opened.
nonisolated enum Reminders {
    private static let prefix = "daily-"
    private static let horizon = 30

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard Settings.reminderOn else { return }
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: break
        default: return
        }

        let calendar = Calendar.current
        let today = GameStore.today
        let minutes = Settings.reminderMinutes
        let choice = Settings.difficulty
        let solvedToday = GameStore.board(for: GameStore.puzzle(for: today)).isSolved

        for offset in 0..<horizon {
            let day = today + offset
            if offset == 0 && solvedToday { continue }
            var when = calendar.dateComponents([.year, .month, .day], from: Generator.date(for: day))
            when.hour = minutes / 60
            when.minute = minutes % 60
            guard let fire = calendar.date(from: when), fire > .now else { continue }

            let level = choice.resolve(day: day)
            let content = UNMutableNotificationContent()
            content.body = "Today's puzzle is ready: \(level.title.lowercased()), \(level.size)×\(level.size)."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: prefix + String(day),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            )
            try? await center.add(request)
        }
    }

    /// Drops a day's reminder once its puzzle is solved.
    static func cancel(day: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [prefix + String(day)])
    }
}
