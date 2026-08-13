import XCTest
@testable import AgoreCore

@MainActor
final class PresenceStoreTests: XCTestCase {
    func testApplyHookEventAndPersist() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.open()
        store.apply(
            PresenceEvent(
                conversationId: "c1",
                kind: .writing,
                toolName: "Write",
                projectSlug: "agore",
                occurredAt: Date(),
                hookEventName: "preToolUse",
                source: .hook
            )
        )
        XCTAssertEqual(store.activeSessions().count, 1)
        XCTAssertEqual(store.activeSessions().first?.kind, .writing)
        XCTAssertFalse(store.isEmpty)

        let restored = PresenceStore(idleTimeout: 60, databaseURL: url)
        restored.open()
        XCTAssertEqual(restored.activeSessions().first?.id, "c1")
        XCTAssertEqual(restored.activeSessions().first?.kind, .writing)
    }

    func testTranscriptDoesNotOverrideFreshHook() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.open()
        store.apply(
            PresenceEvent(
                conversationId: "c1",
                kind: .writing,
                toolName: "Write",
                projectSlug: "agore",
                source: .hook
            )
        )
        store.apply(
            PresenceEvent(
                conversationId: "c1",
                kind: .reading,
                toolName: "Read",
                projectSlug: "agore",
                source: .transcript
            )
        )
        XCTAssertEqual(store.activeSessions().first?.kind, .writing)
        XCTAssertEqual(store.activeSessions().first?.source, .hook)
    }

    func testStaleSessionIsNotActive() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 1, databaseURL: url)
        store.open()
        store.apply(
            PresenceEvent(
                conversationId: "old",
                kind: .running,
                toolName: "Shell",
                projectSlug: "agore",
                occurredAt: Date().addingTimeInterval(-30),
                source: .hook
            )
        )
        XCTAssertTrue(store.activeSessions().isEmpty)
        XCTAssertTrue(store.isEmpty)
    }
}
