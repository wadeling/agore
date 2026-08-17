import Foundation

struct HookPayload: Decodable {
    var conversation_id: String?
    var hook_event_name: String
    var tool_name: String?
    var project_slug: String?
    var occurred_at: String?
    var subagent_id: String?
    var parent_conversation_id: String?
    var workspace_roots: [String]?
    var tool_use_id: String?

    func asPresenceEvent(receivedAt: Date = Date()) -> PresenceEvent? {
        let eventName = hook_event_name
        let isSubagentEvent = eventName == "subagentStart" || eventName == "subagentStop" || subagent_id != nil
        let id: String
        let parent: String?
        if isSubagentEvent, let sub = subagent_id, !sub.isEmpty {
            id = sub
            parent = parent_conversation_id ?? conversation_id
        } else if let conversation = conversation_id, !conversation.isEmpty {
            id = conversation
            parent = parent_conversation_id
        } else {
            return nil
        }

        let slug = project_slug?.isEmpty == false
            ? project_slug!
            : ActivityMapper.projectSlug(fromWorkspaceRoots: workspace_roots ?? [])
        let occurred = Self.parseDate(occurred_at) ?? receivedAt
        let kind = ActivityMapper.kind(eventName: eventName, toolName: tool_name)

        return PresenceEvent(
            conversationId: id,
            parentId: parent,
            kind: kind,
            toolName: tool_name,
            projectSlug: slug,
            occurredAt: occurred,
            hookEventName: eventName,
            toolUseId: tool_use_id?.isEmpty == false ? tool_use_id : nil,
            source: .hook
        )
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }
}
