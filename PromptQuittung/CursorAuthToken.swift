import Foundation

nonisolated enum CursorAuthError: Error, Equatable {
    case malformedToken
    case missingSubject
    case expired
}

nonisolated struct CursorCredential: Equatable {
    let userID: String
    let accessToken: String
    var cookieHeader: String { "WorkosCursorSessionToken=\(userID)%3A%3A\(accessToken)" }
}

nonisolated enum CursorAuthToken {
    // Parses the Cursor access token JWT. `now` is injectable. Requires exp > now + 60 s (if exp is present).
    static func credential(fromAccessToken token: String, now: Date) throws -> CursorCredential {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else { throw CursorAuthError.malformedToken }
        guard let payloadData = base64urlDecode(String(segments[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else { throw CursorAuthError.malformedToken }
        guard let sub = json["sub"] as? String,
              let userID = sub.split(separator: "|", omittingEmptySubsequences: true).last.map(String.init),
              !userID.isEmpty
        else { throw CursorAuthError.missingSubject }
        if let exp = (json["exp"] as? NSNumber)?.doubleValue {
            if exp <= now.addingTimeInterval(60).timeIntervalSince1970 { throw CursorAuthError.expired }
        }
        return CursorCredential(userID: userID, accessToken: token)
    }

    static func base64urlDecode(_ string: String) -> Data? {
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        return Data(base64Encoded: base64)
    }
}
