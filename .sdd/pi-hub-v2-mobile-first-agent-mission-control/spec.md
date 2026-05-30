# Spec — Pi Hub v2 Mobile-First Agent Mission Control

Feature slug: `pi-hub-v2-mobile-first-agent-mission-control`

## Requirements source

`.sdd/specs/requirements.md` was not present. Canonical store is empty for this plan. Requirements below derive from the feature request and observed current code.

## Terms

- **Hub server**: Node HTTP/SSE process in `pi-hub-server.mjs` running on Windows VPS/VM.
- **Agent session**: One Pi Coding Agent session loading `pi-hub.ts`.
- **Mobile client**: Flutter Android app under `apps/pi_hub_app`.
- **Mission control**: Mobile-first surfaces for health, attention inbox, controls, approvals, diff review, creation, and collaboration.
- **Inbox item**: Server-side item representing something the operator may need to notice or act on.
- **Approval request**: Agent-originated request requiring approve/reject/comment response.
- **Diff review**: Structured file change summary/diff requiring review or operator feedback.
- **Command lifecycle**: Queued, delivered, applied, failed, expired, or cancelled state for mobile-issued commands.

## Existing behavior to preserve

- Existing bearer token auth via `Authorization: Bearer <token>` or `?token=<token>`.
- Existing v1 routes: `/api/health`, `/api/snapshot`, `/api/stream`, `/api/register`, `/api/unregister`, `/api/presence`, `/api/event`, `/api/send`, `/api/control`, `/api/poll`.
- Existing controls: prompt send, `abort`, `compact`, `set_model`, `shutdown`.
- Current LAN/Tailscale usage and Android emulator URL behavior.
- Memory-first server state unless a later task adds optional persistence.

## Functional requirements

### R1 — Session registry and scalability

- Server MUST support 5–20 active sessions without UI degradation for normal transcript sizes.
- Server MUST retain session metadata: id, name, cwd, model, pid, startedAt, lastSeen, status, online, context usage, available models, tools, history/live message.
- Server SHOULD cap large strings and arrays before broadcasting to mobile clients.

### R2 — Derived health

Each public session SHOULD include derived health:

```json
{
  "state": "active|idle|stale|offline|blocked|error|unknown",
  "lastSeenAgeMs": 1200,
  "attention": true,
  "attentionReasons": ["approval_pending", "tool_error"],
  "runningToolCount": 1,
  "pendingCommandCount": 0,
  "contextPercent": 72
}
```

- `offline` MUST be set on unregister or prolonged heartbeat absence.
- `stale` SHOULD be set when `lastSeen` exceeds a configurable threshold.
- `blocked` SHOULD be set when approval or diff review is pending.
- `error` SHOULD be set after tool error, command failure, or agent error event.

### R3 — Versioned event model

New events SHOULD use a v2 envelope:

```json
{
  "schemaVersion": 2,
  "id": "evt_...",
  "seq": 42,
  "type": "session.health_updated",
  "sessionId": "session-id",
  "actor": { "kind": "agent|operator|server", "id": "..." },
  "timestamp": 1770000000000,
  "severity": "debug|info|warning|error|critical",
  "attention": false,
  "payload": {}
}
```

- Server MUST continue accepting existing unversioned event payloads.
- Server SHOULD normalize v1 events into internal v2-like records before updating state.
- SSE stream SHOULD emit v2 events on `/api/v2/stream` while preserving `/api/stream` compatibility.

### R4 — Mobile-first mission control UI

- Mobile app MUST work well on portrait phone widths.
- App MUST provide a health/attention overview before transcript detail.
- App SHOULD keep tablet/two-pane behavior for wider screens.
- App SHOULD sort agents by attention state, health severity, and recency by default.
- App MUST keep prompt send and controls reachable for selected session.

### R5 — Agent inbox

Server SHOULD maintain inbox items:

```json
{
  "id": "inbox_...",
  "sessionId": "session-id",
  "type": "completion|approval|diff_review|tool_error|command_failure|stale|collaboration|system",
  "severity": "info|warning|error|critical",
  "title": "Approval needed",
  "body": "Agent requests permission to edit files",
  "createdAt": 1770000000000,
  "updatedAt": 1770000000000,
  "readAt": null,
  "actionRef": { "kind": "approval", "id": "approval_..." }
}
```

- Inbox MUST support unread/read state.
- Inbox SHOULD dedupe noisy repeated health/tool events.
- Inbox SHOULD cap retained items by count and/or age.

### R6 — Command lifecycle

Mobile-issued commands SHOULD be tracked:

