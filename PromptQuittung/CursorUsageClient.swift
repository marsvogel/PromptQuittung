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

    private static let endpoint = URL(string: "https://cursor.com/api/dashboard/get-filtered-usage-events")!

    func buildRequest(cookieHeader: String, now: Date) -> URLRequest {
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        // cursor.com prüft die Origin bei state-changing Requests (CSRF). Ohne diesen Header: 403.
        req.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
        let endMs = Int64(now.timeIntervalSince1970 * 1000)
        let startMs = Int64(now.addingTimeInterval(-lookback).timeIntervalSince1970 * 1000)
        let body: [String: Any] = [
            "teamId": 0,
            "startDate": String(startMs),
            "endDate": String(endMs),
            "page": 1,
            "pageSize": pageSize
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return req
    }

    func fetchEvents(cookieHeader: String) async throws -> [UsageEvent] {
        let req = buildRequest(cookieHeader: cookieHeader, now: now())
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw CursorClientError.network("keine HTTP-Antwort")
        }
        if http.statusCode == 401 || http.statusCode == 403 { throw CursorClientError.notLoggedIn }
        guard http.statusCode == 200 else { throw CursorClientError.network("HTTP \(http.statusCode)") }
        let decoded = try JSONDecoder().decode(UsageEventsResponse.self, from: data)
        return decoded.usageEventsDisplay ?? []
    }
}
