# Tasks — Pi Hub v2 Mobile-First Agent Mission Control

Feature slug: `pi-hub-v2-mobile-first-agent-mission-control`

## Checklist task schema

Each task uses:

- `Files`: expected files touched or added.
- `Detail`: implementation scope and boundaries.
- `Evidence`: commands, tests, fixtures, or manual checks proving completion.
- `Review estimate`: expected changed lines and review time. Keep each task `<=400` changed lines; split before implementation if estimate grows.

## Tasks

- [x] T01 — Add protocol fixtures and v2 contract notes
  - Files:
    - `docs/pi-hub-v2-protocol.md`
    - `apps/pi_hub_app/test/fixtures/mission_control_snapshot.json`
    - `apps/pi_hub_app/test/fixtures/mission_control_events.jsonl`
  - Detail: Document v2 event envelope, health, inbox, command, approval, diff, push device, and agent creation shapes. Add representative fixtures for 20 sessions with mixed health states. No runtime behavior change.
  - Evidence: Docs render in Markdown; fixtures parse with `python -m json.tool` or equivalent JSON validation for snapshot.
  - Review estimate: ~180 changed lines, 20 min.

- [x] T02 — Normalize server events behind existing v1 routes
  - Files:
    - `pi-hub-server.mjs`
  - Detail: Add `normalizeEvent`, server-generated event IDs, schemaVersion handling, and `applyEvent` entry point. Preserve current `/api/event`, `/api/presence`, `/api/register`, and `/api/stream` responses.
  - Evidence: `node --check pi-hub-server.mjs`; smoke register/event/snapshot still works with current payloads.
  - Review estimate: ~320 changed lines, 40 min.

- [x] T03 — Add derived session health on server
  - Files:
    - `pi-hub-server.mjs`
  - Detail: Add health derivation to `publicSession()`: state, lastSeenAgeMs, attention, attentionReasons, runningToolCount, pendingCommandCount, contextPercent. Add stale threshold config default without breaking old config.
  - Evidence: `node --check pi-hub-server.mjs`; snapshot shows health for online/offline/stale/tool-error fixture sessions.
  - Review estimate: ~240 changed lines, 35 min.

- [x] T04 — Enrich extension presence and command result events
  - Files:
    - `pi-hub.ts`
  - Detail: Include protocol/client version in register/presence. When commands are polled, emit result/ack events with command id, type, applied boolean, and error when action fails or target model missing. Keep existing `command_received` behavior.
  - Evidence: Pi extension smoke run; server receives command result events; no regression for prompt/abort/compact/model/shutdown.
  - Review estimate: ~260 changed lines, 40 min.

- [x] T05 — Split Flutter models and API client from `main.dart`
  - Files:
    - `apps/pi_hub_app/lib/main.dart`
    - `apps/pi_hub_app/lib/src/hub_client.dart`
    - `apps/pi_hub_app/lib/src/hub_models.dart`
    - `apps/pi_hub_app/test/widget_test.dart`
  - Detail: Move `HubClient`, `HubSnapshot`, `HubSession`, `HubItem`, `HubTool`, `HubModel`, and `ContextUsage` out of monolithic `main.dart`. Keep UI behavior unchanged.
  - Evidence: `cd apps/pi_hub_app && flutter analyze && flutter test`.
  - Review estimate: ~360 changed lines, 45 min.

- [x] T06 — Add v2 Dart models and fixture parser tests
  - Files:
    - `apps/pi_hub_app/lib/src/hub_models.dart`
    - `apps/pi_hub_app/test/hub_models_test.dart`
    - `apps/pi_hub_app/test/fixtures/mission_control_snapshot.json`
  - Detail: Add Dart parsing for health, inbox items, command status, approvals, diff reviews, audit summary, and server capabilities. Unknown fields must be ignored.
  - Evidence: `flutter test test/hub_models_test.dart`; fixture with 20 sessions parses.
  - Review estimate: ~340 changed lines, 45 min.

