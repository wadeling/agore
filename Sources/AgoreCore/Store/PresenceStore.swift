import Foundation
import Combine

@MainActor
public final class PresenceStore: ObservableObject {
    @Published public private(set) var sessions: [AgentSession] = []
    /// Wiring up a new agent adds a person to the plaza, so the roster has to be told.
    @Published public var bridges: [BridgeStatus] = [] {
        didSet {
            guard bridges != oldValue else { return }
            publish()
            notifyInstanceChange()
        }
    }
    @Published public var lastEventAt: Date?
    @Published public var ingestPort: UInt16 = 0
    @Published public var statusMessage: String = "starting"
    @Published public var plazaLink: PlazaLinkState = .offline

    public var identity = ClientIdentity.ephemeral()
    public var onInstanceChange: ((PlazaMember) -> Void)?
    /// An agent whose bridge was removed has to be taken off the plaza explicitly; the
    /// server only forgets a client's people when the socket itself goes.
    public var onInstanceLeave: ((String) -> Void)?

    private static let shellCall = "shell"
    private static let mcpCall = "mcp"
    /// The agent's turn is over: Cursor says so outright, opencode by falling idle.
    private static let turnEndEvents: Set<String> = ["sessionEnd", "session.idle"]

    public let idleTimeout: TimeInterval
    private let databaseURL: URL
    private let sqlite = SQLiteStore()
    private var byId: [String: AgentSession] = [:]
    private var remoteRoster: [String: PlazaMember] = [:]
    private var idleTimer: Timer?
    private var lastPublished: [String: PlazaMember] = [:]
    private var lastPublishedAt: [String: Date] = [:]
    /// Tool calls that opened but have not reported back, keyed by session then by
    /// tool_use_id. Cursor goes quiet for the whole duration of a tool, so without this
    /// an agent on a five minute test run is indistinguishable from one that quit.
    private var inFlight: [String: [String: Date]] = [:]

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
            statusMessage = byId.isEmpty ? "waiting for agents" : "\(byId.count) restored"
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

        trackToolCall(event)

        let name = event.hookEventName ?? ""
        if Self.turnEndEvents.contains(name) || (name == "subagentStop" && event.kind == .idle) {
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
            provider: event.provider,
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
        session.provider = event.provider
        session.source = event.source
        byId[session.id] = session
        lastEventAt = event.occurredAt
        try? sqlite.upsert(session: session)
        try? sqlite.insert(event: event)
        publish()
        notifyInstanceChange()
    }

    /// Opens a slot on the hook that starts a tool call and closes it on the matching
    /// one, so the idle sweep can tell "waiting on a slow command" from "gone".
    private func trackToolCall(_ event: PresenceEvent) {
        guard event.source == .hook, let name = event.hookEventName else { return }
        switch name {
        case "preToolUse":
            open(event.toolUseId, for: event.conversationId, at: event.occurredAt)
        case "postToolUse", "postToolUseFailure":
            close(event.toolUseId, for: event.conversationId)
        // Shell and MCP pairs carry no call id. Keyed by event name they still bracket
        // the one command a conversation can have outstanding, which covers Cursor
        // builds whose preToolUse payload omits tool_use_id.
        case "beforeShellExecution":
            open(Self.shellCall, for: event.conversationId, at: event.occurredAt)
        case "afterShellExecution":
            close(Self.shellCall, for: event.conversationId)
        case "beforeMCPExecution":
            open(Self.mcpCall, for: event.conversationId, at: event.occurredAt)
        case "afterMCPExecution":
            close(Self.mcpCall, for: event.conversationId)
        // opencode's pair always carries a call id, so it needs no fallback key.
        case "tool.execute.before":
            open(event.toolUseId, for: event.conversationId, at: event.occurredAt)
        case "tool.execute.after":
            close(event.toolUseId, for: event.conversationId)
        // The agent loop ended, so nothing it started is still running.
        case "stop", "sessionEnd", "subagentStop", "session.idle":
            inFlight.removeValue(forKey: event.conversationId)
        default:
            break
        }
    }

    private func open(_ call: String?, for sessionId: String, at started: Date) {
        guard let call, !call.isEmpty else { return }
        inFlight[sessionId, default: [:]][call] = started
    }

    private func close(_ call: String?, for sessionId: String) {
        guard let call, !call.isEmpty else { return }
        inFlight[sessionId]?.removeValue(forKey: call)
        if inFlight[sessionId]?.isEmpty == true {
            inFlight.removeValue(forKey: sessionId)
        }
    }

    /// True while a tool call this session started has yet to report back.
    public func isBusy(_ sessionId: String, at now: Date = Date()) -> Bool {
        guard let calls = inFlight[sessionId] else { return false }
        return calls.values.contains { now.timeIntervalSince($0) < AgoreConstants.toolCallCeiling }
    }

    public func applyPlaza(_ inbound: PlazaInbound) {
        switch inbound {
        case .link(let state):
            guard state != plazaLink else { return }
            plazaLink = state
            if state != .online {
                remoteRoster.removeAll()
            }
        // Our own people are built from local state, not from what the server echoes back:
        // a member is ours when the frame names this client as its owner, whichever agent
        // it stands for.
        case .snapshot(let members):
            remoteRoster = [:]
            for member in members where !member.isLocal {
                remoteRoster[member.id] = member
            }
        case .presence(let member):
            guard !member.isLocal else { return }
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
            if isBusy(session.id, at: now) {
                return true
            }
            return now.timeIntervalSince(session.lastSeen) < idleTimeout
        }
    }

