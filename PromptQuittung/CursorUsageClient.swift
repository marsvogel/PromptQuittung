import Foundation

nonisolated enum CursorClientError: Error, Equatable {
    case notLoggedIn
    case network(String)
}

nonisolated struct CursorUsageClient {
    var session: URLSession = .shared
    var now: () -> Date = Date.init
    var lookback: TimeInterval = 6 * 3600
    var pageSize: Int = 100
    // A whole month needs far more than one page of the polling size; the API accepts this much.
    var historyPageSize: Int = 1000
    // Backstop against a server that keeps handing out full pages forever.
    var maxPages: Int = 50

    private static let endpoint = URL(string: "https://cursor.com/api/dashboard/get-filtered-usage-events")!

    func buildRequest(cookieHeader: String, start: Date, end: Date, page: Int, pageSize: Int) -> URLRequest {
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        // cursor.com checks the Origin on state-changing requests (CSRF). Without this header: 403.
        req.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
        let body: [String: Any] = [
            "teamId": 0,
            "startDate": String(Int64(start.timeIntervalSince1970 * 1000)),
            "endDate": String(Int64(end.timeIntervalSince1970 * 1000)),
            "page": page,
            "pageSize": pageSize
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return req
    }

    // The recent window the notification diff runs on.
    func fetchEvents(cookieHeader: String) async throws -> [UsageEvent] {
        let end = now()
        return try await fetchPage(cookieHeader: cookieHeader,
                                   start: end.addingTimeInterval(-lookback),
                                   end: end,
                                   page: 1,
                                   pageSize: pageSize).events
    }

    // Every event in the given range, following pagination.
    func fetchEvents(cookieHeader: String, from start: Date, to end: Date) async throws -> [UsageEvent] {
        let pageLimit = max(1, maxPages)
        var collected: [UsageEvent] = []
        // The feed keeps growing while we walk it: an event recorded between two requests shifts
        // every older event one slot down, so the last entry of a page reappears as the first
        // entry of the next. Counting it twice would overstate the month by a real amount.
        var seenKeys: Set<String> = []
        for page in 1...pageLimit {
            let (events, total) = try await fetchPage(cookieHeader: cookieHeader,
                                                      start: start,
                                                      end: end,
                                                      page: page,
                                                      pageSize: historyPageSize)
            if events.isEmpty { return collected }
            let fresh = events.filter { seenKeys.insert($0.dedupKey).inserted }
            // Nothing but repeats means the server has no more to give, or ignores `page`
            // altogether; walking on would only spin until the cap.
            if fresh.isEmpty { return collected }
            collected.append(contentsOf: fresh)
            // The reported total is the end marker to prefer: a server that caps pageSize below
            // what we asked answers *every* request with a page shorter than requested, and
            // treating that as the last page would silently drop the rest of the month.
            if let total {
                if collected.count >= total { return collected }
            } else if events.count < historyPageSize {
                return collected
            }
        }
        // The server never signalled an end. Returning the partial collection would put a silently
        // wrong amount in the menu bar, so surface it and let the caller keep whatever total it
        // already had.
        throw CursorClientError.network("usage events did not end within \(pageLimit) pages")
    }

    private func fetchPage(cookieHeader: String,
                           start: Date,
                           end: Date,
                           page: Int,
                           pageSize: Int) async throws -> (events: [UsageEvent], total: Int?) {
        let req = buildRequest(cookieHeader: cookieHeader, start: start, end: end, page: page, pageSize: pageSize)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw CursorClientError.network("no HTTP response")
        }
        if http.statusCode == 401 || http.statusCode == 403 { throw CursorClientError.notLoggedIn }
        guard http.statusCode == 200 else { throw CursorClientError.network("HTTP \(http.statusCode)") }
        let decoded = try JSONDecoder().decode(UsageEventsResponse.self, from: data)
        return (decoded.usageEventsDisplay ?? [], decoded.totalUsageEventsCount?.value)
    }
}
