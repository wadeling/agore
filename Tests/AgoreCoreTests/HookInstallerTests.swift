import XCTest
@testable import AgoreCore

final class HookInstallerTests: XCTestCase {
    func testMergesWithoutClobberingExistingHooks() {
        let installer = HookInstaller(
            hooksFile: URL(fileURLWithPath: "/tmp/unused.json"),
            hooksDirectory: URL(fileURLWithPath: "/tmp")
        )
        let existing: [String: Any] = [
            "version": 1,
            "hooks": [
                "preToolUse": [["command": "./hooks/other.sh"]],
            ],
        ]
        let merged = installer.mergeAgore(into: existing)
        let hooks = merged["hooks"] as? [String: Any]
        let pre = hooks?["preToolUse"] as? [[String: Any]]
        XCTAssertEqual(pre?.count, 2)
        XCTAssertTrue(installer.containsAgore(merged))
        XCTAssertEqual(pre?.first?["command"] as? String, "./hooks/other.sh")

        let removed = installer.removeAgore(from: merged)
        XCTAssertFalse(installer.containsAgore(removed))
        let preAfter = (removed["hooks"] as? [String: Any])?["preToolUse"] as? [[String: Any]]
        XCTAssertEqual(preAfter?.count, 1)
    }

    func testWritesHooksFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("agore-hooks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("hooks.json")
        let existing: [String: Any] = ["version": 1, "hooks": [String: Any]()]
        let data = try JSONSerialization.data(withJSONObject: existing, options: [.prettyPrinted])
        try data.write(to: file)

        let installer = HookInstaller(hooksFile: file, hooksDirectory: dir.appendingPathComponent("hooks"))
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
        json = installer.mergeAgore(into: json)
        let out = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
        try out.write(to: file)
        XCTAssertTrue(installer.isInstalled)
        try installer.uninstall()
        XCTAssertFalse(installer.isInstalled)
    }
}
