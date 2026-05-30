#!/usr/bin/env node
import http from "node:http";
import os from "node:os";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PI_HOME = process.env.PI_HOME || path.join(os.homedir(), ".pi", "agent");
const HUB_DIR = path.join(PI_HOME, "pi-hub");
const CONFIG_PATH = path.join(HUB_DIR, "config.json");
const PID_PATH = path.join(HUB_DIR, "server.pid");

const DEFAULT_CONFIG = {
  enabled: true,
  host: "0.0.0.0",
  port: 17878,
  token: "",
  historyLimit: 500,
  staleThresholdMs: 120_000,
};

function ensureConfig() {
  fs.mkdirSync(HUB_DIR, { recursive: true });
  let config = { ...DEFAULT_CONFIG };
  try {
    config = { ...config, ...JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8")) };
  } catch {}
  if (!config.token || typeof config.token !== "string") {
    config.token = crypto.randomBytes(24).toString("base64url");
  }
  if (!Number.isFinite(Number(config.port))) config.port = DEFAULT_CONFIG.port;
  if (!config.host || typeof config.host !== "string") config.host = DEFAULT_CONFIG.host;
  if (!Number.isFinite(Number(config.historyLimit))) config.historyLimit = DEFAULT_CONFIG.historyLimit;
  if (!Number.isFinite(Number(config.staleThresholdMs))) config.staleThresholdMs = DEFAULT_CONFIG.staleThresholdMs;
  config.staleThresholdMs = Math.max(0, Number(config.staleThresholdMs));
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
  return config;
}

const config = ensureConfig();
const sessions = new Map();
const commandQueues = new Map();
const watchers = new Set();
let eventSeq = 0;
let normalizedEventSeq = 0;

function nowIso() {
  return new Date().toISOString();
}

function capString(value, max = 20000) {
  if (typeof value !== "string") return value;
  return value.length > max ? `${value.slice(0, max)}\n…[truncated ${value.length - max} chars]` : value;
}

function sanitizeItem(item) {
  if (!item || typeof item !== "object") return item;
  const next = { ...item };
  if (typeof next.text === "string") next.text = capString(next.text);
  if (next.metadata && typeof next.metadata === "object") {
    next.metadata = JSON.parse(JSON.stringify(next.metadata, (_key, value) => {
      if (typeof value === "string") return capString(value, 4000);
      return value;
    }));
  }
  return next;
}

function contextPercent(contextUsage) {
  if (!contextUsage || typeof contextUsage !== "object") return undefined;
  if (Number.isFinite(Number(contextUsage.percent))) return Number(contextUsage.percent);
  const used = Number(contextUsage.tokens ?? contextUsage.usedTokens);
  const total = Number(contextUsage.contextWindow ?? contextUsage.maxTokens ?? contextUsage.totalTokens);
  if (Number.isFinite(used) && Number.isFinite(total) && total > 0) return (used / total) * 100;
  return undefined;
}

function publicSession(session) {
  const health = deriveSessionHealth(session);
  return {
    id: session.id,
    name: session.name,
    cwd: session.cwd,
    model: session.model,
    pid: session.pid,
    startedAt: session.startedAt,
    lastSeen: session.lastSeen,
    status: session.status,
    online: session.online,
    contextUsage: session.contextUsage,
    history: session.history,
    liveMessage: session.liveMessage,
    tools: Array.from(session.tools.values()),
    availableModels: session.availableModels || [],
    lastEvent: session.lastEvent,
    health,
  };
}

function serverCapabilities() {
  return {
    schemaVersion: 2,
    eventEnvelope: true,
    health: true,
    inbox: false,
    commandLifecycle: false,
    approvals: false,
    diffReviews: false,
    agentCreation: false,
    pushDevices: false,
  };
}

function snapshot() {
  return {
    server: {
      pid: process.pid,
      startedAt,
      host: config.host,
      port: Number(config.port),
      time: nowIso(),
      version: "1.0.0",
      schemaVersion: 2,
      staleThresholdMs: Number(config.staleThresholdMs),
      capabilities: serverCapabilities(),
    },
    sessions: Array.from(sessions.values())
      .sort((a, b) => String(a.cwd).localeCompare(String(b.cwd)) || String(a.name || a.id).localeCompare(String(b.name || b.id)))
      .map(publicSession),
  };
}

function sendJson(res, status, body) {
  const text = JSON.stringify(body);
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(text),
    "access-control-allow-origin": "*",
    "access-control-allow-headers": "content-type, authorization",
    "access-control-allow-methods": "GET,POST,OPTIONS",
  });
  res.end(text);
}

