import Foundation

public struct TranscriptSnapshot: Equatable, Sendable {
    public var sessionId: String
    public var parentId: String?
    public var projectSlug: String
    public var kind: ActivityKind
    public var toolName: String?
    public var lastModified: Date

    public func asPresenceEvent() -> PresenceEvent {
        PresenceEvent(
            conversationId: sessionId,
            parentId: parentId,
            kind: kind,
            toolName: toolName,
            projectSlug: projectSlug,
            occurredAt: lastModified,
            hookEventName: nil,
            source: .transcript
        )
    }
}

public enum CursorTranscriptParser {
    public static func parseLine(_ line: String) -> ParsedTurn? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        if let type = json["type"] as? String, type == "turn_ended" {
            return ParsedTurn(role: "system", kind: .waiting, toolName: nil)
        }

        let role = json["role"] as? String ?? ""
        if role == "user" {
            return ParsedTurn(role: role, kind: .waiting, toolName: nil)
        }

        let message = json["message"] as? [String: Any]
        let content = message?["content"] as? [[String: Any]] ?? json["content"] as? [[String: Any]] ?? []
        var lastTool: String?
        var sawText = false
        for block in content {
            let type = block["type"] as? String
            if type == "tool_use" || type == "tool_call" {
                lastTool = block["name"] as? String
            } else if type == "text", let text = block["text"] as? String, !text.isEmpty {
                sawText = true
            }
        }
        if let lastTool {
            let kind = ActivityMapper.kind(toolName: lastTool) ?? .thinking
            return ParsedTurn(role: role.isEmpty ? "assistant" : role, kind: kind, toolName: lastTool)
        }
        if role == "assistant" || sawText {
            return ParsedTurn(role: "assistant", kind: .thinking, toolName: nil)
        }
        return nil
    }

    public static func parseFile(at url: URL, lastBytes: Int = 64 * 1024) -> TranscriptSnapshot? {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let start = size > UInt64(lastBytes) ? size - UInt64(lastBytes) : 0
        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        var last: ParsedTurn?
        for line in lines {
            if let turn = parseLine(line) {
                last = turn
            }
        }
        guard let last else { return nil }
        let ids = sessionIds(from: url)
        let slug = projectSlug(from: url)
        return TranscriptSnapshot(
            sessionId: ids.sessionId,
            parentId: ids.parentId,
            projectSlug: slug,
            kind: last.kind,
            toolName: last.toolName,
            lastModified: modified
        )
    }

    public static func sessionIds(from url: URL) -> (sessionId: String, parentId: String?) {
        let parts = url.pathComponents
        if let subIndex = parts.firstIndex(of: "subagents"), subIndex + 1 < parts.count {
            let file = (parts[subIndex + 1] as NSString).deletingPathExtension
            let parent: String?
            if subIndex >= 2 {
                parent = parts[subIndex - 1]
            } else {
                parent = nil
            }
            return (file, parent)
        }
        let name = url.deletingPathExtension().lastPathComponent
        return (name, nil)
    }

    public static func projectSlug(from url: URL) -> String {
        let parts = url.pathComponents
        if let index = parts.firstIndex(of: "projects"), index + 1 < parts.count {
            return parts[index + 1]
        }
        return ""
    }
}

public struct ParsedTurn: Equatable, Sendable {
    public var role: String
    public var kind: ActivityKind
    public var toolName: String?
}

public struct CursorTranscriptScanner: Sendable {
    public var root: URL
    public var idleTimeout: TimeInterval

    public init(
        root: URL = AgorePaths.cursorProjectsRoot,
        idleTimeout: TimeInterval = AgoreConstants.idleTimeout
    ) {
        self.root = root
        self.idleTimeout = idleTimeout
    }

    public func scan(now: Date = Date()) -> [PresenceEvent] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.path) else { return [] }
        let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var events: [PresenceEvent] = []
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension == "jsonl" else { continue }
            guard item.path.contains("/agent-transcripts/") else { continue }
            let values = try? item.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            let modified = values?.contentModificationDate ?? .distantPast
            guard now.timeIntervalSince(modified) < idleTimeout else { continue }
            if let snapshot = CursorTranscriptParser.parseFile(at: item) {
                events.append(snapshot.asPresenceEvent())
            }
        }
        return events
    }
}
