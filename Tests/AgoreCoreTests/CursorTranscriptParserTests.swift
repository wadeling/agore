import XCTest
@testable import AgoreCore

final class CursorTranscriptParserTests: XCTestCase {
    func testParsesToolUseLine() {
        let line = #"{"role":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"path":"/tmp/a.swift"}}]}}"#
        let turn = CursorTranscriptParser.parseLine(line)
        XCTAssertEqual(turn?.kind, .reading)
        XCTAssertEqual(turn?.toolName, "Read")
    }

    func testParsesUserAsWaiting() {
        let line = #"{"role":"user","message":{"content":[{"type":"text","text":"hello"}]}}"#
        XCTAssertEqual(CursorTranscriptParser.parseLine(line)?.kind, .waiting)
    }

    func testParsesFixtureFile() throws {
        let url = try XCTUnwrap(fixtureURL())
        let snapshot = try XCTUnwrap(CursorTranscriptParser.parseFile(at: url))
        XCTAssertEqual(snapshot.kind, .waiting)
        XCTAssertEqual(snapshot.sessionId, "sample")
    }

    func testSessionIdsForSubagent() {
        let url = URL(fileURLWithPath: "/Users/me/.cursor/projects/agore/agent-transcripts/parent-id/subagents/child-id.jsonl")
        let ids = CursorTranscriptParser.sessionIds(from: url)
        XCTAssertEqual(ids.sessionId, "child-id")
        XCTAssertEqual(ids.parentId, "parent-id")
        XCTAssertEqual(CursorTranscriptParser.projectSlug(from: url), "agore")
    }

    func testScannerFindsRecentJsonl() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("agore-scan-\(UUID().uuidString)")
        let dir = root.appendingPathComponent("proj/agent-transcripts/sess")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("sess.jsonl")
        try #"{"role":"assistant","message":{"content":[{"type":"tool_use","name":"Shell"}]}}"#
            .write(to: file, atomically: true, encoding: .utf8)
        let events = CursorTranscriptScanner(root: root, idleTimeout: 60).scan()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .running)
        XCTAssertEqual(events.first?.source, .transcript)
    }

    private func fixtureURL() -> URL? {
        let candidates = [
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures/sample.jsonl"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
