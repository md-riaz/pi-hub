# Proposal — Pi Hub v2 Mobile-First Agent Mission Control

Feature slug: `pi-hub-v2-mobile-first-agent-mission-control`

## Planning inputs and sanity checks

- `.sdd/specs/requirements.md` was not present in this working tree, so canonical requirements store is treated as empty.
- No prior feature artifacts were available under `.sdd/pi-hub-v2-mobile-first-agent-mission-control/`; this proposal starts from current code and README state.
- Current code already provides: Pi session registration/tracking, in-memory hub server, bearer-token HTTP/SSE API, Flutter Android dashboard, conversation history, live tool activity, prompt send, abort/compact/model/shutdown commands, LAN/Tailscale usage.

## Problem

Pi Hub is currently a remote dashboard. It shows and controls running Pi sessions, but the operator still needs RDP/desktop access for many mission-control actions: understanding which agents need attention, reacting to approvals/tool errors, reviewing changes, starting new agents, coordinating agents, and managing security posture.

Target user runs 5–20 Pi agents on a Windows VPS and wants phone-first operation over Tailscale/LAN with minimal RDP use.

## Proposal

Evolve Pi Hub into mobile-first mission control in incremental, backward-compatible slices:

1. Add a v2 event/session contract with derived health, attention reasons, and command lifecycle status while preserving existing `/api/*` behavior.
2. Rework Flutter UI from desktop-like two-pane dashboard into responsive mobile mission control: agent health overview, attention queue, inbox, and session detail optimized for portrait phones.
3. Add agent inbox and in-app notifications for events that need operator action: completions, errors, approvals, stale/offline agents, command failures, diff reviews, and collaboration messages.
4. Add approval and diff-review flows so phone can approve/reject work without RDP.
5. Add guarded agent creation from phone for approved workspace roots on the VPS.
6. Add agent collaboration messages and routing so the operator can coordinate multiple Pi sessions from the app.
7. Add a security roadmap and first hardening steps before any public exposure: token rotation, audit events, rate limits, allowlists, confirmation gates, and optional push-provider isolation.

## Goals

- Manage 5–20 live Pi sessions from Android phone.
- Make health and attention obvious within one tap.
- Preserve current LAN/Tailscale, memory-first architecture where possible.
- Keep v1 clients/endpoints working during rollout.
- Support prompt/control commands with visible queued/delivered/applied/failed state.
- Support agent inbox, approval requests, diff review, agent creation, and collaboration as composable server-side primitives.
- Keep dangerous actions guarded and disabled by default where needed.
- Produce small reviewable implementation tasks; each task should stay at or below 400 changed lines unless explicitly split.

## Non-goals for this feature plan

- No public internet exposure without HTTPS/stronger auth/rate limiting.
- No mandatory database service. Prefer in-memory state with optional compact JSON persistence/audit log later.
- No full desktop IDE replacement; phone flows focus on mission-control decisions and lightweight review.
- No assumption that push notifications work without an external provider such as FCM, ntfy, or webhook bridge.
- No unguarded remote shell or arbitrary command execution from phone.

## Proposed milestones

### Milestone 1 — v2 foundation and mobile shell

- Versioned event envelope and normalized command status.
- Session health derived on server.
- Flutter model/client split from monolithic `main.dart`.
- Portrait-first mission-control home with agent cards and attention sorting.

### Milestone 2 — inbox and action loop

- Inbox item model on server.
- Flutter inbox/read-unread UX.
- Command acknowledgements and failures visible in app.
- In-app notification banners while app is connected.

### Milestone 3 — approvals and diffs

- Approval request model, response commands, and UI.
- Diff review model with file/hunk display and action responses.
- Size caps and redaction for tool/diff payloads.

### Milestone 4 — agent creation and collaboration

- Guarded agent creation endpoint disabled by default.
- Mobile agent creation form with workspace allowlist validation.
- Direct/group collaboration messages between agents and operator.

### Milestone 5 — push and security hardening

- Optional push-provider adapter and mobile token registration.
- Token rotation command/UI.
- Basic rate limits, audit trail, destructive-action confirmation, security docs.

## Success criteria

- Operator can open app and see which agents are healthy, busy, stale, blocked, or failed.
- Operator can clear an attention inbox from phone without RDP for common cases.
- Prompt/control commands show lifecycle status, not only snackbar "queued" state.
- Approval and diff-review requests can be answered from phone.
- Agent creation works only when explicitly enabled and limited to configured workspace roots.
- Existing v1 app/server/extension behavior remains compatible during rollout.
- Security docs clearly say trusted LAN/Tailscale only until hardening complete.

## Key risks

- Pi extension API may not expose every approval/diff event needed; design must degrade gracefully and support synthetic/manual events first.
- Flutter monolith refactor can grow too large; split models/client/UI in small tasks before adding features.
- True push notifications require external credentials/provider and may be out of scope for local-only deployments.
- Agent creation is dangerous on a VPS; must be allowlisted, audited, and disabled by default.
- In-memory server state can be lost on restart; inbox/command audit may need optional JSON persistence after MVP.

## Open questions

- Which push provider should be preferred first: FCM, ntfy, webhook, or Tailscale-only in-app notifications?
- What exact Pi CLI command and workspace policy should agent creation use on Windows VPS?
- Which Pi Coding Agent events/APIs expose approval and diff-review hooks today?
- Should inbox/audit state persist across server restarts in v2 MVP, or remain memory-only until hardening?
