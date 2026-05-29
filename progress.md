# Progress

## 2026-05-29

- Added Pi Hub extension (`pi-hub.ts`) that auto-starts central server, registers each Pi session, streams session history/current work, and polls for commands.
- Added memory-only Pi Hub server (`pi-hub-server.mjs`) with token auth, HTTP JSON endpoints, SSE stream, session registry, and command queues.
- Added Flutter Android app (`apps/pi_hub_app`) for Tailscale/LAN monitoring and control.
- Updated README with Pi Hub setup and Android app usage.
- Expanded repository README and Flutter app README with clone/install/use/build/API/troubleshooting instructions.
- Added root `.gitignore` and cleaned Flutter app metadata for repo readiness.
- Confirmed user decisions after initial commit:
  - hybrid later, local VM server now
  - Tailscale/LAN phone access
  - memory-only history
  - full first-pass controls
- Added controls after consultation: abort, compact, model switch, shutdown.

## Validation

- Pi extension loader loads `index.ts` and `pi-hub.ts` without errors.
- Server smoke tested: health, register, send/poll, control/poll, snapshot availableModels.
- Flutter `flutter analyze` passes.
- Flutter `flutter test` passes.
