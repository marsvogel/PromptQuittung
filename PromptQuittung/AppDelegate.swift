import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let monitor = UsageMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in monitor.start() }
        // Diagnostic mode: fire a synthetic notification every 30s without user interaction
        // to probe the system delivery path (launch with -PQTestNotify).
        if ProcessInfo.processInfo.arguments.contains("-PQTestNotify") {
            Task {
                var sequence = 0
                while true {
                    try? await Task.sleep(for: .seconds(30))
                    sequence += 1
                    Notifier.notifyTest(sequence: sequence)
                }
            }
        }
    }

    // Also show notifications while the app is "active".
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                    @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
