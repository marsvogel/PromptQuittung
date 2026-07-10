import XCTest
@testable import PromptQuittung

final class UsageDiffTests: XCTestCase {
    private func makeEvent(timestamp: Int64, model: String = "test-model") throws -> UsageEvent {
        let json = """
        {"timestamp": \(timestamp), "model": "\(model)", "kind": "USAGE_EVENT_KIND_CHAT"}
        """
        return try JSONDecoder().decode(UsageEvent.self, from: Data(json.utf8))
    }

    func testFirstRunSeedsWithoutNotifying() throws {
        let events = [try makeEvent(timestamp: 1), try makeEvent(timestamp: 2)]
        let result = UsageDiff.detect(events: events, seen: [], isFirstRun: true)
        XCTAssertTrue(result.toNotify.isEmpty)
        XCTAssertEqual(result.updatedSeen.count, 2)
    }

    func testNewEventsAreNotifiedOldestFirst() throws {
        let old = try makeEvent(timestamp: 100)
        let newer = try makeEvent(timestamp: 300)
        let newest = try makeEvent(timestamp: 200)
        let result = UsageDiff.detect(events: [newer, newest], seen: [old.dedupKey], isFirstRun: false)
        XCTAssertEqual(result.toNotify.map { $0.timestamp.value }, [200, 300])
    }

    func testSeenEventsAreNotNotifiedAgain() throws {
        let event = try makeEvent(timestamp: 100)
        let result = UsageDiff.detect(events: [event], seen: [event.dedupKey], isFirstRun: false)
        XCTAssertTrue(result.toNotify.isEmpty)
        XCTAssertEqual(result.updatedSeen, [event.dedupKey])
    }

    func testSameTimestampDifferentModelIsDistinct() throws {
        let eventA = try makeEvent(timestamp: 100, model: "model-a")
        let eventB = try makeEvent(timestamp: 100, model: "model-b")
        let result = UsageDiff.detect(events: [eventA, eventB], seen: [eventA.dedupKey], isFirstRun: false)
        XCTAssertEqual(result.toNotify.map { $0.model }, ["model-b"])
    }
}
