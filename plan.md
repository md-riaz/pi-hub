# Pi Hub Plan

## Decisions

- Server topology: run central Pi Hub server on the user's Pi host machine now; keep protocol HTTP/SSE so a cloud/VPS relay can be added later without replacing clients.
- Phone access: Android connects over any network (WiFi, LAN, VPN, etc.) to the hub host on TCP `17878`, protected by bearer token from `~/.pi/agent/pi-hub/config.json`.
- History: memory-only on the hub server. Each live Pi session sends its recent session entries on registration and event updates while running; no server-side transcript database for now.
- First controls: Flutter app can view sessions, send prompts, abort current work, trigger compaction, switch model, shutdown a selected Pi session, and log out of the active hub while preserving saved recent hub URLs/tokens for switching.
- Agent creation: disabled by default; when explicitly enabled, `/api/v2/agents/create` spawns only the configured command without shell interpolation and only inside configured workspace roots.

## Architecture

```text
Pi sessions in many cwd
  └─ pi-hub.ts extension
      ├─ auto-starts pi-hub-server.mjs once in VM
      ├─ registers session metadata and memory-only history
      ├─ streams live message/tool/status/context events to hub
      └─ polls hub command queue for user_message/control commands

Pi Hub server
  ├─ HTTP JSON API for snapshots and commands
  ├─ SSE /api/stream for Flutter live updates
  ├─ token auth, CORS for local/mobile clients
  └─ memory Map of sessions + per-session command queues

Flutter Android app
  ├─ connects over any network with bearer token
  ├─ renders chat-style UI with conversation history
  ├─ supports file attachments, clipboard paste, and server file browse
  └─ queues prompt/control commands to selected session
```

## AI Onboarding

- Future AI agents should start with `AGENTS.md` and `docs/ai-context.md` before editing.
- Attachment sending from app is paused; design notes live in those docs.

## Phases

1. MVP bridge and app
   - Pi extension: register, history snapshot, live events, command polling.
   - Server: `/api/snapshot`, `/api/stream`, `/api/send`, `/api/control`, `/api/poll`.
   - Flutter: chat-style session detail UI with collapsible tool/command groups, prompt send, abort/compact/model/shutdown controls.
   - File attachments (pick files/images from phone), clipboard paste, and server-side file browse are implemented.
   - Inbox, approval, and diff-review systems have been removed.

2. Hardening
   - Add better command acknowledgements and visible command result status.
   - Keep agent creation guarded with explicit config, audit events, and narrow workspace root allowlists.
   - Add optional PIN rotation command.
   - Add network setup help for LAN/firewall.

3. Hybrid/cloud later
   - Keep same JSON/SSE schema.
   - Add optional relay URL config so Pi sessions can connect outbound to cloud server.
   - Upgrade auth before internet exposure.

## Non-goals now

- Public internet exposure without stronger auth/HTTPS.
- Server-side persistent transcript database.
- Replacing Pi session JSONL storage.
