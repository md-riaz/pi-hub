# Progress

## 2026-05-29

- Added Pi Hub extension (`pi-hub.ts`) that auto-starts central server, registers each Pi session, streams session history/current work, and polls for commands.
- Added memory-only Pi Hub server (`pi-hub-server.mjs`) with token auth, HTTP JSON endpoints, SSE stream, session registry, and command queues.
- Added Flutter Android app (`apps/pi_hub_app`) for Tailscale/LAN monitoring and control.
- Updated README with Pi Hub setup and Android app usage.
- Expanded repository README and Flutter app README with professional direct Git URL install, local development, use/build/API/troubleshooting instructions.
- Added root `.gitignore` and cleaned Flutter app metadata for repo readiness.
- Confirmed user decisions after initial commit:
  - hybrid later, local VM server now
  - Tailscale/LAN phone access
  - memory-only history
  - full first-pass controls
- Added controls after consultation: abort, compact, model switch, shutdown.
- Added guarded agent creation backend disabled by default, with workspace root allowlist, shell-free spawn, `/api/v2/agents/create`, audit entries, and README risk docs.
- Added mobile create-agent form shown only when server capability `agentCreation` is true.

## Validation

- Pi extension loader loads `index.ts` and `pi-hub.ts` without errors.
- Server smoke tested: health, register, send/poll, control/poll, snapshot availableModels.
- Agent creation smoke tested: disabled path returns `403`; out-of-root enabled path returns `400`; enabled temp allowlist with Node harmless command in `testMode` returns success and audit entry.
- Flutter `flutter analyze` passes.
- Flutter `flutter test` passes.
