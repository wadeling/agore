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

    func testOpenToolCallOutlivesIdleTimeout() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.identity = ClientIdentity(clientId: "me", sessionId: "s")
        store.open()
        let started = Date().addingTimeInterval(-300)
        store.apply(
            PresenceEvent(
                conversationId: "c1",
                kind: .running,
                toolName: "Shell",
                projectSlug: "agore",
                occurredAt: started,
                hookEventName: "preToolUse",
                toolUseId: "call-1",
                source: .hook
            )
        )
        // Five minutes of silence, but the command never reported back.
        XCTAssertTrue(store.isBusy("c1"))
        XCTAssertEqual(store.activeSessions().count, 1)
        XCTAssertEqual(store.localActivity(), .running)
        XCTAssertFalse(store.isEmpty)
    }

    func testToolCallCloseLetsSessionGoIdle() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.open()
        let started = Date().addingTimeInterval(-300)
        store.apply(
            PresenceEvent(
                conversationId: "c1",
                kind: .running,
                toolName: "Shell",
                projectSlug: "agore",
                occurredAt: started,
                hookEventName: "preToolUse",
                toolUseId: "call-1",
                source: .hook
            )
        )
        store.apply(
            PresenceEvent(
                conversationId: "c1",
                kind: .thinking,
                toolName: "Shell",
                projectSlug: "agore",
                occurredAt: started.addingTimeInterval(1),
                hookEventName: "postToolUse",
                toolUseId: "call-1",
                source: .hook
            )
        )
        XCTAssertFalse(store.isBusy("c1"))
        XCTAssertTrue(store.activeSessions().isEmpty)
        XCTAssertTrue(store.isEmpty)
    }

    func testShellPairTracksCallWithoutToolUseId() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.open()
        let started = Date().addingTimeInterval(-300)
        store.apply(
            PresenceEvent(
                conversationId: "c1",
                kind: .running,
                projectSlug: "agore",
                occurredAt: started,
                hookEventName: "beforeShellExecution",
                source: .hook
            )
        )
        XCTAssertTrue(store.isBusy("c1"))
        store.apply(
            PresenceEvent(
                conversationId: "c1",
                kind: .thinking,
                projectSlug: "agore",
                occurredAt: started.addingTimeInterval(1),
                hookEventName: "afterShellExecution",
                source: .hook
            )
        )
        XCTAssertFalse(store.isBusy("c1"))
    }

    func testStopClearsOpenToolCalls() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.open()
        store.apply(
            PresenceEvent(
                conversationId: "c1",
                kind: .running,
                toolName: "Shell",
                projectSlug: "agore",
                hookEventName: "preToolUse",
                toolUseId: "call-1",
                source: .hook
            )
        )
        XCTAssertTrue(store.isBusy("c1"))
        store.apply(
            PresenceEvent(
                conversationId: "c1",
                kind: .waiting,
                projectSlug: "agore",
                hookEventName: "stop",
                source: .hook
            )
        )
        XCTAssertFalse(store.isBusy("c1"))
    }

    func testOpencodeToolPairTracksCall() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.open()
        let started = Date().addingTimeInterval(-300)
        store.apply(
            PresenceEvent(
                conversationId: "ses_1",
                kind: .running,
                toolName: "bash",
                projectSlug: "agore",
                occurredAt: started,
                hookEventName: "tool.execute.before",
                toolUseId: "call_1",
                provider: AgoreConstants.providerOpencode,
                source: .hook
            )
        )
        XCTAssertTrue(store.isBusy("ses_1"))
        XCTAssertEqual(store.activeSessions().first?.provider, AgoreConstants.providerOpencode)
        store.apply(
            PresenceEvent(
                conversationId: "ses_1",
                kind: .thinking,
                toolName: "bash",
                projectSlug: "agore",
                occurredAt: started.addingTimeInterval(1),
                hookEventName: "tool.execute.after",
                toolUseId: "call_1",
                provider: AgoreConstants.providerOpencode,
                source: .hook
            )
        )
        XCTAssertFalse(store.isBusy("ses_1"))
    }

    func testOpencodeIdleSessionSitsDown() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.open()
        store.apply(
            PresenceEvent(
                conversationId: "ses_1",
                kind: .running,
                toolName: "bash",
                projectSlug: "agore",
                hookEventName: "tool.execute.before",
                toolUseId: "call_1",
                provider: AgoreConstants.providerOpencode,
                source: .hook
            )
        )
        store.apply(
            PresenceEvent(
                conversationId: "ses_1",
                kind: .idle,
                projectSlug: "agore",
                hookEventName: "session.idle",
                provider: AgoreConstants.providerOpencode,
                source: .hook
            )
        )
        XCTAssertFalse(store.isBusy("ses_1"))
        XCTAssertEqual(store.sessions.first?.kind, .idle)
        XCTAssertEqual(store.localActivity(), .idle)
    }

    func testStaleToolCallStopsCountingAfterCeiling() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.open()
        let started = Date().addingTimeInterval(-(AgoreConstants.toolCallCeiling + 60))
        store.apply(
            PresenceEvent(
                conversationId: "c1",
                kind: .running,
                toolName: "Shell",
                projectSlug: "agore",
                occurredAt: started,
                hookEventName: "preToolUse",
                toolUseId: "call-1",
                source: .hook
            )
        )
        XCTAssertFalse(store.isBusy("c1"))
        XCTAssertTrue(store.activeSessions().isEmpty)
    }

    /// Subagents and parallel chats within one agent still share a person.
    func testOneAgentFoldsItsConversations() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.identity = ClientIdentity(clientId: "me", sessionId: "s")
        store.open()
        store.apply(
            PresenceEvent(
                conversationId: "c1",
                kind: .reading,
                toolName: "Read",
                projectSlug: "alpha",
                source: .hook
            )
        )
        store.apply(
            PresenceEvent(
                conversationId: "c2",
                kind: .writing,
                toolName: "Write",
                projectSlug: "beta",
                source: .hook
            )
        )
        XCTAssertEqual(store.activeSessions().count, 2)
        XCTAssertEqual(store.plazaMembers().count, 1)
        XCTAssertEqual(store.localMembers().map(\.id), ["me:cursor"])
        XCTAssertEqual(store.localActivity(), .writing)
    }

    /// One Mac running two coding agents is two people on the plaza, each busy with its
    /// own work.
    func testEachAgentGetsItsOwnPerson() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.identity = ClientIdentity(clientId: "me", sessionId: "s")
        store.open()
        store.apply(
            PresenceEvent(
                conversationId: "c1",
                kind: .reading,
                toolName: "Read",
                projectSlug: "alpha",
                source: .hook
            )
        )
        store.apply(
            PresenceEvent(
                conversationId: "ses_1",
                kind: .running,
                toolName: "bash",
                projectSlug: "beta",
                hookEventName: "tool.execute.before",
                toolUseId: "call_1",
                provider: AgoreConstants.providerOpencode,
                source: .hook
            )
        )
        let members = store.localMembers().sorted { $0.id < $1.id }
        XCTAssertEqual(members.map(\.id), ["me:cursor", "me:opencode"])
        XCTAssertEqual(members.map(\.kind), [.reading, .running])
        XCTAssertEqual(members.map(\.project), ["alpha", "beta"])
        XCTAssertTrue(members.allSatisfy(\.isLocal))
        // The name says which agent, so two people from one Mac are told apart.
        XCTAssertEqual(members.last?.label.hasSuffix("-oc"), true)
        XCTAssertEqual(members.last?.fullLabel.hasSuffix("-opencode"), true)
        // The strip over the plaza still speaks for the Mac as a whole.
        XCTAssertEqual(store.localActivity(), .running)
    }

    /// An agent Agore is wired into is on the plaza whether or not it has run today.
    func testWiredUpAgentStandsIdleUntilItRuns() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.identity = ClientIdentity(clientId: "me", sessionId: "s")
        store.open()
        var published: [String] = []
        var left: [String] = []
        store.onInstanceChange = { published.append($0.id) }
        store.onInstanceLeave = { left.append($0) }

        store.bridges = [
            BridgeStatus(provider: .cursor, isDetected: true, isInstalled: true),
            BridgeStatus(provider: .opencode, isDetected: true, isInstalled: true),
        ]
        XCTAssertEqual(store.localMembers().map(\.id), ["me:cursor", "me:opencode"])
        XCTAssertTrue(store.localMembers().allSatisfy { $0.kind == .idle })
        XCTAssertEqual(published.sorted(), ["me:cursor", "me:opencode"])
        // The person that stood in before any agent was known has gone home.
        XCTAssertEqual(left, ["me"])

        // Unwiring an agent takes its person off the plaza rather than leaving it asleep
        // there until this client disconnects.
        left.removeAll()
        store.bridges = [BridgeStatus(provider: .cursor, isDetected: true, isInstalled: true)]
        XCTAssertEqual(store.localMembers().map(\.id), ["me:cursor"])
        XCTAssertEqual(left, ["me:opencode"])
    }

    func testLocalMemberStandsOnStageWithoutAnyAgent() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.identity = ClientIdentity(clientId: "me", sessionId: "s")
        store.open()
        XCTAssertTrue(store.isEmpty)
        // Nothing has ever run, and the pixel person is on the plaza all the same.
        XCTAssertEqual(store.plazaMembers().map(\.id), ["me"])
        XCTAssertEqual(store.plazaMembers().first?.kind, .idle)
        // Still there long after any grace period would have expired.
        let later = Date().addingTimeInterval(3600)
        XCTAssertEqual(store.plazaMembers(at: later).map(\.id), ["me"])
    }

    func testQuietPeerStaysUntilItLeaves() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.identity = ClientIdentity(clientId: "me", sessionId: "s")
        store.open()
        store.applyPlaza(.presence(
            PlazaMember(id: "other", displayName: "stoa", kind: .idle, lastSeen: Date().addingTimeInterval(-3600))
        ))
        XCTAssertEqual(store.plazaMembers().map(\.id).sorted(), ["me", "other"])
        store.applyPlaza(.leave("other"))
        XCTAssertEqual(store.plazaMembers().map(\.id), ["me"])
    }

    func testDroppedPlazaLinkClearsPeers() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.identity = ClientIdentity(clientId: "me", sessionId: "s")
        store.open()
        store.applyPlaza(.link(.online))
        store.applyPlaza(.presence(PlazaMember(id: "other", displayName: "stoa", kind: .reading)))
        XCTAssertEqual(store.plazaMembers().count, 2)
        store.applyPlaza(.link(.offline))
        XCTAssertEqual(store.plazaMembers().map(\.id), ["me"])
    }

    func testRemoteRosterDoesNotDuplicateLocal() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agore-store-\(UUID().uuidString).sqlite")
        let store = PresenceStore(idleTimeout: 60, databaseURL: url)
        store.identity = ClientIdentity(clientId: "me", sessionId: "s")
        store.open()
        store.apply(
            PresenceEvent(
                conversationId: "c1",
                kind: .running,
                toolName: "Shell",
                projectSlug: "agore",
                source: .hook
            )
        )
        store.applyPlaza(.snapshot([
            PlazaMember(id: "me:cursor", displayName: "self", kind: .thinking, isLocal: true),
            PlazaMember(id: "other", displayName: "stoa", kind: .reading),
        ]))
        let ids = store.plazaMembers().map(\.id).sorted()
        XCTAssertEqual(ids, ["me:cursor", "other"])
        XCTAssertEqual(store.plazaMembers().first { $0.id == "me:cursor" }?.kind, .running)
    }
}
