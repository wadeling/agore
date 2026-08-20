import Foundation
import Network

public final class HookIngestServer: @unchecked Sendable {
    public var onEvent: (@Sendable (PresenceEvent) -> Void)?
    public var onReady: (@Sendable (UInt16) -> Void)?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.wadeling.agore.ingest")
    private(set) public var port: UInt16 = 0

    public init() {}

    public func start() throws {
        let parameters = NWParameters.tcp
        parameters.acceptLocalOnly = true
        parameters.requiredInterfaceType = .loopback
        let listener = try NWListener(using: parameters, on: .any)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                if let value = listener.port?.rawValue {
                    self.port = value
                    self.writePortFile(value)
                    self.onReady?(value)
                }
            case .failed(let error):
                NSLog("Agore ingest failed: \(error)")
            default:
                break
            }
        }
        listener.start(queue: queue)
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        try? FileManager.default.removeItem(at: AgorePaths.ingestPortFile)
    }

    private func writePortFile(_ port: UInt16) {
        do {
            try AgorePaths.ensureApplicationSupport()
            try String(port).data(using: .utf8)?.write(to: AgorePaths.ingestPortFile, options: .atomic)
        } catch {
            NSLog("Agore failed to write ingest port: \(error)")
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var next = buffer
            if let data { next.append(data) }
            if let request = HTTPRequest.parse(next) {
                self.respond(to: request, on: connection)
                return
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self.receive(on: connection, buffer: next)
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) {
        guard request.method == "POST", request.path == "/events" else {
            send(status: 404, on: connection)
            return
        }
        do {
            let payload = try JSONDecoder().decode(HookPayload.self, from: request.body)
            if let event = payload.asPresenceEvent() {
                onEvent?(event)
            }
            send(status: 204, on: connection)
        } catch {
            send(status: 400, on: connection)
        }
    }

    /// Cancelling before the send completes drops the response on the floor, and the
    /// forwarder then treats a healthy ingest as unreachable.
    private func send(status: Int, on connection: NWConnection) {
        connection.send(
            content: HTTPRequest.response(status: status, body: Data()),
            completion: .contentProcessed { _ in connection.cancel() }
        )
    }
}

struct HTTPRequest {
    var method: String
    var path: String
    var body: Data

    static func parse(_ data: Data) -> HTTPRequest? {
        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = data.subdata(in: data.startIndex..<headerRange.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0])
        let path = String(parts[1].split(separator: "?").first ?? parts[1])
        var contentLength = 0
        for line in lines.dropFirst() {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                let value = line.split(separator: ":", maxSplits: 1).last?
                    .trimmingCharacters(in: .whitespaces)
                contentLength = Int(value ?? "0") ?? 0
            }
        }
        let bodyStart = headerRange.upperBound
        let available = data.count - bodyStart
        guard available >= contentLength else { return nil }
        let body = data.subdata(in: bodyStart..<(bodyStart + contentLength))
        return HTTPRequest(method: method, path: path, body: body)
    }

    static func response(status: Int, body: Data) -> Data {
        let reason = status == 204 ? "No Content" : status == 400 ? "Bad Request" : "Not Found"
        let header = "HTTP/1.1 \(status) \(reason)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}
