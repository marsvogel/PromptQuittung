import CommonCrypto
import Foundation
import os
import Security

nonisolated enum CursorSafeStorageError: Error, Equatable {
    // Cursor's encryption key could not be read from the keychain: missing, or access denied.
    case keychain(OSStatus)
    case malformedValue
    case decryptionFailed
}

// Since Cursor 3.27 the auth tokens in `state.vscdb` are no longer plain JWTs. Cursor stores them
// as "cursor-safe-storage:v1:" + base64 of Electron's `safeStorage.encryptString`, which on macOS
// is Chromium's OSCrypt: "v10" + AES-128-CBC under a key derived from a password that Cursor keeps
// in the login keychain. Reading the token as before yields a value that is not a JWT at all, so
// every poll failed and the menu bar froze on the last total it had.
nonisolated enum CursorSafeStorage {
    static let prefix = "cursor-safe-storage:v1:"

    // Chromium's fixed OSCrypt parameters on macOS (os_crypt_mac.mm).
    private static let version = Data("v10".utf8)
    private static let salt = Data("saltysalt".utf8)
    private static let iterations: UInt32 = 1003
    private static let initializationVector = Data(repeating: 0x20, count: kCCBlockSizeAES128)

    // Electron names the keychain item after the app.
    private static let keychainService = "Cursor Safe Storage"
    private static let keychainAccount = "Cursor Key"

    // Read once per launch: the first read is what asks the user for keychain access, and a one-off
    // "Allow" would otherwise bring the dialog back on every poll.
    private static let cachedPassword = OSAllocatedUnfairLock<Data?>(initialState: nil)

    // Returns the token as Cursor would load it. A value without the prefix passes through
    // untouched, as it does in Cursor: tokens written before the switch are still plain text, and
    // reading them must not cost a keychain dialog. `password` is injectable for tests.
    static func decode(_ value: String, password: () throws -> Data) throws -> String {
        guard value.hasPrefix(prefix) else { return value }
        guard let sealed = Data(base64Encoded: String(value.dropFirst(prefix.count))) else {
            throw CursorSafeStorageError.malformedValue
        }
        return try decrypt(sealed, password: password())
    }

    // `decode` with the password from Cursor's keychain item.
    static func decodeWithKeychain(_ value: String) throws -> String {
        do {
            return try decode(value, password: keychainPassword)
        } catch CursorSafeStorageError.decryptionFailed {
            // A cached password that no longer fits would fail every poll until the app restarts;
            // dropping it lets the next poll read the current one.
            cachedPassword.withLock { $0 = nil }
            throw CursorSafeStorageError.decryptionFailed
        }
    }

    static func decrypt(_ sealed: Data, password: Data) throws -> String {
        guard sealed.starts(with: version) else { throw CursorSafeStorageError.malformedValue }
        let ciphertext = Data(sealed.dropFirst(version.count))
        let key = try deriveKey(from: password)
        var plaintext = Data(count: ciphertext.count + kCCBlockSizeAES128)
        var written = 0
        let status = plaintext.withUnsafeMutableBytes { output in
            ciphertext.withUnsafeBytes { input in
                key.withUnsafeBytes { keyBytes in
                    initializationVector.withUnsafeBytes { ivBytes in
                        CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                                keyBytes.baseAddress, keyBytes.count, ivBytes.baseAddress,
                                input.baseAddress, input.count,
                                output.baseAddress, output.count, &written)
                    }
                }
            }
        }
        // A wrong key almost always surfaces as broken padding; the rare survivor is garbage that
        // is caught as invalid UTF-8 or, at the latest, by the JWT parser.
        guard status == kCCSuccess,
              let token = String(data: plaintext.prefix(written), encoding: .utf8)
        else { throw CursorSafeStorageError.decryptionFailed }
        return token
    }

    private static func deriveKey(from password: Data) throws -> Data {
        var key = Data(count: kCCKeySizeAES128)
        let status = key.withUnsafeMutableBytes { keyBytes in
            password.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                         passwordBytes.baseAddress?.assumingMemoryBound(to: CChar.self),
                                         passwordBytes.count,
                                         saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                                         saltBytes.count,
                                         CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                                         iterations,
                                         keyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                                         keyBytes.count)
                }
            }
        }
        guard status == kCCSuccess else { throw CursorSafeStorageError.decryptionFailed }
        return key
    }

    // The item belongs to Cursor, so macOS asks the user before handing it to this app; with
    // "Always Allow" it stays quiet until the app's signature changes.
    private static func keychainPassword() throws -> Data {
        if let password = cachedPassword.withLock({ $0 }) { return password }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let password = result as? Data else {
            throw CursorSafeStorageError.keychain(status)
        }
        cachedPassword.withLock { $0 = password }
        return password
    }
}
