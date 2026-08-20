import Foundation

public enum ActivityMapper {
    /// Cursor's hook names and opencode's event names share one table. They never
    /// collide — Cursor spells its events in camel case, opencode in dotted lower case —
    /// and both describe the same handful of things an agent can be doing.
    public static func kind(eventName: String, toolName: String?) -> ActivityKind {
        let event = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        switch event {
        case "afterAgentThought":
            return .thinking
        case "stop", "sessionStart":
            return .waiting
        case "sessionEnd":
            return .idle
        case "subagentStart":
            return .running
        case "subagentStop":
            return .idle
        case "afterFileEdit":
            return .writing
        case "beforeShellExecution", "beforeMCPExecution":
            return .running
        // A finished tool hands control back to the model, so the agent is chewing on
        // the result rather than still running it.
        case "afterShellExecution", "afterMCPExecution", "postToolUse", "postToolUseFailure":
            return .thinking
        // opencode: a fresh session, a user turn, and a prompt for permission all leave
        // the agent standing about. `session.idle` is the end of its turn, and is the
        // closest thing opencode has to Cursor's sessionEnd.
        case "session.created", "session.error", "message.updated", "permission.asked":
            return .waiting
        case "session.idle":
            return .idle
        case "tool.execute.after":
            return .thinking
        // "tool.execute.before" falls through to the tool it is about to run.
        default:
            return kind(toolName: toolName) ?? .thinking
        }
    }

    /// Matched case-insensitively because the same tools are PascalCase in Cursor and
    /// lower case in opencode, and a couple of them are spelled differently besides.
    public static func kind(toolName: String?) -> ActivityKind? {
        guard let raw = toolName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let name = (raw.split(separator: ":").first.map(String.init) ?? raw).lowercased()
        switch name {
        case "read", "grep", "glob", "list", "websearch", "webfetch", "semanticsearch":
            return .reading
        case "write", "edit", "multiedit", "patch", "strreplace", "editnotebook", "applypatch", "delete":
            return .writing
        case "shell", "bash", "task", "batch", "awaitshell", "callmcptool", "generateimage":
            return .running
        default:
            if name.hasPrefix("mcp") || name.hasPrefix("browser_") {
                return .running
            }
            return .thinking
        }
    }

    public static func projectSlug(fromWorkspaceRoots roots: [String]) -> String {
        guard let first = roots.first, !first.isEmpty else { return "" }
        return slug(fromPath: first)
    }

    public static func slug(fromPath path: String) -> String {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return "" }
        return (trimmed as NSString).lastPathComponent
    }

    public static func displayName(projectSlug: String, isSubagent: Bool) -> String {
        let base = projectSlug.isEmpty ? "agent" : projectSlug
        let clipped = String(base.prefix(18))
        return isSubagent ? "\(clipped) · sub" : clipped
    }
}
