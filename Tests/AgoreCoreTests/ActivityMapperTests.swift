import XCTest
@testable import AgoreCore

final class ActivityMapperTests: XCTestCase {
    func testToolMapping() {
        XCTAssertEqual(ActivityMapper.kind(toolName: "Read"), .reading)
        XCTAssertEqual(ActivityMapper.kind(toolName: "Grep"), .reading)
        XCTAssertEqual(ActivityMapper.kind(toolName: "Write"), .writing)
        XCTAssertEqual(ActivityMapper.kind(toolName: "StrReplace"), .writing)
        XCTAssertEqual(ActivityMapper.kind(toolName: "Shell"), .running)
        XCTAssertEqual(ActivityMapper.kind(toolName: "Task"), .running)
        XCTAssertEqual(ActivityMapper.kind(eventName: "afterAgentThought", toolName: nil), .thinking)
        XCTAssertEqual(ActivityMapper.kind(eventName: "stop", toolName: nil), .waiting)
        XCTAssertEqual(ActivityMapper.kind(eventName: "sessionEnd", toolName: nil), .idle)
        XCTAssertEqual(ActivityMapper.kind(eventName: "afterFileEdit", toolName: nil), .writing)
        XCTAssertEqual(ActivityMapper.kind(eventName: "preToolUse", toolName: "Read"), .reading)
        XCTAssertEqual(ActivityMapper.kind(eventName: "beforeShellExecution", toolName: nil), .running)
        XCTAssertEqual(ActivityMapper.kind(eventName: "afterShellExecution", toolName: nil), .thinking)
        XCTAssertEqual(ActivityMapper.kind(eventName: "postToolUse", toolName: "Shell"), .thinking)
        XCTAssertEqual(ActivityMapper.kind(eventName: "postToolUseFailure", toolName: "Shell"), .thinking)
        XCTAssertEqual(ActivityMapper.kind(eventName: "beforeMCPExecution", toolName: nil), .running)
    }

    func testProjectSlug() {
        XCTAssertEqual(ActivityMapper.projectSlug(fromWorkspaceRoots: ["/Users/me/src/agore"]), "agore")
        XCTAssertEqual(ActivityMapper.displayName(projectSlug: "agore", isSubagent: true), "agore · sub")
    }
}
