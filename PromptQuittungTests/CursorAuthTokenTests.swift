import XCTest
@testable import PromptQuittung

final class CursorAuthTokenTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeToken(payload: [String: Any]) -> String {
        let header = Data("{\"alg\":\"HS256\"}".utf8).base64urlEncoded
        // swiftlint:disable:next force_try
        let body = try! JSONSerialization.data(withJSONObject: payload).base64urlEncoded
        return "\(header).\(body).signature"
    }

    func testValidTokenYieldsCredential() throws {
        let token = makeToken(payload: ["sub": "auth0|user_123", "exp": now.timeIntervalSince1970 + 3_600])
        let credential = try CursorAuthToken.credential(fromAccessToken: token, now: now)
        XCTAssertEqual(credential.userID, "user_123")
        XCTAssertEqual(credential.accessToken, token)
        XCTAssertEqual(credential.cookieHeader, "WorkosCursorSessionToken=user_123%3A%3A\(token)")
    }

    func testTokenWithoutExpiryIsAccepted() throws {
        let token = makeToken(payload: ["sub": "auth0|user_123"])
        let credential = try CursorAuthToken.credential(fromAccessToken: token, now: now)
        XCTAssertEqual(credential.userID, "user_123")
    }

    func testMalformedTokenThrows() {
        XCTAssertThrowsError(try CursorAuthToken.credential(fromAccessToken: "not-a-jwt", now: now)) { error in
            XCTAssertEqual(error as? CursorAuthError, .malformedToken)
        }
    }

    func testNonJSONPayloadThrows() {
        let token = "aGVhZGVy.bm90LWpzb24.sig"
        XCTAssertThrowsError(try CursorAuthToken.credential(fromAccessToken: token, now: now)) { error in
            XCTAssertEqual(error as? CursorAuthError, .malformedToken)
        }
    }

    func testMissingSubjectThrows() {
        let token = makeToken(payload: ["exp": now.timeIntervalSince1970 + 3_600])
        XCTAssertThrowsError(try CursorAuthToken.credential(fromAccessToken: token, now: now)) { error in
            XCTAssertEqual(error as? CursorAuthError, .missingSubject)
        }
    }

    func testExpiredTokenThrows() {
        let token = makeToken(payload: ["sub": "auth0|user_123", "exp": now.timeIntervalSince1970 - 1])
        XCTAssertThrowsError(try CursorAuthToken.credential(fromAccessToken: token, now: now)) { error in
            XCTAssertEqual(error as? CursorAuthError, .expired)
        }
    }

    func testTokenExpiringWithinGracePeriodThrows() {
        // exp within the 60-second grace window counts as expired.
        let token = makeToken(payload: ["sub": "auth0|user_123", "exp": now.timeIntervalSince1970 + 30])
        XCTAssertThrowsError(try CursorAuthToken.credential(fromAccessToken: token, now: now)) { error in
            XCTAssertEqual(error as? CursorAuthError, .expired)
        }
    }

    func testBase64urlDecodeHandlesUnpaddedInput() {
        XCTAssertEqual(CursorAuthToken.base64urlDecode("aGk"), Data("hi".utf8))
        XCTAssertNil(CursorAuthToken.base64urlDecode("!!!"))
    }
}

private extension Data {
    var base64urlEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
