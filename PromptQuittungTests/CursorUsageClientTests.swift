import XCTest
@testable import PromptQuittung

// Serves canned responses in call order and records the requests that were made.
private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [(status: Int, body: String)] = []
    nonisolated(unsafe) static var sentBodies: [[String: Any]] = []

    static var requestCount: Int { sentBodies.count }

    static func reset(responses: [(status: Int, body: String)] = []) {
        self.responses = responses
        sentBodies = []
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let index = Self.requestCount
        Self.sentBodies.append(Self.jsonBody(of: request) ?? [:])
        // Running past the canned list means the client paginated further than the test expected.
        let canned = index < Self.responses.count ? Self.responses[index] : (status: 500, body: "{}")
        let response = HTTPURLResponse(url: request.url!,
                                       statusCode: canned.status,
                                       httpVersion: "HTTP/1.1",
                                       headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(canned.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    // URLSession hands a custom protocol the request body as a stream, not via httpBody, so the
    // body has to be drained here to be inspectable at all.
    private static func jsonBody(of request: URLRequest) -> [String: Any]? {
        var data = request.httpBody
        if data == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var drained = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                drained.append(buffer, count: read)
            }
            data = drained
        }
        guard let data else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

final class CursorUsageClientTests: XCTestCase {
    private let cookie = "WorkosCursorSessionToken=user%3A%3Atoken"

    override func tearDown() {
        // The stub's state is global; leaving it behind would couple tests to their run order.
        StubURLProtocol.reset()
        super.tearDown()
    }

    private func makeClient(responses: [(status: Int, body: String)]) -> CursorUsageClient {
        StubURLProtocol.reset(responses: responses)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        var client = CursorUsageClient(session: URLSession(configuration: config))
        client.historyPageSize = 2
        client.maxPages = 3
        return client
    }

    // `count` events, each charged one cent, with timestamps `first..<first+count`. Distinct
    // timestamps make distinct events, so `first` is what keeps consecutive pages from colliding.
    private func events(count: Int, first: Int) -> String {
        (first..<(first + count))
            .map { #"{"timestamp": \#($0), "chargedCents": 1}"# }
            .joined(separator: ",")
    }

    // A page of events plus the server-reported total.
    private func page(count: Int, total: Int, first: Int = 0) -> (status: Int, body: String) {
        (200, #"{"totalUsageEventsCount": \#(total), "usageEventsDisplay": [\#(events(count: count, first: first))]}"#)
    }

    // The same page without the total, for servers that do not report one.
    private func pageWithoutTotal(count: Int, first: Int = 0) -> (status: Int, body: String) {
        (200, #"{"usageEventsDisplay": [\#(events(count: count, first: first))]}"#)
    }

    private func body(of request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
    }

    // MARK: buildRequest

    func testBuildRequestEncodesRangeAndPagingAsCursorExpects() throws {
        let client = CursorUsageClient()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let request = client.buildRequest(cookieHeader: cookie,
                                          start: start,
                                          end: start.addingTimeInterval(3600),
                                          page: 2,
                                          pageSize: 250)
        let json = try body(of: request)
        XCTAssertEqual(json["startDate"] as? String, "1700000000000")
        XCTAssertEqual(json["endDate"] as? String, "1700003600000")
        XCTAssertEqual(json["page"] as? Int, 2)
        XCTAssertEqual(json["pageSize"] as? Int, 250)
        // Without the Origin header cursor.com answers 403.
        XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://cursor.com")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), cookie)
    }

    // MARK: fetchEvents (recent window)

    func testRecentFetchAsksForOnePageOfTheLookbackWindow() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var client = makeClient(responses: [page(count: 1, total: 1)])
        client.now = { now }
        _ = try await client.fetchEvents(cookieHeader: cookie)
        XCTAssertEqual(StubURLProtocol.requestCount, 1)

        // Asserted against what actually went out, not against a request the test rebuilt itself.
        let sent = try XCTUnwrap(StubURLProtocol.sentBodies.first)
        XCTAssertEqual(sent["startDate"] as? String, "1699978400000")  // now minus the 6h lookback
        XCTAssertEqual(sent["endDate"] as? String, "1700000000000")
        XCTAssertEqual(sent["page"] as? Int, 1)
        XCTAssertEqual(sent["pageSize"] as? Int, client.pageSize)
    }

    // MARK: fetchEvents (range, paginated)

    func testRangeFetchFollowsPaginationUntilTheTotalIsReached() async throws {
        let client = makeClient(responses: [page(count: 2, total: 3), page(count: 1, total: 3, first: 2)])
        let events = try await client.fetchEvents(cookieHeader: cookie, from: .distantPast, to: .distantFuture)
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(StubURLProtocol.requestCount, 2)
        // The page number has to advance, otherwise page 1 would simply be collected twice.
        XCTAssertEqual(StubURLProtocol.sentBodies.map { $0["page"] as? Int }, [1, 2])
        XCTAssertEqual(StubURLProtocol.sentBodies.map { $0["pageSize"] as? Int },
                       [client.historyPageSize, client.historyPageSize])
    }

    func testRangeFetchKeepsPagingWhenTheServerCapsThePageSize() async throws {
        // The server ignores our pageSize and answers with 2 events per page. Every page is
        // "short", so a short-page-means-last rule would report 2 of 4 events — half the month.
        var client = makeClient(responses: [page(count: 2, total: 4), page(count: 2, total: 4, first: 2)])
        client.historyPageSize = 500
        let events = try await client.fetchEvents(cookieHeader: cookie, from: .distantPast, to: .distantFuture)
        XCTAssertEqual(events.count, 4)
        XCTAssertEqual(StubURLProtocol.requestCount, 2)
    }

    func testRangeFetchStopsOnAShortPageWhenNoTotalIsReported() async throws {
        let client = makeClient(responses: [pageWithoutTotal(count: 2), pageWithoutTotal(count: 1, first: 2)])
        let events = try await client.fetchEvents(cookieHeader: cookie, from: .distantPast, to: .distantFuture)
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(StubURLProtocol.requestCount, 2)
    }

    func testRangeFetchStopsOnAFullFinalPageWhenTheTotalIsReached() async throws {
        // A page that is full but complete: without the total the client would fetch an empty page.
        let client = makeClient(responses: [page(count: 2, total: 2)])
        let events = try await client.fetchEvents(cookieHeader: cookie, from: .distantPast, to: .distantFuture)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    func testRangeFetchStopsOnAnEmptyPageDespiteAHigherTotal() async throws {
        // The total overpromises; the empty page is what ends the walk.
        let client = makeClient(responses: [page(count: 2, total: 99), page(count: 0, total: 99)])
        let events = try await client.fetchEvents(cookieHeader: cookie, from: .distantPast, to: .distantFuture)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(StubURLProtocol.requestCount, 2)
    }

    func testRangeFetchSkipsEventsThatRepeatAcrossPages() async throws {
        // An event recorded mid-walk shifts the feed down, so page 2 starts with page 1's last
        // event. Counting it twice would overstate the month by that event's charge.
        let client = makeClient(responses: [page(count: 2, total: 4, first: 0),
                                            page(count: 2, total: 4, first: 1),
                                            page(count: 2, total: 4, first: 3)])
        let events = try await client.fetchEvents(cookieHeader: cookie, from: .distantPast, to: .distantFuture)
        // Timestamps 0,1 then 1,2 then 3,4 — five distinct events, not six.
        XCTAssertEqual(events.count, 5)
        XCTAssertEqual(events.map(\.timestamp.value), [0, 1, 2, 3, 4])
    }

    func testRangeFetchStopsWhenAPageRepeatsEverythingAlreadySeen() async throws {
        // A server that ignores `page` answers every request with page 1. Walking on would only
        // spin until the cap and then throw, discarding a collection that is already complete.
        let repeated = page(count: 2, total: 99)
        let client = makeClient(responses: [repeated, repeated, repeated])
        let events = try await client.fetchEvents(cookieHeader: cookie, from: .distantPast, to: .distantFuture)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(StubURLProtocol.requestCount, 2)
    }

    func testRangeFetchThrowsWhenTheServerNeverEnds() async {
        // Full pages of genuinely new events and an implausible total forever. Returning the
        // partial collection would put a silently wrong amount in the menu bar, so this has to
        // surface as an error.
        let client = makeClient(responses: (0..<4).map { page(count: 2, total: 999, first: $0 * 2) })
        do {
            _ = try await client.fetchEvents(cookieHeader: cookie, from: .distantPast, to: .distantFuture)
            XCTFail("expected the page cap to throw")
        } catch {
            XCTAssertEqual(error as? CursorClientError,
                           .network("usage events did not end within 3 pages"))
        }
        XCTAssertEqual(StubURLProtocol.requestCount, 3)
    }

    func testRangeFetchHandlesAnEmptyMonth() async throws {
        let client = makeClient(responses: [page(count: 0, total: 0)])
        let events = try await client.fetchEvents(cookieHeader: cookie, from: .distantPast, to: .distantFuture)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    // MARK: errors

    func testRejectedSessionThrowsNotLoggedIn() async {
        let client = makeClient(responses: [(403, "{}")])
        do {
            _ = try await client.fetchEvents(cookieHeader: cookie, from: .distantPast, to: .distantFuture)
            XCTFail("expected notLoggedIn")
        } catch {
            XCTAssertEqual(error as? CursorClientError, .notLoggedIn)
        }
    }

    func testServerErrorMidPaginationPropagates() async {
        let client = makeClient(responses: [page(count: 2, total: 4), (500, "{}")])
        do {
            _ = try await client.fetchEvents(cookieHeader: cookie, from: .distantPast, to: .distantFuture)
            XCTFail("expected network error")
        } catch {
            XCTAssertEqual(error as? CursorClientError, .network("HTTP 500"))
        }
    }
}
