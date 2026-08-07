import SwiftUI

@main
struct PromptQuittungApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(monitor: appDelegate.monitor)
        } label: {
            MenuBarLabel(monitor: appDelegate.monitor)
        }
        .menuBarExtraStyle(.menu)
    }
}

// Owl plus the amount spent this calendar month; icon only until the first total arrives.
struct MenuBarLabel: View {
    @ObservedObject var monitor: UsageMonitor

    var body: some View {
        HStack(spacing: 3) {
            // The custom label replaces the one MenuBarExtra's title argument used to provide.
            Image("MenuBarIcon").accessibilityLabel("PromptQuittung")
            if let monthToDate = monitor.monthToDateShort {
                Text(monthToDate)
            }
        }
    }
}

struct MenuContent: View {
    @ObservedObject var monitor: UsageMonitor

    var body: some View {
        if let monthToDate = monitor.monthToDateExact {
            Text("This month: \(monthToDate)")
        }
        Text(monitor.statusText)
        if let warning = monitor.monthToDateWarning {
            Text("⚠️ \(warning)")
        }
        if let warning = monitor.notificationWarning {
            Text("⚠️ \(warning)")
        }
        if let last = monitor.lastPoll {
            Text("Last poll: \(last.formatted(date: .omitted, time: .standard))")
        }
        Divider()
        Button("Poll now") { Task { await monitor.poll() } }
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}
