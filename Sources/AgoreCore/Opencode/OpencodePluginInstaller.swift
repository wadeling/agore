import Foundation

/// opencode loads every file in its plugin directory at startup, so installing is a
/// copy rather than the read-merge-write that `~/.cursor/hooks.json` needs. What has to
/// be reconciled instead is the version: an opencode config left holding last release's
/// forwarder would keep reporting through it forever.
public struct OpencodePluginInstaller: Sendable {
    public var pluginsDirectory: URL
    public var legacyPluginsDirectory: URL?

    public init(
        pluginsDirectory: URL = AgorePaths.opencodePluginsDirectory,
        legacyPluginsDirectory: URL? = AgorePaths.opencodeLegacyPluginsDirectory
    ) {
        self.pluginsDirectory = pluginsDirectory
        self.legacyPluginsDirectory = legacyPluginsDirectory
    }

    public var pluginFile: URL {
        pluginsDirectory.appendingPathComponent(AgoreConstants.opencodePluginFileName)
    }

    public var isInstalled: Bool {
        targets.allSatisfy(isCurrent)
    }

    @discardableResult
    public func ensureInstalled(from bundle: Bundle = .main) throws -> Bool {
        try ensureInstalled(source: Self.bundledPlugin(in: bundle))
    }

    @discardableResult
    public func ensureInstalled(source: URL) throws -> Bool {
        let script = try String(contentsOf: source, encoding: .utf8)
        guard script.contains(AgoreConstants.opencodePluginMarker) else {
            throw OpencodeInstallerError.pluginUnversioned
        }
        var changed = false
        for target in targets where !isCurrent(target) {
            try write(script, to: target)
            changed = true
        }
        return changed
    }

    public func uninstall() throws {
        let fm = FileManager.default
        for target in [pluginFile] + legacyTargets where fm.fileExists(atPath: target.path) {
            try fm.removeItem(at: target)
        }
    }

    public static func bundledPlugin(in bundle: Bundle = .main) throws -> URL {
        guard let url = bundle.url(
            forResource: (AgoreConstants.opencodePluginFileName as NSString).deletingPathExtension,
            withExtension: (AgoreConstants.opencodePluginFileName as NSString).pathExtension
        ) else {
            throw OpencodeInstallerError.pluginMissing
        }
        return url
    }

    /// The current plugin directory always counts. The singular one only does when the
    /// user already has it, meaning they are on a build that reads from there.
    private var targets: [URL] {
        [pluginFile] + legacyTargets.filter {
            FileManager.default.fileExists(atPath: $0.deletingLastPathComponent().path)
        }
    }

    private var legacyTargets: [URL] {
        guard let legacyPluginsDirectory else { return [] }
        return [legacyPluginsDirectory.appendingPathComponent(AgoreConstants.opencodePluginFileName)]
    }

    private func isCurrent(_ target: URL) -> Bool {
        guard let script = try? String(contentsOf: target, encoding: .utf8) else { return false }
        return script.contains(AgoreConstants.opencodePluginMarker)
    }

    private func write(_ script: String, to target: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(script.utf8).write(to: target, options: .atomic)
    }
}

enum OpencodeInstallerError: Error, LocalizedError {
    case pluginMissing
    case pluginUnversioned

    var errorDescription: String? {
        switch self {
        case .pluginMissing:
            return "agore.js is missing from the app bundle"
        case .pluginUnversioned:
            return "agore.js carries no version marker"
        }
    }
}
