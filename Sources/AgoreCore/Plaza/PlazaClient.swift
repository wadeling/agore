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
                self?.flush()
            }
            self.debounceWork = work
            self.queue.asyncAfter(deadline: .now() + AgoreConstants.plazaDebounce, execute: work)
        }
    }

    public func sendNick(_ name: String) {
        queue.async {
            self.send(PlazaEnvelope.nick(name))
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
        task.resume()
        send(PlazaEnvelope.hello(
            identity: identity,
            displayName: ClientIdentity.displayName,
            token: ClientIdentity.plazaToken
        ))
        receive()
        startHeartbeat()
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            self.queue.async {
                switch result {
                case .failure:
                    self.handleDrop()
                case .success(let message):
                    self.handle(message)
                    self.receive()
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
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
            flush(immediate: true)
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
            handleDrop()
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

    private func flush(immediate: Bool = false) {
        guard let member = pending else { return }
        if !immediate, debounceWork?.isCancelled == false {
            // still waiting
        }
        send(PlazaEnvelope.presence(member))
    }

    private func send(_ envelope: PlazaEnvelope) {
        guard let task, let data = try? envelope.encoded() else { return }
        guard let text = String(data: data, encoding: .utf8) else { return }
        task.send(.string(text)) { [weak self] error in
            if error != nil {
                self?.queue.async { self?.handleDrop() }
            }
        }
    }

    private func startHeartbeat() {
        heartbeat?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + AgoreConstants.plazaHeartbeat, repeating: AgoreConstants.plazaHeartbeat)
        timer.setEventHandler { [weak self] in
            self?.send(PlazaEnvelope.ping())
        }
        timer.resume()
        heartbeat = timer
    }

    private func handleDrop() {
        guard running else { return }
        if rejected { return }
        emit(.link(.offline))
        tearDown()
        let delays: [TimeInterval] = [1, 2, 5, 15]
        let delay = delays[min(reconnectAttempt, delays.count - 1)]
        reconnectAttempt += 1
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.running, !self.rejected else { return }
            self.connect()
        }
    }

    private func tearDown() {
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
