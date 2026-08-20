// agore-plugin v1
// opencode plugin: forward presence to Agore, tell it nothing about the work itself,
// and never get in the agent's way.
import { readFileSync } from "node:fs"
import { basename, join } from "node:path"

const PORT_FILE = join(
  process.env.HOME || "",
  "Library/Application Support/Agore/ingest.port",
)

// Session lifecycle and user turns. Tool calls arrive through the dedicated hooks
// below instead, which are the only place the call id is available, so the generic
// listener must not forward them a second time.
const FORWARDED = new Set([
  "session.created",
  "session.idle",
  "session.error",
  "message.updated",
  "permission.asked",
])

function ingestPort() {
  try {
    const raw = readFileSync(PORT_FILE, "utf8").trim()
    return /^\d+$/.test(raw) ? raw : ""
  } catch {
    return ""
  }
}

// opencode carries the session id in a different place per event: directly on the
// properties for session-scoped events, under `info` for the ones that wrap a record.
function sessionOf(properties) {
  const info = properties?.info
  return properties?.sessionID || info?.sessionID || info?.id || ""
}

export const Agore = async ({ directory, worktree }) => {
  const project = basename((worktree || directory || "").replace(/\/+$/, ""))

  // Deliberately not awaited by the hooks: a presence POST must add no latency to a
  // tool call, and a rejected fetch must never reach the agent.
  function send(fields) {
    const port = ingestPort()
    if (!port || !fields.conversation_id) return
    fetch(`http://127.0.0.1:${port}/events`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        provider: "opencode",
        project_slug: project,
        occurred_at: new Date().toISOString(),
        ...fields,
      }),
      signal: AbortSignal.timeout(400),
    }).then(
      () => {},
      () => {},
    )
  }

  return {
    event: async ({ event }) => {
      if (!FORWARDED.has(event.type)) return
      // Every assistant token updates a message; only the user's own turn means the
      // agent is standing about waiting for something.
      if (event.type === "message.updated" && event.properties?.info?.role !== "user") {
        return
      }
      send({
        conversation_id: sessionOf(event.properties),
        hook_event_name: event.type,
        parent_conversation_id: event.properties?.info?.parentID,
      })
    },

    // Reads `tool` alone. The arguments hold prompts, paths and shell commands, and
    // are frozen on newer opencode besides.
    "tool.execute.before": async (input) => {
      send({
        conversation_id: input.sessionID,
        hook_event_name: "tool.execute.before",
        tool_name: input.tool,
        tool_use_id: input.callID,
      })
    },

    "tool.execute.after": async (input) => {
      send({
        conversation_id: input.sessionID,
        hook_event_name: "tool.execute.after",
        tool_name: input.tool,
        tool_use_id: input.callID,
      })
    },
  }
}
