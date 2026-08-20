import Foundation

/// Wire envelope shared with the Go plaza server. Optional fields stay nil so one
/// Codable type covers hello, presence, snapshot, and errors.
public struct PlazaEnvelope: Codable, Equatable, Sendable {
    public var v: Int
    public var type: String
    public var ts: Int64
    /// The connection a frame belongs to. One client owns as many members as it has
    /// agents, so presence and leave name the member as well.
    public var client_id: String?
    public var member_id: String?
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
        member_id: String? = nil,
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
        self.member_id = member_id
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

    public static func presence(_ member: PlazaMember, from clientId: String) -> PlazaEnvelope {
        PlazaEnvelope(
            type: "presence",
            client_id: clientId,
            member_id: member.id,
            display_name: member.displayName,
            kind: member.kind.rawValue,
            project: member.project
        )
    }

    public static func leave(_ memberId: String, from clientId: String) -> PlazaEnvelope {
        PlazaEnvelope(type: "leave", client_id: clientId, member_id: memberId)
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
    public var member_id: String?
    public var display_name: String
    public var kind: String
    public var project: String
    public var ts: Int64

    public init(
        client_id: String,
        member_id: String? = nil,
        display_name: String,
        kind: String,
        project: String,
        ts: Int64
    ) {
        self.client_id = client_id
        self.member_id = member_id
        self.display_name = display_name
        self.kind = kind
        self.project = project
        self.ts = ts
    }

    /// A client that predates per-agent members sends none, and stands on the plaza as a
    /// single person under its client id.
    public func asMember(localId: String) -> PlazaMember {
        let id = member_id?.isEmpty == false ? member_id! : client_id
        return PlazaMember(
            id: id,
            displayName: display_name,
            kind: ActivityKind(rawValue: kind) ?? .thinking,
            project: project,
            lastSeen: Date(timeIntervalSince1970: TimeInterval(ts)),
            provider: Self.agent(of: id),
            isLocal: client_id == localId
        )
    }

    /// Which agent a person is running, read back out of the member id rather than sent
    /// twice. A name is only what the user called their Mac; the plaza is what pairs it
    /// with the agent when it draws the two together.
    private static func agent(of memberId: String) -> String {
        guard let tail = memberId.split(separator: ":").last else { return "plaza" }
        return AgentProvider(rawValue: String(tail))?.rawValue ?? "plaza"
    }
}

public enum PlazaInbound: Sendable {
    case link(PlazaLinkState)
    case snapshot([PlazaMember])
    case presence(PlazaMember)
    case leave(String)
}
