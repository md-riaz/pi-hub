# Pi Hub

**Version: 2.0.1+1**

Pi Hub is a local-first mission-control dashboard for Pi Coding Agent sessions. It combines a Pi extension, a small HTTP/SSE hub server, and a Flutter Android app so you can monitor and control multiple running agents from a phone over any network that can reach the hub host.

> Status: early but usable. The hub is designed for private networks and should not be exposed directly to the public internet.

## What you get

- Live overview of connected Pi sessions, health, model, context usage, active tools, and recent transcript entries.
- Mobile prompt sending and controls for abort, compact, model switch, and shutdown.
- Command lifecycle visibility beyond simple queued snackbars.
- Chat-style session detail with user bubbles, assistant bubbles (streaming cursor), tool groups, terminal cards, edit cards, waiting cards.
- Real file attachments: pick files, pick images, paste from clipboard.
- Server browse endpoint for remote directory listing.
- Model sheet with scrollable list.
- Optional provider-neutral push registration with an `ntfy` implementation, disabled by default.
- Optional guarded agent creation endpoint for allowlisted workspace roots, disabled by default.
- Memory-only hub state by default: no transcript database and no cloud dependency.

## Architecture

```text
Pi sessions
  └─ pi-hub.ts extension
      ├─ starts/registers with the local hub
      ├─ streams presence, transcript, tool, and command-result events
      └─ polls for queued mobile commands

Hub host
  └─ pi-hub-server.mjs
      ├─ token-protected HTTP JSON API
      ├─ SSE live stream for the mobile app
      ├─ in-memory sessions, commands, push devices, and audit ring
      └─ optional guarded process creation for trusted workspaces

Android device
  └─ apps/pi_hub_app
      ├─ Connection screen → Session list → Session detail (chat-style)
      ├─ Composer with attachment/slash/model buttons
      └─ Bottom sheets: model, slash, attachment, session menu, new session, broadcast, diff drawer
```

## Requirements

- Pi Coding Agent `>=0.60.0`.
- Node.js `18+` on the machine running Pi sessions.
- Flutter/Dart if you want to run or build the Android app from source.
- Android emulator, USB-connected Android device, or phone on any network that can reach the hub host (same WiFi, VPN, etc.).

## Installation

### 1. Install the Pi extension

Install directly from GitHub:

```bash
pi install https://github.com/md-riaz/pi-hub
```

Equivalent Git source form:

```bash
pi install git:github.com/md-riaz/pi-hub
```

For development, install from a local checkout instead:

```bash
git clone https://github.com/md-riaz/pi-hub.git
cd pi-hub
pi install .
```

Restart the Pi sessions you want to manage. Each restarted session loads `pi-hub.ts`, starts the hub server if needed, and registers with it.

### 2. Check the hub from Pi

Inside any Pi session:

```text
/hub info
```

Useful commands:

```text
/hub              # show hub status
/hub start        # start or reconnect to the hub server
/hub info         # show LAN IPs, token, and status
/hub stop         # disconnect this session from hub
/hub server stop  # kill the hub server (all sessions)
```

## Mobile app

### Run in development

```bash
cd apps/pi_hub_app
flutter pub get
flutter run
```

### Build an APK

```bash
cd apps/pi_hub_app
flutter build apk --release
```

APK output:

```text
apps/pi_hub_app/build/app/outputs/flutter-apk/app-release.apk
```

For quick local testing you can also build a debug APK:

```bash
flutter build apk --debug
```

## Connecting from Android

The app needs the hub URL and token.

Token file on the hub host:

```text
~/.pi/agent/pi-hub/config.json
```

Common URLs (the app adds `http://` automatically if you enter only `host:port`):

- Android emulator: `http://10.0.2.2:17878`
- Phone on same WiFi/LAN: `http://<hub-host-lan-ip>:17878`
- Phone over VPN or other network: use any IP that reaches the hub host

Run `/hub info` to see detected LAN IPs. The server binds `0.0.0.0` by default so any network interface works. Allow inbound TCP `17878` through the hub host firewall if needed.

## Daily usage

1. Start or restart your Pi sessions.
2. Open the Android app.
3. Enter the hub URL and token, then tap **Connect**.
4. Select a session.
5. Review chat history, tools, and health in a terminal-style view.
6. Use composer to send messages, attach files, or run slash commands.

Commands are queued on the hub and picked up by Pi sessions during polling. The default polling interval is `1500ms`.

## Configuration

Pi Hub creates this config file automatically:

```text
~/.pi/agent/pi-hub/config.json
```

Example:

```json
{
  "enabled": true,
  "host": "0.0.0.0",
  "port": 17878,
  "token": "generated-token",
  "historyLimit": 500,
  "autoStartServer": true,
  "pollIntervalMs": 1500,
  "push": {
    "enabled": false,
    "provider": "ntfy",
    "defaultScopes": ["critical", "command_failure", "stale", "offline"],
    "ntfy": {
      "serverUrl": "https://ntfy.sh",
      "topic": "",
      "token": "",
      "priority": 4
    }
  },
  "agentCreation": {
    "enabled": false,
    "piCommand": "pi",
    "workspaceRoots": [],
    "defaultArgs": [],
    "testMode": false
  }
}
```

