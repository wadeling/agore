import Foundation
import Combine

@MainActor
public final class PresenceStore: ObservableObject {
    @Published public private(set) var sessions: [AgentSession] = []
    @Published public var hooksInstalled = false
    @Published public var lastEventAt: Date?
    @Published public var ingestPort: UInt16 = 0
    @Published public var statusMessage: String = "starting"

    public let idleTimeout: TimeInterval
    private let databaseURL: URL
    private let sqlite = SQLiteStore()
    private var byId: [String: AgentSession] = [:]
    private var idleTimer: Timer?

    public init(
        idleTimeout: TimeInterval = AgoreConstants.idleTimeout,
        databaseURL: URL = AgorePaths.databaseFile
    ) {
        self.idleTimeout = idleTimeout
        self.databaseURL = databaseURL
    }

    public func open() {
        do {
            try AgorePaths.ensureApplicationSupport()
            try sqlite.open(at: databaseURL)
            let cutoff = Date().addingTimeInterval(-idleTimeout)
            let restored = try sqlite.loadRecentSessions(since: cutoff)
            for session in restored where session.source != .demo {
                byId[session.id] = session
            }
            publish()
            statusMessage = byId.isEmpty ? "waiting for cursor" : "\(byId.count) restored"
        } catch {
            statusMessage = "store error"
        }
        startIdleTimer()
    }

    public func apply(_ event: PresenceEvent) {
        if event.source == .transcript, let existing = byId[event.conversationId] {
            if existing.source == .hook, Date().timeIntervalSince(existing.lastSeen) < 30 {
                return
            }
        }

        if event.hookEventName == "sessionEnd" || event.kind == .idle && event.hookEventName == "subagentStop" {
            if var existing = byId[event.conversationId] {
                existing.kind = .idle
                existing.lastSeen = event.occurredAt
                existing.source = event.source
                byId[event.conversationId] = existing
                try? sqlite.upsert(session: existing)
            }
            lastEventAt = event.occurredAt
            publish()
            try? sqlite.insert(event: event)
            return
        }

        let display = ActivityMapper.displayName(projectSlug: event.projectSlug, isSubagent: event.parentId != nil)
        var session = byId[event.conversationId] ?? AgentSession(
            id: event.conversationId,
            parentId: event.parentId,
            provider: AgoreConstants.providerCursor,
            projectSlug: event.projectSlug,
            displayName: display,
            kind: event.kind,
            toolName: event.toolName,
            lastSeen: event.occurredAt,
            source: event.source
        )
        if !event.projectSlug.isEmpty {
            session.projectSlug = event.projectSlug
            session.displayName = display
        }
        if event.parentId != nil {
            session.parentId = event.parentId
        }
        session.kind = event.kind
        session.toolName = event.toolName
        session.lastSeen = event.occurredAt
        session.source = event.source
        byId[session.id] = session
        lastEventAt = event.occurredAt
        try? sqlite.upsert(session: session)
        try? sqlite.insert(event: event)
        publish()
        statusMessage = "\(activeSessions().count) agents"
    }

    public func activeSessions(at now: Date = Date()) -> [AgentSession] {
        sessions.filter { session in
            if session.kind == .idle {
                return now.timeIntervalSince(session.lastSeen) < AgoreConstants.departureGrace
            }
            return now.timeIntervalSince(session.lastSeen) < idleTimeout
        }
    }

    public var isEmpty: Bool {
        activeSessions().isEmpty
    }

    private func startIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sweepIdle()
            }
        }
        idleTimer?.tolerance = 1
    }

    private func sweepIdle() {
        let now = Date()
        var changed = false
        for (id, session) in byId {
            if now.timeIntervalSince(session.lastSeen) >= idleTimeout, session.kind != .idle {
                var next = session
                next.kind = .idle
                next.lastSeen = now
                byId[id] = next
                try? sqlite.upsert(session: next)
                changed = true
            }
        }
        let stale = byId
            .filter { $0.value.kind == .idle && now.timeIntervalSince($0.value.lastSeen) >= AgoreConstants.departureGrace }
            .map(\.key)
        for id in stale {
            byId.removeValue(forKey: id)
            changed = true
        }
        if changed { publish() }
        try? sqlite.prune(olderThan: now.addingTimeInterval(-7 * 24 * 60 * 60))
        statusMessage = isEmpty ? "waiting for cursor" : "\(activeSessions().count) agents"
    }

    private func publish() {
        sessions = byId.values.sorted { $0.lastSeen > $1.lastSeen }
    }
}
