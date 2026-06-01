#!/usr/bin/env node
import http from "node:http";
import os from "node:os";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PI_HOME = process.env.PI_HOME || path.join(os.homedir(), ".pi", "agent");
const HUB_DIR = path.join(PI_HOME, "pi-hub");
const CONFIG_PATH = path.join(HUB_DIR, "config.json");
const PID_PATH = path.join(HUB_DIR, "server.pid");

const SERVER_VERSION = "2.0.36";

const DEFAULT_CONFIG = {
  enabled: true,
  host: "0.0.0.0",
  port: 17878,
  token: "",
  historyLimit: 500,
  staleThresholdMs: 120_000,
  commandTimeoutMs: 300_000,
  commandHistoryLimit: 500,
  corsOrigins: [],
  agentCreation: {
    piCommand: "pi",
    defaultArgs: [],
    testMode: false,
  },
};

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function normalizeAgentCreationConfig(value = {}) {
  const source = isPlainObject(value) ? value : {};
  return {
    piCommand: typeof source.piCommand === "string" && source.piCommand.trim()
      ? source.piCommand.trim()
      : DEFAULT_CONFIG.agentCreation.piCommand,
    defaultArgs: Array.isArray(source.defaultArgs)
      ? source.defaultArgs.filter(arg => typeof arg === "string")
      : [],
    testMode: source.testMode === true,
  };
}

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
  if (!Number.isFinite(Number(config.commandTimeoutMs))) config.commandTimeoutMs = DEFAULT_CONFIG.commandTimeoutMs;
  if (!Number.isFinite(Number(config.commandHistoryLimit))) config.commandHistoryLimit = DEFAULT_CONFIG.commandHistoryLimit;
  delete config.allowQueryToken;
  config.corsOrigins = Array.isArray(config.corsOrigins) ? config.corsOrigins.filter(origin => typeof origin === "string" && origin.trim()).map(origin => origin.trim()) : [];
  config.agentCreation = normalizeAgentCreationConfig(config.agentCreation);
  config.staleThresholdMs = Math.max(0, Number(config.staleThresholdMs));
  config.commandTimeoutMs = Math.max(1000, Number(config.commandTimeoutMs));
  config.commandHistoryLimit = Math.max(1, Number(config.commandHistoryLimit));
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
  return config;
}

const config = ensureConfig();
const sessions = new Map();
const commandQueues = new Map();
const commands = new Map();
const watchers = new Set();
const MAX_WATCHERS = 25;
const PENDING_COMMAND_STATUSES = new Set(["queued", "delivered"]);
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
    slashCommands: Array.isArray(session.slashCommands) ? session.slashCommands : [],
    todos: Array.isArray(session.todos) ? session.todos : [],
    lastEvent: session.lastEvent,
    health,
    commands: publicCommandsForSession(session.id),
  };
}

function publicCommandsForSession(sessionId) {
  return Array.from(commands.values())
    .filter(command => command.sessionId === sessionId)
    .sort((a, b) => Number(b.createdAt || 0) - Number(a.createdAt || 0))
    .map(publicCommand);
}


function serverCapabilities() {
  return {
    schemaVersion: 2,
    eventEnvelope: true,
    health: true,
    commandLifecycle: true,
    agentCreation: true,
    collaboration: true,
    browse: true,
    attachments: true,
  };
}

function removeSessionState(sessionId, reason = "removed") {
  const session = sessions.get(sessionId);
  const publicBefore = session ? publicSession(session) : undefined;
  sessions.delete(sessionId);
  commandQueues.delete(sessionId);
  for (const [id, command] of Array.from(commands.entries())) {
    if (command.sessionId === sessionId) commands.delete(id);
  }
  broadcast({ type: "session_removed", reason, sessionId, session: publicBefore });
  return publicBefore;
}

function isSessionVisible(session) {
  return Boolean(session && session.online !== false && session.status !== "offline");
}

function snapshot() {
  expireCommands();
  return {
    server: {
      pid: process.pid,
      startedAt,
      host: config.host,
      port: Number(config.port),
      time: nowIso(),
      version: SERVER_VERSION,
      schemaVersion: 2,
      staleThresholdMs: Number(config.staleThresholdMs),
      commandTimeoutMs: Number(config.commandTimeoutMs),
      capabilities: serverCapabilities(),
    },
    sessions: Array.from(sessions.values())
      .filter(isSessionVisible)
      .sort((a, b) => String(a.cwd).localeCompare(String(b.cwd)) || String(a.name || a.id).localeCompare(String(b.name || b.id)))
      .map(publicSession),
    commands: publicCommands(),
  };
}

