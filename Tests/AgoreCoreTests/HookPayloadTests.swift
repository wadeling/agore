import XCTest
@testable import AgoreCore

final class HookPayloadTests: XCTestCase {
    func testDecodesSanitizedHook() throws {
        let json = """
        {
          "conversation_id": "abc-123",
          "hook_event_name": "preToolUse",
          "tool_name": "Read",
          "project_slug": "agore",
          "occurred_at": "2026-08-13T08:00:00Z"
        }
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(HookPayload.self, from: json)
        let event = try XCTUnwrap(payload.asPresenceEvent())
        XCTAssertEqual(event.conversationId, "abc-123")
        XCTAssertEqual(event.kind, .reading)
        XCTAssertEqual(event.projectSlug, "agore")
        XCTAssertEqual(event.source, .hook)
        XCTAssertNil(event.parentId)
    }

    func testForwardsToolUseId() throws {
        let json = """
        {
          "conversation_id": "abc-123",
          "hook_event_name": "postToolUse",
          "tool_name": "Shell",
          "tool_use_id": "call-9",
          "project_slug": "agore"
        }
        """.data(using: .utf8)!
        let event = try XCTUnwrap(JSONDecoder().decode(HookPayload.self, from: json).asPresenceEvent())
        XCTAssertEqual(event.toolUseId, "call-9")
        XCTAssertEqual(event.kind, .thinking)
    }

    func testDefaultsToCursorWhenNoProviderIsGiven() throws {
        let json = """
        {
          "conversation_id": "abc-123",
          "hook_event_name": "preToolUse",
          "tool_name": "Read"
        }
        """.data(using: .utf8)!
        let event = try XCTUnwrap(JSONDecoder().decode(HookPayload.self, from: json).asPresenceEvent())
        XCTAssertEqual(event.provider, AgoreConstants.providerCursor)
    }

    func testDecodesOpencodeToolCall() throws {
        let json = """
        {
          "provider": "opencode",
          "conversation_id": "ses_1",
          "hook_event_name": "tool.execute.before",
          "tool_name": "bash",
          "tool_use_id": "call_1",
          "project_slug": "agore"
        }
        """.data(using: .utf8)!
        let event = try XCTUnwrap(JSONDecoder().decode(HookPayload.self, from: json).asPresenceEvent())
        XCTAssertEqual(event.provider, AgoreConstants.providerOpencode)
        XCTAssertEqual(event.conversationId, "ses_1")
        XCTAssertEqual(event.toolUseId, "call_1")
        XCTAssertEqual(event.kind, .running)
    }

    /// opencode reports a subagent as a session with a parent, so it needs none of the
    /// separate subagent id that Cursor sends.
    func testDecodesOpencodeChildSession() throws {
        let json = """
        {
          "provider": "opencode",
          "conversation_id": "ses_child",
          "parent_conversation_id": "ses_parent",
          "hook_event_name": "session.created",
          "project_slug": "agore"
        }
        """.data(using: .utf8)!
        let event = try XCTUnwrap(JSONDecoder().decode(HookPayload.self, from: json).asPresenceEvent())
        XCTAssertEqual(event.conversationId, "ses_child")
        XCTAssertEqual(event.parentId, "ses_parent")
        XCTAssertTrue(event.isSubagent)
        XCTAssertEqual(event.kind, .waiting)
    }

    func testSubagentUsesSubagentId() throws {
        let json = """
        {
          "conversation_id": "parent",
          "hook_event_name": "subagentStart",
          "subagent_id": "child",
          "parent_conversation_id": "parent",
          "project_slug": "agore"
        }
        """.data(using: .utf8)!
        let event = try XCTUnwrap(JSONDecoder().decode(HookPayload.self, from: json).asPresenceEvent())
        XCTAssertEqual(event.conversationId, "child")
        XCTAssertEqual(event.parentId, "parent")
        XCTAssertEqual(event.kind, .running)
    }
}