function sendText(res, status, text) {
  res.writeHead(status, {
    "content-type": "text/plain; charset=utf-8",
    "content-length": Buffer.byteLength(text),
    "access-control-allow-origin": "*",
  });
  res.end(text);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", chunk => {
      body += chunk;
      if (body.length > 5_000_000) {
        reject(new Error("body too large"));
        req.destroy();
      }
    });
    req.on("end", () => {
      if (!body) return resolve({});
      try { resolve(JSON.parse(body)); }
      catch (error) { reject(error); }
    });
    req.on("error", reject);
  });
}

function getToken(req, url) {
  const auth = req.headers.authorization || "";
  if (auth.toLowerCase().startsWith("bearer ")) return auth.slice(7).trim();
  return url.searchParams.get("token") || "";
}

function isAuthorized(req, url) {
  return config.token && getToken(req, url) === config.token;
}

function broadcast(payload) {
  const packet = {
    seq: ++eventSeq,
    timestamp: Date.now(),
    ...payload,
  };
  const text = `data: ${JSON.stringify(packet)}\n\n`;
  for (const res of Array.from(watchers)) {
    try { res.write(text); }
    catch { watchers.delete(res); }
  }
}

function mapLegacyEventType(type) {
  const map = {
    history: "session.history",
    presence: "session.presence",
    register: "session.registered",
    unregister: "session.unregistered",
    agent_start: "session.agent_start",
    agent_end: "session.agent_end",
    message_update: "session.message_update",
    message_end: "session.message_end",
    tool_start: "session.tool_start",
    tool_update: "session.tool_update",
    tool_end: "session.tool_end",
    input: "session.input",
    command_received: "command.result",
    command_queued: "command.queued",
    model_select: "session.model_select",
    thinking_level_select: "session.thinking_level_select",
  };
  return map[type] || type || "session.event";
}

function unmapV2EventType(type) {
  const map = {
    "session.history": "history",
    "session.presence": "presence",
    "session.registered": "register",
    "session.unregistered": "unregister",
    "session.agent_start": "agent_start",
    "session.agent_end": "agent_end",
    "session.message_update": "message_update",
    "session.message_end": "message_end",
    "session.tool_start": "tool_start",
    "session.tool_update": "tool_update",
    "session.tool_end": "tool_end",
    "session.input": "input",
    "command.result": "command_received",
    "command.queued": "command_queued",
    "session.model_select": "model_select",
    "session.thinking_level_select": "thinking_level_select",
  };
  return map[type] || type;
}

function inferSeverity(type, payload = {}) {
  if (payload.severity) return String(payload.severity);
  if (payload.tool?.isError || payload.error || type === "command.result" && payload.applied === false) return "error";
  if (payload.attention) return "warning";
  return "info";
}

