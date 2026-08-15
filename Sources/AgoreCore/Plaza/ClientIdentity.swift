import Foundation

public struct ClientIdentity: Equatable, Sendable {
    public var clientId: String
    public var sessionId: String

    public init(clientId: String, sessionId: String = UUID().uuidString) {
        self.clientId = clientId
        self.sessionId = sessionId
    }

    public static func ephemeral() -> ClientIdentity {
        ClientIdentity(clientId: UUID().uuidString, sessionId: UUID().uuidString)
    }

    /// Loads the durable client id from Application Support, creating one on first launch.
    public static func load(file: URL = AgorePaths.clientIdentityFile) -> ClientIdentity {
        if let data = try? Data(contentsOf: file),
           let saved = try? JSONDecoder().decode(Persisted.self, from: data),
           !saved.client_id.isEmpty {
            return ClientIdentity(clientId: saved.client_id)
        }
        let created = ClientIdentity(clientId: UUID().uuidString)
        try? AgorePaths.ensureApplicationSupport()
        if let data = try? JSONEncoder().encode(Persisted(client_id: created.clientId)) {
            try? data.write(to: file, options: .atomic)
        }
        return created
    }

    public static var displayName: String {
        get {
            let stored = UserDefaults.standard.string(forKey: AgoreConstants.displayNameKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return stored.isEmpty ? defaultDisplayName : stored
        }
        set {
            let trimmed = String(newValue.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
            UserDefaults.standard.set(trimmed, forKey: AgoreConstants.displayNameKey)
        }
    }

    public static var plazaToken: String {
        get { UserDefaults.standard.string(forKey: AgoreConstants.plazaTokenKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: AgoreConstants.plazaTokenKey) }
    }

    public static var plazaURL: URL {
        get {
            let raw = UserDefaults.standard.string(forKey: AgoreConstants.plazaURLKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return URL(string: raw.isEmpty ? AgoreConstants.defaultPlazaURL : raw)
                ?? URL(string: AgoreConstants.defaultPlazaURL)!
        }
        set {
            UserDefaults.standard.set(newValue.absoluteString, forKey: AgoreConstants.plazaURLKey)
        }
    }

    public static var defaultDisplayName: String {
        let host = Host.current().localizedName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return host.isEmpty ? "agent" : String(host.prefix(24))
    }

    private struct Persisted: Codable {
        var client_id: String
    }
}
