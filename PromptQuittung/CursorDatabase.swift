import Foundation
import SQLite3

nonisolated enum CursorDatabaseError: Error, Equatable {
    case notFound
    case openFailed
    case queryFailed
    case noValue
}

nonisolated enum CursorDatabase {
    static var defaultPath: String {
        NSHomeDirectory() + "/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    }

    // Liest einen Wert aus dem VS-Code-ItemTable-Key/Value-Store, read-only.
    static func value(forKey key: String, dbPath: String = defaultPath) throws -> String {
        guard FileManager.default.fileExists(atPath: dbPath) else { throw CursorDatabaseError.notFound }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw CursorDatabaseError.openFailed
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let sql = "SELECT value FROM ItemTable WHERE key = ? LIMIT 1;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw CursorDatabaseError.queryFailed
        }
        defer { sqlite3_finalize(stmt) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) else {
            throw CursorDatabaseError.noValue
        }
        return String(cString: c)
    }
}