function normalizeEvent(input = {}, fallbackSessionId, fallbackType = "session.event") {
  const source = input && typeof input === "object" ? input : {};
  const schemaVersion = Number(source.schemaVersion) === 2 ? 2 : 1;
  const payload = schemaVersion === 2 && source.payload && typeof source.payload === "object"
    ? { ...source.payload }
    : { ...source };
  for (const key of ["schemaVersion", "id", "seq", "actor", "severity", "attention", "payload", "type", "sessionId"]) delete payload[key];
  const incomingType = String(source.type || fallbackType);
  const type = schemaVersion === 2 ? incomingType : mapLegacyEventType(incomingType);
  const legacyType = schemaVersion === 2 ? unmapV2EventType(incomingType) : incomingType;
  const sessionId = source.sessionId || fallbackSessionId;
  const severitySource = schemaVersion === 2 ? { ...payload, severity: source.severity, attention: source.attention } : source;
  const normalized = {
    schemaVersion: 2,
    id: typeof source.id === "string" && source.id ? source.id : `evt_${crypto.randomUUID()}`,
    seq: ++normalizedEventSeq,
    type,
    legacyType,
    sessionId: typeof sessionId === "string" ? sessionId : undefined,
    actor: source.actor && typeof source.actor === "object" ? source.actor : { kind: sessionId ? "agent" : "server", id: sessionId || "pi-hub" },
    timestamp: Number.isFinite(Number(source.timestamp)) ? Number(source.timestamp) : Date.now(),
    severity: inferSeverity(type, severitySource),
    attention: Boolean(source.attention || payload.tool?.isError || payload.error),
    payload,
    raw: source,
  };
  return normalized;
}

function touchSession(session, patch = {}) {
  Object.assign(session, patch);
  session.lastSeen = Date.now();
  session.online = true;
  sessions.set(session.id, session);
  return session;
}

function getOrCreateSession(id) {
  let session = sessions.get(id);
  if (!session) {
    session = {
      id,
      name: undefined,
      cwd: "",
      model: "unknown",
      pid: 0,
      startedAt: Date.now(),
      lastSeen: Date.now(),
      status: "unknown",
      online: true,
      contextUsage: undefined,
      history: [],
      liveMessage: undefined,
      tools: new Map(),
      availableModels: [],
      lastEvent: undefined,
    };
    sessions.set(id, session);
  }
  if (!(session.tools instanceof Map)) session.tools = new Map(Object.entries(session.tools || {}));
  return session;
}

function handleHubEvent(session, event) {
  session.lastEvent = event;
  if (!event || typeof event !== "object") return;

  switch (event.type) {
    case "history": {
      const entries = Array.isArray(event.entries) ? event.entries.map(sanitizeItem) : [];
      session.history = entries.slice(-Number(config.historyLimit));
      break;
    }
    case "presence": {
      if (typeof event.status === "string") session.status = event.status;
      if (typeof event.model === "string") session.model = event.model;
      if (event.contextUsage !== undefined) session.contextUsage = event.contextUsage;
      break;
    }
    case "agent_start": {
      session.status = "thinking";
      break;
    }
    case "agent_end": {
      session.status = "idle";
      session.liveMessage = undefined;
      session.tools.clear();
      break;
    }
    case "message_update": {
      if (event.item) session.liveMessage = sanitizeItem({ ...event.item, streaming: true });
      break;
    }
    case "message_end": {
      if (event.item) {
        const item = sanitizeItem(event.item);
        const idx = session.history.findIndex(existing => existing.id === item.id);
        if (idx >= 0) session.history[idx] = item;
        else session.history.push(item);
        session.history = session.history.slice(-Number(config.historyLimit));
      }
      session.liveMessage = undefined;
      break;
    }
    case "tool_start": {
      if (event.tool) session.tools.set(event.tool.id, { ...event.tool, status: "running" });
      session.status = event.tool?.name ? `tool:${event.tool.name}` : "tool";
      break;
    }
    case "tool_update": {
      if (event.tool?.id) {
        const prev = session.tools.get(event.tool.id) || { id: event.tool.id };
        session.tools.set(event.tool.id, { ...prev, ...event.tool, status: "running" });
      }
      break;
    }
    case "tool_end": {
      if (event.tool?.id) {
        const prev = session.tools.get(event.tool.id) || { id: event.tool.id };
        session.tools.set(event.tool.id, { ...prev, ...event.tool, status: event.tool.isError ? "error" : "done" });
      }
      break;
    }
    case "input":
    case "command_received":
    case "model_select":
    case "thinking_level_select":
      break;
  }
}

