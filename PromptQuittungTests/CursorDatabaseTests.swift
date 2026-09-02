import SQLite3
import XCTest
@testable import PromptQuittung

final class CursorDatabaseTests: XCTestCase {
    private var directory = URL(fileURLWithPath: NSTemporaryDirectory())
    private var dbPath: String { directory.appendingPathComponent("state.vscdb").path }

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CursorDatabaseTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    // A key/value store shaped like Cursor's, in the same WAL mode Cursor uses.
    private func writeDatabase(token: String) throws {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(dbPath, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil),
                       SQLITE_OK)
        defer { sqlite3_close(database) }
        let sql = """
        PRAGMA journal_mode=WAL;
        CREATE TABLE ItemTable (key TEXT PRIMARY KEY, value BLOB);
        INSERT INTO ItemTable VALUES ('cursorAuth/accessToken', '\(token)');
        """
        XCTAssertEqual(sqlite3_exec(database, sql, nil, nil, nil), SQLITE_OK)
    }

    // What a clean Cursor shutdown leaves behind: the database alone, no WAL index beside it.
    private func removeWalSidecars() throws {
        for suffix in ["-shm", "-wal"] where FileManager.default.fileExists(atPath: dbPath + suffix) {
            try FileManager.default.removeItem(atPath: dbPath + suffix)
        }
    }

    private func digestOfDatabaseFile() throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: dbPath))
    }

    func testReadsTheTokenWhileTheWalIndexIsStillThere() throws {
        try writeDatabase(token: "tok123")
        XCTAssertEqual(try CursorDatabase.value(forKey: "cursorAuth/accessToken", dbPath: dbPath), "tok123")
    }

    func testReadsTheTokenAfterCursorTookTheWalIndexWithIt() throws {
        // The regression this guards: a read-only connection cannot create the -shm index a WAL
        // database needs, so once Cursor exits and deletes it, every read fails — for as long as
        // Cursor stays closed, which is precisely when the app is on its own.
        try writeDatabase(token: "tok123")
        try removeWalSidecars()

        XCTAssertEqual(try CursorDatabase.value(forKey: "cursorAuth/accessToken", dbPath: dbPath), "tok123")
    }

    func testReadingLeavesCursorsDatabaseByteForByteUnchanged() throws {
        // The retry opens the database writable to get the index rebuilt. That is the whole of the
        // privilege it wants: not one byte of Cursor's own data may move.
        try writeDatabase(token: "tok123")
        try removeWalSidecars()
        let before = try digestOfDatabaseFile()

        _ = try CursorDatabase.value(forKey: "cursorAuth/accessToken", dbPath: dbPath)

        XCTAssertEqual(try digestOfDatabaseFile(), before)
    }

    func testMissingDatabaseIsReportedAsNotFound() {
        let missing = directory.appendingPathComponent("nothing-here.vscdb").path
        XCTAssertThrowsError(try CursorDatabase.value(forKey: "cursorAuth/accessToken", dbPath: missing)) {
            XCTAssertEqual($0 as? CursorDatabaseError, .notFound)
        }
    }

    func testAnAbsentKeyIsReportedAsNoValue() throws {
        try writeDatabase(token: "tok123")
        XCTAssertThrowsError(try CursorDatabase.value(forKey: "cursorAuth/refreshToken", dbPath: dbPath)) {
            XCTAssertEqual($0 as? CursorDatabaseError, .noValue)
        }
    }

    func testAnAbsentKeyIsStillReportedAsNoValueWithoutTheWalIndex() throws {
        // Through the retry the outcome must stay the same: a missing key is not a failed read.
        try writeDatabase(token: "tok123")
        try removeWalSidecars()
        XCTAssertThrowsError(try CursorDatabase.value(forKey: "cursorAuth/refreshToken", dbPath: dbPath)) {
            XCTAssertEqual($0 as? CursorDatabaseError, .noValue)
        }
    }
}
