import Combine
import Foundation
import os

@MainActor
final class UsageMonitor: ObservableObject {
    @Published var statusText: String = "Starting…"
    @Published var lastPoll: Date?
    @Published var notificationWarning: String?

    private var seen: Set<String> = []
    private var isFirstRun = true
    private var timer: Timer?
    private let client = CursorUsageClient()
    private let interval: TimeInterval = 60
    private let log = Logger(subsystem: "io.github.marsvogel.PromptQuittung", category: "monitor")

    func start() {
        guard timer == nil else { return }
        Notifier.requestAuthorization()
        Task { await poll() }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.poll() }
        }
    }

    func poll() async {
        do {
            let cred = try CursorAuth.currentCredential()
            let events = try await client.fetchEvents(cookieHeader: cred.cookieHeader)
            let wasFirstRun = isFirstRun
            let (toNotify, updated) = UsageDiff.detect(events: events, seen: seen, isFirstRun: isFirstRun)
            seen = updated
            isFirstRun = false
            for event in toNotify {
                Notifier.notify(event: event)
                let title = event.notificationTitle
                log.notice("notify: \(title, privacy: .public) · \(event.notificationBody, privacy: .public)")
            }
            lastPoll = Date()
            statusText = "OK · \(events.count) events · \(toNotify.count) new"
            let seedSuffix = wasFirstRun ? " (seed)" : ""
            log.notice("poll ok: \(events.count) events, \(toNotify.count) new\(seedSuffix, privacy: .public)")
        } catch {
            statusText = statusMessage(for: error)
            log.error("poll error: \(self.statusText, privacy: .public)")
        }
        notificationWarning = await Notifier.authorizationProblem()
        if let warning = notificationWarning {
            log.error("notification warning: \(warning, privacy: .public)")
        }
    }

    private func statusMessage(for error: Error) -> String {
        switch error {
        case CursorDatabaseError.notFound: return "Cursor app not found / not logged in"
        case CursorAuthError.expired: return "Token expired – reopen Cursor"
        case CursorClientError.notLoggedIn: return "Session invalid (401/403)"
        default: return "Error: \(error)"
        }
    }
}