function applyEvent(event) {
  if (!event?.sessionId) return undefined;
  const session = touchSession(getOrCreateSession(event.sessionId));
  const legacyEvent = { ...event.payload, type: event.legacyType || event.type };
  if (event.type === "session.registered") {
    const info = event.payload.session && typeof event.payload.session === "object" ? event.payload.session : event.payload;
    Object.assign(session, {
      name: info.name,
      cwd: info.cwd || "",
      model: info.model || "unknown",
      pid: Number(info.pid || 0),
      startedAt: Number(info.startedAt || Date.now()),
      status: info.status || "idle",
      contextUsage: info.contextUsage,
      availableModels: Array.isArray(info.availableModels) ? info.availableModels : [],
    });
    if (Array.isArray(info.history)) session.history = info.history.map(sanitizeItem).slice(-Number(config.historyLimit));
  } else if (event.type === "session.unregistered") {
    session.online = false;
    session.status = "offline";
    session.lastSeen = Date.now();
    session.tools.clear();
  } else {
    handleHubEvent(session, legacyEvent);
  }
  session.lastEvent = event;
  return session;
}

function deriveSessionHealth(session) {
  const lastSeen = Number(session.lastSeen || 0);
  const age = lastSeen ? Math.max(0, Date.now() - lastSeen) : undefined;
  const tools = Array.from(session.tools?.values?.() || []);
  const runningToolCount = tools.filter(tool => tool?.status === "running").length;
  const pendingCommandCount = (commandQueues.get(session.id) || []).length;
  const attentionReasons = [];
  const explicitOffline = session.online === false || session.status === "offline";
  const isStale = !explicitOffline && age !== undefined && Number(config.staleThresholdMs) > 0 && age > Number(config.staleThresholdMs);
  const hasToolError = tools.some(tool => tool?.status === "error" || tool?.isError);
  const lastEventAge = Number.isFinite(Number(session.lastEvent?.timestamp)) ? Date.now() - Number(session.lastEvent.timestamp) : 0;
  const recentWindowMs = Number(config.staleThresholdMs) > 0 ? Number(config.staleThresholdMs) * 2 : Number.POSITIVE_INFINITY;
  const recentLastEvent = lastEventAge <= recentWindowMs;
  const hasCommandFailure = recentLastEvent && session.lastEvent?.type === "command.result" && session.lastEvent?.payload?.applied === false;
  const errorPayload = session.lastEvent?.payload || {};
  const hasAgentError = recentLastEvent && (session.lastEvent?.severity === "error" || (errorPayload.error && session.lastEvent?.type !== "command.queued"));
  const pendingActionType = recentLastEvent ? session.lastEvent?.type : undefined;
  const hasPendingApproval = pendingActionType === "approval.requested" || pendingActionType === "approval_requested";
  const hasPendingDiff = pendingActionType === "diff_review.requested" || pendingActionType === "diff_review_requested";

  if (explicitOffline) attentionReasons.push("offline");
  if (isStale) attentionReasons.push("stale");
  if (hasPendingApproval) attentionReasons.push("approval_pending");
  if (hasPendingDiff) attentionReasons.push("diff_review_pending");
  if (hasToolError) attentionReasons.push("tool_error");
  if (hasCommandFailure) attentionReasons.push("command_failure");
  else if (hasAgentError && !hasToolError) attentionReasons.push("agent_error");

  let state = "idle";
  if (!session.id) state = "unknown";
  else if (explicitOffline) state = "offline";
  else if (isStale) state = "stale";
  else if (hasPendingApproval || hasPendingDiff || session.status === "blocked") state = "blocked";
  else if (hasToolError || hasCommandFailure || hasAgentError) state = "error";
  else if (runningToolCount > 0 || session.status === "thinking" || session.liveMessage) state = "active";

  return {
    state,
    lastSeenAgeMs: age,
    attention: attentionReasons.length > 0,
    attentionReasons,
    runningToolCount,
    pendingCommandCount,
    contextPercent: contextPercent(session.contextUsage),
  };
}

