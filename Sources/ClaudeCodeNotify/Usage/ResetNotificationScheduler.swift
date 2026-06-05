import Foundation
import UserNotifications

enum ResetNotificationScheduler {
    private static let id5h = "ccnotify-reset-5h"
    private static let id7d = "ccnotify-reset-7d"

    static func schedule(from usage: UsageData) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            scheduleReset(id: id5h, resetDate: usage.reset5h, utilization: usage.util5h, label: "5-hour")
            scheduleReset(id: id7d, resetDate: usage.reset7d, utilization: usage.util7d, label: "7-day")
        }
    }

    private static func scheduleReset(id: String, resetDate: Date?, utilization: Double, label: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard utilization > 0, let date = resetDate, date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Claude Code limit reset"
        content.body = "Your \(label) usage limit has reset. You're good to go."
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