    /// One pixel person per agent this client is wired into, each folding that agent's
    /// conversations into a single activity. Two agents on one Mac are two people on the
    /// plaza; a single agent's subagents still share one.
    public func localMembers(at now: Date = Date()) -> [PlazaMember] {
        let providers = localProviders()
        guard !providers.isEmpty else {
            // No agent is wired up at all. Standing on the plaza is about being connected,
            // so the client still gets a person rather than an empty stage.
            return [
                PlazaMember(
                    id: identity.clientId,
                    displayName: ClientIdentity.displayName,
                    kind: .idle,
                    lastSeen: lastEventAt ?? now,
                    isLocal: true
                )
            ]
        }
        return providers.map { member(for: $0, at: now) }
    }

    /// What this client as a whole is up to, for the one-line status strip. The busiest
    /// agent speaks for the Mac.
    public func localActivity(at now: Date = Date()) -> ActivityKind {
        Self.dominantKind(of: localMembers(at: now).map(\.kind))
    }

    /// Agents Agore is wired into, plus any that are reporting activity regardless — a
    /// bridge installed by hand still deserves its person. Ordered so the plaza does not
    /// reshuffle between refreshes.
    private func localProviders() -> [AgentProvider] {
        let installed = Set(bridges.filter(\.isInstalled).map(\.provider))
        let reporting = Set(byId.values.compactMap { AgentProvider(rawValue: $0.provider) })
        return AgentProvider.allCases.filter { installed.contains($0) || reporting.contains($0) }
    }

    private func member(for provider: AgentProvider, at now: Date) -> PlazaMember {
        let active = activeSessions(at: now).filter { $0.kind != .idle && $0.provider == provider.rawValue }
        let project = active.first(where: { !$0.projectSlug.isEmpty })?.projectSlug ?? ""
        // Everyone ages us out on this timestamp, so an open tool call has to count as
        // being seen even though it produces no events of its own.
        let seen = active.contains { isBusy($0.id, at: now) }
            ? now
            : (active.map(\.lastSeen).max() ?? now)
        return PlazaMember(
            id: PlazaMember.id(client: identity.clientId, provider: provider),
            // The nickname alone: which agent this is rides along in the member id, and the
            // plaza works out how to fit the two of them under a pixel person.
            displayName: ClientIdentity.displayName,
            kind: Self.dominantKind(of: active.map(\.kind)),
            project: project,
            lastSeen: seen,
            provider: provider.rawValue,
            isLocal: true
        )
    }

    private static func dominantKind(of kinds: [ActivityKind]) -> ActivityKind {
        let order: [ActivityKind] = [.running, .writing, .reading, .thinking, .waiting]
        return order.first { kinds.contains($0) } ?? .idle
    }

    /// Standing on the plaza is about being connected, not about being busy. The server
    /// drops a client's people from the roster the moment its socket closes, so everyone
    /// still listed — ourselves first of all — gets a pixel person, idle or not.
    public func plazaMembers(at now: Date = Date()) -> [PlazaMember] {
        var members = remoteRoster
        for member in localMembers(at: now) {
            members[member.id] = member
        }
        return members.values.sorted { $0.lastSeen > $1.lastSeen }
    }

    /// True when nothing is happening anywhere: no local agent awake and no peers.
    public var isEmpty: Bool {
        activeSessions().isEmpty && remoteRoster.isEmpty
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
        pruneExpiredCalls(at: now)
        for (id, session) in byId {
            if now.timeIntervalSince(session.lastSeen) >= idleTimeout, session.kind != .idle {
                if isBusy(id, at: now) { continue }
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
            inFlight.removeValue(forKey: id)
            changed = true
        }
        if changed { publish() }
        try? sqlite.prune(olderThan: now.addingTimeInterval(-7 * 24 * 60 * 60))
        notifyInstanceChange()
        let people = plazaMembers().count
        switch plazaLink {
        case .online:
            statusMessage = "\(people) people"
        case .unauthorized:
            statusMessage = "plaza unauthorized"
        case .connecting:
            statusMessage = "plaza connecting"
        case .offline:
            statusMessage = "\(people) people · plaza offline"
        }
    }

    private func pruneExpiredCalls(at now: Date) {
        for (sessionId, calls) in inFlight {
            let live = calls.filter { now.timeIntervalSince($0.value) < AgoreConstants.toolCallCeiling }
            if live.isEmpty {
                inFlight.removeValue(forKey: sessionId)
            } else if live.count != calls.count {
                inFlight[sessionId] = live
            }
        }
    }

    private func publish() {
        sessions = byId.values.sorted { $0.lastSeen > $1.lastSeen }
        objectWillChange.send()
    }

    private func notifyInstanceChange(at now: Date = Date()) {
        let members = localMembers(at: now)
        let live = Set(members.map(\.id))
        for id in Array(lastPublished.keys) where !live.contains(id) {
            lastPublished.removeValue(forKey: id)
            lastPublishedAt.removeValue(forKey: id)
            onInstanceLeave?(id)
        }
        for member in members {
            let previous = lastPublished[member.id]
            let changed = member.kind != previous?.kind
                || member.project != previous?.project
                || member.displayName != previous?.displayName
            // Peers time us out on the timestamp we last sent them, so a long tool call
            // needs a refresh even when the activity itself has not changed.
            let stale = member.kind != .idle
                && (lastPublishedAt[member.id].map { now.timeIntervalSince($0) >= AgoreConstants.plazaHeartbeat } ?? true)
            guard changed || stale else { continue }
            lastPublished[member.id] = member
            lastPublishedAt[member.id] = now
            onInstanceChange?(member)
        }
    }
}
