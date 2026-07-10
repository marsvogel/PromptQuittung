import Foundation

nonisolated enum CursorAuth {
    // Liest den lokalen Cursor-Desktop-Token und baut das Session-Credential. `now` injizierbar.
    static func currentCredential(now: Date = Date()) throws -> CursorCredential {
        let token = try CursorDatabase.value(forKey: "cursorAuth/accessToken")
        return try CursorAuthToken.credential(fromAccessToken: token, now: now)
    }
}
