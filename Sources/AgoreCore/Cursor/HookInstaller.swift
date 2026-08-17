import Foundation

public struct HookInstaller: Sendable {
    /// Cursor stays silent while a tool runs, so the closing half of each pair
    /// (postToolUse, afterShellExecution, afterMCPExecution) is what tells us a long
    /// command finished rather than the agent having quit.
    public static let subscribedEvents = [
        "preToolUse",
        "postToolUse",
        "postToolUseFailure",
        "afterFileEdit",
        "beforeShellExecution",
        "afterShellExecution",
        "beforeMCPExecution",
        "afterMCPExecution",
        "subagentStart",
        "subagentStop",
        "afterAgentThought",
        "stop",
        "sessionStart",
        "sessionEnd",
    ]

    public var hooksFile: URL
    public var hooksDirectory: URL

    public init(
        hooksFile: URL = AgorePaths.cursorHooksFile,
        hooksDirectory: URL = AgorePaths.cursorHooksDirectory
    ) {
        self.hooksFile = hooksFile
        self.hooksDirectory = hooksDirectory
    }

    public var isInstalled: Bool {
        guard let json = try? loadHooks() else { return false }
        return isSubscriptionComplete(json)
    }

    @discardableResult
    public func syncForwarder(from bundle: Bundle = .main) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: hooksDirectory, withIntermediateDirectories: true)
        guard let source = bundle.url(forResource: "agore-forward", withExtension: "sh") else {
            throw InstallerError.forwarderMissing
        }
        let destination = hooksDirectory.appendingPathComponent("agore-forward.sh")
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
        return destination
    }

    /// Reconciles against the full event list rather than stopping at the first Agore
    /// entry, so an install made by an older build picks up newly subscribed events.
    @discardableResult
    public func ensureInstalled(from bundle: Bundle = .main) throws -> Bool {
        try syncForwarder(from: bundle)
        let json = (try? loadHooks()) ?? defaultHooks()
        if isSubscriptionComplete(json) {
            return false
        }
        try saveHooks(mergeAgore(into: json))
        return true
    }

    public func uninstall() throws {
        guard var json = try? loadHooks() else { return }
        json = removeAgore(from: json)
        try saveHooks(json)
    }

    private func loadHooks() throws -> [String: Any] {
        let url = hooksFile
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InstallerError.invalidHooksFile
        }
        return json
    }

    private func saveHooks(_ json: [String: Any]) throws {
        let url = hooksFile
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func defaultHooks() -> [String: Any] {
        ["version": 1, "hooks": [String: Any]()]
    }

    func containsAgore(_ json: [String: Any]) -> Bool {
        guard let hooks = json["hooks"] as? [String: Any] else { return false }
        for value in hooks.values {
            if let items = value as? [[String: Any]], items.contains(where: isAgoreEntry) {
                return true
            }
        }
        return false
    }

    func isSubscriptionComplete(_ json: [String: Any]) -> Bool {
        guard let hooks = json["hooks"] as? [String: Any] else { return false }
        return Self.subscribedEvents.allSatisfy { event in
            (hooks[event] as? [[String: Any]])?.contains(where: isAgoreEntry) == true
        }
    }

    func mergeAgore(into json: [String: Any]) -> [String: Any] {
        var next = json
        if next["version"] == nil {
            next["version"] = 1
        }
        var hooks = next["hooks"] as? [String: Any] ?? [:]
        let entry: [String: Any] = [
            "command": AgoreConstants.hookCommand,
            "timeout": 1,
        ]
        for event in Self.subscribedEvents {
            var items = hooks[event] as? [[String: Any]] ?? []
            if !items.contains(where: isAgoreEntry) {
                items.append(entry)
            }
            hooks[event] = items
        }
        next["hooks"] = hooks
        return next
    }

    func removeAgore(from json: [String: Any]) -> [String: Any] {
        var next = json
        guard var hooks = next["hooks"] as? [String: Any] else { return next }
        for event in hooks.keys {
            if var items = hooks[event] as? [[String: Any]] {
                items.removeAll(where: isAgoreEntry)
                hooks[event] = items
            }
        }
        next["hooks"] = hooks
        return next
    }

    private func isAgoreEntry(_ item: [String: Any]) -> Bool {
        guard let command = item["command"] as? String else { return false }
        return command.contains(AgoreConstants.hookMarker)
    }
}

enum InstallerError: Error, LocalizedError {
    case forwarderMissing
    case invalidHooksFile

    var errorDescription: String? {
        switch self {
        case .forwarderMissing:
            return "agore-forward.sh is missing from the app bundle"
        case .invalidHooksFile:
            return "existing ~/.cursor/hooks.json is not valid JSON"
        }
    }
}
