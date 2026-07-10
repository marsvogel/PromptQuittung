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
        // The icon on the left of the notification is automatically the app icon from the bundle
        // (not settable via code) — the AppIcon in the asset catalog takes care of that.
        let request = UNNotificationRequest(identifier: event.dedupKey, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