Key fields:

- `enabled`: enables the extension bridge.
- `host`: bind address. Use `0.0.0.0` for phone access on a trusted network.
- `port`: hub server port.
- `token`: bearer token required by the app and API.
- `historyLimit`: maximum in-memory transcript items per session.
- `autoStartServer`: lets the extension start the hub automatically.
- `pollIntervalMs`: how often sessions poll for mobile commands.
- `push.enabled`: enables external push dispatch. In-app SSE notifications work without this.
- `agentCreation.enabled`: enables API/mobile creation of new Pi processes. Keep disabled unless you understand the risk.

Restart Pi sessions and the hub server after changing configuration.

## Optional push notifications

Push is disabled by default. The current low-friction provider is [`ntfy`](https://ntfy.sh/). Configure a private or self-hosted topic before enabling it:

```json
{
  "push": {
    "enabled": true,
    "provider": "ntfy",
    "ntfy": {
      "serverUrl": "https://ntfy.sh",
      "topic": "your-private-topic",
      "token": "",
      "priority": 4
    }
  }
}
```

Provider tokens/topics are not exposed in snapshots; public device records only report `hasToken`.

## Optional agent creation

Agent creation starts a new local process on the hub host. It is disabled by default and restricted to server-side allowlisted workspace roots.

Example configuration:

```json
{
  "agentCreation": {
    "enabled": true,
    "piCommand": "pi",
    "workspaceRoots": ["/home/alice/projects"],
    "defaultArgs": [],
    "testMode": false
  }
}
```

Security model:

- The app cannot choose an arbitrary executable.
- The server launches `agentCreation.piCommand` with `shell: false`.
- Requested working directories are resolved and must be inside `workspaceRoots`.
- Accepted, rejected, succeeded, and failed attempts are recorded in the in-memory audit ring.

Only enable this feature on trusted networks and with a narrow workspace allowlist.

## Manual server run

Normally the extension starts the server. To run it manually:

```bash
npm run hub:server
```

Health check:

```bash
curl "http://127.0.0.1:17878/api/health?token=<token>"
```

## API summary

All API routes except `/` require either `Authorization: Bearer <token>` or `?token=<token>`.

### v1-compatible routes

- `GET /api/health` — server status and local addresses.
- `GET /api/snapshot` — full session snapshot.
- `GET /api/stream` — SSE snapshot/session update stream.
- `POST /api/register` — register a Pi session.
- `POST /api/unregister` — mark a Pi session offline.
- `POST /api/presence` — update session status/model/context.
- `POST /api/event` — push transcript, tool, and other session events.
- `POST /api/send` — queue a user prompt.
- `POST /api/control` — queue `abort`, `compact`, `set_model`, or `shutdown`.
- `GET /api/poll` — Pi session command polling endpoint.

### v2 routes

- `GET /api/v2/push/devices` — list public push device records and provider status.
- `POST /api/v2/push/devices` — register/update/disable a push device.
- `POST /api/v2/agents/create` — guarded agent creation for allowlisted workspace roots.
- `GET /api/v2/browse` — list remote directories.
- `POST /api/v2/send-attachment` — send files as attachments.

See [`docs/pi-hub-v2-protocol.md`](docs/pi-hub-v2-protocol.md) for protocol notes.

## Security notes

Pi Hub is intended for trusted network environments (LAN, VPN, etc.).

Do not expose the hub directly to the public internet without additional hardening. Before public exposure, add HTTPS, stronger authentication, token rotation, rate limiting, and persistent audit controls.

Protect `~/.pi/agent/pi-hub/config.json`; it contains the bearer token and may contain push provider credentials. If agent creation is enabled, bearer-token access can start new local processes inside configured workspace roots.

## Troubleshooting

- **No sessions visible**: restart Pi sessions after installing the extension, then run `/hub start`.
- **Phone cannot connect**: run `/hub info` to see LAN IPs, keep `host: "0.0.0.0"`, and check firewall rules for TCP `17878`.
- **Unauthorized**: copy the current token from `~/.pi/agent/pi-hub/config.json`.
- **Stale server state**: stop the old Node process or remove the stale `~/.pi/agent/pi-hub/server.pid`, then run `/hub start`.
- **Emulator cannot connect**: use `http://10.0.2.2:17878`, not `localhost`.

## Development

```bash
node --check pi-hub-server.mjs
cd apps/pi_hub_app
flutter analyze
flutter test
```

### AI agent onboarding

Future AI agents should read these first:

- [`AGENTS.md`](AGENTS.md) — project map, decisions, workflows, gotchas.
- [`docs/ai-context.md`](docs/ai-context.md) — compact context reference and task entry points.
- [`plan.md`](plan.md), [`progress.md`](progress.md), [`TODO.md`](TODO.md) — direction, status, and checklist.

## License

MIT. See [LICENSE](LICENSE).
