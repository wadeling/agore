import Foundation

public enum AgentProvider: String, CaseIterable, Sendable {
    case cursor
    case opencode

    public var displayName: String {
        switch self {
        case .cursor: return "Cursor"
        case .opencode: return "opencode"
        }
    }

    /// Two letters to sit under a pixel person twelve pixels wide. Spelled out per agent
    /// rather than cut from the name, so each new one picks a tag that reads and does not
    /// collide with a tag already taken — `cc` for Claude Code, say, next to `cs` and `oc`.
    public var shortName: String {
        switch self {
        case .cursor: return "cs"
        case .opencode: return "oc"
        }
    }

    /// What the user has to go and install, in their words rather than ours.
    public var bridgeName: String {
        switch self {
        case .cursor: return "Cursor Hooks"
        case .opencode: return "opencode Plugin"
        }
    }
}

public struct BridgeStatus: Equatable, Identifiable, Sendable {
    public var provider: AgentProvider
    /// Whether this agent appears to be on the Mac at all. Agore leaves an undetected
    /// provider alone rather than scattering config directories for tools nobody runs.
    public var isDetected: Bool
    public var isInstalled: Bool
    public var failed: Bool

    public var id: String { provider.rawValue }

    public init(provider: AgentProvider, isDetected: Bool, isInstalled: Bool, failed: Bool = false) {
        self.provider = provider
        self.isDetected = isDetected
        self.isInstalled = isInstalled
        self.failed = failed
    }
}

/// One door for both ways into Agore: Cursor's user hooks and opencode's plugin
/// directory. They are installed differently and can fail independently, so the app
/// deals in a list of per-provider states instead of a single "hooks are on" flag.
public struct AgentBridges: Sendable {
    public var cursor: HookInstaller
    public var opencode: OpencodePluginInstaller

    public init(
        cursor: HookInstaller = HookInstaller(),
        opencode: OpencodePluginInstaller = OpencodePluginInstaller()
    ) {
        self.cursor = cursor
        self.opencode = opencode
    }

    public func statuses() -> [BridgeStatus] {
        AgentProvider.allCases.map { provider in
            BridgeStatus(
                provider: provider,
                isDetected: isDetected(provider),
                isInstalled: isInstalled(provider)
            )
        }
    }

    /// Installs into every detected provider, or into one named provider whether or not
    /// it was detected — that being the point of asking for it by hand.
    @discardableResult
    public func install(_ only: AgentProvider? = nil, from bundle: Bundle = .main) -> [BridgeStatus] {
        AgentProvider.allCases.map { provider in
            let detected = isDetected(provider)
            guard only == provider || (only == nil && detected) else {
                return BridgeStatus(provider: provider, isDetected: detected, isInstalled: isInstalled(provider))
            }
            var failed = false
            do {
                switch provider {
                case .cursor: try cursor.ensureInstalled(from: bundle)
                case .opencode: try opencode.ensureInstalled(from: bundle)
                }
            } catch {
                failed = true
                NSLog("Agore failed to install the \(provider.bridgeName): \(error)")
            }
            return BridgeStatus(
                provider: provider,
                isDetected: detected,
                isInstalled: isInstalled(provider),
                failed: failed
            )
        }
    }

    private func isInstalled(_ provider: AgentProvider) -> Bool {
        switch provider {
        case .cursor: return cursor.isInstalled
        case .opencode: return opencode.isInstalled
        }
    }

    /// Both agents keep a dot-directory in the home folder from their first run, which is
    /// all the detection Agore needs: a GUI app inherits no PATH worth searching.
    private func isDetected(_ provider: AgentProvider) -> Bool {
        let fm = FileManager.default
        switch provider {
        case .cursor:
            return fm.fileExists(atPath: AgorePaths.cursorRoot.path)
        case .opencode:
            return [AgorePaths.opencodeConfigDirectory, AgorePaths.opencodeDataDirectory]
                .contains { fm.fileExists(atPath: $0.path) }
        }
    }
}

public extension Array where Element == BridgeStatus {
    /// Undetected providers are left out entirely; a status strip nineteen pixels tall
    /// has no room to nag about an agent the user does not run.
    var summary: String {
        let detected = filter(\.isDetected)
        guard !detected.isEmpty else { return "no agents" }
        return detected
            .map { status in
                let state = status.failed ? "failed" : status.isInstalled ? "on" : "off"
                return "\(status.provider.rawValue) \(state)"
            }
            .joined(separator: " · ")
    }

    var needsInstall: Bool {
        contains { $0.isDetected && !$0.isInstalled }
    }
}