function requireSessionId(body) {
  const sessionId = body?.sessionId || body?.session?.id || body?.event?.sessionId;
  if (!sessionId || typeof sessionId !== "string") throw new Error("sessionId required");
  return sessionId;
}

function localAddresses() {
  const out = [];
  for (const net of Object.values(os.networkInterfaces())) {
    for (const addr of net || []) {
      if (addr.family === "IPv4" && !addr.internal) out.push(addr.address);
    }
  }
  return out;
}

const startedAt = Date.now();

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);

  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "content-type, authorization",
      "access-control-allow-methods": "GET,POST,OPTIONS",
    });
    res.end();
    return;
  }

  if (url.pathname === "/") {
    sendText(res, 200, [
      "Pi Hub server running.",
      `Port: ${config.port}`,
      `LAN: ${localAddresses().map(ip => `http://${ip}:${config.port}`).join(", ") || "none"}`,
      "Use Flutter Pi Hub app with token from ~/.pi/agent/pi-hub/config.json.",
    ].join("\n"));
    return;
  }

  if (!isAuthorized(req, url)) {
    sendJson(res, 401, { error: "unauthorized" });
    return;
  }

  try {
    if (req.method === "GET" && url.pathname === "/api/health") {
      sendJson(res, 200, { ok: true, pid: process.pid, startedAt, host: config.host, port: Number(config.port), addresses: localAddresses() });
      return;
    }

    if (req.method === "GET" && url.pathname === "/api/snapshot") {
      sendJson(res, 200, snapshot());
      return;
    }

    if (req.method === "GET" && url.pathname === "/api/stream") {
      res.writeHead(200, {
        "content-type": "text/event-stream; charset=utf-8",
        "cache-control": "no-cache, no-transform",
        connection: "keep-alive",
        "access-control-allow-origin": "*",
      });
      res.write(`data: ${JSON.stringify({ seq: ++eventSeq, type: "snapshot", timestamp: Date.now(), snapshot: snapshot() })}\n\n`);
      const heartbeat = setInterval(() => {
        try { res.write(`: ping ${Date.now()}\n\n`); }
        catch { clearInterval(heartbeat); watchers.delete(res); }
      }, 15000);
      watchers.add(res);
      req.on("close", () => {
        clearInterval(heartbeat);
        watchers.delete(res);
      });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/register") {
      const body = await readBody(req);
      const info = body.session || body;
      if (!info?.id || typeof info.id !== "string") throw new Error("session.id required");
      const event = normalizeEvent({ ...info, type: "register" }, info.id, "register");
      const session = applyEvent(event);
      broadcast({ type: "session_updated", reason: "register", session: publicSession(session), event });
      sendJson(res, 200, { ok: true, session: publicSession(session) });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/unregister") {
      const body = await readBody(req);
      const sessionId = requireSessionId(body);
      const event = normalizeEvent({ ...body, type: "unregister" }, sessionId, "unregister");
      const session = applyEvent(event);
      broadcast({ type: "session_updated", reason: "unregister", session: publicSession(session), event });
      sendJson(res, 200, { ok: true });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/presence") {
      const body = await readBody(req);
      const sessionId = requireSessionId(body);
      const current = getOrCreateSession(sessionId);
      const event = normalizeEvent({
        ...body,
        type: "presence",
        cwd: body.cwd ?? current.cwd,
        model: body.model ?? current.model,
        status: body.status ?? current.status,
        availableModels: Array.isArray(body.availableModels) ? body.availableModels : current.availableModels,
      }, sessionId, "presence");
      const session = applyEvent(event);
      if (typeof body.name !== "undefined") session.name = body.name;
      if (typeof event.payload.cwd !== "undefined") session.cwd = event.payload.cwd;
      if (Array.isArray(event.payload.availableModels)) session.availableModels = event.payload.availableModels;
      broadcast({ type: "session_updated", reason: "presence", session: publicSession(session), event });
      sendJson(res, 200, { ok: true });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/event") {
      const body = await readBody(req);
      const sessionId = requireSessionId(body);
      const event = normalizeEvent(body.event, sessionId);
      const session = applyEvent(event);
      broadcast({ type: "session_updated", reason: event.legacyType || event.type || "event", session: publicSession(session), event });
      sendJson(res, 200, { ok: true });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/send") {
      const body = await readBody(req);
      const sessionId = requireSessionId(body);
      const text = String(body.text || "").trim();
      if (!text) throw new Error("text required");
      if (!sessions.has(sessionId)) {
        sendJson(res, 404, { error: "session not found" });
        return;
      }
      const command = {
        id: `cmd_${crypto.randomUUID()}`,
        type: "user_message",
        text,
        timestamp: Date.now(),
      };
      if (!commandQueues.has(sessionId)) commandQueues.set(sessionId, []);
      commandQueues.get(sessionId).push(command);
      const session = getOrCreateSession(sessionId);
      const event = normalizeEvent({ type: "command_queued", command: { id: command.id, type: command.type, timestamp: command.timestamp } }, sessionId, "command_queued");
      session.lastEvent = event;
      broadcast({ type: "command_queued", sessionId, command: { ...command, text: undefined } });
      sendJson(res, 200, { ok: true, commandId: command.id });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/control") {
      const body = await readBody(req);
      const sessionId = requireSessionId(body);
      const action = String(body.action || "").trim();
      const allowed = new Set(["abort", "compact", "set_model", "shutdown"]);
      if (!allowed.has(action)) throw new Error("unsupported control action");
      if (action === "set_model" && !body.modelId) throw new Error("modelId required for set_model");
      if (!sessions.has(sessionId)) {
        sendJson(res, 404, { error: "session not found" });
        return;
      }
      const command = {
        id: `cmd_${crypto.randomUUID()}`,
        type: action,
        modelId: typeof body.modelId === "string" ? body.modelId : undefined,
        timestamp: Date.now(),
      };
      if (!commandQueues.has(sessionId)) commandQueues.set(sessionId, []);
      commandQueues.get(sessionId).push(command);
      const session = getOrCreateSession(sessionId);
      const event = normalizeEvent({ type: "command_queued", command: { id: command.id, type: command.type, timestamp: command.timestamp } }, sessionId, "command_queued");
      session.lastEvent = event;
      broadcast({ type: "command_queued", sessionId, command: { id: command.id, type: command.type, timestamp: command.timestamp } });
      sendJson(res, 200, { ok: true, commandId: command.id });
      return;
    }

    if (req.method === "GET" && url.pathname === "/api/poll") {
      const sessionId = url.searchParams.get("sessionId") || "";
      if (!sessionId) throw new Error("sessionId required");
      const queue = commandQueues.get(sessionId) || [];
      commandQueues.set(sessionId, []);
      sendJson(res, 200, { ok: true, commands: queue });
      return;
    }

    sendJson(res, 404, { error: "not found" });
  } catch (error) {
    sendJson(res, 400, { error: error instanceof Error ? error.message : String(error) });
  }
});

server.on("error", error => {
  console.error("Pi Hub server error:", error);
  process.exitCode = 1;
});

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
process.on("exit", () => {
  try { fs.unlinkSync(PID_PATH); } catch {}
});

function shutdown() {
  for (const res of Array.from(watchers)) {
    try { res.end(); } catch {}
  }
  watchers.clear();
  try { fs.unlinkSync(PID_PATH); } catch {}
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 1000).unref();
}

server.listen(Number(config.port), config.host, () => {
  fs.mkdirSync(HUB_DIR, { recursive: true });
  fs.writeFileSync(PID_PATH, String(process.pid));
  console.log(`Pi Hub server listening on ${config.host}:${config.port}`);
  const addresses = localAddresses().map(ip => `http://${ip}:${config.port}`).join(", ");
  if (addresses) console.log(`LAN URLs: ${addresses}`);
});
