import XCTest
@testable import PromptQuittung

final class MonthToDateTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func event(cents: Double, at when: Date = .distantFuture) throws -> UsageEvent {
        let millis = Int64(when.timeIntervalSince1970 * 1000)
        return try JSONDecoder().decode(UsageEvent.self,
                                        from: Data(#"{"timestamp": \#(millis), "chargedCents": \#(cents)}"#.utf8))
    }

    // MARK: startOfMonth

    func testStartOfMonthIsMidnightOnTheFirst() {
        let start = MonthToDate.startOfMonth(containing: date(2026, 8, 7, 23, 59), calendar: calendar)
        XCTAssertEqual(start, date(2026, 8, 1, 0, 0))
    }

    func testStartOfMonthOnTheFirstReturnsThatDay() {
        let start = MonthToDate.startOfMonth(containing: date(2026, 8, 1, 0, 30), calendar: calendar)
        XCTAssertEqual(start, date(2026, 8, 1, 0, 0))
    }

    func testStartOfMonthCrossesTheYearBoundary() {
        let start = MonthToDate.startOfMonth(containing: date(2026, 1, 3), calendar: calendar)
        XCTAssertEqual(start, date(2026, 1, 1, 0, 0))
    }

    // MARK: totalCost

    func testTotalCostSumsChargedCentsAsDollars() throws {
        let events = [try event(cents: 250), try event(cents: 125), try event(cents: 0)]
        XCTAssertEqual(MonthToDate.totalCost(of: events), 3.75, accuracy: 0.0001)
    }

    func testTotalCostOfNoEventsIsZero() {
        XCTAssertEqual(MonthToDate.totalCost(of: []), 0)
    }

    // MARK: adding

    func testAddingFoldsNewEventsIntoTheRunningTotal() throws {
        let now = date(2026, 8, 7, 12, 0)
        let fresh = try event(cents: 250, at: date(2026, 8, 7, 11, 30))
        XCTAssertEqual(try XCTUnwrap(MonthToDate.adding([fresh], to: 10, now: now, calendar: calendar)),
                       12.5,
                       accuracy: 0.0001)
    }

    func testAddingNothingLeavesTheTotalUntouched() throws {
        let now = date(2026, 8, 7, 12, 0)
        XCTAssertEqual(try XCTUnwrap(MonthToDate.adding([], to: 10, now: now, calendar: calendar)),
                       10,
                       accuracy: 0.0001)
    }

    func testAddingWithoutABaselineStaysUnknown() throws {
        let now = date(2026, 8, 7, 12, 0)
        // Without a fetched month the new events are only a fragment; showing them alone would
        // understate the month by everything charged before the app started.
        XCTAssertNil(MonthToDate.adding([try event(cents: 250)], to: nil, now: now, calendar: calendar))
    }

    func testAddingIgnoresEventsFromThePreviousMonth() throws {
        // Just past midnight on the 1st the poll's lookback window still covers July. An event
        // arriving late from there was billed to July and must not inflate August.
        let now = date(2026, 8, 1, 0, 2)
        let late = try event(cents: 250, at: date(2026, 7, 31, 23, 58))
        let fresh = try event(cents: 100, at: date(2026, 8, 1, 0, 1))
        XCTAssertEqual(try XCTUnwrap(MonthToDate.adding([late, fresh], to: 10, now: now, calendar: calendar)),
                       11,
                       accuracy: 0.0001)
    }

    // MARK: needsRefresh

    func testRefreshesWhenNothingFetchedYet() {
        XCTAssertTrue(MonthToDate.needsRefresh(lastRefresh: nil,
                                               now: date(2026, 8, 7),
                                               calendar: calendar))
    }

    func testSkipsRefreshWhileTotalIsFresh() {
        let now = date(2026, 8, 7, 12, 0)
        XCTAssertFalse(MonthToDate.needsRefresh(lastRefresh: now.addingTimeInterval(-60),
                                                now: now,
                                                calendar: calendar))
    }

    func testRefreshesOnceTheTotalWentStale() {
        let now = date(2026, 8, 7, 12, 0)
        XCTAssertTrue(MonthToDate.needsRefresh(lastRefresh: now.addingTimeInterval(-MonthToDate.refreshInterval),
                                               now: now,
                                               calendar: calendar))
    }

    func testRefreshesRightAfterAMonthRollover() {
        // Fetched on the last evening of July, now it is the first minute of August: the previous
        // total belongs to the old month and must not be shown, stale interval or not.
        XCTAssertTrue(MonthToDate.needsRefresh(lastRefresh: date(2026, 7, 31, 23, 59),
                                               now: date(2026, 8, 1, 0, 1),
                                               calendar: calendar))
    }

    func testRefreshesAfterTheClockJumpedBackwards() {
        // A stamp in the future (sleep, NTP correction, time zone edit) would otherwise never
        // reach the staleness interval, freezing the total permanently.
        let now = date(2026, 8, 7, 12, 0)
        XCTAssertTrue(MonthToDate.needsRefresh(lastRefresh: now.addingTimeInterval(3600),
                                               now: now,
                                               calendar: calendar))
    }

    // MARK: belongsToAPastMonth

    func testATotalFetchedLastMonthIsRecognisedAsBelongingToIt() {
        // The caller drops such a total instead of showing it under "this month": if the refetch
        // that follows the rollover fails, July's amount would otherwise sit there as August's.
        XCTAssertTrue(MonthToDate.belongsToAPastMonth(lastRefresh: date(2026, 7, 31, 23, 59),
                                                      now: date(2026, 8, 1, 0, 1),
                                                      calendar: calendar))
    }

    func testATotalFetchedThisMonthStillBelongsToIt() {
        XCTAssertFalse(MonthToDate.belongsToAPastMonth(lastRefresh: date(2026, 8, 1, 0, 0),
                                                       now: date(2026, 8, 31, 23, 59),
                                                       calendar: calendar))
    }

    func testNoTotalYetBelongsToNoMonth() {
        XCTAssertFalse(MonthToDate.belongsToAPastMonth(lastRefresh: nil,
                                                       now: date(2026, 8, 7),
                                                       calendar: calendar))
    }

    // MARK: billingCalendar

    func testBillingCalendarIgnoresTheRegionCalendar() {
        // Cursor bills on Gregorian months; a Persian or Islamic region setting must not move
        // the window the total is computed over.
        XCTAssertEqual(MonthToDate.billingCalendar.identifier, .gregorian)
    }
}
