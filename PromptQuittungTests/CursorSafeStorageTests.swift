import XCTest
@testable import PromptQuittung

final class CursorSafeStorageTests: XCTestCase {
    // Sealed with openssl and Python's hashlib, not with the code under test, so a mistake in the
    // OSCrypt parameters cannot cancel itself out in a round trip:
    //   key = pbkdf2_hmac("sha1", password, b"saltysalt", 1003, 16)
    //   "cursor-safe-storage:v1:" + base64("v10" + `openssl enc -aes-128-cbc -K key -iv 20…20`)
    private let password = Data("dGVzdC1zYWZlLXN0b3JhZ2U=".utf8)
    private let plainToken = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJhdXRoMHx1c2VyXzEyMyJ9.signature"
    private let storedToken = "cursor-safe-storage:v1:"
        + "djEw6lznFvb8bkOmkjf+Us7MQ7R8EGYIwSSQNRWymKZHJ92clRtDoENIEr+FXI3TKhEuCz7P34gEfYTBJGITgiOKfg=="

    func testDecryptsATokenSealedTheWayCursorSealsIt() throws {
        XCTAssertEqual(try CursorSafeStorage.decode(storedToken, password: { password }), plainToken)
    }

    func testThePlainTokenIsAJwtTheAuthLayerAccepts() throws {
        let token = try CursorSafeStorage.decode(storedToken, password: { password })
        let credential = try CursorAuthToken.credential(fromAccessToken: token, now: Date())
        XCTAssertEqual(credential.userID, "user_123")
    }

    func testPlainTokensPassThroughWithoutTouchingTheKeychain() throws {
        // Tokens written before Cursor switched to encryption are still plain text. Reading one
        // must not ask for keychain access the app does not need.
        let decoded = try CursorSafeStorage.decode(plainToken, password: {
            XCTFail("the keychain must not be asked for a plain token")
            return Data()
        })
        XCTAssertEqual(decoded, plainToken)
    }

    func testAWrongPasswordFailsInsteadOfYieldingGarbage() {
        XCTAssertThrowsError(try CursorSafeStorage.decode(storedToken, password: { Data("wrong-password".utf8) })) {
            XCTAssertEqual($0 as? CursorSafeStorageError, .decryptionFailed)
        }
    }

    func testAKeychainFailureIsPassedOn() {
        XCTAssertThrowsError(try CursorSafeStorage.decode(storedToken, password: {
            throw CursorSafeStorageError.keychain(errSecUserCanceled)
        })) {
            XCTAssertEqual($0 as? CursorSafeStorageError, .keychain(errSecUserCanceled))
        }
    }

    func testAPayloadThatIsNotBase64IsMalformed() {
        let garbled = "cursor-safe-storage:v1:not base64!"
        XCTAssertThrowsError(try CursorSafeStorage.decode(garbled, password: { password })) {
            XCTAssertEqual($0 as? CursorSafeStorageError, .malformedValue)
        }
    }

    func testAPayloadWithoutTheOSCryptVersionIsMalformed() {
        let unversioned = "cursor-safe-storage:v1:" + Data("v11 some other scheme".utf8).base64EncodedString()
        XCTAssertThrowsError(try CursorSafeStorage.decode(unversioned, password: { password })) {
            XCTAssertEqual($0 as? CursorSafeStorageError, .malformedValue)
        }
    }
}