- [x] T07 — Add mission-control mobile shell
  - Files:
    - `apps/pi_hub_app/lib/main.dart`
    - `apps/pi_hub_app/lib/src/mission_control_screen.dart`
    - `apps/pi_hub_app/lib/src/session_detail_screen.dart`
    - `apps/pi_hub_app/lib/src/widgets/connection_bar.dart`
  - Detail: Introduce responsive `LayoutBuilder`. Narrow screens use single-column navigation; wide screens preserve two-pane layout. Keep connect/send/control flows available.
  - Evidence: `flutter analyze && flutter test`; manual emulator check at phone and tablet widths.
  - Review estimate: ~390 changed lines, 60 min.

- [x] T08 — Add agent health overview UI
  - Files:
    - `apps/pi_hub_app/lib/src/mission_control_screen.dart`
    - `apps/pi_hub_app/lib/src/widgets/agent_card.dart`
    - `apps/pi_hub_app/lib/src/widgets/health_chip.dart`
    - `apps/pi_hub_app/test/widget_test.dart`
  - Detail: Show attention-sorted agent cards with state, status, cwd/name, model, context, running tool count, unread inbox count, and last seen. Support 20 fixture sessions without overflow.
  - Evidence: Widget test renders health cards from fixture; `flutter analyze`.
  - Review estimate: ~330 changed lines, 45 min.

- [x] T09 — Track command lifecycle on server
  - Files:
    - `pi-hub-server.mjs`
  - Detail: Add `commands` map/ring, status transitions queued->delivered->applied/failed/expired. Update `/api/send`, `/api/control`, `/api/poll`, and event handling for command result. Broadcast command updates.
  - Evidence: `node --check pi-hub-server.mjs`; smoke test queues command, polls it, posts result, snapshot shows final status.
  - Review estimate: ~360 changed lines, 55 min.

- [x] T10 — Show command lifecycle in Flutter
  - Files:
    - `apps/pi_hub_app/lib/src/hub_models.dart`
    - `apps/pi_hub_app/lib/src/session_detail_screen.dart`
    - `apps/pi_hub_app/lib/src/widgets/command_status_strip.dart`
    - `apps/pi_hub_app/test/widget_test.dart`
  - Detail: Display pending/recent command state for selected session. Failed commands should be prominent and link to inbox item when present.
  - Evidence: Widget test for queued/delivered/failed commands; `flutter analyze && flutter test`.
  - Review estimate: ~300 changed lines, 40 min.

- [x] T11 — Add server inbox model and read API
  - Files:
    - `pi-hub-server.mjs`
  - Detail: Add capped `inboxItems` store, item generation for command failures/tool errors/stale/offline/approval/diff placeholders, `/api/v2/inbox/read`, snapshot inclusion, SSE broadcasts, dedupe rules.
  - Evidence: `node --check pi-hub-server.mjs`; smoke creates tool error, reads item, snapshot updates readAt.
  - Review estimate: ~380 changed lines, 60 min.

- [x] T12 — Add Flutter inbox screen
  - Files:
    - `apps/pi_hub_app/lib/src/inbox_screen.dart`
    - `apps/pi_hub_app/lib/src/mission_control_screen.dart`
    - `apps/pi_hub_app/lib/src/hub_client.dart`
    - `apps/pi_hub_app/test/widget_test.dart`
  - Detail: Render unread/read inbox items, filter by severity/session/type, mark read, and navigate to referenced session/action. Use v2 read API when available.
  - Evidence: Widget tests for unread count and mark-read call; `flutter analyze && flutter test`.
  - Review estimate: ~370 changed lines, 60 min.

- [x] T13 — Add connected in-app notifications
  - Files:
    - `apps/pi_hub_app/lib/src/mission_control_screen.dart`
    - `apps/pi_hub_app/lib/src/widgets/notification_banner.dart`
    - `apps/pi_hub_app/test/widget_test.dart`
  - Detail: While SSE is connected, show dismissible banners/snackbars for new high-severity inbox items, approvals, diff reviews, command failures, and stale/offline transitions. No external push yet.
  - Evidence: Widget test injects stream event and verifies banner; `flutter analyze && flutter test`.
  - Review estimate: ~220 changed lines, 30 min.

