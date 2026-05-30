# Design — Pi Hub v2 Mobile-First Agent Mission Control

Feature slug: `pi-hub-v2-mobile-first-agent-mission-control`

## Code roots

Repository-relative implementation roots:

- `pi-hub.ts`
- `pi-hub-server.mjs`
- `apps/pi_hub_app/lib/main.dart`
- `apps/pi_hub_app/lib/src/**`
- `apps/pi_hub_app/test/widget_test.dart`
- `apps/pi_hub_app/pubspec.yaml`
- `apps/pi_hub_app/android/app/src/main/AndroidManifest.xml`
- `apps/pi_hub_app/android/app/src/debug/AndroidManifest.xml`
- `README.md`
- `plan.md`
- `progress.md`
- `TODO.md`

## Current architecture summary

```text
Pi sessions
  └─ pi-hub.ts
      ├─ loads config from ~/.pi/agent/pi-hub/config.json
      ├─ auto-starts pi-hub-server.mjs
      ├─ registers session metadata/history
      ├─ posts presence and event payloads
      └─ polls /api/poll for commands

Hub server
  └─ pi-hub-server.mjs
      ├─ memory-only sessions Map
      ├─ memory-only commandQueues Map
      ├─ /api/snapshot JSON
      ├─ /api/stream SSE
      ├─ token auth
      └─ command endpoints /api/send and /api/control

Flutter Android app
  └─ apps/pi_hub_app/lib/main.dart
      ├─ Material app and connection form
      ├─ two-pane session list/detail layout
      ├─ HubClient HTTP/SSE client
      ├─ model parsing classes
      └─ prompt/control UI
```

Strengths: small, low-dependency, already usable over LAN/Tailscale. Weaknesses: monolithic Flutter file, desktop-oriented UI, no command lifecycle status, no inbox, no approval/diff/creation/collaboration primitives, no push, minimal security hardening.

## Target architecture

```text
Pi session extension (pi-hub.ts)
  ├─ v1-compatible registration/presence/events
  ├─ v2 event envelope for new events
  ├─ command acknowledgement/result events
  ├─ approval/diff/collaboration command handling where Pi APIs allow
  └─ guarded feature detection for APIs not present in current Pi version

Hub server (pi-hub-server.mjs)
  ├─ v1 API preserved
  ├─ v2 state model: sessions, health, inbox, commands, approvals, diffs, devices, audit
  ├─ v2 JSON snapshot and SSE event stream
  ├─ derived health/attention engine
  ├─ capped memory stores with optional later JSON persistence
  ├─ guarded agent creation service
  └─ security middleware: auth, rate limits, audit, confirmation metadata

Flutter app (apps/pi_hub_app/lib)
  ├─ models and API client split from UI
  ├─ responsive mobile-first mission-control shell
  ├─ health overview and attention-sorted agent cards
  ├─ inbox screen and in-app notifications
  ├─ session detail transcript/tools/controls
  ├─ approval and diff review flows
  ├─ agent creation form when server allows it
  └─ collaboration composer/thread UI
```

## Server design

### State containers

Current `sessions`, `commandQueues`, and `watchers` stay, with additive structures:

```text
sessions: Map<sessionId, SessionState>
commands: Map<commandId, CommandStatus>
commandQueues: Map<sessionId, Command[]>
inboxItems: Map<inboxId, InboxItem>
approvals: Map<approvalId, ApprovalRequest>
diffReviews: Map<diffId, DiffReview>
devices: Map<deviceId, PushDevice>
auditEvents: RingBuffer<AuditEvent>
watchers: Set<SseResponse>
```

All stores should be capped by count/age to avoid unbounded memory for 5–20 agents.

### Event normalization

Add a small normalizer in `pi-hub-server.mjs`:

1. Accept existing v1 payloads from `/api/event`, `/api/presence`, `/api/register`.
2. Convert into internal v2-ish events with server-assigned id/seq/timestamp when missing.
3. Update state through one path: `applyEvent(event)`.
4. Broadcast v1-compatible updates on `/api/stream` and v2 events on `/api/v2/stream`.

This avoids a flag-day migration.

### Health engine

Health is derived server-side after any presence/event/command update:

- `offline`: explicit unregister or heartbeat timeout.
- `stale`: `Date.now() - lastSeen > staleThresholdMs`.
- `blocked`: pending approval or diff review for session.
- `error`: recent tool error, command failure, agent error event.
- `active`: running tool or thinking status.
- `idle`: online and no attention.

`publicSession()` should include `health` but retain existing top-level fields.

### Command lifecycle

Current queue entries get IDs already. Extend state:

- Create command status on `/api/send`, `/api/control`, and new `/api/v2/commands`.
- Mark `delivered` when `/api/poll` returns it to an agent.
- Mark `applied`/`failed` from `command_received` or new `command_result` events.
- Expire old queued/delivered commands after configurable timeout.
- Create inbox item for failures or long pending commands.

### Inbox

Inbox items are generated from:

- health transitions needing attention,
- tool errors,
- command failures,
- approvals,
- diff reviews,
- collaboration mentions/messages,
- agent completion events if configured.

Deduping should use `(sessionId, type, actionRef.kind, actionRef.id)` when available, or a time-bucket key for repeated stale/tool errors.

### Approval and diff review

Approval and diff records are action records. Each creates an inbox item. Mobile response creates:

