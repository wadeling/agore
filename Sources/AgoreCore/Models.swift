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
    case plaza
}

public enum PlazaLinkState: String, Sendable {
    case offline
    case connecting
    case online
    case unauthorized
}

/// Daylight on the plaza. Backgrounds are cached per period so a dusk sky is not
/// rebuilt every frame; the scene swaps the texture when the hour rolls over.
public enum PlazaPeriod: Hashable, Sendable {
    case day
    case dusk
    case night

    public static func current(at date: Date = Date()) -> PlazaPeriod {
        at(hour: Calendar.current.component(.hour, from: date))
    }

    public static func at(hour: Int) -> PlazaPeriod {
        switch hour {
        case 6..<8, 17..<20: return .dusk
        case 0..<6, 20...23: return .night
        default: return .day
        }
    }
}

/// One pixel person on the plaza. A member is a client-and-agent pair rather than a whole
/// Mac, so running Cursor and opencode side by side puts two of them on stage.
public struct PlazaMember: Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var kind: ActivityKind
    public var project: String
    public var lastSeen: Date
    public var provider: String
    public var isLocal: Bool

    public init(
        id: String,
        displayName: String,
        kind: ActivityKind,
        project: String = "",
        lastSeen: Date = Date(),
        provider: String = "plaza",
        isLocal: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.project = project
        self.lastSeen = lastSeen
        self.provider = provider
        self.isLocal = isLocal
    }

    /// Stable across restarts and distinct per agent, and prefixed with the client id so
    /// the plaza server can tell at a glance which connection a member belongs to.
    public static func id(client: String, provider: AgentProvider) -> String {
        "\(client):\(provider.rawValue)"
    }

    /// The agent this person stands for, where it is one Agore knows how to name.
    public var agent: AgentProvider? {
        AgentProvider(rawValue: provider)
    }

    /// What stands under the pixel person, and it has to stay narrow: a name much wider
    /// than the twelve pixels it belongs to runs into the neighbours' names. So the agent
    /// is a two-letter tag and a long nickname is cut — `wade-oc`, `lingximosm…-cs`. The
    /// whole of it is a hover away.
    public var label: String {
        let nickname = displayName.count > AgoreConstants.nicknameCeiling
            ? displayName.prefix(AgoreConstants.nicknameCeiling) + "…"
            : displayName
        guard let agent else { return String(nickname) }
        return "\(nickname)-\(agent.shortName)"
    }

    /// Nothing abbreviated away, for a hover.
    public var fullLabel: String {
        guard let agent else { return displayName }
        return "\(displayName)-\(agent.rawValue)"
    }

    public func asSession() -> AgentSession {
        AgentSession(
            id: id,
            provider: provider,
            projectSlug: project,
            displayName: label,
            fullName: fullLabel,
            kind: kind,
            lastSeen: lastSeen,
            source: isLocal ? .hook : .plaza
        )
    }
}

public struct PresenceEvent: Equatable, Sendable {
    public var conversationId: String
    public var parentId: String?
    public var kind: ActivityKind
    public var toolName: String?
    public var projectSlug: String
    public var occurredAt: Date
    public var hookEventName: String?
    /// Pairs a tool call's opening hook with its closing one. Only the generic
    /// preToolUse/postToolUse family carries it.
    public var toolUseId: String?
    public var provider: String
    public var source: PresenceSource

