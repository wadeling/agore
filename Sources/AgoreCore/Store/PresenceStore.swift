import Foundation
import Combine

@MainActor
public final class PresenceStore: ObservableObject {
    @Published public private(set) var sessions: [AgentSession] = []
    @Published public var hooksInstalled = false
    @Published public var lastEventAt: Date?
    @Published public var ingestPort: UInt16 = 0
    @Published public var statusMessage: String = "starting"
    @Published public var plazaLink: PlazaLinkState = .offline

    public var identity = ClientIdentity.ephemeral()
    public var onInstanceChange: ((PlazaMember) -> Void)?

    public let idleTimeout: TimeInterval
    private let databaseURL: URL
    private let sqlite = SQLiteStore()
    private var byId: [String: AgentSession] = [:]
    private var remoteRoster: [String: PlazaMember] = [:]
    private var idleTimer: Timer?
    private var lastPublished: PlazaMember?

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
            for session in restored where session.source != .demo && session.source != .plaza {
                byId[session.id] = session
            }
            lastEventAt = restored.map(\.lastSeen).max()
            publish()
            statusMessage = byId.isEmpty ? "waiting for cursor" : "\(byId.count) restored"
        } catch {
            statusMessage = "store error"
        }
        startIdleTimer()
        notifyInstanceChange()
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
            notifyInstanceChange()
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
        notifyInstanceChange()
    }

    public func applyPlaza(_ inbound: PlazaInbound) {
        switch inbound {
        case .link(let state):
            plazaLink = state
            if state != .online {
                remoteRoster.removeAll()
            }
        case .snapshot(let members):
            remoteRoster = [:]
            for member in members where member.id != identity.clientId {
                remoteRoster[member.id] = member
            }
        case .presence(let member):
            guard member.id != identity.clientId else { return }
            remoteRoster[member.id] = member
        case .leave(let id):
            remoteRoster.removeValue(forKey: id)
        }
        publish()
    }

    public func renameLocal(to name: String) {
        ClientIdentity.displayName = name
        notifyInstanceChange()
        publish()
    }

    public func activeSessions(at now: Date = Date()) -> [AgentSession] {
        sessions.filter { session in
            if session.kind == .idle {
                return now.timeIntervalSince(session.lastSeen) < AgoreConstants.departureGrace
            }
            return now.timeIntervalSince(session.lastSeen) < idleTimeout
        }
    }

    /// One pixel person per Cursor instance: fold every local conversation into a single
    /// activity, then overlay whoever the plaza server currently knows about.
    public func instancePresence(at now: Date = Date()) -> PlazaMember {
        let active = activeSessions(at: now).filter { $0.kind != .idle }
        let order: [ActivityKind] = [.running, .writing, .reading, .thinking, .waiting]
        let kind = order.first { candidate in
            active.contains { $0.kind == candidate }
        } ?? .idle
        let project = active.first(where: { !$0.projectSlug.isEmpty })?.projectSlug ?? ""
        return PlazaMember(
            id: identity.clientId,
            displayName: ClientIdentity.displayName,
            kind: kind,
            project: project,
            lastSeen: lastEventAt ?? now,
            isLocal: true
        )
    }

    public func plazaMembers(at now: Date = Date()) -> [PlazaMember] {
        var members = remoteRoster
        let local = instancePresence(at: now)
        if shouldShow(local, at: now) {
            members[local.id] = local
        }
        return members.values
            .filter { shouldShow($0, at: now) }
            .sorted { $0.lastSeen > $1.lastSeen }
    }

    public var isEmpty: Bool {
        plazaMembers().isEmpty
    }

    private func shouldShow(_ member: PlazaMember, at now: Date) -> Bool {
        if member.kind == .idle {
            return now.timeIntervalSince(member.lastSeen) < AgoreConstants.departureGrace
        }
        return now.timeIntervalSince(member.lastSeen) < idleTimeout
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
        notifyInstanceChange()
        let people = plazaMembers().count
        switch plazaLink {
        case .online:
            statusMessage = people == 0 ? "plaza on" : "\(people) people"
        case .unauthorized:
            statusMessage = "plaza unauthorized"
        case .connecting:
            statusMessage = "plaza connecting"
        case .offline:
            statusMessage = people == 0 ? "waiting for cursor" : "\(people) people · plaza offline"
        }
    }

    private func publish() {
        sessions = byId.values.sorted { $0.lastSeen > $1.lastSeen }
        objectWillChange.send()
    }

    private func notifyInstanceChange() {
        let current = instancePresence()
        if current.kind != lastPublished?.kind
            || current.project != lastPublished?.project
            || current.displayName != lastPublished?.displayName {
            lastPublished = current
            onInstanceChange?(current)
        }
    }
}
