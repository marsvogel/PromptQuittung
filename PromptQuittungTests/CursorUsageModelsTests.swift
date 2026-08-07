import XCTest
@testable import PromptQuittung

final class CursorUsageModelsTests: XCTestCase {
    private func decodeEvent(_ json: String) throws -> UsageEvent {
        try JSONDecoder().decode(UsageEvent.self, from: Data(json.utf8))
    }

    // MARK: Flexible decoding

    func testTimestampDecodesFromNumberAndString() throws {
        XCTAssertEqual(try decodeEvent(#"{"timestamp": 1700000000000}"#).timestamp.value, 1_700_000_000_000)
        XCTAssertEqual(try decodeEvent(#"{"timestamp": "1700000000000"}"#).timestamp.value, 1_700_000_000_000)
        XCTAssertEqual(try decodeEvent(#"{"timestamp": 1.7e12}"#).timestamp.value, 1_700_000_000_000)
    }

    func testUndecodableTimestampFallsBackToZero() throws {
        XCTAssertEqual(try decodeEvent(#"{"timestamp": "abc"}"#).timestamp.value, 0)
    }

    func testLenientDoubleDecodesDashAsZero() throws {
        XCTAssertEqual(try decodeEvent(#"{"timestamp": 1, "chargedCents": "-"}"#).chargedCents?.value, 0)
        XCTAssertEqual(try decodeEvent(#"{"timestamp": 1, "chargedCents": "42.5"}"#).chargedCents?.value, 42.5)
        XCTAssertEqual(try decodeEvent(#"{"timestamp": 1, "chargedCents": 42.5}"#).chargedCents?.value, 42.5)
    }

    func testFlexibleIntDecodesFromString() throws {
        let event = try decodeEvent(#"{"timestamp": 1, "tokenUsage": {"inputTokens": "123"}}"#)
        XCTAssertEqual(event.tokenUsage?.inputTokens?.value, 123)
    }

    // MARK: Derived values

    func testTotalTokensSumsAllFourCategories() throws {
        let json = #"{"timestamp": 1, "tokenUsage": {"inputTokens": 1, "outputTokens": 2, "#
            + #""cacheWriteTokens": 3, "cacheReadTokens": 4}}"#
        let event = try decodeEvent(json)
        XCTAssertEqual(event.totalTokens, 10)
    }

    func testDisplayCostConvertsCentsToDollars() throws {
        let event = try decodeEvent(#"{"timestamp": 1, "chargedCents": 250}"#)
        XCTAssertEqual(event.displayCost, 2.5)
        XCTAssertEqual(event.costString, "$2.50")
    }

    func testDateConvertsMillisecondsToADate() throws {
        let event = try decodeEvent(#"{"timestamp": 1700000000000}"#)
        XCTAssertEqual(event.date, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testKindShortStripsPrefix() throws {
        let event = try decodeEvent(#"{"timestamp": 1, "kind": "USAGE_EVENT_KIND_CHAT"}"#)
        XCTAssertEqual(event.kindShort, "CHAT")
    }

    func testNotificationTitleFallsBackToCursorWithoutModel() throws {
        let event = try decodeEvent(#"{"timestamp": 1}"#)
        XCTAssertEqual(event.notificationTitle, "$0.00 · Cursor")
    }

    // MARK: Money

    func testFormattedAsUSD() {
        XCTAssertEqual(Money.usd(0), "$0.00")
        XCTAssertEqual(Money.usd(7.891), "$7.89")
        XCTAssertEqual(Money.usd(1234.5), "$1234.50")
    }

    func testRoundedFormatDropsCentsForTheMenuBar() {
        XCTAssertEqual(Money.usdRounded(0), "$0")
        XCTAssertEqual(Money.usdRounded(0.42), "$0")
        XCTAssertEqual(Money.usdRounded(7.2), "$7")
        XCTAssertEqual(Money.usdRounded(7.891), "$8")
    }

    // MARK: compactTokens

    func testCompactTokens() {
        XCTAssertEqual(UsageEvent.compactTokens(0), "0")
        XCTAssertEqual(UsageEvent.compactTokens(999), "999")
        XCTAssertEqual(UsageEvent.compactTokens(1_000), "1.0k")
        XCTAssertEqual(UsageEvent.compactTokens(198_862), "198.9k")
        XCTAssertEqual(UsageEvent.compactTokens(2_500_000), "2.5M")
    }
}
