import Foundation

public enum ActivityMapper {
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
        default:
            return kind(toolName: toolName) ?? .thinking
        }
    }

    public static func kind(toolName: String?) -> ActivityKind? {
        guard let raw = toolName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let name = raw.split(separator: ":").first.map(String.init) ?? raw
        switch name {
        case "Read", "Grep", "Glob", "WebSearch", "WebFetch", "SemanticSearch":
            return .reading
        case "Write", "StrReplace", "EditNotebook", "ApplyPatch", "Delete":
            return .writing
        case "Shell", "Task", "AwaitShell", "CallMcpTool", "GenerateImage":
            return .running
        default:
            if name.hasPrefix("MCP") || name.hasPrefix("browser_") {
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
