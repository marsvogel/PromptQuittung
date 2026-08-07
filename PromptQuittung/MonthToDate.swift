import Foundation

// The "spent so far this calendar month" figure shown next to the menu bar icon.
nonisolated enum MonthToDate {
    // How long a month-to-date total stays valid before it is fetched again.
    static let refreshInterval: TimeInterval = 15 * 60

    // Cursor bills on the Gregorian month, so the window must not follow the user's region
    // calendar — with Persian or Islamic selected in System Settings, `Calendar.current` would
    // start the month on a completely different day than the dashboard we are mirroring.
    // Rebuilt per access so a time zone change is picked up.
    static var billingCalendar: Calendar { Calendar(identifier: .gregorian) }

    // First instant of the calendar month containing `date`, in the calendar's time zone.
    static func startOfMonth(containing date: Date,
                             calendar: Calendar = MonthToDate.billingCalendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    // Total charged amount of the given events, in USD.
    static func totalCost(of events: [UsageEvent]) -> Double {
        events.reduce(0) { $0 + $1.displayCost }
    }

    // Keeps the running total current between full refetches, from events the poll just found.
    // A nil total stays nil: without a fetched baseline there is nothing to add to, and showing
    // only the newest events would understate the month by everything before them.
    // Only events of the current month count: shortly after midnight on the 1st the poll's
    // lookback window still reaches into the previous month, and an event arriving late from
    // there would otherwise inflate the new month by an amount that was already billed.
    static func adding(_ events: [UsageEvent],
                       to total: Double?,
                       now: Date,
                       calendar: Calendar = MonthToDate.billingCalendar) -> Double? {
        guard let total else { return nil }
        let start = startOfMonth(containing: now, calendar: calendar)
        return total + totalCost(of: events.filter { $0.date >= start })
    }

    // True when a total fetched at `lastRefresh` covers a month that has since ended. Such a total
    // is wrong rather than merely outdated, so it must not stay on screen under "this month" while
    // a refetch is pending — a refetch that then fails would leave last month's amount there.
    static func belongsToAPastMonth(lastRefresh: Date?,
                                    now: Date,
                                    calendar: Calendar = MonthToDate.billingCalendar) -> Bool {
        guard let lastRefresh else { return false }
        return lastRefresh < startOfMonth(containing: now, calendar: calendar)
    }

    // A full month of events is expensive to fetch, so it is refetched only when it can have
    // changed: never fetched yet, the total went stale, or the month rolled over. New events in
    // between are folded in by `adding(_:to:)` rather than by refetching the whole month.
    static func needsRefresh(lastRefresh: Date?,
                             now: Date,
                             calendar: Calendar = MonthToDate.billingCalendar) -> Bool {
        guard let lastRefresh else { return true }
        // A stamp in the future means the clock jumped backwards (sleep, NTP, time zone edit);
        // without this the interval below can never elapse and the total would freeze for good.
        if lastRefresh > now { return true }
        if now.timeIntervalSince(lastRefresh) >= refreshInterval { return true }
        return belongsToAPastMonth(lastRefresh: lastRefresh, now: now, calendar: calendar)
    }
}
