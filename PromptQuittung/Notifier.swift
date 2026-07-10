import Foundation
import UserNotifications

enum Notifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notify(event: UsageEvent) {
        let content = UNMutableNotificationContent()
        content.title = event.notificationTitle
        content.body = event.notificationBody
        content.sound = .default
        // Das linke Icon der Notification ist automatisch das App-Icon aus dem Bundle
        // (nicht per Code setzbar) — dafür sorgt das AppIcon im Asset-Katalog.
        let request = UNNotificationRequest(identifier: event.dedupKey, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
