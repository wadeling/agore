import Foundation

public enum ActivityKind: String, Codable, Sendable, CaseIterable {
    case reading
    case writing
    case running
    case thinking
    case waiting
    case idle
}

public enum PresenceSource: String, Codable, Sendable {
    case hook
    case transcript
    case demo
}

public struct PresenceEvent: Equatable, Sendable {
    public var conversationId: String
    public var parentId: String?
    public var kind: ActivityKind
    public var toolName: String?
    public var projectSlug: String
    public var occurredAt: Date
    public var hookEventName: String?
    public var source: PresenceSource

    public init(
        conversationId: String,
        parentId: String? = nil,
        kind: ActivityKind,
        toolName: String? = nil,
        projectSlug: String = "",
        occurredAt: Date = Date(),
        hookEventName: String? = nil,
        source: PresenceSource
    ) {
        self.conversationId = conversationId
        self.parentId = parentId
        self.kind = kind
        self.toolName = toolName
        self.projectSlug = projectSlug
        self.occurredAt = occurredAt
        self.hookEventName = hookEventName
        self.source = source
    }

    public var isSubagent: Bool { parentId != nil }
}

public struct AgentSession: Equatable, Identifiable, Sendable {
    public var id: String
    public var parentId: String?
    public var provider: String
    public var projectSlug: String
    public var displayName: String
    public var kind: ActivityKind
    public var toolName: String?
    public var lastSeen: Date
    public var source: PresenceSource

    public init(
        id: String,
        parentId: String? = nil,
        provider: String = "cursor",
        projectSlug: String,
        displayName: String,
        kind: ActivityKind,
        toolName: String? = nil,
        lastSeen: Date,
        source: PresenceSource
    ) {
        self.id = id
        self.parentId = parentId
        self.provider = provider
        self.projectSlug = projectSlug
        self.displayName = displayName
        self.kind = kind
        self.toolName = toolName
        self.lastSeen = lastSeen
        self.source = source
    }

    public var isSubagent: Bool { parentId != nil }
}

public enum AgorePaths {
    public static var applicationSupport: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("Agore", isDirectory: true)
    }

    public static var ingestPortFile: URL {
        applicationSupport.appendingPathComponent("ingest.port")
    }

    public static var databaseFile: URL {
        applicationSupport.appendingPathComponent("presence.sqlite")
    }

    public static var cursorHooksDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor", isDirectory: true)
            .appendingPathComponent("hooks", isDirectory: true)
    }

    public static var cursorHooksFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor", isDirectory: true)
            .appendingPathComponent("hooks.json")
    }

    public static var forwarderFile: URL {
        cursorHooksDirectory.appendingPathComponent("agore-forward.sh")
    }

    public static var cursorProjectsRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor", isDirectory: true)
            .appendingPathComponent("projects", isDirectory: true)
    }

    public static func ensureApplicationSupport() throws {
        try FileManager.default.createDirectory(at: applicationSupport, withIntermediateDirectories: true)
    }
}

public enum AgoreConstants {
    /// A slim strip that can sit above other windows all day without covering work.
    public static let panelSize = CGSize(width: 720, height: 102)
    public static let plazaHeight: CGFloat = 84
    public static let statusHeight: CGFloat = 18
    public static let cornerRadius: CGFloat = 12
    /// The plaza floor is translucent so the desktop shows through; the actors stay opaque.
    public static let groundOpacity: CGFloat = 0.7
    public static let alwaysOnTopKey = "AgoreAlwaysOnTop"
    /// Silence for this long counts as the agent having gone to sleep.
    public static let idleTimeout: TimeInterval = 2 * 60
    /// How long a departing agent stays on stage, long enough to walk off screen.
    public static let departureGrace: TimeInterval = 6
    public static let hookCommand = "./hooks/agore-forward.sh"
    public static let hookMarker = "agore-forward"
    public static let providerCursor = "cursor"
}
