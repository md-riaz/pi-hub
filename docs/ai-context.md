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

### `0.0.0.0:17878` HTTP server

Reason: phone needs to reach host over LAN/VPN/public route. HTTP is simpler for local/trusted networks. Android cleartext is enabled for this.

### Token auth only

Reason: enough for trusted LAN/VPN use. Not enough for public internet; hardening is future work.

### `/hub stop` vs `/hub server stop`

Reason: user wanted session-level disconnect without killing hub for other agents. Therefore:

- `/hub stop` => unregister current session only
- `/hub server stop` => kill shared server

### No `/hub token`

Reason: `/hub info` already shows token; separate token command created confusion.

### Stale session pruning

Reason: app should show only connected/current agents. Server removes stale sessions and related commands/inbox state.

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
3. `apps/pi_hub_app/lib/src/widgets/agent_card.dart`.

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

## Feature Backlog Notes

### Attachments from app (requested but paused)

Pi supports `sendUserMessage` with text and image content arrays. Future implementation should add:

- Flutter file/image picker.
- `/api/send` `attachments` payload.
- Server validation and command queuing.
- Extension conversion to Pi `TextContent | ImageContent` array.

Do not implement arbitrary binary injection directly into LLM context. Start with images and text/code files.

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