    public init(
        conversationId: String,
        parentId: String? = nil,
        kind: ActivityKind,
        toolName: String? = nil,
        projectSlug: String = "",
        occurredAt: Date = Date(),
        hookEventName: String? = nil,
        toolUseId: String? = nil,
        provider: String = AgoreConstants.providerCursor,
        source: PresenceSource
    ) {
        self.conversationId = conversationId
        self.parentId = parentId
        self.kind = kind
        self.toolName = toolName
        self.projectSlug = projectSlug
        self.occurredAt = occurredAt
        self.hookEventName = hookEventName
        self.toolUseId = toolUseId
        self.provider = provider
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
    /// The same name with nothing abbreviated away, shown when the pointer rests on this
    /// one. Equal to `displayName` unless the name had to be cut down to fit under a
    /// twelve-pixel figure.
    public var fullName: String
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
        fullName: String? = nil,
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
        self.fullName = fullName ?? displayName
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

    public static var clientIdentityFile: URL {
        applicationSupport.appendingPathComponent("client.json")
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

    public static var cursorRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor", isDirectory: true)
    }

    /// A menu bar app inherits none of the shell's environment, so `XDG_CONFIG_HOME` is
    /// almost always absent here; it is honoured anyway for the people who set it in
    /// their launch agent.
    public static var opencodeConfigDirectory: URL {
        let base = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
        let root = base?.isEmpty == false
            ? URL(fileURLWithPath: base!, isDirectory: true)
            : FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config", isDirectory: true)
        return root.appendingPathComponent("opencode", isDirectory: true)
    }

    public static var opencodePluginsDirectory: URL {
        opencodeConfigDirectory.appendingPathComponent("plugins", isDirectory: true)
    }

    /// Older opencode builds scanned a singular `plugin/`. Agore writes there too, but
    /// only when the directory already exists, rather than leaving a stray folder in the
    /// config of everyone on a current build.
    public static var opencodeLegacyPluginsDirectory: URL {
        opencodeConfigDirectory.appendingPathComponent("plugin", isDirectory: true)
    }

    public static var opencodeDataDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("share", isDirectory: true)
            .appendingPathComponent("opencode", isDirectory: true)
    }

    public static func ensureApplicationSupport() throws {
        try FileManager.default.createDirectory(at: applicationSupport, withIntermediateDirectories: true)
    }
}

public enum AgoreConstants {
    public static let plazaHeight: CGFloat = 84
    public static let statusHeight: CGFloat = 18
    /// The original strip card: plaza plus the status band. The band now overlays
    /// the bottom on hover instead of sitting under the art, but the window stays
    /// this tall so the plaza can use the full card at 2×.
    public static let panelSize = CGSize(width: 720, height: plazaHeight + statusHeight)
    /// Dock / first-launch window. Plaza area is 720×720 (3× the 240 courtyard).
    public static let windowSize = CGSize(width: 720, height: 738)
    public static let cornerRadius: CGFloat = 12
    /// The plaza floor is translucent so the desktop shows through; the actors stay opaque.
    public static let groundOpacity: CGFloat = 0.7
    public static let alwaysOnTopKey = "AgoreAlwaysOnTop"
    public static let plazaURLKey = "AgorePlazaURL"
    public static let plazaTokenKey = "AgorePlazaToken"
    public static let displayNameKey = "AgoreDisplayName"
    public static let themeKey = "AgoreTheme"
    public static let panelOpacityKey = "AgorePanelOpacity"
    public static let defaultPlazaURL = "wss://agore.bytebar.dev/v1/plaza"
    /// Version 2 added member_id: one client stands on the plaza as a person per agent.
    public static let plazaProtocolVersion = 2
    /// Letters of a nickname that fit under a pixel person before it has to be cut.
    public static let nicknameCeiling = 10
    public static let plazaHeartbeat: TimeInterval = 25
    public static let plazaDebounce: TimeInterval = 0.4
    /// Silence for this long counts as the agent having gone to sleep, unless a tool
    /// call is still open — Cursor emits nothing at all while one runs.
    public static let idleTimeout: TimeInterval = 2 * 60
    /// Ceiling on how long an unclosed tool call keeps an agent awake. A hook that
    /// never reports back (fail-open timeout, app restart mid-call) must not pin
    /// someone to the plaza forever.
    public static let toolCallCeiling: TimeInterval = 30 * 60
    /// How long a departing agent stays on stage, long enough to walk off screen.
    public static let departureGrace: TimeInterval = 6
    public static let hookCommand = "./hooks/agore-forward.sh"
    public static let hookMarker = "agore-forward"
    /// Bumped whenever `Resources/plugins/agore.js` changes, so an opencode config
    /// carrying an older copy is reinstalled instead of being left as it is.
    public static let opencodePluginVersion = 1
    public static let opencodePluginFileName = "agore.js"
    public static var opencodePluginMarker: String { "agore-plugin v\(opencodePluginVersion)" }
    public static let providerCursor = AgentProvider.cursor.rawValue
    public static let providerOpencode = AgentProvider.opencode.rawValue
}
