import Foundation

/// Wire envelope shared with the Go plaza server. Optional fields stay nil so one
/// Codable type covers hello, presence, snapshot, and errors.
public struct PlazaEnvelope: Codable, Equatable, Sendable {
    public var v: Int
    public var type: String
    public var ts: Int64
    public var client_id: String?
    public var session_id: String?
    public var display_name: String?
    public var token: String?
    public var kind: String?
    public var project: String?
    public var snapshot: [PlazaPresenceDTO]?
    public var code: String?

    public init(
        v: Int = AgoreConstants.plazaProtocolVersion,
        type: String,
        ts: Int64 = PlazaEnvelope.now,
        client_id: String? = nil,
        session_id: String? = nil,
        display_name: String? = nil,
        token: String? = nil,
        kind: String? = nil,
        project: String? = nil,
        snapshot: [PlazaPresenceDTO]? = nil,
        code: String? = nil
    ) {
        self.v = v
        self.type = type
        self.ts = ts
        self.client_id = client_id
        self.session_id = session_id
        self.display_name = display_name
        self.token = token
        self.kind = kind
        self.project = project
        self.snapshot = snapshot
        self.code = code
    }

    public static var now: Int64 {
        Int64(Date().timeIntervalSince1970)
    }

    public static func hello(identity: ClientIdentity, displayName: String, token: String) -> PlazaEnvelope {
        PlazaEnvelope(
            type: "hello",
            client_id: identity.clientId,
            session_id: identity.sessionId,
            display_name: displayName,
            token: token
        )
    }

    public static func presence(_ member: PlazaMember) -> PlazaEnvelope {
        PlazaEnvelope(
            type: "presence",
            client_id: member.id,
            display_name: member.displayName,
            kind: member.kind.rawValue,
            project: member.project
        )
    }

    public static func nick(_ name: String) -> PlazaEnvelope {
        PlazaEnvelope(type: "nick", display_name: name)
    }

    public static func ping() -> PlazaEnvelope {
        PlazaEnvelope(type: "ping")
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data) throws -> PlazaEnvelope {
        try JSONDecoder().decode(PlazaEnvelope.self, from: data)
    }
}

public struct PlazaPresenceDTO: Codable, Equatable, Sendable {
    public var client_id: String
    public var display_name: String
    public var kind: String
    public var project: String
    public var ts: Int64

    public init(client_id: String, display_name: String, kind: String, project: String, ts: Int64) {
        self.client_id = client_id
        self.display_name = display_name
        self.kind = kind
        self.project = project
        self.ts = ts
    }

    public func asMember(localId: String) -> PlazaMember {
        PlazaMember(
            id: client_id,
            displayName: display_name,
            kind: ActivityKind(rawValue: kind) ?? .thinking,
            project: project,
            lastSeen: Date(timeIntervalSince1970: TimeInterval(ts)),
            isLocal: client_id == localId
        )
    }
}

public enum PlazaInbound: Sendable {
    case link(PlazaLinkState)
    case snapshot([PlazaMember])
    case presence(PlazaMember)
    case leave(String)
}
