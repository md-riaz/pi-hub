# AI Context Reference

Use this alongside `AGENTS.md` when a new AI agent starts work on Pi Hub.

## One-Screen Summary

Pi Hub = Pi Coding Agent extension + local Node hub server + Flutter Android app.

- Extension (`pi-hub.ts`) bridges a live Pi session to the hub.
- Server (`pi-hub-server.mjs`) stores live state in memory and exposes HTTP/SSE API.
- App (`apps/pi_hub_app`) connects to the server, watches SSE, and sends commands.

The product is for controlling many Pi agents from a phone. It is not a hosted SaaS. It is a trusted-network tool.

## Why Major Decisions Exist

### Memory-only hub state

Reason: user wants live mission control, not a transcript database. Old/stale agents should disappear. Persisting session history would reintroduce stale clutter.

### `127.0.0.1:17878` default HTTP server

Reason: private-by-default is safer. Phone access over LAN/VPN/Tailscale requires opting into `host: "0.0.0.0"` and opening the firewall. HTTP is simpler for local/trusted networks. Android cleartext is enabled for hub connections; use LAN/VPN/Tailscale or an HTTPS reverse proxy for routed access.

### Bearer token auth

Reason: enough for trusted LAN/VPN use. App and extension use `Authorization: Bearer <token>` for every request, including SSE and browse/attachment routes. Query-string tokens are disabled by default (`allowQueryToken: false`) and only exist for manual/debug compatibility.

### `/hub stop` vs `/hub server stop`

Reason: user wanted session-level disconnect without killing hub for other agents. Therefore:

- `/hub stop` => unregister current session only
- `/hub server stop` => kill shared server

### No `/hub token`

Reason: `/hub info` already shows token; separate token command created confusion.

### Stale session pruning

Reason: app should show only connected/current agents. Server removes stale sessions and related command queues.

### Terminal-style detail view

Reason: user wants exact Pi TUI feel, readable chat history, not cards/tool clutter. Detail view uses compact terminal colors, monospace text, collapsed commands/tools/tool outputs.

## What To Read First For Common Tasks

### Change hub command behavior

Read:

1. `pi-hub.ts` command registration near bottom.
2. `networkHint()` / `firewallHint()`.
3. `disconnectSession()`.

### Change server session lifecycle

Read:

1. `pi-hub-server.mjs` `removeSessionState()`.
2. `pruneStaleSessions()`.
3. `/api/register`, `/api/unregister`, `/api/presence` routes.
4. `snapshot()`.

### Change mobile session list/navigation

Read:

1. `apps/pi_hub_app/lib/main.dart` selected/detail session state.
2. `apps/pi_hub_app/lib/src/mission_control_screen.dart` narrow vs wide layout.

### Change detail transcript UI

Read:

1. `apps/pi_hub_app/lib/src/session_detail_screen.dart`.
2. `HubItem` model in `apps/pi_hub_app/lib/src/hub_models.dart`.

### Change API payload models

Read:

1. `apps/pi_hub_app/lib/src/hub_client.dart`.
2. `apps/pi_hub_app/lib/src/hub_models.dart`.
3. Server route in `pi-hub-server.mjs`.
4. Extension command handling in `pi-hub.ts` `pollCommands()`.
5. `apps/pi_hub_app/lib/src/widgets/remote_path_browser.dart` for browse endpoint UI.

## Feature Backlog Notes

### Attachments from app (implemented)

Pi supports `sendUserMessage` with text and image content arrays. Implementation:

- Flutter file/image picker and clipboard paste for selecting attachments.
- `POST /api/send-attachment` with `{sessionId, text, attachments: [{name, mimeType, data}]}`.
- Server validates size/type (max 5 attachments, images up to 5 MB, text files up to 100k chars) and queues command.
- Extension converts to Pi `TextContent | ImageContent` array via `pi.sendUserMessage`.
- Only inline images and text/code files are supported; arbitrary binaries are rejected.

### Chat-style UI redesign

Agent detail uses a terminal-style transcript view: compact terminal colors, monospace text, collapsed tools/commands/outputs. Tools, commands, and tool-like transcript entries collapse by default so chat history stays readable. The session list is now an inner screen on narrow/mobile layouts rather than a tab.

### Better no-admin connectivity

Direct phone -> Windows/VPS server needs inbound firewall rule. If user lacks admin/provider control, options are:

- VPN/Tailscale (not required by app, but possible route)
- reverse tunnel/relay (future feature)
- hosting hub on machine with firewall access

Changing port will not avoid firewall requirement.

## Validation Checklist Before Commit

For server/extension only:

```bash
node --check pi-hub-server.mjs
```

For app changes:

```bash
cd apps/pi_hub_app
flutter analyze
flutter test
flutter build apk --release
```

For release:

```bash
git push
gh release create vX.Y.Z apps/pi_hub_app/build/app/outputs/flutter-apk/app-release.apk --title "Pi Hub vX.Y.Z" --notes "..."
```

## Current Known Operational Notes

- After updating server code, running Node server must be restarted: `/hub server stop`, then `/hub start`.
- Installed extension checkout on this machine is `~/.pi/agent/git/github.com/md-riaz/pi-hub/`.
- Runtime config and token are in `~/.pi/agent/pi-hub/config.json`.
- Release APK is attached to GitHub releases, not committed to repo.
