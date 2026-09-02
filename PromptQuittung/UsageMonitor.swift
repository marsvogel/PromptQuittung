import Combine
import Foundation
import os

@MainActor
final class UsageMonitor: ObservableObject {
    @Published var statusText: String = "Starting…"
    @Published var lastPoll: Date?
    @Published var notificationWarning: String?
    // Spent so far this calendar month; nil until the first successful fetch.
    @Published var monthToDateCost: Double?
    // Why the month total is missing. `statusText` cannot carry this: by the time the month fetch
    // runs it already reads "OK", and a failing month fetch does not make the poll itself a
    // failure — without its own line the whole feature would fail invisibly.
    @Published var monthToDateWarning: String?

    // Menu bar: whole dollars. Menu: the exact amount.
    var monthToDateShort: String? { monthToDateCost.map(Money.usdRounded) }
    var monthToDateExact: String? { monthToDateCost.map(Money.usd) }

    private var seen: Set<String> = []
    private var isFirstRun = true
    private var isPolling = false
    private var timer: Timer?
    var lastMonthToDateRefresh: Date?
    private let client = CursorUsageClient()
    // Injectable so a test can drive the path where the poll fails before it ever gets to the
    // month total. In production it reads the session of the locally installed Cursor.
    var credential: () throws -> CursorCredential = { try CursorAuth.currentCredential() }
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
        // A poll spans several awaits and can outlast the timer interval; without this guard the
        // timer and the "Poll now" button stack up overlapping runs that interleave at every
        // suspension point — duplicating the month fetch and letting an older run overwrite the
        // status of a newer one.
        guard !isPolling else { return }
        isPolling = true
        defer { isPolling = false }
        // Ahead of the fetch, because the fetch is what fails: dropping a past month's total only
        // inside `refreshMonthToDate` never happens while polls keep failing (expired token,
        // Cursor closed, no network), leaving last month's amount frozen under "This month" for
        // the whole of the new one.
        dropMonthToDateIfFromAPastMonth(now: Date())
        do {
            let cred = try credential()
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
            // After the status, so a slow month fetch cannot delay the poll result in the menu.
            await refreshMonthToDate(cookieHeader: cred.cookieHeader, newEvents: toNotify)
        } catch {
            statusText = statusMessage(for: error)
            log.error("poll error: \(self.statusText, privacy: .public)")
        }
        notificationWarning = await Notifier.authorizationProblem()
        if let warning = notificationWarning {
            log.error("notification warning: \(warning, privacy: .public)")
        }
    }

    // Keeps the menu bar figure current without refetching a whole month on every poll: between
    // full refetches the events this poll already found are simply added to the running total,
    // which reacts immediately and costs no extra request. The periodic refetch reconciles drift.
    // A failure within the current month leaves the previous total in place — a stale amount beats
    // a blank menu bar — and reports itself through `monthToDateWarning`.
    private func refreshMonthToDate(cookieHeader: String, newEvents: [UsageEvent]) async {
        let now = Date()
        // Again here: the rollover can fall between the check opening the poll and this fetch.
        dropMonthToDateIfFromAPastMonth(now: now)
        guard MonthToDate.needsRefresh(lastRefresh: lastMonthToDateRefresh, now: now) else {
            // Guarded because assigning an unchanged total still republishes it, redrawing the
            // menu bar label once a minute for nothing. Adding no events is the identity.
            if !newEvents.isEmpty {
                monthToDateCost = MonthToDate.adding(newEvents, to: monthToDateCost, now: now)
            }
            return
        }
        do {
            let events = try await client.fetchEvents(cookieHeader: cookieHeader,
                                                      from: MonthToDate.startOfMonth(containing: now),
                                                      to: now)
            monthToDateCost = MonthToDate.totalCost(of: events)
            lastMonthToDateRefresh = now
            monthToDateWarning = nil
            log.notice("month-to-date: \(events.count) events, \(self.monthToDateExact ?? "-", privacy: .public)")
        } catch {
            monthToDateWarning = "Month total unavailable: \(statusMessage(for: error))"
            log.error("month-to-date error: \(self.statusMessage(for: error), privacy: .public)")
        }
    }

    // A total fetched in a previous month is wrong rather than merely outdated: left in place it
    // reports last month's spending as this month's. So it goes the moment the month rolls over,
    // whether or not a fetch can succeed right now — an empty menu bar is honest, a stale one is
    // not. The stamp goes with it, so the total cannot be revived by `adding(_:to:)` and the next
    // successful poll refetches the new month.
    func dropMonthToDateIfFromAPastMonth(now: Date) {
        guard MonthToDate.belongsToAPastMonth(lastRefresh: lastMonthToDateRefresh, now: now) else { return }
        monthToDateCost = nil
        lastMonthToDateRefresh = nil
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
