import Foundation
import os
import UserNotifications

enum Notifier {
    private static let log = Logger(subsystem: "io.github.marsvogel.PromptQuittung", category: "notifier")

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                log.error("requestAuthorization failed: \(error, privacy: .public)")
            } else {
                log.notice("requestAuthorization granted: \(granted, privacy: .public)")
            }
        }
    }

    // Returns a short problem description when the system will not deliver our
    // notifications (e.g. permission denied, or an unsigned binary the daemon
    // rejects — then the status never leaves .notDetermined), nil when all is fine.
    static func authorizationProblem() async -> String? {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return nil
        case .denied: return "Notifications denied – enable in System Settings"
        case .notDetermined: return "Notifications not authorized"
        @unknown default: return "Notifications in unknown state"
        }
    }

    static func notify(event: UsageEvent) {
        let content = UNMutableNotificationContent()
        content.title = event.notificationTitle
        content.body = event.notificationBody
        content.sound = .default
        // The icon on the left of the notification is automatically the app icon from the bundle
        // (not settable via code) — the AppIcon in the asset catalog takes care of that.
        deliver(identifier: event.dedupKey, content: content)
    }

    // Diagnostic path: posts a synthetic notification to test delivery without a real usage event.
    static func notifyTest(sequence: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Test notification #\(sequence)"
        content.body = "Delivery-path diagnostic"
        content.sound = .default
        deliver(identifier: "test-\(sequence)", content: content)
    }

    private static func deliver(identifier: String, content: UNNotificationContent) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let auth = settings.authorizationStatus.rawValue
            let alert = settings.alertSetting.rawValue
            log.notice("pre-add settings: auth=\(auth, privacy: .public) alert=\(alert, privacy: .public)")
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            center.add(request) { error in
                if let error {
                    log.error("add failed for \(identifier, privacy: .public): \(error, privacy: .public)")
                } else {
                    log.notice("add succeeded for \(identifier, privacy: .public)")
                }
            }
        }
    }
}