```json
{
  "id": "cmd_...",
  "sessionId": "session-id",
  "type": "user_message|abort|compact|set_model|shutdown|approval_response|collaboration_message",
  "status": "queued|delivered|applied|failed|expired|cancelled",
  "createdAt": 1770000000000,
  "deliveredAt": null,
  "finishedAt": null,
  "error": null
}
```

- Server MUST assign command IDs.
- Polling an agent SHOULD mark matching commands `delivered`.
- Agent acknowledgement SHOULD mark commands `applied` or `failed`.
- Mobile UI SHOULD show pending/failed commands, not only snackbar feedback.

### R7 — In-app notifications and push roadmap

- Connected app SHOULD show in-app banners for high-severity inbox items.
- True push notifications MUST be optional and disabled until provider config exists.
- Push provider integration MUST NOT require exposing hub server publicly.
- Device registration SHOULD support provider-neutral records: platform, token, scopes, enabled flag.

### R8 — Approval requests

Approval request model:

```json
{
  "id": "approval_...",
  "sessionId": "session-id",
  "title": "Approve command",
  "body": "Agent wants to run ...",
  "risk": "low|medium|high",
  "choices": ["approve", "reject"],
  "status": "pending|approved|rejected|expired|cancelled",
  "createdAt": 1770000000000,
  "resolvedAt": null,
  "responseComment": null
}
```

- Server SHOULD expose pending approvals in snapshot and stream.
- Mobile UI MUST allow approve/reject with optional comment.
- Responses SHOULD be delivered to agent as commands.
- If Pi extension cannot apply approval API directly, response MUST still be recorded and visible.

### R9 — Diff review

Diff review model:

```json
{
  "id": "diff_...",
  "sessionId": "session-id",
  "title": "Review proposed changes",
  "status": "pending|approved|changes_requested|closed",
  "files": [
    { "path": "lib/main.dart", "status": "modified", "additions": 12, "deletions": 4, "patch": "@@ ..." }
  ],
  "createdAt": 1770000000000,
  "updatedAt": 1770000000000
}
```

- Server SHOULD cap diff size per file and total review payload.
- Mobile UI SHOULD show file list and readable hunks.
- Review actions SHOULD create command/inbox/audit events.

### R10 — Agent creation

- Agent creation MUST be disabled by default.
- When enabled, server MUST restrict creation to configured workspace roots.
- Mobile create flow SHOULD collect cwd/workspace, optional name, model, and initial prompt.
- Server MUST audit each creation attempt and result.
- Server MUST NOT accept arbitrary shell commands from mobile.

### R11 — Agent collaboration

- Operator SHOULD send a message to one session, selected sessions, or all sessions.
- Collaboration messages SHOULD appear in inbox/history and be delivered as commands or user messages.
- Server SHOULD include origin actor and target session IDs.

### R12 — Security

- Current deployment remains trusted LAN/Tailscale only.
- Public internet exposure is out of compliance until HTTPS, stronger auth, rate limiting, and token rotation exist.
- Destructive actions (`shutdown`, future agent creation, high-risk approvals) SHOULD require explicit mobile confirmation.
- Token values MUST not be logged or exposed in snapshots.
- Config secrets SHOULD remain in `~/.pi/agent/pi-hub/config.json` and ignored by git.

### R13 — Observability and diagnostics

- `/api/health` or v2 health SHOULD report server pid, uptime, version, addresses, session counts, and watcher count without secrets.
- Server SHOULD record recent audit events in memory, capped by count.
- README/docs SHOULD list validation commands.

## Planned API additions

V1 routes remain. V2 routes are additive:

- `GET /api/v2/snapshot` — full mission-control state.
- `GET /api/v2/stream` — SSE v2 event stream.
- `POST /api/v2/commands` — generic command creation.
- `POST /api/v2/inbox/read` — mark inbox items read/unread.
- `POST /api/v2/approvals/:id/respond` — approve/reject/comment.
- `POST /api/v2/diff-reviews/:id/respond` — approve/request changes/comment.
- `POST /api/v2/agents/create` — guarded agent creation when enabled.
- `POST /api/v2/push/devices` — register/update mobile device token when push configured.
- `POST /api/v2/collaboration/messages` — route operator/agent collaboration messages.

## Acceptance criteria

- Existing tests still pass: `node --check pi-hub-server.mjs`, `flutter analyze`, `flutter test`.
- Existing app can still connect to current v1 endpoints during v2 rollout.
- New mobile home shows health/attention for at least 20 fixture sessions.
- Command lifecycle statuses visible in UI using fixture and smoke server tests.
- Inbox items render, can be marked read, and update via stream.
- Approval and diff fixtures can be responded to from mobile UI.
- Agent creation endpoint rejects requests when disabled and rejects cwd outside allowlist when enabled.
- Security docs warn against public exposure and document hardening requirements.
