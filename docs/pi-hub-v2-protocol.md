# Pi Hub v2 protocol notes

Pi Hub v2 is additive. Existing v1 routes stay available while new mobile mission-control surfaces adopt versioned events and richer snapshot fields.

## Compatibility

- Auth remains bearer token via `Authorization: Bearer <token>` or `?token=<token>`.
- Existing v1 routes keep their response shape: `/api/register`, `/api/presence`, `/api/event`, `/api/stream`, `/api/snapshot`, `/api/send`, `/api/control`, `/api/poll`.
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
    "version": "1.0.0",
    "schemaVersion": 2,
    "capabilities": {
      "health": true,
      "eventEnvelope": true,
      "inbox": false,
      "commandLifecycle": false,
      "approvals": false,
      "diffReviews": false,
      "agentCreation": false,
      "pushDevices": true,
      "pushNotifications": {
        "enabled": false,
        "configured": false,
        "provider": "ntfy",
        "ntfy": {
          "serverUrl": "https://ntfy.sh",
          "topicConfigured": false,
          "tokenConfigured": false
        }
      }
    }
  },
  "sessions": []
}
```

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
- `blocked`: pending approval/diff review exists for session.
- `error`: recent tool error, command failure, or agent error event.
- `active`: running tool, thinking, or streaming message.
- `idle`: online without attention.
- `unknown`: insufficient data.

## Inbox item

Inbox items are server-owned action or notification records.

```json
{
  "id": "inbox_01HXZ8RJA0EXAMPLE",
  "sessionId": "session-004",
  "type": "tool_error",
  "severity": "error",
  "title": "Tool failed",
  "body": "shell_command failed in workspace app",
  "createdAt": 1770000000000,
  "updatedAt": 1770000000000,
  "readAt": null,
  "actionRef": { "kind": "session", "id": "session-004" }
}
```

Planned types: `completion`, `approval`, `diff_review`, `tool_error`, `command_failure`, `stale`, `collaboration`, `system`.

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

## Approval request

```json
{
  "id": "approval_01HXZ8RJA2EXAMPLE",
  "sessionId": "session-010",
  "title": "Approve command",
  "body": "Agent wants to run a database migration.",
  "risk": "high",
  "choices": ["approve", "reject"],
  "status": "pending",
  "createdAt": 1770000000000,
  "resolvedAt": null,
  "responseComment": null
}
```

Responses will queue an `approval_response` command and update the approval, inbox, audit, and stream records.

## Diff review

```json
{
  "id": "diff_01HXZ8RJA3EXAMPLE",
  "sessionId": "session-011",
  "title": "Review proposed changes",
  "status": "pending",
  "files": [
    {
      "path": "lib/main.dart",
      "status": "modified",
      "additions": 12,
      "deletions": 4,
      "patch": "@@ -1,3 +1,4 @@\n import 'package:flutter/material.dart';"
    }
  ],
  "createdAt": 1770000000000,
  "updatedAt": 1770000000000
}
```

Server must sanitize paths and cap patch text before storing or broadcasting.

## Push device

Provider-neutral device registration does not send notifications unless a provider is configured.

```json
{
  "deviceId": "android-demo-device",
  "platform": "android",
  "provider": "ntfy",
  "token": "provider-token-or-topic-not-returned-in-snapshot",
  "enabled": true,
  "scopes": ["critical", "approval", "diff_review"],
  "updatedAt": 1770000000000
}
```

`POST /api/v2/push/devices` registers or updates by `deviceId`. Send `{ "action": "disable", "deviceId": "android-demo-device" }` to disable. `GET /api/v2/push/devices` returns public records only:

```json
{
  "deviceId": "android-demo-device",
  "platform": "android",
  "provider": "ntfy",
  "enabled": true,
  "scopes": ["critical", "approval", "diff_review"],
  "label": "Pi Hub Android app",
  "createdAt": 1770000000000,
  "updatedAt": 1770000000000,
  "disabledAt": null,
  "hasToken": true
}
```

Snapshots must not expose provider tokens. `server.capabilities.pushNotifications` reports whether a provider is enabled/configured. Current low-friction provider is `ntfy`; dispatch stays disabled unless `push.enabled=true`, `push.provider="ntfy"`, and an ntfy topic (server default or device token/topic) exist in config.

## Agent creation

Agent creation is disabled by default. When enabled, mobile submits a bounded request:

```json
{
  "cwd": "/home/alice/projects/project-a",
  "name": "project-a-reviewer",
  "model": "gpt-5-codex",
  "initialPrompt": "Review TODOs and report blockers."
}
```

Server validates `cwd` under configured workspace roots and spawns the configured Pi command without shell interpolation. Server must reject arbitrary command strings.

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
| `approval.requested` | approval record |
| `diff_review.requested` | diff review record |
| `inbox.updated` | inbox item |