function corsOrigin(req) {
  const origin = req.headers.origin;
  if (!origin) return undefined;
  return config.corsOrigins.includes(origin) ? origin : undefined;
}

function corsHeaders(req) {
  const origin = corsOrigin(req);
  if (!origin) return {};
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-headers": "content-type, authorization",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "vary": "origin",
  };
}

function sendJson(req, res, status, body) {
  const text = JSON.stringify(body);
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(text),
    ...corsHeaders(req),
  });
  res.end(text);
}

function sendText(req, res, status, text) {
  res.writeHead(status, {
    "content-type": "text/plain; charset=utf-8",
    "content-length": Buffer.byteLength(text),
    ...corsHeaders(req),
  });
  res.end(text);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", chunk => {
      body += chunk;
      if (body.length > 6_000_000) {
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

function getToken(req) {
  const auth = req.headers.authorization || "";
  if (auth.toLowerCase().startsWith("bearer ")) return auth.slice(7).trim();
  return "";
}

function isAuthorized(req, url) {
  return config.token && getToken(req) === config.token;
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

function commandQueuePayload(command) {
  return {
    id: command.id,
    type: command.type,
    timestamp: command.createdAt,
    ...command.payload,
  };
}

function publicCommand(command) {
  return {
    id: command.id,
    sessionId: command.sessionId,
    type: command.type,
    status: command.status,
    createdAt: command.createdAt,
    deliveredAt: command.deliveredAt || null,
    finishedAt: command.finishedAt || null,
    error: command.error || null,
    payload: command.payload || {},
  };
}

function publicCommands() {
  return Array.from(commands.values())
    .sort((a, b) => Number(b.createdAt || 0) - Number(a.createdAt || 0))
    .map(publicCommand);
}

function pendingCommandCountForSession(sessionId) {
  let count = 0;
  for (const command of commands.values()) {
    if (command.sessionId === sessionId && PENDING_COMMAND_STATUSES.has(command.status)) count++;
  }
  return count;
}

function targetSessionIds(body = {}) {
  const source = Array.isArray(body.sessionIds)
    ? body.sessionIds
    : Array.isArray(body.targetSessionIds)
      ? body.targetSessionIds
      : Array.isArray(body.targets)
        ? body.targets
        : body.sessionId
          ? [body.sessionId]
          : [];
  const ids = source.map(id => String(id || "").trim()).filter(Boolean);
  const unique = Array.from(new Set(ids));
  if (body.all === true) return Array.from(sessions.keys());
  return unique;
}

function collaborationMessageText(body = {}) {
  const text = String(body.text ?? body.message ?? body.body ?? "").trim();
  if (!text) throw new Error("message text required");
  return capString(text, 8000);
}

function collaborationTitle(text) {
  const firstLine = text.split(/\r?\n/).find(line => line.trim()) || text;
  return capString(firstLine, 120);
}

function collaborationHistoryItem(message, targetSessionId) {
  return sanitizeItem({
    id: `collab-${message.id}-${targetSessionId}`,
    kind: "custom",
    role: "collaboration",
    timestamp: message.createdAt,
    text: message.text,
    metadata: {
      collaborationId: message.id,
      origin: message.origin,
      targetSessionIds: message.targetSessionIds,
      deliveredTo: targetSessionId,
    },
  });
}

function routeCollaborationMessage(body = {}) {
  const text = collaborationMessageText(body);
  const sessionIds = targetSessionIds(body);
  if (!sessionIds.length) throw new Error("target sessionIds required");
  const missing = sessionIds.filter(id => !sessions.has(id));
  if (missing.length) throw new Error(`session not found: ${missing.join(", ")}`);
  const now = Date.now();
  const message = {
    id: `collab_${crypto.randomUUID()}`,
    text,
    title: String(body.title || `Collaboration: ${collaborationTitle(text)}`),
    severity: String(body.severity || "info"),
    origin: body.origin && typeof body.origin === "object" ? body.origin : { kind: "operator", id: "mobile" },
    targetSessionIds: sessionIds,
    createdAt: now,
  };
  const commandsCreated = [];
  for (const sessionId of sessionIds) {
    const session = getOrCreateSession(sessionId);
    const historyItem = collaborationHistoryItem(message, sessionId);
    const idx = session.history.findIndex(existing => existing.id === historyItem.id);
    if (idx >= 0) session.history[idx] = historyItem;
    else session.history.push(historyItem);
    session.history = session.history.slice(-Number(config.historyLimit));
    const command = createCommand(sessionId, "collaboration_message", {
      collaborationId: message.id,
      text: message.text,
      title: message.title,
      origin: message.origin,
      targetSessionIds: sessionIds,
    });
    commandsCreated.push(command);
    session.lastEvent = normalizeEvent({
      type: "collaboration_message",
      collaborationId: message.id,
      item: historyItem,
      text: message.text,
      title: message.title,
      origin: message.origin,
      targetSessionIds: sessionIds,
    }, sessionId, "collaboration_message");
    broadcast({ type: "session_updated", reason: "collaboration", session: publicSession(session), event: session.lastEvent });
  }
  broadcast({
    type: "collaboration.message.created",
    collaborationMessage: message,
    commands: commandsCreated.map(publicCommand),
  });
  return { message, commands: commandsCreated };
}

function broadcastCommandUpdate(command, reason) {
  const session = sessions.get(command.sessionId);
  broadcast({
    type: "command_updated",
    reason,
    sessionId: command.sessionId,
    command: publicCommand(command),
    session: session ? publicSession(session) : undefined,
  });
}

function trimCommands() {
  const limit = Number(config.commandHistoryLimit);
  if (commands.size <= limit) return;
  const oldest = Array.from(commands.values()).sort((a, b) => Number(a.createdAt || 0) - Number(b.createdAt || 0));
  for (const command of oldest) {
    if (commands.size <= limit) break;
    if (!PENDING_COMMAND_STATUSES.has(command.status)) commands.delete(command.id);
  }
  for (const command of oldest) {
    if (commands.size <= limit) break;
    commands.delete(command.id);
  }
}

function markCommandStatus(commandOrId, status, options = {}) {
  const command = typeof commandOrId === "string" ? commands.get(commandOrId) : commandOrId;
  if (!command) return undefined;
  const previous = command.status;
  const final = !PENDING_COMMAND_STATUSES.has(previous);
  if (final && previous !== status) return command;
  const now = Date.now();
  if (status === "delivered" && previous !== "queued") return command;
  if ((status === "applied" || status === "failed") && previous !== "queued" && previous !== "delivered") return command;
  command.status = status;
  if (status === "delivered") command.deliveredAt = command.deliveredAt || now;
  if (status === "applied" || status === "failed" || status === "expired") command.finishedAt = command.finishedAt || now;
  if (typeof options.error === "string" && options.error) command.error = options.error;
  commands.set(command.id, command);
  if (previous !== command.status || options.error) broadcastCommandUpdate(command, options.reason || status);
  trimCommands();
  return command;
}

function expireCommands() {
  const now = Date.now();
  for (const command of commands.values()) {
    if (PENDING_COMMAND_STATUSES.has(command.status) && now >= Number(command.expiresAt || 0)) {
      markCommandStatus(command, "expired", { error: "command expired", reason: "expired" });
    }
  }
}

function updateQueuedCommand(commandId, payload = {}) {
  const command = commands.get(commandId);
  if (!command) throw new Error("command not found");
  if (command.status !== "queued") throw new Error(`command is already ${command.status}`);
  command.payload = { ...command.payload, ...payload };
  commands.set(command.id, command);
  const queue = commandQueues.get(command.sessionId) || [];
  const queued = queue.find(item => item.id === command.id);
  if (queued) Object.assign(queued, commandQueuePayload(command));
  broadcastCommandUpdate(command, "updated");
  return command;
}

function cancelQueuedCommand(commandId) {
  const command = commands.get(commandId);
  if (!command) throw new Error("command not found");
  if (!PENDING_COMMAND_STATUSES.has(command.status)) return command;
  commandQueues.set(command.sessionId, (commandQueues.get(command.sessionId) || []).filter(item => item.id !== command.id));
  return markCommandStatus(command, "cancelled", { reason: "cancelled" }) || command;
}

function createCommand(sessionId, type, payload = {}) {
  if (!sessionId || typeof sessionId !== "string") throw new Error("sessionId required");
  expireCommands();
  const createdAt = Date.now();
  const command = {
    id: `cmd_${crypto.randomUUID()}`,
    sessionId,
    type,
    status: "queued",
    createdAt,
    deliveredAt: null,
    finishedAt: null,
    expiresAt: createdAt + Number(config.commandTimeoutMs),
    error: null,
    payload: { ...payload },
  };
  commands.set(command.id, command);
  if (!commandQueues.has(sessionId)) commandQueues.set(sessionId, []);
  commandQueues.get(sessionId).push(commandQueuePayload(command));
  trimCommands();
  broadcastCommandUpdate(command, "queued");
  return command;
}

function commandIdFromPayload(payload = {}) {
  return typeof payload.commandId === "string" && payload.commandId
    ? payload.commandId
    : typeof payload.command?.id === "string" && payload.command.id
      ? payload.command.id
      : undefined;
}

function applyCommandResult(event) {
  const payload = event.payload || {};
  const commandId = commandIdFromPayload(payload);
  if (!commandId) return undefined;
  const commandPayload = payload.command && typeof payload.command === "object" ? payload.command : {};
  const applied = typeof payload.applied === "boolean" ? payload.applied : commandPayload.applied !== false;
  const error = typeof payload.error === "string" ? payload.error : typeof commandPayload.error === "string" ? commandPayload.error : undefined;
  let command = commands.get(commandId);
  if (!command) {
    const createdAt = Number(commandPayload.timestamp || event.timestamp || Date.now());
    command = {
      id: commandId,
      sessionId: event.sessionId,
      type: String(payload.commandType || commandPayload.type || "unknown"),
      status: "delivered",
      createdAt,
      deliveredAt: createdAt,
      finishedAt: null,
      expiresAt: createdAt + Number(config.commandTimeoutMs),
      error: null,
      payload: { ...commandPayload },
    };
    delete command.payload.id;
    delete command.payload.type;
    delete command.payload.timestamp;
    delete command.payload.applied;
    delete command.payload.error;
    commands.set(command.id, command);
  }
  return markCommandStatus(command, applied ? "applied" : "failed", { error, reason: applied ? "applied" : "failed" });
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
      slashCommands: [],
      todos: [],
      lastEvent: undefined,
    };
    sessions.set(id, session);
  }
  if (!(session.tools instanceof Map)) session.tools = new Map(Object.entries(session.tools || {}));
  return session;
}

function upsertHistoryItem(session, rawItem) {
  const item = sanitizeItem(rawItem);
  const commandId = item?.metadata?.commandId;
  let idx = commandId ? session.history.findIndex(existing => existing?.metadata?.commandId === commandId) : -1;
  if (idx < 0) idx = session.history.findIndex(existing => existing.id === item.id);
  if (idx < 0 && item?.kind === "user" && item?.text) {
    idx = session.history.findIndex(existing => existing?.kind === "user" && existing?.text === item.text);
  }
  if (idx >= 0) session.history[idx] = { ...session.history[idx], ...item, metadata: { ...(session.history[idx].metadata || {}), ...(item.metadata || {}) } };
  else session.history.push(item);
  session.history = session.history.slice(-Number(config.historyLimit));
}

function recordOutgoingUserMessage(session, command, text, extraMetadata = {}) {
  const item = sanitizeItem({
    id: `mobile-${command.id}`,
    kind: "user",
    role: "user",
    timestamp: command.createdAt,
    text,
    metadata: {
      source: "mobile",
      commandId: command.id,
      commandType: command.type,
      ...extraMetadata,
    },
  });
  upsertHistoryItem(session, item);
  const event = normalizeEvent({ type: "input", item }, session.id, "input");
  session.lastEvent = event;
  broadcast({ type: "session_updated", reason: "input", session: publicSession(session), event });
  return item;
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
        upsertHistoryItem(session, event.item);
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
    case "input": {
      if (event.item) {
        upsertHistoryItem(session, event.item);
      }
      break;
    }
    case "command_received":
    case "model_select":
    case "thinking_level_select":
      break;
    default: {
      if (event.item) {
        upsertHistoryItem(session, event.item);
      }
      break;
    }
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
      slashCommands: Array.isArray(info.slashCommands) ? info.slashCommands : [],
      todos: Array.isArray(info.todos) ? info.todos : [],
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
  if (event.type === "command.result" || event.legacyType === "command_received") {
    applyCommandResult(event);
  }
  session.lastEvent = event;
  return session;
}

function deriveSessionHealth(session) {
  const lastSeen = Number(session.lastSeen || 0);
  const age = lastSeen ? Math.max(0, Date.now() - lastSeen) : undefined;
  const tools = Array.from(session.tools?.values?.() || []);
  const runningToolCount = tools.filter(tool => tool?.status === "running").length;
  const pendingCommandCount = pendingCommandCountForSession(session.id);
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

  if (explicitOffline) attentionReasons.push("offline");
  if (isStale) attentionReasons.push("stale");
  if (hasToolError) attentionReasons.push("tool_error");
  if (hasCommandFailure) attentionReasons.push("command_failure");
  else if (hasAgentError && !hasToolError) attentionReasons.push("agent_error");

  let state = "idle";
  if (!session.id) state = "unknown";
  else if (explicitOffline) state = "offline";
  else if (isStale) state = "stale";
  else if (session.status === "blocked") state = "blocked";
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

function creationText(value, field, max) {
  if (value === undefined || value === null) return "";
  const text = String(value).trim();
  if (text.length > max) throw new Error(`${field} too long`);
  return text;
}

function resolveWorkspace(cwd) {
  const raw = creationText(cwd, "cwd", 2000);
  if (!raw) throw new Error("cwd required");
  const resolved = path.resolve(raw);
  let stats;
  try { stats = fs.statSync(resolved); }
  catch { throw new Error("cwd must be an existing directory"); }
  if (!stats.isDirectory()) throw new Error("cwd must be an existing directory");
  return fs.realpathSync(resolved);
}

function validateAgentCreationRequest(body = {}) {
  const cwd = resolveWorkspace(body.cwd ?? body.workspace);
  return {
    cwd,
    name: creationText(body.name, "name", 120),
    model: creationText(body.model, "model", 160),
    initialPrompt: creationText(body.initialPrompt ?? body.prompt, "initialPrompt", 8000),
  };
}

function publicAgentCreationStatus(creation) {
  return {
    id: creation.id,
    status: creation.status,
    cwd: creation.cwd,
    name: creation.name || null,
    model: creation.model || null,
    pid: creation.pid || null,
    createdAt: creation.createdAt,
    finishedAt: creation.finishedAt || null,
    exitCode: creation.exitCode ?? null,
    error: creation.error || null,
    testMode: creation.testMode,
  };
}

function broadcastAgentCreation(creation) {
  broadcast({ type: "agent.creation.updated", creation: publicAgentCreationStatus(creation) });
}

function agentCreationDetails(request, extra = {}) {
  return {
    cwd: request.cwd,
    name: request.name || null,
    model: request.model || null,
    hasInitialPrompt: Boolean(request.initialPrompt),
    ...extra,
  };
}

function agentCreationArgs(request) {
  const args = [...config.agentCreation.defaultArgs];
  if (request.name) args.push("--name", request.name);
  if (request.model) args.push("--model", request.model);
  if (request.initialPrompt) args.push(request.initialPrompt);
  return args;
}

function startAgentCreation(request) {
  const createdAt = Date.now();
  const creation = {
    id: `agent_create_${crypto.randomUUID()}`,
    status: "spawning",
    cwd: request.cwd,
    name: request.name,
    model: request.model,
    pid: null,
    createdAt,
    finishedAt: null,
    exitCode: null,
    error: null,
    testMode: config.agentCreation.testMode,
  };
  const env = {
    ...process.env,
    PI_HUB_AGENT_CWD: request.cwd,
    PI_HUB_AGENT_NAME: request.name,
    PI_HUB_AGENT_MODEL: request.model,
    PI_HUB_INITIAL_PROMPT: request.initialPrompt,
  };
  const args = agentCreationArgs(request);
  const child = process.platform === "win32" && !config.agentCreation.testMode
    ? spawn("cmd.exe", ["/c", "start", "Pi Hub Agent", config.agentCreation.piCommand, ...args], {
        cwd: request.cwd,
        env,
        shell: false,
        windowsHide: false,
        detached: true,
        stdio: "ignore",
      })
    : spawn(config.agentCreation.piCommand, args, {
        cwd: request.cwd,
        env,
        shell: false,
        windowsHide: false,
        detached: !config.agentCreation.testMode,
        stdio: config.agentCreation.testMode ? ["ignore", "pipe", "pipe"] : "ignore",
      });
  creation.pid = child.pid || null;
  creation.status = config.agentCreation.testMode ? "running" : "spawned";
  broadcastAgentCreation(creation);

  if (!config.agentCreation.testMode) {
    child.once("error", error => {
      creation.status = "failed";
      creation.error = error.message;
      creation.finishedAt = Date.now();
      broadcastAgentCreation(creation);
    });
    child.unref();
    return { creation: publicAgentCreationStatus(creation), complete: false };
  }

  const waitForExit = new Promise(resolve => {
    let stdout = "";
    let stderr = "";
    let settled = false;
    const finish = (status, error, exitCode = null) => {
      if (settled) return;
      settled = true;
      creation.status = status;
      creation.error = error || null;
      creation.exitCode = exitCode;
      creation.finishedAt = Date.now();
      const details = agentCreationDetails(request, {
        creationId: creation.id,
        pid: creation.pid,
        exitCode,
        stdoutBytes: Buffer.byteLength(stdout),
        stderrBytes: Buffer.byteLength(stderr),
      });
      broadcastAgentCreation(creation);
      resolve({ creation: publicAgentCreationStatus(creation), complete: true });
    };
    child.stdout?.on("data", chunk => { stdout = capString(stdout + chunk.toString(), 4000); });
    child.stderr?.on("data", chunk => { stderr = capString(stderr + chunk.toString(), 4000); });
    child.once("error", error => finish("failed", error.message));
    child.once("close", code => finish(code === 0 ? "succeeded" : "failed", code === 0 ? null : `process exited ${code}`, code));
    setTimeout(() => finish("failed", "test mode timed out"), 5000).unref();
  });
  return waitForExit;
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
    const headers = corsHeaders(req);
    res.writeHead(Object.keys(headers).length ? 204 : 403, headers);
    res.end();
    return;
  }

  if (url.pathname === "/") {
    sendText(req, res, 200, [
      "Pi Hub server running.",
      `Port: ${config.port}`,
      `LAN: ${localAddresses().map(ip => `http://${ip}:${config.port}`).join(", ") || "none"}`,
      "Use Flutter Pi Hub app with token from ~/.pi/agent/pi-hub/config.json.",
    ].join("\n"));
    return;
  }

  if (!isAuthorized(req, url)) {
    sendJson(req, res, 401, { error: "unauthorized" });
    return;
  }

  try {
    if (req.method === "GET" && url.pathname === "/api/health") {
      sendJson(req, res, 200, {
        ok: true,
        pid: process.pid,
        startedAt,
        host: config.host,
        port: Number(config.port),
        addresses: localAddresses(),
        version: SERVER_VERSION,
        schemaVersion: 2,
        capabilities: serverCapabilities(),
      });
      return;
    }

    if (req.method === "GET" && url.pathname === "/api/snapshot") {
      sendJson(req, res, 200, snapshot());
      return;
    }

    if (req.method === "GET" && url.pathname === "/api/stream") {
      if (watchers.size >= MAX_WATCHERS) {
        const oldest = watchers.values().next().value;
        try { oldest.end(); } catch {}
        watchers.delete(oldest);
      }
      req.socket?.setNoDelay?.(true);
      res.writeHead(200, {
        "content-type": "text/event-stream; charset=utf-8",
        "cache-control": "no-cache, no-transform",
        connection: "keep-alive",
        ...corsHeaders(req),
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
      sendJson(req, res, 200, { ok: true, session: publicSession(session) });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/unregister") {
      const body = await readBody(req);
      const sessionId = requireSessionId(body);
      removeSessionState(sessionId, "unregister");
      sendJson(req, res, 200, { ok: true });
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
        slashCommands: Array.isArray(body.slashCommands) ? body.slashCommands : current.slashCommands,
        todos: Array.isArray(body.todos) ? body.todos : current.todos,
      }, sessionId, "presence");
      const session = applyEvent(event);
      if (typeof body.name !== "undefined") session.name = body.name;
      if (typeof event.payload.cwd !== "undefined") session.cwd = event.payload.cwd;
      if (Array.isArray(event.payload.availableModels)) session.availableModels = event.payload.availableModels;
      if (Array.isArray(event.payload.slashCommands)) session.slashCommands = event.payload.slashCommands;
      if (Array.isArray(event.payload.todos)) session.todos = event.payload.todos;
      broadcast({ type: "session_updated", reason: "presence", session: publicSession(session), event });
      sendJson(req, res, 200, { ok: true });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/event") {
      const body = await readBody(req);
      const sessionId = requireSessionId(body);
      const event = normalizeEvent(body.event, sessionId);
      const session = applyEvent(event);
      broadcast({ type: "session_updated", reason: event.legacyType || event.type || "event", session: publicSession(session), event });
      sendJson(req, res, 200, { ok: true });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/agents/create") {
      const body = await readBody(req);
      let request;
      try {
        request = validateAgentCreationRequest(body);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        sendJson(req, res, 400, { ok: false, error: message });
        return;
      }
      const result = await startAgentCreation(request);
      sendJson(req, res, 200, { ok: true, ...result });
      return;
    }

    if (req.method === "POST" && url.pathname.startsWith("/api/commands/")) {
      const parts = url.pathname.split("/").filter(Boolean);
      const commandId = decodeURIComponent(parts[2] || "");
      const action = parts[3] || "";
      if (!commandId) throw new Error("command id required");
      const body = await readBody(req);
      if (action === "cancel") {
        const command = cancelQueuedCommand(commandId);
        sendJson(req, res, 200, { ok: true, command: publicCommand(command) });
        return;
      }
      if (action === "update") {
        const command = updateQueuedCommand(commandId, { text: String(body.text || "").trim() });
        sendJson(req, res, 200, { ok: true, command: publicCommand(command) });
        return;
      }
      sendJson(req, res, 404, { error: "unknown command action" });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/collaboration/messages") {
      const body = await readBody(req);
      const result = routeCollaborationMessage(body);
      sendJson(req, res, 200, {
        ok: true,
        collaborationMessage: result.message,
        commands: result.commands.map(publicCommand),
      });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/send") {
      const body = await readBody(req);
      const sessionId = requireSessionId(body);
      const text = String(body.text || "").trim();
      if (!text) throw new Error("text required");
      if (!sessions.has(sessionId)) {
        sendJson(req, res, 404, { error: "session not found" });
        return;
      }
      const commandType = text.startsWith("/") ? "slash_command" : "user_message";
      const command = createCommand(sessionId, commandType, { text });
      const session = getOrCreateSession(sessionId);
      recordOutgoingUserMessage(session, command, text);
      sendJson(req, res, 200, { ok: true, commandId: command.id });
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
        sendJson(req, res, 404, { error: "session not found" });
        return;
      }
      const payload = typeof body.modelId === "string" ? { modelId: body.modelId } : {};
      const command = createCommand(sessionId, action, payload);
      const session = getOrCreateSession(sessionId);
      const event = normalizeEvent({ type: "command_queued", command: { id: command.id, type: command.type, timestamp: command.createdAt } }, sessionId, "command_queued");
      session.lastEvent = event;
      broadcast({ type: "command_queued", sessionId, command: publicCommand(command) });
      sendJson(req, res, 200, { ok: true, commandId: command.id });
      return;
    }

    if (req.method === "GET" && url.pathname === "/api/poll") {
      const sessionId = url.searchParams.get("sessionId") || "";
      if (!sessionId) throw new Error("sessionId required");
      expireCommands();
      const queue = commandQueues.get(sessionId) || [];
      const deliverable = [];
      for (const command of queue) {
        const status = commands.get(command.id);
        if (status && status.status === "queued") {
          markCommandStatus(status, "delivered", { reason: "delivered" });
          deliverable.push(commandQueuePayload(status));
        } else if (!status) {
          deliverable.push(command);
        }
      }
      commandQueues.set(sessionId, []);
      sendJson(req, res, 200, { ok: true, commands: deliverable });
      return;
    }

    if (req.method === "GET" && url.pathname === "/api/browse") {
      const rawPath = url.searchParams.get("path") || "";
      const dirPath = path.resolve(rawPath || os.homedir());
      try {
        const stat = fs.statSync(dirPath);
        if (!stat.isDirectory()) throw new Error("not a directory");
      } catch {
        sendJson(req, res, 400, { error: "invalid directory path" });
        return;
      }
      const limit = 500;
      const entries = fs.readdirSync(dirPath, { withFileTypes: true });
      const visibleEntries = entries.filter(e => !e.name.startsWith("."));
      const items = visibleEntries
        .sort((a, b) => {
          if (a.isDirectory() !== b.isDirectory()) return a.isDirectory() ? -1 : 1;
          return a.name.localeCompare(b.name);
        })
        .slice(0, limit)
        .map(e => ({
          name: e.name,
          path: path.join(dirPath, e.name),
          isDirectory: e.isDirectory(),
        }));
      sendJson(req, res, 200, { ok: true, path: dirPath, parent: path.dirname(dirPath), items, truncated: visibleEntries.length > limit, total: visibleEntries.length, limit });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/send-attachment") {
      const body = await readBody(req);
      const sessionId = requireSessionId(body);
      const text = String(body.text || "").trim();
      const attachments = Array.isArray(body.attachments) ? body.attachments : [];
      if (!text && attachments.length === 0) throw new Error("text or attachments required");
      if (!sessions.has(sessionId)) {
        sendJson(req, res, 404, { error: "session not found" });
        return;
      }
      if (attachments.length > 5) {
        sendJson(req, res, 400, { error: "maximum 5 attachments" });
        return;
      }
      const session = getOrCreateSession(sessionId);
      const matchingModels = Array.isArray(session.availableModels)
        ? session.availableModels.filter(model => model?.id === session.model || model?.name === session.model)
        : [];
      const modelSupportsImages = matchingModels.some(model => Array.isArray(model?.input) && model.input.includes("image"));
      const attachmentDir = path.join(os.tmpdir(), "pi-hub-attachments");
      fs.mkdirSync(attachmentDir, { recursive: true });
      const savedAttachments = [];
      const content = [];
      const textParts = [];
      if (text) textParts.push(text);
      for (const att of attachments) {
        const originalName = path.basename(String(att.name || "attachment"));
        const safeName = originalName.replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 120) || "attachment";
        const mimeType = String(att.mimeType || "application/octet-stream");
        const data = String(att.data || "");
        if (!data) continue;
        const bytes = Buffer.from(data, "base64");
        if (bytes.length > 5 * 1024 * 1024) {
          sendJson(req, res, 400, { error: `Attachment ${originalName} exceeds 5MB limit` });
          return;
        }
        const isImage = mimeType.startsWith("image/");
        const filePath = path.join(attachmentDir, `${Date.now()}-${crypto.randomUUID()}-${safeName}`);
        fs.writeFileSync(filePath, bytes);
        const saved = { name: originalName, mimeType, path: filePath, size: bytes.length };
        savedAttachments.push(saved);

        if (isImage && modelSupportsImages) {
          textParts.push(`See attached image: ${originalName}`);
          content.push({ type: "image", data, mimeType });
        } else if (isImage) {
          textParts.push(`See attached image: ${originalName}`);
          textParts.push(`[Image attachment: ${originalName}] ${filePath}`);
        } else {
          textParts.push(`See attached file: ${originalName}`);
          textParts.push(`[Attachment: ${originalName}] ${filePath}`);
        }

        if (!isImage && (mimeType.startsWith("text/") || ["application/json", "application/xml"].includes(mimeType))) {
          textParts.push(`[File contents: ${originalName}]\n${bytes.toString("utf-8")}`);
        }
      }
      const messageText = textParts.filter(Boolean).join("\n\n");
      if (messageText) content.unshift({ type: "text", text: messageText });
      const commandType = messageText.trim().startsWith("/") ? "slash_command" : "user_message";
      const command = createCommand(sessionId, commandType, {
        text: messageText,
        attachments: content,
        savedAttachments,
        attachmentMode: modelSupportsImages ? "inline-image" : "file-path",
      });
      recordOutgoingUserMessage(session, command, messageText, {
        hasAttachments: savedAttachments.length > 0,
        attachmentMode: modelSupportsImages ? "inline-image" : "file-path",
      });
      sendJson(req, res, 200, { ok: true, commandId: command.id, attachments: savedAttachments });
      return;
    }

    sendJson(req, res, 404, { error: "not found" });
  } catch (error) {
    sendJson(req, res, 400, { error: error instanceof Error ? error.message : String(error) });
  }
});

server.on("error", error => {
  console.error("Pi Hub server error:", error);
  process.exit(1);
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
