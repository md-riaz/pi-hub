# Pi Hub v2 protocol notes

Pi Hub v2 is additive. Pi Hub uses canonical `/api/...` routes while mobile mission-control surfaces use versioned events and richer snapshot fields.

## Compatibility

- Auth uses `Authorization: Bearer <token>`. Query-string tokens are disabled by default and only available when `allowQueryToken` is explicitly enabled for manual debugging.
- Canonical routes keep their response shape: `/api/register`, `/api/presence`, `/api/event`, `/api/stream`, `/api/snapshot`, `/api/send`, `/api/control`, `/api/poll`.
- New fields are optional for older clients. Unknown fields should be ignored.
- Server normalizes v1 payloads into internal v2 events before applying state changes.

## Event envelope

```json
{
  "schemaVersion": 2,
  "id": "evt_01HXZ8RJ9X2ZK3Z4R6W6QF2Q0E",
  "seq": 42,
  "type": "session.presence",
  "sessionId": "session-001",
  "actor": { "kind": "agent", "id": "session-001" },
  "timestamp": 1770000000000,
  "severity": "info",
  "attention": false,
  "payload": { "status": "idle" }
}
```

Fields:

| Field | Required | Notes |
| --- | --- | --- |
| `schemaVersion` | yes | `2` for v2 envelopes. Missing or older payloads are treated as v1. |
| `id` | server | Server assigns `evt_<uuid>` when client omits it. |
| `seq` | server | Monotonic server sequence. |
| `type` | yes | Dot names are preferred for v2, e.g. `session.tool_end`. |
| `sessionId` | optional | Required for session-scoped events. |
| `actor` | optional | `agent`, `operator`, or `server`. |
| `timestamp` | server | Milliseconds since epoch. Server fills missing values. |
| `severity` | optional | `debug`, `info`, `warning`, `error`, `critical`. |
| `attention` | optional | Whether event should create/raise operator attention. |
| `payload` | optional | Event-specific body. |

## Snapshot shape

`GET /api/snapshot` keeps the v1 `server` and `sessions` shape. v2 adds optional mission-control fields under existing objects.

```json
{
  "server": {
    "pid": 1234,
    "startedAt": 1770000000000,
    "host": "0.0.0.0",
    "port": 17878,
    "time": "2026-02-03T04:05:06.000Z",
    "version": "2.0.34",
    "schemaVersion": 2,
    "capabilities": {
      "health": true,
      "eventEnvelope": true,
      "commandLifecycle": true,
      "agentCreation": true,
      "browse": true,
      "attachments": true,
      "collaboration": true
    }
  },
  "sessions": []
}
```

Push devices/notifications are not part of the current canonical server surface.

## Health

Each public session may include derived `health`:

```json
{
  "state": "active",
  "lastSeenAgeMs": 1200,
  "attention": false,
  "attentionReasons": [],
  "runningToolCount": 1,
  "pendingCommandCount": 0,
  "contextPercent": 72
}
```

Health states:

- `offline`: explicit unregister or online flag false.
- `stale`: last presence older than server `staleThresholdMs`.
- `error`: recent tool error, command failure, or agent error event.
- `active`: running tool, thinking, or streaming message.
- `idle`: online without attention.
- `unknown`: insufficient data.

## Command

Commands are queued by mobile/operator routes and delivered by `/api/poll`.

```json
{
  "id": "cmd_01HXZ8RJA1EXAMPLE",
  "sessionId": "session-001",
  "type": "user_message",
  "status": "queued",
  "createdAt": 1770000000000,
  "deliveredAt": null,
  "finishedAt": null,
  "error": null,
  "payload": { "text": "Summarize current status" }
}
```

Statuses: `queued`, `delivered`, `applied`, `failed`, `expired`, `cancelled`.

Current v1 command payloads keep `id`, `type`, `text`, `modelId`, and `timestamp` for extension compatibility.

## Agent creation

Agent creation is always advertised as capable. Mobile submits a bounded request:

```json
{
  "cwd": "/home/alice/projects/project-a",
  "name": "project-a-reviewer",
  "model": "gpt-5-codex",
  "initialPrompt": "Review TODOs and report blockers."
}
```

Server resolves `cwd`, requires it to be an existing directory on the hub host, and spawns the configured Pi command without shell interpolation. Server must reject arbitrary command strings.

## Browse remote directories

`GET /api/browse?path=/home/user/projects` returns directory listing for the host machine. Requires `browse` capability.

Request query params: `?path=<absolute-path>` (defaults to the hub host home directory when omitted).

Response:

```json
{
  "ok": true,
  "path": "/home/user/projects",
  "parent": "/home/user",
  "items": [
    { "name": "project-a", "type": "directory", "size": null, "modifiedAt": 1770000000000 },
    { "name": "README.md", "type": "file", "size": 1024, "modifiedAt": 1770000000000 }
  ]
}
```

Server resolves the requested path and rejects invalid or non-directory paths.

## Send attachment

`POST /api/send-attachment` sends files as attachments to a session. Requires `attachments` capability.

Request body:

```json
{
  "sessionId": "session-001",
  "text": "Describe this image",
  "attachments": [
    { "name": "screenshot.png", "mimeType": "image/png", "data": "<base64>" }
  ]
}
```

Limits: max 5 attachments, images up to 5 MB each, text files up to 100k chars. Only inline images and text/code files are supported; arbitrary binaries are rejected.

Server validates size and type, then queues a command with attachments. Extension converts to Pi `TextContent | ImageContent` array via `pi.sendUserMessage`.

## Representative event types

| Type | Payload summary |
| --- | --- |
| `session.registered` | session metadata and optional history |
| `session.presence` | status, model, context usage, available models |
| `session.history` | capped transcript entries |
| `session.tool_start` | tool id/name/args |
| `session.tool_update` | partial tool output |
| `session.tool_end` | result, `isError`, endedAt |
| `command.queued` | command id/type/session id |
| `command.result` | command id/type/applied/error |
