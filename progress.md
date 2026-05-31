# Progress

### 2026-05-31 — Dedicated Flutter logout

- Added dedicated Flutter logout controls on session list and session detail screens.
- Logout leaves the active hub and returns to connection screen while keeping recent hub URLs/tokens saved for quick hub switching.
- Kept disconnect as separate quick action for dropping the current live connection.

### 2026-05-31 — v2.0.1: UX overhaul + cleanup

**Flutter app completely redesigned:**
- Chat-style session detail with user/assistant bubbles, streaming cursor
- Tool group cards, terminal cards, edit cards, waiting cards
- Full-screen connection with persisted recent connections
- Session list with search bar and state filter chips
- Composer with attachment, slash commands, model switch buttons
- 7 bottom sheets: model, slash, attachment, session menu, new session, broadcast, diff drawer
- Remote path browser for new session creation
- Status dots with glowing effect

**Real file attachments:**
- Pick files from device storage
- Pick images from gallery
- Paste from clipboard
- Server browse endpoint (`GET /api/v2/browse`)
- File upload via base64 (`POST /api/v2/send-attachment`)

**Server/extension cleanup (-697 lines):**
- Removed inbox, approval, diff review systems from server
- Removed approval response handling from extension
- Server: 2131 → 1475 lines
- Extension: 806 → 767 lines

**Bug fixes:**
- Connect button rebuilds on text input
- Recent connections loaded from SharedPreferences
- Model lists from server (not hardcoded)
- Session chips show display name, model, cwd
- Auto-scroll only when near bottom
- SafeArea wrapping
- Model sheet scrollable
- Back button returns to session list
- OS-specific firewall commands
- Human-readable error messages

**Version:** 2.0.1+1

## 2026-05-29

- Added Pi Hub extension (`pi-hub.ts`) that auto-starts central server, registers each Pi session, streams session history/current work, and polls for commands.
- Added memory-only Pi Hub server (`pi-hub-server.mjs`) with token auth, HTTP JSON endpoints, SSE stream, session registry, and command queues.
- Added Flutter Android app (`apps/pi_hub_app`) for remote monitoring and control over any network.
- Updated README with Pi Hub setup and Android app usage.
- Expanded repository README and Flutter app README with professional direct Git URL install, local development, use/build/API/troubleshooting instructions.
- Added root `.gitignore` and cleaned Flutter app metadata for repo readiness.
- Confirmed user decisions after initial commit:
  - hybrid later, local VM server now
  - any-network phone access
  - memory-only history
  - full first-pass controls
- Added controls after consultation: abort, compact, model switch, shutdown.
- Added guarded agent creation backend disabled by default, with workspace root allowlist, shell-free spawn, `/api/v2/agents/create`, audit entries, and README risk docs.
- Added mobile create-agent form shown only when server capability `agentCreation` is true.
- Improved mobile connection UX: host-only URLs auto-normalize to `http://`, connected state hides setup form, and empty agent state explains how sessions appear.

## Validation

- Pi extension loader loads `index.ts` and `pi-hub.ts` without errors.
- Server smoke tested: health, register, send/poll, control/poll, snapshot availableModels.
- Agent creation smoke tested: disabled path returns `403`; out-of-root enabled path returns `400`; enabled temp allowlist with Node harmless command in `testMode` returns success and audit entry.
- Flutter `flutter analyze` passes.
- Flutter `flutter test` passes.

## 2026-05-30

- Added AI-friendly onboarding docs (`AGENTS.md`, `docs/ai-context.md`) so future agents can quickly understand architecture, product decisions, current behavior, gotchas, release flow, and paused attachment work.
