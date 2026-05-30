# AGENTS.md — AI Agent Onboarding Guide

This repository is intended to be easy for future AI coding agents to scan quickly. Start here before editing.

## Project Purpose

Pi Hub is a local-first mobile mission-control surface for Pi Coding Agent sessions. It has three parts:

1. `pi-hub.ts` — Pi extension loaded into each Pi session.
2. `pi-hub-server.mjs` — local HTTP/SSE hub server shared by sessions.
3. `apps/pi_hub_app` — Flutter Android app for monitoring/control from phone.

Primary user goal: monitor and control many Pi sessions from Android without RDP, with fast LAN/VPN access and minimal setup.

## Current User Preferences / Product Direction

- App must **not require Tailscale**. It should work over any network route that reaches the hub host.
- Direct phone access requires host firewall/provider firewall to allow TCP `17878`; port choice does not remove firewall requirement.
- App should remember URL + token and auto-connect.
- App should show only connected/current sessions. Hub should not retain stale disconnected sessions in memory.
- Agent detail should feel like Pi TUI/terminal, not a cluttered mobile card dashboard.
- Tools/commands/tool outputs should be collapsible so chat history stays readable.
- `/hub stop` disconnects current session only; `/hub server stop` kills hub for all sessions.
- `/hub info` already shows token; no separate `/hub token` command.

## Current Feature State

Implemented:

- Pi extension auto-start/register/presence/event streaming/command polling.
- Hub server memory-only state, token auth, HTTP JSON API, SSE stream.
- Android app with connection persistence + auto-connect.
- Mobile controls: prompt, abort, compact, model switch, shutdown.
- Inbox/approvals/diff review/collaboration/push-device registration/agent creation surfaces.
- Stale session pruning from hub memory.
- Terminal-style agent detail inner screen.
- Release APKs published via GitHub releases.

Not implemented / paused:

- App file/image attachment sending. Investigation found Pi supports `pi.sendUserMessage(content: string | (TextContent | ImageContent)[])`, but app/server/extension attachment pipeline is not implemented yet.
- Public-internet hardening (HTTPS, stronger auth, rate limits, token rotation) is not implemented.
- Cloud/reverse relay is not implemented.

## Key Files

### Root

- `README.md` — user-facing setup/use/troubleshooting.
- `plan.md` — architecture decisions and phased plan.
- `progress.md` — implementation status and validation history.
- `TODO.md` — current task checklist.
- `docs/pi-hub-v2-protocol.md` — API/protocol notes.
- `.sdd/pi-hub-v2-mobile-first-agent-mission-control/` — original design/spec/proposal artifacts.

### Extension

- `pi-hub.ts`
  - Loads config from `~/.pi/agent/pi-hub/config.json`.
  - Auto-starts server unless `autoStartServer=false`.
  - Registers session at `/api/register`.
  - Sends presence/events.
  - Polls `/api/poll` and applies commands.
  - Registers `/hub` command family.

Important command behavior:

- `/hub` / `/hub info` / `/hub status`: show status, app URLs, token, firewall hint.
- `/hub start`: start/reconnect this session.
- `/hub stop`: unregister/disconnect this session only.
- `/hub server stop`: kill hub server process; all sessions disconnect.
- `/hub firewall`: print exact Windows firewall command.

### Server

- `pi-hub-server.mjs`
  - Node HTTP server on `config.host`/`config.port`, default `0.0.0.0:17878`.
  - Bearer token or `?token=` auth.
  - In-memory Maps: `sessions`, `commands`, `commandQueues`, `inboxItems`, approvals, diff reviews, push devices, audit events.
  - `snapshot()` prunes stale sessions before returning data.
  - `/api/unregister` removes session state and broadcasts `session_removed`.

Important functions:

- `snapshot()` — returns full state to app.
- `removeSessionState(sessionId, reason)` — delete session + command queues + commands + inbox items, broadcast removal.
- `pruneStaleSessions()` — remove sessions past `staleThresholdMs`.
- `createCommand()` / `markCommandStatus()` — command lifecycle.
- `routeCollaborationMessage()` — collaboration fan-out.

### Flutter Android app

Main files:

- `apps/pi_hub_app/lib/main.dart`
  - Connection persistence via `shared_preferences`.
  - Auto-connect if URL + token saved.
  - Maintains current snapshot and selected/detail session.

- `apps/pi_hub_app/lib/src/hub_client.dart`
  - HTTP + SSE client.
  - Handles `session_removed` by removing session from local snapshot.
  - Uses 8 second connection timeout.

