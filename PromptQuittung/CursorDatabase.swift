import Foundation
import SQLite3

nonisolated enum CursorDatabaseError: Error, Equatable {
    case notFound
    case openFailed(String)
    case queryFailed(String)
    case noValue
}

nonisolated enum CursorDatabase {
    static var defaultPath: String {
        NSHomeDirectory() + "/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    }

    // Reads a value from the VS Code ItemTable key/value store, leaving the database untouched.
    //
    // Cursor keeps this database in WAL mode, and a WAL reader needs the -shm index next to it.
    // A read-only connection never creates that file — it only ever opens an existing one. So
    // while Cursor runs and holds the index everything reads fine, but a clean Cursor shutdown
    // deletes -shm, and from then on every open succeeds and every statement fails with
    // SQLITE_CANTOPEN. That is not a transient miss: it lasts until Cursor is started again, and
    // it blinds the app for exactly as long.
    //
    // Hence the second attempt. Read-write is what lets SQLite rebuild the index; `query_only`
    // below then bars it from changing any of Cursor's data. Read-only is still tried first, so
    // in the common case we ask for no more than we need.
    static func value(forKey key: String, dbPath: String = defaultPath) throws -> String {
        guard FileManager.default.fileExists(atPath: dbPath) else { throw CursorDatabaseError.notFound }
        do {
            return try value(forKey: key, dbPath: dbPath, flags: SQLITE_OPEN_READONLY)
        } catch CursorDatabaseError.queryFailed {
            return try value(forKey: key, dbPath: dbPath, flags: SQLITE_OPEN_READWRITE)
        }
    }

    private static func value(forKey key: String, dbPath: String, flags: Int32) throws -> String {
        var database: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &database, flags, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(database))
            sqlite3_close(database)
            throw CursorDatabaseError.openFailed(message)
        }
        defer { sqlite3_close(database) }

        // The database is opened writable only so the WAL index can be rebuilt; nothing about
        // Cursor's data is ours to change. Bailing out beats reading on with the guard unset.
        if flags & SQLITE_OPEN_READWRITE != 0 {
            guard sqlite3_exec(database, "PRAGMA query_only = 1;", nil, nil, nil) == SQLITE_OK else {
                throw CursorDatabaseError.queryFailed(String(cString: sqlite3_errmsg(database)))
            }
        }

        var stmt: OpaquePointer?
        let sql = "SELECT value FROM ItemTable WHERE key = ? LIMIT 1;"
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw CursorDatabaseError.queryFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(stmt) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)

        // A missing WAL index usually surfaces at prepare time, but not always — anything that is
        // neither a row nor a clean end is a failed read, and has to reach the retry above as one.
        let step = sqlite3_step(stmt)
        guard step == SQLITE_ROW || step == SQLITE_DONE else {
            throw CursorDatabaseError.queryFailed(String(cString: sqlite3_errmsg(database)))
        }
        guard step == SQLITE_ROW, let text = sqlite3_column_text(stmt, 0) else {
            throw CursorDatabaseError.noValue
        }
        return String(cString: text)
    }
}