- [x] T14 — Add approval request backend/protocol
  - Files:
    - `pi-hub-server.mjs`
    - `pi-hub.ts`
  - Detail: Add approval records, inbox creation, response route `/api/v2/approvals/:id/respond`, command type `approval_response`, and extension handler with feature detection/fallback notification. Keep unsupported Pi API graceful.
  - Evidence: Server smoke creates approval event, responds approve/reject, command polls to agent; extension handles unknown API without crash.
  - Review estimate: ~380 changed lines, 70 min.

- [x] T15 — Add approval request mobile UI
  - Files:
    - `apps/pi_hub_app/lib/src/approval_sheet.dart`
    - `apps/pi_hub_app/lib/src/inbox_screen.dart`
    - `apps/pi_hub_app/lib/src/hub_client.dart`
    - `apps/pi_hub_app/test/widget_test.dart`
  - Detail: Bottom sheet shows title/body/risk/choices. Supports approve/reject/comment and updates local status from stream.
  - Evidence: Widget test opens approval from inbox and submits reject comment; `flutter analyze && flutter test`.
  - Review estimate: ~330 changed lines, 50 min.

- [x] T16 — Add diff review backend/protocol
  - Files:
    - `pi-hub-server.mjs`
    - `pi-hub.ts`
  - Detail: Add diff review records, size caps, inbox creation, response route `/api/v2/diff-reviews/:id/respond`, and extension fallback command handling. Sanitize file paths and cap patch text.
  - Evidence: Smoke posts diff event with two files, snapshot includes capped review, response queues command; `node --check`.
  - Review estimate: ~390 changed lines, 75 min.

- [x] T17 — Add diff review mobile UI
  - Files:
    - `apps/pi_hub_app/lib/src/diff_review_screen.dart`
    - `apps/pi_hub_app/lib/src/inbox_screen.dart`
    - `apps/pi_hub_app/lib/src/hub_client.dart`
    - `apps/pi_hub_app/test/widget_test.dart`
  - Detail: Show file list, additions/deletions, monospaced hunks, approve/request changes/comment actions. Handle capped/truncated patches clearly.
  - Evidence: Widget test renders multi-file fixture and submits changes-requested comment; `flutter analyze && flutter test`.
  - Review estimate: ~390 changed lines, 70 min.

- [x] T18 — Add guarded agent creation backend
  - Files:
    - `pi-hub-server.mjs`
    - `README.md`
    - `TODO.md`
  - Detail: Add disabled-by-default `agentCreation` config, workspace root allowlist, safe `spawn` without shell interpolation, `/api/v2/agents/create`, audit event, and rejection responses for disabled/out-of-root requests.
  - Evidence: `node --check`; smoke disabled returns 403/400; enabled temp allowlist spawns configured harmless command in test mode; README documents risk.
  - Review estimate: ~380 changed lines, 75 min.

- [x] T19 — Add agent creation mobile form
  - Files:
    - `apps/pi_hub_app/lib/src/agent_create_sheet.dart`
    - `apps/pi_hub_app/lib/src/mission_control_screen.dart`
    - `apps/pi_hub_app/lib/src/hub_client.dart`
    - `apps/pi_hub_app/test/widget_test.dart`
  - Detail: Show create action only when server capabilities allow. Collect workspace/name/model/initial prompt, display warning, submit, and show creation status.
  - Evidence: Widget test hidden when disabled and submit path when enabled; `flutter analyze && flutter test`.
  - Review estimate: ~320 changed lines, 50 min.

- [x] T20 — Add provider-neutral notification device registry
  - Files:
    - `pi-hub-server.mjs`
    - `apps/pi_hub_app/lib/src/hub_models.dart`
    - `docs/pi-hub-v2-protocol.md`
  - Detail: Add device registration records and `/api/v2/push/devices` without sending external notifications yet. Include scopes and provider config status in capabilities.
  - Evidence: `node --check`; smoke register/update/disable device; snapshot excludes secret token values.
  - Review estimate: ~280 changed lines, 45 min.

