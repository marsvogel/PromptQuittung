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
            Text("Last poll: \(last.formatted(date: .omitted, time: .standard))")
        }
        Divider()
        Button("Poll now") { Task { await monitor.poll() } }
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}
