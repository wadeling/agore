import XCTest
@testable import AgoreCore

final class OpencodePluginInstallerTests: XCTestCase {
    func testInstallsIntoPluginsDirectory() throws {
        let root = try makeRoot()
        let installer = OpencodePluginInstaller(
            pluginsDirectory: root.appendingPathComponent("plugins"),
            legacyPluginsDirectory: root.appendingPathComponent("plugin")
        )
        XCTAssertFalse(installer.isInstalled)

        XCTAssertTrue(try installer.ensureInstalled(source: try makeSource(in: root)))
        XCTAssertTrue(installer.isInstalled)
        // Installing twice must not rewrite a plugin opencode has already loaded.
        XCTAssertFalse(try installer.ensureInstalled(source: try makeSource(in: root)))

        try installer.uninstall()
        XCTAssertFalse(installer.isInstalled)
    }

    func testOlderVersionIsReinstalled() throws {
        let root = try makeRoot()
        let plugins = root.appendingPathComponent("plugins")
        let installer = OpencodePluginInstaller(pluginsDirectory: plugins, legacyPluginsDirectory: nil)
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try "// agore-plugin v0\n".write(
            to: plugins.appendingPathComponent(AgoreConstants.opencodePluginFileName),
            atomically: true,
            encoding: .utf8
        )
        XCTAssertFalse(installer.isInstalled)
        XCTAssertTrue(try installer.ensureInstalled(source: try makeSource(in: root)))
        XCTAssertTrue(installer.isInstalled)
    }

    /// The singular directory is only written to when the user is on a build that reads
    /// from it, which shows as the directory already being there.
    func testLegacyDirectoryIsOnlyWrittenWhenItExists() throws {
        let root = try makeRoot()
        let legacy = root.appendingPathComponent("plugin")
        let installer = OpencodePluginInstaller(
            pluginsDirectory: root.appendingPathComponent("plugins"),
            legacyPluginsDirectory: legacy
        )
        try installer.ensureInstalled(source: try makeSource(in: root))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))

        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        XCTAssertFalse(installer.isInstalled)
        try installer.ensureInstalled(source: try makeSource(in: root))
        XCTAssertTrue(installer.isInstalled)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: legacy.appendingPathComponent(AgoreConstants.opencodePluginFileName).path
            )
        )
    }

    func testUnversionedSourceIsRejected() throws {
        let root = try makeRoot()
        let installer = OpencodePluginInstaller(
            pluginsDirectory: root.appendingPathComponent("plugins"),
            legacyPluginsDirectory: nil
        )
        let source = root.appendingPathComponent("stray.js")
        try "export const Agore = async () => ({})\n".write(to: source, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try installer.ensureInstalled(source: source))
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agore-opencode-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeSource(in root: URL) throws -> URL {
        let source = root.appendingPathComponent("source.js")
        try "// \(AgoreConstants.opencodePluginMarker)\nexport const Agore = async () => ({})\n"
            .write(to: source, atomically: true, encoding: .utf8)
        return source
    }
}