1. audit event,
2. command queued to target session,
3. state update (`approved`, `rejected`, `changes_requested`, etc.),
4. SSE event.

If the extension cannot apply response directly, the server still records the response and shows it to the operator.

### Agent creation

Agent creation service is disabled by default in config:

```json
{
  "agentCreation": {
    "enabled": false,
    "piCommand": "pi",
    "workspaceRoots": ["/home/alice/projects"],
    "defaultArgs": []
  }
}
```

Flow:

1. Mobile requests create with cwd/name/model/initialPrompt.
2. Server verifies feature enabled.
3. Server normalizes cwd and checks it is under allowlisted workspace root.
4. Server spawns configured Pi command without shell interpolation.
5. Server records audit and emits creation status.
6. New session registers through existing extension path.

No arbitrary command string should be accepted from app.

### Security middleware

Add small helpers, not a framework:

- shared auth check for v1/v2 routes,
- optional method/path rate limit by token/IP,
- audit ring buffer for command/approval/create/security events,
- destructive action confirmation metadata,
- token rotation endpoint/command later.

Keep warning: trusted LAN/Tailscale only until HTTPS/stronger auth exists.

## Extension design

`pi-hub.ts` remains the agent bridge.

Additions:

- Include client/protocol version in register/presence.
- Send command result events with command id, type, applied boolean, and error message when available.
- Poll and handle new command types:
  - `approval_response`,
  - `diff_review_response`,
  - `collaboration_message`.
- Emit v2 envelopes for new action events, but keep existing event types for current server compatibility.
- Feature-detect Pi APIs for approvals/diffs; degrade to visible notification/event if unavailable.
- Continue respecting `enabled`, `autoStartServer`, and `pollIntervalMs` config.

## Flutter app design

### File organization

Current `main.dart` is monolithic. Split before feature work:

```text
apps/pi_hub_app/lib/main.dart
apps/pi_hub_app/lib/src/hub_client.dart
apps/pi_hub_app/lib/src/hub_models.dart
apps/pi_hub_app/lib/src/mission_control_screen.dart
apps/pi_hub_app/lib/src/session_detail_screen.dart
apps/pi_hub_app/lib/src/inbox_screen.dart
apps/pi_hub_app/lib/src/approval_sheet.dart
apps/pi_hub_app/lib/src/diff_review_screen.dart
apps/pi_hub_app/lib/src/agent_create_sheet.dart
apps/pi_hub_app/lib/src/widgets/...
```

Avoid adding heavy state-management dependencies initially; `StatefulWidget`, `ValueNotifier`, or a small app state class is enough.

### Mobile-first layout

Use `LayoutBuilder`:

- Narrow width: single-column app with bottom navigation or tab controller.
  - Mission: agent cards sorted by attention.
  - Inbox: unread/action items.
  - Detail: selected agent transcript/tools/controls.
  - More/Create: settings, create agent when enabled.
- Wide width: preserve two-pane session list/detail with optional inbox side panel.

### User flows

#### Connect

Same as current: server URL + token. Later task may persist encrypted/local preferences, but not required for v2 foundation.

#### Triage

Open app -> see agent cards -> tap attention item -> jump to approval/diff/session detail -> act -> item resolves or stays pending.

#### Command

Send prompt/control -> command row appears `queued` -> updates to `delivered` -> `applied` or `failed` via stream.

#### Approval

Inbox item -> approval bottom sheet -> approve/reject/comment -> command queued -> request status updates.

#### Diff review

Inbox item -> diff review screen -> select files/hunks -> approve/request changes/comment -> command queued.

#### Agent creation

Create -> choose workspace/name/model/prompt -> confirm risk -> server validates -> status shown until new session registers.

## Push notification design

True push is optional because local LAN/Tailscale server cannot wake Android app without an external service.

Provider-neutral first step:

```json
{
  "deviceId": "android-uuid",
  "platform": "android",
  "provider": "fcm|ntfy|webhook",
  "token": "provider-token-or-topic",
  "enabled": true,
  "scopes": ["critical", "approval", "diff_review"]
}
```

Server dispatches only when provider config is present. Without provider, connected app still shows in-app notifications from SSE.

## Compatibility and migration

- Keep v1 endpoints and existing app behavior until v2 UI/client is ready.
- Add `/api/v2/*` routes rather than changing v1 response shapes in breaking ways.
- If adding `health` to existing session JSON, existing Flutter parser ignores unknown fields.
- Extension can send both old event types and new metadata without breaking server.
- Roll out in order: model/client split -> server health/commands -> UI -> inbox -> approvals/diffs -> creation/push/security.

## Validation strategy

- Server syntax: `node --check pi-hub-server.mjs`.
- Server smoke: use curl or small Node script for health/register/snapshot/stream/send/poll.
- Flutter static checks: `cd apps/pi_hub_app && flutter analyze`.
- Flutter tests: `cd apps/pi_hub_app && flutter test`.
- Fixture tests: add JSON fixtures for 20 sessions, inbox, approval, diff, command lifecycle.
- Manual acceptance: Android emulator with `http://10.0.2.2:17878`; physical/Tailscale phone with VPS IP.

## Documentation updates

Implementation tasks that change API, security, or behavior should update:

- `README.md` for user setup/usage/API/security notes.
- `apps/pi_hub_app/README.md` for mobile run/build/use.
- `plan.md`, `progress.md`, and `TODO.md` when project direction or API decisions become active.
