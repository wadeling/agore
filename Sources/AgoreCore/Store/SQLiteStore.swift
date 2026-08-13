import Foundation
import SQLite3

final class SQLiteStore: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()

    func open(at url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            throw StoreError.openFailed(message)
        }
        try exec("""
        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            provider TEXT NOT NULL,
            project_slug TEXT,
            display_name TEXT,
            last_seen REAL NOT NULL,
            kind TEXT NOT NULL,
            tool_name TEXT,
            parent_id TEXT,
            source TEXT
        );
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            tool_name TEXT,
            occurred_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS events_occurred ON events(occurred_at);
        """)
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    deinit { close() }

    func upsert(session: AgentSession) throws {
        try withLock {
            try exec(
                """
                INSERT INTO sessions (id, provider, project_slug, display_name, last_seen, kind, tool_name, parent_id, source)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    provider=excluded.provider,
                    project_slug=excluded.project_slug,
                    display_name=excluded.display_name,
                    last_seen=excluded.last_seen,
                    kind=excluded.kind,
                    tool_name=excluded.tool_name,
                    parent_id=excluded.parent_id,
                    source=excluded.source;
                """,
                binds: [
                    .text(session.id),
                    .text(session.provider),
                    .text(session.projectSlug),
                    .text(session.displayName),
                    .double(session.lastSeen.timeIntervalSince1970),
                    .text(session.kind.rawValue),
                    .text(session.toolName),
                    .text(session.parentId),
                    .text(session.source.rawValue),
                ]
            )
        }
    }

    func insert(event: PresenceEvent) throws {
        try withLock {
            try exec(
                """
                INSERT INTO events (session_id, kind, tool_name, occurred_at)
                VALUES (?, ?, ?, ?);
                """,
                binds: [
                    .text(event.conversationId),
                    .text(event.kind.rawValue),
                    .text(event.toolName),
                    .double(event.occurredAt.timeIntervalSince1970),
                ]
            )
        }
    }

    func prune(olderThan cutoff: Date) throws {
        try withLock {
            try exec("DELETE FROM events WHERE occurred_at < ?;", binds: [.double(cutoff.timeIntervalSince1970)])
            try exec("DELETE FROM sessions WHERE last_seen < ?;", binds: [.double(cutoff.timeIntervalSince1970)])
        }
    }

    func loadRecentSessions(since cutoff: Date) throws -> [AgentSession] {
        try withLock {
            var statement: OpaquePointer?
            let sql = """
            SELECT id, provider, project_slug, display_name, last_seen, kind, tool_name, parent_id, source
            FROM sessions WHERE last_seen >= ? ORDER BY last_seen DESC;
            """
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw StoreError.prepareFailed(message)
            }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_double(statement, 1, cutoff.timeIntervalSince1970)
            var rows: [AgentSession] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = string(statement, 0) ?? ""
                let provider = string(statement, 1) ?? AgoreConstants.providerCursor
                let slug = string(statement, 2) ?? ""
                let display = string(statement, 3) ?? slug
                let lastSeen = Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
                let kind = ActivityKind(rawValue: string(statement, 5) ?? "") ?? .idle
                let tool = string(statement, 6)
                let parent = string(statement, 7)
                let source = PresenceSource(rawValue: string(statement, 8) ?? "") ?? .transcript
                rows.append(
                    AgentSession(
                        id: id,
                        parentId: parent,
                        provider: provider,
                        projectSlug: slug,
                        displayName: display,
                        kind: kind,
                        toolName: tool,
                        lastSeen: lastSeen,
                        source: source
                    )
                )
            }
            return rows
        }
    }

    private enum Bind {
        case text(String?)
        case double(Double)
    }

    private func exec(_ sql: String, binds: [Bind] = []) throws {
        if binds.isEmpty {
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw StoreError.execFailed(message)
            }
            return
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.prepareFailed(message)
        }
        defer { sqlite3_finalize(statement) }
        for (index, bind) in binds.enumerated() {
            let i = Int32(index + 1)
            switch bind {
            case .text(let value):
                if let value {
                    sqlite3_bind_text(statement, i, (value as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                } else {
                    sqlite3_bind_null(statement, i)
                }
            case .double(let value):
                sqlite3_bind_double(statement, i, value)
            }
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StoreError.execFailed(message)
        }
    }

    private func string(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        let value = String(cString: cString)
        return value.isEmpty ? nil : value
    }

    private var message: String {
        db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown sqlite error"
    }

    private func withLock<T>(_ body: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}

enum StoreError: Error, LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case execFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let m), .prepareFailed(let m), .execFailed(let m):
            return m
        }
    }
}
