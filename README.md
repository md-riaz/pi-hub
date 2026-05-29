# Pi Hub Dashboard

Pi Coding Agent extension plus Flutter Android app for managing multiple Pi sessions from a phone over LAN/Tailscale.

## Decisions

- Local Windows VM server now; HTTP/SSE protocol kept cloud-relay-friendly for later.
- Android phone connects over Tailscale/LAN to TCP `17878`.
- Memory-only server history; no server-side transcript database.
- First controls: view sessions, send prompts, abort, compact, switch model, shutdown.

## Layout

```text
pi-hub.ts             Pi extension loaded by every Pi session
pi-hub-server.mjs     Central memory-only HTTP/SSE server
apps/pi_hub_app       Flutter Android dashboard
plan.md               Architecture plan
progress.md           Progress/validation notes
TODO.md               Follow-up work
```

## Install/use as Pi extension

From this repo:

```bash
pi install C:/Users/vm_user/Downloads/pi-hub
```

Restart Pi sessions. Each session auto-starts/registers with the hub.

Inside Pi:

```text
/hub
/hub start
```

Config/token:

```text
~/.pi/agent/pi-hub/config.json
```

Default server listens on `0.0.0.0:17878`. For physical phone, use Windows VM LAN/Tailscale IP and allow Windows firewall TCP `17878` if needed.

## Flutter Android app

```bash
cd apps/pi_hub_app
flutter run
# or
flutter build apk --release
```

Connect using:

- Android emulator: `http://10.0.2.2:17878`
- Physical phone: `http://<Windows-VM-IP>:17878`
- Token from `~/.pi/agent/pi-hub/config.json`

## API summary

- `GET /api/health`
- `GET /api/snapshot`
- `GET /api/stream` (SSE)
- `POST /api/register`
- `POST /api/unregister`
- `POST /api/presence`
- `POST /api/event`
- `POST /api/send`
- `POST /api/control`
- `GET /api/poll`

All API routes except `/` require bearer token or `?token=`.
