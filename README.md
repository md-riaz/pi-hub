# Pi Hub Dashboard

Pi Hub is a Pi Coding Agent extension plus Flutter Android app for watching and controlling multiple Pi sessions from a phone over LAN or Tailscale.

It gives you one local hub server, live session snapshots, conversation history, active tool status, and remote controls for prompts, abort, compaction, model switching, and shutdown.

## Features

- Auto-starting Pi extension (`pi-hub.ts`) loaded by every Pi session.
- Memory-only local hub server (`pi-hub-server.mjs`) with token auth.
- Flutter Android dashboard (`apps/pi_hub_app`) for phone or emulator.
- Live HTTP/SSE updates for session status, transcript, tools, model, context usage, and presence.
- Command queue for sending prompts or controls back to selected Pi session.
- LAN/Tailscale-first design; protocol stays ready for a future relay.

## Repo layout

```text
pi-hub.ts             Pi extension loaded by Pi Coding Agent
pi-hub-server.mjs     Central memory-only HTTP/SSE hub server
apps/pi_hub_app       Flutter Android dashboard
package.json          Pi package metadata and npm scripts
plan.md               Architecture plan
progress.md           Progress and validation notes
TODO.md               Follow-up work
```

## Requirements

- Pi Coding Agent `>=0.60.0`.
- Node.js `18+` available where Pi runs.
- Flutter/Dart for Android app development (`flutter --version`).
- Android emulator, USB device, or physical phone on same LAN/Tailscale network.

## Quick start

### 1. Clone repo

```bash
git clone https://github.com/md-riaz/pi-hub.git
cd pi-hub
```

### 2. Install Pi extension

Install from local clone path:

```bash
pi install C:/path/to/pi-hub
```

Example for this VM path:

```bash
pi install C:/Users/vm_user/Downloads/pi-hub
```

Restart every Pi session you want to show in the dashboard. Each session loads `pi-hub.ts`, auto-starts the hub server once, and registers itself.

### 3. Start/check hub inside Pi

Inside any Pi session:

```text
/hub
/hub start
/hub info
```

- `/hub` or `/hub info` shows server status, local URL, token, and config path.
- `/hub start` starts the server manually if auto-start did not run.

### 4. Get token

Token lives in:

```text
~/.pi/agent/pi-hub/config.json
```

PowerShell:

```powershell
Get-Content "$env:USERPROFILE\.pi\agent\pi-hub\config.json"
```

macOS/Linux shell:

```bash
cat ~/.pi/agent/pi-hub/config.json
```

### 5. Run Android dashboard

```bash
cd apps/pi_hub_app
flutter pub get
flutter run
```

Connect with:

- Android emulator: `http://10.0.2.2:17878`
- Physical phone: `http://<Windows-VM-IP>:17878`
- Tailscale phone: `http://<Tailscale-IP>:17878`
- Token: value from `~/.pi/agent/pi-hub/config.json`

For physical phones, keep `host` as `0.0.0.0` in config and allow inbound Windows firewall TCP `17878` if needed.

### 6. Build APK

```bash
cd apps/pi_hub_app
flutter build apk --release
```

APK output:

```text
apps/pi_hub_app/build/app/outputs/flutter-apk/app-release.apk
```

Install that APK on phone, then enter server URL and token.

## How to use dashboard

1. Open app and enter server URL + token.
2. Tap **Connect**.
3. Select Pi session in left list.
4. Read transcript and active tool strip.
5. Type prompt at bottom and tap **Send**.
6. Use controls:
   - **Abort**: stop current Pi work.
   - **Compact**: trigger session compaction.
   - **Model**: pick available model from selected session.
   - **Shutdown**: close selected Pi session.

Commands are queued on hub server. Pi sessions poll queue every `pollIntervalMs` (default `1500ms`).

## Configuration

Config file is created automatically:

```text
~/.pi/agent/pi-hub/config.json
```

Typical config:

```json
{
  "enabled": true,
  "host": "0.0.0.0",
  "port": 17878,
  "token": "generated-token",
  "historyLimit": 500,
  "autoStartServer": true,
  "pollIntervalMs": 1500
}
```

Fields:

- `enabled`: enable/disable extension bridge.
- `host`: server bind host. Use `0.0.0.0` for phone access.
- `port`: server port.
- `token`: bearer token for app/API.
- `historyLimit`: max in-memory transcript items per session.
- `autoStartServer`: extension starts hub server automatically.
- `pollIntervalMs`: Pi session command polling interval.

After config edits, restart Pi sessions and server.

## Manual server run

Normally Pi extension starts server. To run manually:

```bash
npm run hub:server
```

Health check:

```bash
curl "http://127.0.0.1:17878/api/health?token=<token>"
```

## API summary

All API routes except `/` require bearer token (`Authorization: Bearer <token>`) or `?token=<token>`.

- `GET /api/health` — server status and local addresses.
- `GET /api/snapshot` — full sessions snapshot.
- `GET /api/stream` — SSE stream of snapshots/session updates.
- `POST /api/register` — register Pi session.
- `POST /api/unregister` — mark Pi session offline.
- `POST /api/presence` — update session status/model/context.
- `POST /api/event` — push transcript/tool/event update.
- `POST /api/send` — queue user prompt.
- `POST /api/control` — queue `abort`, `compact`, `set_model`, or `shutdown`.
- `GET /api/poll` — Pi session polls queued commands.

## Security notes

Pi Hub is built for trusted LAN/Tailscale use. Do not expose it directly to public internet. Before public exposure, add HTTPS, stronger auth, token rotation, and rate limiting.

Keep `~/.pi/agent/pi-hub/config.json` private because it contains the bearer token.

## Troubleshooting

- **No sessions visible**: restart Pi sessions after `pi install`, then run `/hub start`.
- **Phone cannot connect**: use VM LAN/Tailscale IP, keep `host: "0.0.0.0"`, and allow firewall TCP `17878`.
- **Unauthorized**: copy fresh token from `~/.pi/agent/pi-hub/config.json`.
- **Stale server state**: stop old Node process or remove stale `~/.pi/agent/pi-hub/server.pid`, then run `/hub start`.
- **Emulator cannot connect**: use `http://10.0.2.2:17878`, not `localhost`.

## Development checks

```bash
node --check pi-hub-server.mjs
cd apps/pi_hub_app
flutter analyze
flutter test
```

## License

MIT. See [LICENSE](LICENSE).
