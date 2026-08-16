import Foundation

/// URLSession WebSocket client for the shared plaza. Reconnects on drop, except after
/// an unauthorized hello — that waits for the token or URL to change.
public final class PlazaClient: @unchecked Sendable {
    public var onInbound: (@Sendable (PlazaInbound) -> Void)?

    private let identity: ClientIdentity
    private let queue = DispatchQueue(label: "com.wadeling.agore.plaza")
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var heartbeat: DispatchSourceTimer?
    private var debounceWork: DispatchWorkItem?
    private var pending: PlazaMember?
    private var running = false
    private var reconnectAttempt = 0
    private var lastURL: URL?
    private var lastToken: String?
    private var rejected = false
    /// Bumped by every tear-down. A socket has several callbacks in flight at once — the
    /// receive, the hello send, the heartbeat ping — and an unreachable server fails all
    /// of them. Stamping each with the generation it belongs to means one dead socket
    /// produces one reconnect instead of one per callback, which is what turned a missing
    /// plaza server into tens of thousands of live URLSessions.
    private var generation = 0
    private var reconnectScheduled = false

    public init(identity: ClientIdentity) {
        self.identity = identity
    }

    public func start() {
        queue.async {
            self.running = true
            self.rejected = false
            self.reconnectAttempt = 0
            self.connect()
        }
    }

    public func stop() {
        queue.async {
            self.running = false
            self.tearDown()
            self.emit(.link(.offline))
        }
    }

    /// Call after the user edits the token or server URL so a rejected client tries again.
    public func reconnect() {
        queue.async {
            self.rejected = false
            self.reconnectAttempt = 0
            self.tearDown()
            guard self.running else {
                self.running = true
                self.connect()
                return
            }
            self.connect()
        }
    }

    public func publish(_ member: PlazaMember) {
        queue.async {
            self.pending = member
            self.debounceWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.flush(generation: self.generation)
            }
            self.debounceWork = work
            self.queue.asyncAfter(deadline: .now() + AgoreConstants.plazaDebounce, execute: work)
        }
    }

    public func sendNick(_ name: String) {
        queue.async {
            self.send(PlazaEnvelope.nick(name), generation: self.generation)
        }
    }

    private func connect() {
        tearDown()
        guard running, !rejected else { return }
        lastURL = ClientIdentity.plazaURL
        lastToken = ClientIdentity.plazaToken
        emit(.link(.connecting))

        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        let session = URLSession(configuration: config)
        self.session = session
        let task = session.webSocketTask(with: ClientIdentity.plazaURL)
        self.task = task
        let generation = self.generation
        task.resume()
        send(PlazaEnvelope.hello(
            identity: identity,
            displayName: ClientIdentity.displayName,
            token: ClientIdentity.plazaToken
        ), generation: generation)
        receive(on: task, generation: generation)
        startHeartbeat(generation: generation)
    }

    private func receive(on task: URLSessionWebSocketTask, generation: Int) {
        task.receive { [weak self] result in
            guard let self else { return }
            self.queue.async {
                guard generation == self.generation else { return }
                switch result {
                case .failure:
                    self.handleDrop(generation: generation)
                case .success(let message):
                    self.handle(message, generation: generation)
                    self.receive(on: task, generation: generation)
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message, generation: Int) {
        let data: Data
        switch message {
        case .data(let value):
            data = value
        case .string(let text):
            data = Data(text.utf8)
        @unknown default:
            return
        }
        guard let envelope = try? PlazaEnvelope.decode(data) else { return }
        switch envelope.type {
        case "welcome":
            reconnectAttempt = 0
            emit(.link(.online))
            let members = (envelope.snapshot ?? []).map { $0.asMember(localId: identity.clientId) }
            emit(.snapshot(members))
            flush(generation: generation)
        case "presence":
            if let dto = snapshotItem(from: envelope) {
                emit(.presence(dto.asMember(localId: identity.clientId)))
            }
        case "leave":
            if let id = envelope.client_id {
                emit(.leave(id))
            }
        case "error":
            if envelope.code == "unauthorized" {
                rejected = true
                emit(.link(.unauthorized))
                tearDown()
                return
            }
            handleDrop(generation: generation)
        case "pong":
            break
        default:
            break
        }
    }

    private func snapshotItem(from envelope: PlazaEnvelope) -> PlazaPresenceDTO? {
        if let first = envelope.snapshot?.first {
            return first
        }
        guard let id = envelope.client_id else { return nil }
        return PlazaPresenceDTO(
            client_id: id,
            display_name: envelope.display_name ?? "",
            kind: envelope.kind ?? ActivityKind.thinking.rawValue,
            project: envelope.project ?? "",
            ts: envelope.ts
        )
    }

    private func flush(generation: Int) {
        guard let member = pending else { return }
        send(PlazaEnvelope.presence(member), generation: generation)
    }

    private func send(_ envelope: PlazaEnvelope, generation: Int) {
        guard generation == self.generation, let task else { return }
        guard let data = try? envelope.encoded() else { return }
        guard let text = String(data: data, encoding: .utf8) else { return }
        task.send(.string(text)) { [weak self] error in
            guard error != nil, let self else { return }
            self.queue.async { self.handleDrop(generation: generation) }
        }
    }

    private func startHeartbeat(generation: Int) {
        heartbeat?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + AgoreConstants.plazaHeartbeat, repeating: AgoreConstants.plazaHeartbeat)
        timer.setEventHandler { [weak self] in
            self?.send(PlazaEnvelope.ping(), generation: generation)
        }
        timer.resume()
        heartbeat = timer
    }

    private func handleDrop(generation: Int) {
        guard generation == self.generation, running, !rejected else { return }
        emit(.link(.offline))
        tearDown()
        scheduleReconnect()
    }

    /// One retry in flight at a time. Backoff alone does not bound the socket count if
    /// every failed attempt is allowed to queue a fresh one.
    private func scheduleReconnect() {
        guard !reconnectScheduled else { return }
        reconnectScheduled = true
        let delays: [TimeInterval] = [1, 2, 5, 15]
        let delay = delays[min(reconnectAttempt, delays.count - 1)]
        reconnectAttempt += 1
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.reconnectScheduled = false
            // start() or reconnect() may have built a socket while this retry waited.
            guard self.running, !self.rejected, self.task == nil else { return }
            self.connect()
        }
    }

    private func tearDown() {
        generation &+= 1
        heartbeat?.cancel()
        heartbeat = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private func emit(_ inbound: PlazaInbound) {
        onInbound?(inbound)
    }
}