- `apps/pi_hub_app/lib/src/mission_control_screen.dart`
  - Main shell/tabs.
  - On narrow/mobile layout, agent detail is an inner screen, not a tab.

- `apps/pi_hub_app/lib/src/session_detail_screen.dart`
  - Terminal/TUI-style agent detail.
  - Commands/tools/tool-like transcript entries collapse by default.

- `apps/pi_hub_app/android/app/src/main/AndroidManifest.xml`
  - Must keep `android:usesCleartextTraffic="true"` because hub is HTTP.

## API Summary

All non-root routes require `Authorization: Bearer <token>` or `?token=<token>`.

Core routes:

- `GET /api/health`
- `GET /api/snapshot`
- `GET /api/stream` — SSE stream; emits `snapshot`, `session_updated`, `session_removed`, etc.
- `POST /api/register`
- `POST /api/unregister`
- `POST /api/presence`
- `POST /api/event`
- `POST /api/send`
- `POST /api/control`
- `GET /api/poll`

v2 routes:

- `POST /api/v2/inbox/read`
- `GET|POST /api/v2/push/devices`
- `POST /api/v2/agents/create`
- `POST /api/v2/approvals/:id/respond`
- `POST /api/v2/diff-reviews/:id/respond`
- `POST /api/v2/collaboration/messages`

## Attachment Sending Investigation (Paused)

Pi supports image attachments through `pi.sendUserMessage`:

```ts
pi.sendUserMessage(
  [
    { type: "text", text: "Describe this" },
    { type: "image", mimeType: "image/png", data: "<base64>" }
  ]
)
```

Recommended future design:

- App uses file picker to choose images/text files.
- App sends `/api/send` payload with `attachments` array.
- Server validates count/type/size and queues attachments with command.
- Extension converts command into `TextContent | ImageContent` array and calls `pi.sendUserMessage(content)`.
- V1 should support inline images and text/code files only; reject arbitrary binaries.

Suggested caps:

- max attachments: 5
- image max size: 5 MB each
- text file max: 100k chars
- allowed image MIME: png/jpeg/webp/gif if Pi supports it

## Development Commands

From repo root:

```bash
node --check pi-hub-server.mjs
```

Flutter:

```bash
cd apps/pi_hub_app
flutter analyze
flutter test
flutter build apk --release
```

Release APK output:

```text
apps/pi_hub_app/build/app/outputs/flutter-apk/app-release.apk
```

## Release Flow

1. Commit changes with descriptive message.
2. Push `master`.
3. Build release APK.
4. Create GitHub release with new semver tag and attach APK:

```bash
gh release create vX.Y.Z apps/pi_hub_app/build/app/outputs/flutter-apk/app-release.apk \
  --title "Pi Hub vX.Y.Z" \
  --notes "..."
```

5. Update locally installed extension checkout:

```bash
cd ~/.pi/agent/git/github.com/md-riaz/pi-hub && git pull
```

Current installed extension path on this machine:

```text
~/.pi/agent/git/github.com/md-riaz/pi-hub/
```

## Runtime / Troubleshooting Context

Config path:

```text
~/.pi/agent/pi-hub/config.json
```

Server PID path:

```text
~/.pi/agent/pi-hub/server.pid
```

Default server:

```text
0.0.0.0:17878
```

If app cannot connect without Tailscale:

- Verify app uses URL from `/hub info`.
- Verify Android APK has cleartext enabled.
- Verify host is listening on `0.0.0.0:17878`.
- Windows firewall or VPS provider firewall must allow inbound TCP `17878`.
- Changing port does not bypass firewall requirement.

Admin CMD firewall command:

```cmd
netsh advfirewall firewall add rule name="Pi Hub TCP 17878" dir=in action=allow protocol=TCP localport=17878
```

PowerShell command can get mangled in some terminals; use Admin CMD if needed.

## Coding Notes / Gotchas

- Keep hub server memory-only unless user explicitly approves persistence.
- Do not reintroduce `/hub token`; `/hub info` has token.
- Avoid showing stale/offline sessions in app; server should prune/remove them.
- For mobile UI, prefer TUI-like compact transcript over dashboard cards in detail view.
- Keep `android:usesCleartextTraffic="true"` while hub uses HTTP.
- If adding file uploads, validate size/type on server; do not trust app.
- If adding public exposure, first add HTTPS/auth hardening/rate limit; current token auth is for trusted networks.