- [x] T21 — Add optional push provider integration
  - Files:
    - `pi-hub-server.mjs`
    - `apps/pi_hub_app/pubspec.yaml`
    - `apps/pi_hub_app/android/app/src/main/AndroidManifest.xml`
    - `apps/pi_hub_app/lib/main.dart`
    - `README.md`
  - Detail: Integrate one chosen provider (FCM, ntfy, or webhook) behind config. Disabled when provider credentials/topic absent. Do not require public hub exposure. If FCM is chosen, include Android setup docs and keep secrets out of git.
  - Evidence: `node --check`; `flutter analyze`; provider-disabled path works; manual provider smoke documented if credentials available.
  - Review estimate: ~390 changed lines, 90 min.

- [ ] T22 — Add collaboration routing backend/extension handling
  - Files:
    - `pi-hub-server.mjs`
    - `pi-hub.ts`
  - Detail: Add `/api/v2/collaboration/messages`, target session selection, inbox/history event creation, and command type `collaboration_message`. Extension injects as user-visible message or notification based on available Pi API.
  - Evidence: Smoke sends message to two sessions, both poll commands, inbox shows collaboration item.
  - Review estimate: ~350 changed lines, 65 min.

- [ ] T23 — Add collaboration mobile UI
  - Files:
    - `apps/pi_hub_app/lib/src/collaboration_screen.dart`
    - `apps/pi_hub_app/lib/src/mission_control_screen.dart`
    - `apps/pi_hub_app/lib/src/hub_client.dart`
    - `apps/pi_hub_app/test/widget_test.dart`
  - Detail: Compose direct/group message, choose target agents, show recent collaboration thread/inbox references.
  - Evidence: Widget test selects two agents and submits message; `flutter analyze && flutter test`.
  - Review estimate: ~320 changed lines, 55 min.

- [ ] T24 — Add token rotation command and docs
  - Files:
    - `pi-hub.ts`
    - `pi-hub-server.mjs`
    - `README.md`
    - `TODO.md`
  - Detail: Add `/hub rotate-token` or equivalent guarded flow. Server reloads/uses new token safely; docs explain reconnecting mobile clients. Avoid logging token.
  - Evidence: Manual smoke rotates token, old token rejected, new token works; `node --check`.
  - Review estimate: ~300 changed lines, 60 min.

- [ ] T25 — Add rate limits, audit ring, and destructive confirmations
  - Files:
    - `pi-hub-server.mjs`
    - `apps/pi_hub_app/lib/src/session_detail_screen.dart`
    - `README.md`
  - Detail: Add lightweight per-token/IP rate limits for write routes, capped audit events in snapshot, and explicit confirmation UI for shutdown/create/high-risk approvals.
  - Evidence: Smoke repeated bad requests hit rate limit; widget test confirms shutdown dialog; README security section updated.
  - Review estimate: ~380 changed lines, 80 min.

- [ ] T26 — Update project tracking docs after active API decisions land
  - Files:
    - `plan.md`
    - `progress.md`
    - `TODO.md`
    - `README.md`
    - `apps/pi_hub_app/README.md`
  - Detail: Once implementation begins changing API/project direction, update tracking docs with v2 architecture, progress, TODOs, setup, API, security, and validation notes.
  - Evidence: Docs match implemented endpoints/features; links/commands verified.
  - Review estimate: ~260 changed lines, 35 min.

## Review Workload

| Area | Tasks | Est. changed lines | Review notes |
| --- | --- | ---: | --- |
| Protocol and server foundation | T01–T04 | ~1,000 | Validate compatibility first; no UI dependency. |
| Flutter refactor and mobile shell | T05–T08 | ~1,420 | Highest regression risk from layout/refactor; use fixtures. |
| Command lifecycle and inbox | T09–T13 | ~1,630 | Core mission-control loop; review state transitions carefully. |
| Approvals and diffs | T14–T17 | ~1,490 | Needs payload caps and graceful extension fallback. |
| Agent creation, push, collaboration | T18–T23 | ~2,040 | Security-sensitive; keep features disabled/configured by default. |
| Security and docs | T24–T26 | ~940 | Must update README/tracking docs when active decisions land. |

Total planned implementation review: ~8,520 changed lines across 26 small tasks. Expected reviewer time: 18–24 hours total, but each task remains independently reviewable and should be split if it exceeds 400 changed lines.
