import XCTest
@testable import PromptQuittung

@MainActor
final class UsageMonitorTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    // A stamp inside the month before the one we are in right now. The monitor reads the clock
    // itself, so the fixture has to be relative to the real "now" rather than a fixed date.
    private func lastMonth() throws -> Date {
        let start = MonthToDate.startOfMonth(containing: Date(), calendar: calendar)
        return try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: start))
    }

    // MARK: dropMonthToDateIfFromAPastMonth

    func testDroppingClearsATotalFetchedLastMonth() throws {
        let monitor = UsageMonitor()
        monitor.monthToDateCost = 431
        monitor.lastMonthToDateRefresh = try lastMonth()

        monitor.dropMonthToDateIfFromAPastMonth(now: Date())

        XCTAssertNil(monitor.monthToDateCost)
        // The stamp goes too, so the cleared total cannot be revived by folding in new events.
        XCTAssertNil(monitor.lastMonthToDateRefresh)
    }

    func testDroppingKeepsATotalFetchedThisMonth() {
        let monitor = UsageMonitor()
        monitor.monthToDateCost = 431
        monitor.lastMonthToDateRefresh = Date()

        monitor.dropMonthToDateIfFromAPastMonth(now: Date())

        XCTAssertEqual(try XCTUnwrap(monitor.monthToDateCost), 431, accuracy: 0.0001)
    }

    // MARK: poll

    func testAPollThatCannotReachCursorStillDropsLastMonthsTotal() async throws {
        // The regression this guards: the rollover check used to sit inside the month refresh,
        // which a failing poll never reaches. With Cursor unreadable across a month boundary the
        // menu bar kept showing last month's spending as this month's, indefinitely.
        let monitor = UsageMonitor()
        monitor.monthToDateCost = 431
        monitor.lastMonthToDateRefresh = try lastMonth()
        monitor.credential = { throw CursorDatabaseError.queryFailed }

        await monitor.poll()

        XCTAssertNil(monitor.monthToDateCost)
        XCTAssertEqual(monitor.statusText, "Error: queryFailed")
    }

    func testAFailingPollWithinTheMonthKeepsTheTotal() async {
        // Within the month a stale amount is still better than a blank menu bar.
        let monitor = UsageMonitor()
        monitor.monthToDateCost = 431
        monitor.lastMonthToDateRefresh = Date()
        monitor.credential = { throw CursorDatabaseError.queryFailed }

        await monitor.poll()

        XCTAssertEqual(try XCTUnwrap(monitor.monthToDateCost), 431, accuracy: 0.0001)
    }
}
