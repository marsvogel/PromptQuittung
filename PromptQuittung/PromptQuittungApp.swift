import SwiftUI

@main
struct PromptQuittungApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("PromptQuittung", image: "MenuBarIcon") {
            MenuContent(monitor: appDelegate.monitor)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    @ObservedObject var monitor: UsageMonitor

    var body: some View {
        Text(monitor.statusText)
        if let last = monitor.lastPoll {
            Text("Letzter Poll: \(last.formatted(date: .omitted, time: .standard))")
        }
        Divider()
        Button("Jetzt pollen") { Task { await monitor.poll() } }
        Button("Beenden") { NSApplication.shared.terminate(nil) }
    }
}
