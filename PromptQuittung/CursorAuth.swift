import Foundation

nonisolated enum CursorAuth {
    // Reads the local Cursor desktop token and builds the session credential. `now` is injectable.
    static func currentCredential(now: Date = Date()) throws -> CursorCredential {
        let token = try CursorDatabase.value(forKey: "cursorAuth/accessToken")
        return try CursorAuthToken.credential(fromAccessToken: token, now: now)
    }
}
