#!/usr/bin/env node
import http from "node:http";
import https from "node:https";
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

const DEFAULT_CONFIG = {
  enabled: true,
  host: "0.0.0.0",
  port: 17878,
  token: "",
  historyLimit: 500,
  staleThresholdMs: 120_000,
  commandTimeoutMs: 300_000,
  commandHistoryLimit: 500,
  inboxLimit: 500,
  inboxDedupeWindowMs: 300_000,
  diffReviewLimit: 100,
  diffReviewMaxFiles: 20,
  diffReviewPatchMaxChars: 12_000,
  diffReviewTotalPatchMaxChars: 60_000,
  auditLimit: 500,
  pushDeviceLimit: 100,
  push: {
    enabled: false,
    provider: "ntfy",
    defaultScopes: ["critical", "approval", "diff_review", "command_failure", "stale", "offline"],
    ntfy: {
      serverUrl: "https://ntfy.sh",
      topic: "",
      token: "",
      priority: 4,
    },
  },
  agentCreation: {
    enabled: false,
    piCommand: "pi",
    workspaceRoots: [],
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
    enabled: source.enabled === true,
    piCommand: typeof source.piCommand === "string" && source.piCommand.trim()
      ? source.piCommand.trim()
      : DEFAULT_CONFIG.agentCreation.piCommand,
    workspaceRoots: Array.isArray(source.workspaceRoots)
      ? source.workspaceRoots.filter(root => typeof root === "string" && root.trim()).map(root => path.resolve(root))
      : [],
    defaultArgs: Array.isArray(source.defaultArgs)
      ? source.defaultArgs.filter(arg => typeof arg === "string")
      : [],
    testMode: source.testMode === true,
  };
}

function normalizeScopeList(value, fallback = []) {
  const source = Array.isArray(value) ? value : fallback;
  const out = [];
  for (const item of source) {
    if (typeof item !== "string") continue;
    const scope = item.trim().toLowerCase();
    if (scope && !out.includes(scope)) out.push(scope);
  }
  return out;
}

function normalizePushConfig(value = {}) {
  const source = isPlainObject(value) ? value : {};
  const provider = typeof source.provider === "string" && source.provider.trim()
    ? source.provider.trim().toLowerCase()
    : DEFAULT_CONFIG.push.provider;
  const ntfySource = isPlainObject(source.ntfy) ? source.ntfy : {};
  const defaultNtfy = DEFAULT_CONFIG.push.ntfy;
  return {
    enabled: source.enabled === true,
    provider,
    defaultScopes: normalizeScopeList(source.defaultScopes, DEFAULT_CONFIG.push.defaultScopes),
    ntfy: {
      serverUrl: typeof ntfySource.serverUrl === "string" && ntfySource.serverUrl.trim()
        ? ntfySource.serverUrl.trim().replace(/\/+$/, "")
        : defaultNtfy.serverUrl,
      topic: typeof ntfySource.topic === "string" ? ntfySource.topic.trim() : "",
      token: typeof ntfySource.token === "string" ? ntfySource.token.trim() : "",
      priority: Number.isFinite(Number(ntfySource.priority)) ? Number(ntfySource.priority) : defaultNtfy.priority,
    },
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
  if (!Number.isFinite(Number(config.inboxLimit))) config.inboxLimit = DEFAULT_CONFIG.inboxLimit;
  if (!Number.isFinite(Number(config.inboxDedupeWindowMs))) config.inboxDedupeWindowMs = DEFAULT_CONFIG.inboxDedupeWindowMs;
  if (!Number.isFinite(Number(config.diffReviewLimit))) config.diffReviewLimit = DEFAULT_CONFIG.diffReviewLimit;
  if (!Number.isFinite(Number(config.diffReviewMaxFiles))) config.diffReviewMaxFiles = DEFAULT_CONFIG.diffReviewMaxFiles;
  if (!Number.isFinite(Number(config.diffReviewPatchMaxChars))) config.diffReviewPatchMaxChars = DEFAULT_CONFIG.diffReviewPatchMaxChars;
  if (!Number.isFinite(Number(config.diffReviewTotalPatchMaxChars))) config.diffReviewTotalPatchMaxChars = DEFAULT_CONFIG.diffReviewTotalPatchMaxChars;
  if (!Number.isFinite(Number(config.auditLimit))) config.auditLimit = DEFAULT_CONFIG.auditLimit;
  if (!Number.isFinite(Number(config.pushDeviceLimit))) config.pushDeviceLimit = DEFAULT_CONFIG.pushDeviceLimit;
  config.agentCreation = normalizeAgentCreationConfig(config.agentCreation);
  config.push = normalizePushConfig(config.push);
  config.staleThresholdMs = Math.max(0, Number(config.staleThresholdMs));
  config.commandTimeoutMs = Math.max(1000, Number(config.commandTimeoutMs));
  config.commandHistoryLimit = Math.max(1, Number(config.commandHistoryLimit));
  config.inboxLimit = Math.max(1, Number(config.inboxLimit));
  config.inboxDedupeWindowMs = Math.max(1000, Number(config.inboxDedupeWindowMs));
  config.diffReviewLimit = Math.max(1, Number(config.diffReviewLimit));
  config.diffReviewMaxFiles = Math.max(1, Number(config.diffReviewMaxFiles));
  config.diffReviewPatchMaxChars = Math.max(256, Number(config.diffReviewPatchMaxChars));
  config.diffReviewTotalPatchMaxChars = Math.max(256, Number(config.diffReviewTotalPatchMaxChars));
  config.auditLimit = Math.max(1, Number(config.auditLimit));
  config.pushDeviceLimit = Math.max(1, Number(config.pushDeviceLimit));
  config.push.ntfy.priority = Math.max(1, Math.min(5, Number(config.push.ntfy.priority)));
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
  return config;
}

const config = ensureConfig();
const sessions = new Map();
const commandQueues = new Map();
const commands = new Map();
const inboxItems = new Map();
const inboxDedupe = new Map();
const approvals = new Map();
const diffReviews = new Map();
const pushDevices = new Map();
const auditEvents = [];
const watchers = new Set();
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
    lastEvent: session.lastEvent,
    health,
    commands: publicCommandsForSession(session.id),
    inboxItems: publicInboxItemsForSession(session.id),
  };
}

function publicCommandsForSession(sessionId) {
  return Array.from(commands.values())
    .filter(command => command.sessionId === sessionId)
    .sort((a, b) => Number(b.createdAt || 0) - Number(a.createdAt || 0))
    .map(publicCommand);
}

function publicInboxItemsForSession(sessionId) {
  return Array.from(inboxItems.values())
    .filter(item => item.sessionId === sessionId)
    .sort((a, b) => Number(b.updatedAt || b.createdAt || 0) - Number(a.updatedAt || a.createdAt || 0))
    .map(publicInboxItem);
}

function pushProviderStatus() {
  const provider = config.push.provider;
  const ntfyReady = provider === "ntfy" && Boolean(config.push.ntfy.serverUrl && config.push.ntfy.topic);
  return {
    enabled: config.push.enabled === true && ntfyReady,
    configured: ntfyReady,
    provider,
    defaultScopes: config.push.defaultScopes,
    ntfy: {
      configured: ntfyReady,
      serverUrl: config.push.ntfy.serverUrl,
      topicConfigured: Boolean(config.push.ntfy.topic),
      tokenConfigured: Boolean(config.push.ntfy.token),
    },
  };
}

function serverCapabilities() {
  return {
    schemaVersion: 2,
    eventEnvelope: true,
    health: true,
    inbox: true,
    commandLifecycle: true,
    approvals: true,
    diffReviews: true,
    agentCreation: config.agentCreation.enabled,
    collaboration: true,
    pushDevices: true,
    pushNotifications: pushProviderStatus(),
  };
}

function publicInboxItem(item) {
  return {
    id: item.id,
    sessionId: item.sessionId || null,
    type: item.type,
    severity: item.severity,
    title: item.title,
    body: item.body,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
    readAt: item.readAt || null,
    actionRef: item.actionRef || null,
  };
}

function publicInboxItems() {
  return Array.from(inboxItems.values())
    .sort((a, b) => Number(b.updatedAt || b.createdAt || 0) - Number(a.updatedAt || a.createdAt || 0))
    .map(publicInboxItem);
}

function pushScopeFromInboxType(type, severity) {
  if (severity === "critical") return "critical";
  if (type === "approval") return "approval";
  if (type === "diff_review") return "diff_review";
  if (type === "command_failure") return "command_failure";
  if (type === "stale") return "stale";
  if (type === "offline") return "offline";
  return "inbox";
}

function publicPushDevice(device) {
  return {
    deviceId: device.deviceId,
    platform: device.platform,
    provider: device.provider,
    enabled: device.enabled,
    scopes: Array.isArray(device.scopes) ? device.scopes : [],
    label: device.label || null,
    createdAt: device.createdAt,
    updatedAt: device.updatedAt,
    disabledAt: device.disabledAt || null,
    hasToken: Boolean(device.token),
  };
}

function publicPushDevices() {
  return Array.from(pushDevices.values())
    .sort((a, b) => Number(b.updatedAt || 0) - Number(a.updatedAt || 0))
    .map(publicPushDevice);
}

function normalizeDeviceId(value) {
  return typeof value === "string" ? value.trim().slice(0, 160) : "";
}

function normalizePushProvider(value) {
  const provider = typeof value === "string" && value.trim() ? value.trim().toLowerCase() : config.push.provider;
  return ["ntfy", "webhook", "fcm"].includes(provider) ? provider : config.push.provider;
}

function sanitizePushDeviceInput(input = {}) {
  const deviceId = normalizeDeviceId(input.deviceId || input.id);
  if (!deviceId) throw new Error("deviceId required");
  const provider = normalizePushProvider(input.provider);
  const existing = pushDevices.get(deviceId);
  const token = typeof input.token === "string" ? input.token.trim() : typeof input.topic === "string" ? input.topic.trim() : undefined;
  return {
    deviceId,
    platform: typeof input.platform === "string" && input.platform.trim() ? input.platform.trim().toLowerCase().slice(0, 40) : existing?.platform || "unknown",
    provider,
    token: token === undefined ? existing?.token || "" : token.slice(0, 4000),
    enabled: input.enabled === undefined ? existing?.enabled ?? true : input.enabled === true,
    scopes: normalizeScopeList(input.scopes, existing?.scopes || config.push.defaultScopes),
    label: typeof input.label === "string" ? input.label.trim().slice(0, 120) : existing?.label || "",
  };
}

function trimPushDevices() {
  if (pushDevices.size <= Number(config.pushDeviceLimit)) return;
  const oldest = Array.from(pushDevices.values()).sort((a, b) => Number(a.updatedAt || 0) - Number(b.updatedAt || 0));
  for (const device of oldest) {
    if (pushDevices.size <= Number(config.pushDeviceLimit)) break;
    if (!device.enabled) pushDevices.delete(device.deviceId);
  }
  for (const device of oldest) {
    if (pushDevices.size <= Number(config.pushDeviceLimit)) break;
    pushDevices.delete(device.deviceId);
  }
}

function upsertPushDevice(input = {}) {
  const next = sanitizePushDeviceInput(input);
  const now = Date.now();
  const existing = pushDevices.get(next.deviceId);
  const device = {
    ...existing,
    ...next,
    createdAt: existing?.createdAt || now,
    updatedAt: now,
    disabledAt: next.enabled ? null : now,
  };
  pushDevices.set(device.deviceId, device);
  trimPushDevices();
  broadcast({ type: "push.device.updated", pushDevice: publicPushDevice(device) });
  return device;
}

function isPushProviderReadyForDevice(device) {
  if (!config.push.enabled) return false;
  if (device.provider !== config.push.provider) return false;
  if (device.provider === "ntfy") return Boolean(config.push.ntfy.serverUrl && (device.token || config.push.ntfy.topic));
  return false;
}

function shouldSendPushForScope(device, scope) {
  if (!device.enabled) return false;
  if (!isPushProviderReadyForDevice(device)) return false;
  const scopes = Array.isArray(device.scopes) ? device.scopes : [];
  return scopes.includes(scope) || scopes.includes("all");
}

function dispatchPushForInboxItem(item) {
  if (!item || item.readAt) return;
  const scope = pushScopeFromInboxType(item.type, item.severity);
  for (const device of pushDevices.values()) {
    if (!shouldSendPushForScope(device, scope)) continue;
    void sendNtfyNotification(device, item, scope);
  }
}

function sendNtfyNotification(device, item, scope) {
  const base = config.push.ntfy.serverUrl;
  const topic = encodeURIComponent(device.token || config.push.ntfy.topic);
  let target;
  try {
    target = new URL(`${base}/${topic}`);
  } catch {
    return Promise.resolve(false);
  }
  const body = `${item.title}\n${item.body || ""}`.trim();
  const client = target.protocol === "http:" ? http : https;
  return new Promise(resolve => {
    const request = client.request(target, {
      method: "POST",
      headers: {
        "content-type": "text/plain; charset=utf-8",
        "title": item.title,
        "priority": String(config.push.ntfy.priority),
        "tags": scope,
        ...(config.push.ntfy.token ? { authorization: `Bearer ${config.push.ntfy.token}` } : {}),
      },
      timeout: 5000,
    }, response => {
      response.resume();
      response.on("end", () => {
        const ok = response.statusCode >= 200 && response.statusCode < 300;
        if (!ok) recordAudit("push.send.failed", `ntfy push failed with ${response.statusCode}`, { provider: "ntfy", deviceId: device.deviceId, statusCode: response.statusCode, inboxId: item.id });
        resolve(ok);
      });
    });
    request.on("timeout", () => request.destroy(new Error("ntfy push timed out")));
    request.on("error", error => {
      recordAudit("push.send.failed", `ntfy push failed: ${error.message}`, { provider: "ntfy", deviceId: device.deviceId, inboxId: item.id });
      resolve(false);
    });
    request.end(body);
  });
}

function disablePushDevice(deviceId) {
  const id = normalizeDeviceId(deviceId);
  if (!id) throw new Error("deviceId required");
  const existing = pushDevices.get(id);
  if (!existing) return undefined;
  existing.enabled = false;
  existing.disabledAt = Date.now();
  existing.updatedAt = existing.disabledAt;
  pushDevices.set(id, existing);
  broadcast({ type: "push.device.updated", pushDevice: publicPushDevice(existing) });
  return existing;
}

function publicAuditEvent(event) {
  return {
    id: event.id,
    type: event.type,
    timestamp: event.timestamp,
    actor: event.actor,
    summary: event.summary,
    details: event.details || {},
  };
}

function publicAuditEvents() {
  return auditEvents
    .slice()
    .sort((a, b) => Number(b.timestamp || 0) - Number(a.timestamp || 0))
    .map(publicAuditEvent);
}

function auditSummary() {
  const last = auditEvents.reduce((max, event) => Math.max(max, Number(event.timestamp || 0)), 0);
  return {
    totalCount: auditEvents.length,
    recentCount: auditEvents.length,
    lastEventAt: last || null,
  };
}

function recordAudit(type, summary, details = {}, actor = { kind: "server", id: "pi-hub" }) {
  const event = {
    id: `audit_${crypto.randomUUID()}`,
    type,
    timestamp: Date.now(),
    actor,
    summary,
    details,
  };
  auditEvents.push(event);
  while (auditEvents.length > Number(config.auditLimit)) auditEvents.shift();
  broadcast({ type: "audit.created", auditEvent: publicAuditEvent(event) });
  return event;
}

function snapshot() {
  expireCommands();
  refreshAttentionInboxItems();
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
      commandTimeoutMs: Number(config.commandTimeoutMs),
      inboxLimit: Number(config.inboxLimit),
      diffReviewLimit: Number(config.diffReviewLimit),
      diffReviewMaxFiles: Number(config.diffReviewMaxFiles),
      diffReviewPatchMaxChars: Number(config.diffReviewPatchMaxChars),
      diffReviewTotalPatchMaxChars: Number(config.diffReviewTotalPatchMaxChars),
      capabilities: serverCapabilities(),
    },
    sessions: Array.from(sessions.values())
      .sort((a, b) => String(a.cwd).localeCompare(String(b.cwd)) || String(a.name || a.id).localeCompare(String(b.name || b.id)))
      .map(publicSession),
    commands: publicCommands(),
    inboxItems: publicInboxItems(),
    approvals: publicApprovals(),
    diffReviews: publicDiffReviews(),
    pushDevices: publicPushDevices(),
    auditEvents: publicAuditEvents(),
    auditSummary: auditSummary(),
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

function publicApproval(approval) {
  return {
    id: approval.id,
    sessionId: approval.sessionId || null,
    title: approval.title,
    body: approval.body,
    risk: approval.risk,
    choices: Array.isArray(approval.choices) ? approval.choices : ["approve", "reject"],
    status: approval.status,
    createdAt: approval.createdAt,
    resolvedAt: approval.resolvedAt || null,
    responseComment: approval.responseComment || null,
  };
}

function publicApprovals() {
  return Array.from(approvals.values())
    .sort((a, b) => Number(b.createdAt || 0) - Number(a.createdAt || 0))
    .map(publicApproval);
}

function pendingApprovalCountForSession(sessionId) {
  let count = 0;
  for (const approval of approvals.values()) {
    if (approval.sessionId === sessionId && approval.status === "pending") count++;
  }
  return count;
}

function pendingCommandCountForSession(sessionId) {
  let count = 0;
  for (const command of commands.values()) {
    if (command.sessionId === sessionId && PENDING_COMMAND_STATUSES.has(command.status)) count++;
  }
  return count;
}

function trimInboxItems() {
  const limit = Number(config.inboxLimit);
  if (inboxItems.size <= limit) return;
  const oldest = Array.from(inboxItems.values()).sort((a, b) => Number(a.updatedAt || a.createdAt || 0) - Number(b.updatedAt || b.createdAt || 0));
  for (const item of oldest) {
    if (inboxItems.size <= limit) break;
    if (item.readAt) inboxItems.delete(item.id);
  }
  for (const item of oldest) {
    if (inboxItems.size <= limit) break;
    inboxItems.delete(item.id);
  }
}

function capTextWithFlag(value, max) {
  const text = typeof value === "string" ? value : value == null ? "" : String(value);
  const limit = Math.max(0, Number(max) || 0);
  if (text.length <= limit) return { text, truncated: false, originalLength: text.length };
  const marker = "\n...[truncated " + (text.length - limit) + " chars]";
  if (limit <= marker.length) return { text: marker.slice(0, limit), truncated: true, originalLength: text.length };
  return {
    text: `${text.slice(0, limit - marker.length)}${marker}`,
    truncated: true,
    originalLength: text.length,
  };
}

function sanitizeDiffPath(value) {
  let raw = typeof value === "string" ? value : value == null ? "" : String(value);
  raw = raw.split("\\").join("/").replace(/[\u0000-\u001f\u007f]/g, "").trim();
  raw = raw.replace(/^[a-zA-Z]:\/+/, "").replace(/^\/+/, "");
  const parts = [];
  for (const part of raw.split("/")) {
    if (!part || part === "." || part === "..") continue;
    parts.push(part.replace(/[<>:"|?*]/g, "_"));
  }
  const sanitized = parts.join("/").slice(0, 240);
  return sanitized || "unnamed-file";
}

function sanitizeDiffFile(input = {}, remainingChars = Number(config.diffReviewTotalPatchMaxChars)) {
  const sourcePatch = typeof input.patch === "string" ? input.patch : input.patch == null ? "" : String(input.patch);
  const patchCap = Math.max(0, Math.min(Number(config.diffReviewPatchMaxChars), remainingChars));
  const capped = capTextWithFlag(sourcePatch, patchCap);
  const originalLength = Number.isFinite(Number(input.originalLength)) ? Number(input.originalLength) : capped.originalLength;
  const truncated = Boolean(input.truncated || capped.truncated || originalLength > patchCap);
  const patchLength = Math.min(originalLength, patchCap);
  return {
    path: sanitizeDiffPath(input.path || input.file || input.filePath),
    status: String(input.status || "modified").slice(0, 40),
    additions: Math.max(0, Number(input.additions || 0) || 0),
    deletions: Math.max(0, Number(input.deletions || 0) || 0),
    patch: capped.text,
    truncated,
    originalLength,
    patchLength,
  };
}

function publicDiffFile(file) {
  const { patchLength, ...publicFile } = file;
  return publicFile;
}

function publicDiffReview(review) {
  return {
    id: review.id,
    sessionId: review.sessionId || null,
    title: review.title,
    status: review.status,
    files: review.files.map(publicDiffFile),
    createdAt: review.createdAt,
    updatedAt: review.updatedAt,
    resolvedAt: review.resolvedAt || null,
    responseComment: review.responseComment || null,
    responseAction: review.responseAction || null,
    truncated: Boolean(review.truncated),
  };
}

function publicDiffReviews() {
  return Array.from(diffReviews.values())
    .sort((a, b) => Number(b.updatedAt || b.createdAt || 0) - Number(a.updatedAt || a.createdAt || 0))
    .map(publicDiffReview);
}

function trimDiffReviews() {
  const limit = Number(config.diffReviewLimit);
  if (diffReviews.size <= limit) return;
  const oldest = Array.from(diffReviews.values()).sort((a, b) => Number(a.updatedAt || a.createdAt || 0) - Number(b.updatedAt || b.createdAt || 0));
  for (const review of oldest) {
    if (diffReviews.size <= limit) break;
    if (review.status !== "pending") diffReviews.delete(review.id);
  }
  for (const review of oldest) {
    if (diffReviews.size <= limit) break;
    diffReviews.delete(review.id);
  }
}

function upsertDiffReviewFromEvent(event) {
  const payload = event.payload || {};
  const input = payload.diffReview && typeof payload.diffReview === "object" ? payload.diffReview : payload;
  const id = String(input.id || payload.diffReviewId || `diff_${crypto.randomUUID()}`);
  const now = Date.now();
  let remaining = Number(config.diffReviewTotalPatchMaxChars);
  const rawFiles = Array.isArray(input.files) ? input.files : [];
  const files = [];
  let truncated = rawFiles.length > Number(config.diffReviewMaxFiles);
  for (const rawFile of rawFiles.slice(0, Number(config.diffReviewMaxFiles))) {
    const file = sanitizeDiffFile(rawFile && typeof rawFile === "object" ? rawFile : {}, remaining);
    remaining = Math.max(0, remaining - file.patchLength);
    truncated = truncated || file.truncated || remaining <= 0;
    files.push(file);
  }
  const existing = diffReviews.get(id);
  const review = {
    id,
    sessionId: event.sessionId,
    title: String(input.title || "Review proposed changes").slice(0, 200),
    status: String(input.status || existing?.status || "pending"),
    files,
    createdAt: Number(input.createdAt || existing?.createdAt || event.timestamp || now),
    updatedAt: Number(input.updatedAt || now),
    resolvedAt: existing?.resolvedAt || null,
    responseComment: existing?.responseComment || null,
    responseAction: existing?.responseAction || null,
    truncated,
  };
  diffReviews.set(id, review);
  trimDiffReviews();
  upsertInboxItem({
    sessionId: event.sessionId,
    type: "diff_review",
    severity: String(input.severity || "warning"),
    title: review.title,
    body: `${sessionLabel(event.sessionId)} has ${files.length} file${files.length === 1 ? "" : "s"} ready for review${truncated ? " (truncated)" : ""}.`,
    actionRef: { kind: "diff_review", id },
    dedupeKey: `${event.sessionId || "global"}:diff_review:${id}`,
  });
  broadcast({ type: "diff_review.updated", diffReview: publicDiffReview(review) });
  return review;
}

function respondToDiffReview(id, body = {}) {
  const review = diffReviews.get(String(id));
  if (!review) return undefined;
  const action = String(body.action || body.status || "").trim();
  const allowed = new Set(["approve", "approved", "request_changes", "changes_requested", "comment"]);
  if (!allowed.has(action)) throw new Error("unsupported diff review action");
  const status = action === "approve" || action === "approved" ? "approved" : action === "comment" ? "pending" : "changes_requested";
  if (review.status !== "pending") throw new Error("diff review already resolved");
  const now = Date.now();
  const comment = typeof body.comment === "string" ? capString(body.comment, 4000) : "";
  review.status = status;
  review.updatedAt = now;
  if (status !== "pending") review.resolvedAt = now;
  review.responseAction = action;
  review.responseComment = comment || null;
  const command = createCommand(review.sessionId, "diff_review_response", {
    diffReviewId: review.id,
    action,
    status,
    comment,
  });
  markInboxForAction("diff_review", review.id, status === "pending" ? undefined : now);
  broadcast({ type: "diff_review.updated", diffReview: publicDiffReview(review), command: publicCommand(command) });
  return { review, command };
}

function markInboxForAction(kind, id, readAt) {
  const now = Date.now();
  for (const item of inboxItems.values()) {
    if (item.actionRef?.kind !== kind || item.actionRef?.id !== id) continue;
    if (readAt !== undefined) item.readAt = readAt;
    item.updatedAt = now;
    broadcast({ type: "inbox.updated", inboxItem: publicInboxItem(item) });
  }
}

function inboxDedupeKey({ sessionId, type, actionRef, dedupeKey }) {
  if (dedupeKey) return String(dedupeKey);
  if (actionRef?.kind && actionRef?.id) return `${sessionId || "global"}:${type}:${actionRef.kind}:${actionRef.id}`;
  const bucket = Math.floor(Date.now() / Number(config.inboxDedupeWindowMs));
  return `${sessionId || "global"}:${type}:${bucket}`;
}

function upsertInboxItem(input = {}) {
  const now = Date.now();
  const type = String(input.type || "system");
  const key = inboxDedupeKey({ ...input, type });
  const existingId = inboxDedupe.get(key);
  const existing = existingId ? inboxItems.get(existingId) : undefined;
  const sessionId = typeof input.sessionId === "string" ? input.sessionId : undefined;
  const item = existing || {
    id: input.id || `inbox_${crypto.randomUUID()}`,
    sessionId,
    type,
    severity: String(input.severity || "info"),
    title: String(input.title || "Hub notification"),
    body: String(input.body || ""),
    createdAt: Number(input.createdAt || now),
    updatedAt: Number(input.updatedAt || now),
    readAt: input.readAt || null,
    actionRef: input.actionRef || null,
  };
  let changed = !existing;
  if (existing) {
    const nextSeverity = String(input.severity || item.severity || "info");
    const nextTitle = String(input.title || item.title || "Hub notification");
    const nextBody = String(input.body || item.body || "");
    const nextActionRef = input.actionRef || item.actionRef;
    const nextReadAt = input.readAt !== undefined ? input.readAt : item.readAt;
    changed = item.severity !== nextSeverity || item.title !== nextTitle || item.body !== nextBody || JSON.stringify(item.actionRef || null) !== JSON.stringify(nextActionRef || null) || item.readAt !== nextReadAt;
    item.severity = nextSeverity;
    item.title = nextTitle;
    item.body = nextBody;
    item.actionRef = nextActionRef || null;
    item.readAt = nextReadAt || null;
    if (changed) item.updatedAt = Number(input.updatedAt || now);
  }
  inboxItems.set(item.id, item);
  inboxDedupe.set(key, item.id);
  trimInboxItems();
  if (changed) {
    broadcast({ type: "inbox.updated", inboxItem: publicInboxItem(item) });
    dispatchPushForInboxItem(item);
  }
  return item;
}

function markInboxItemsRead(ids = []) {
  const now = Date.now();
  const updated = [];
  for (const id of ids) {
    const item = inboxItems.get(String(id));
    if (!item) continue;
    if (!item.readAt) item.readAt = now;
    item.updatedAt = now;
    updated.push(item);
    broadcast({ type: "inbox.updated", inboxItem: publicInboxItem(item) });
  }
  return updated;
}

function sessionLabel(sessionId) {
  const session = sessionId ? sessions.get(sessionId) : undefined;
  return session?.name || session?.cwd?.split(/[\\/]/).filter(Boolean).pop() || sessionId || "agent";
}

function createApprovalInboxItem(approval) {
  if (!approval) return undefined;
  return upsertInboxItem({
    sessionId: approval.sessionId,
    type: "approval",
    severity: approval.risk === "high" ? "critical" : "warning",
    title: approval.title || "Approval needed",
    body: approval.body || `${sessionLabel(approval.sessionId)} requested approval.`,
    actionRef: { kind: "approval", id: approval.id },
    dedupeKey: `${approval.sessionId || "global"}:approval:${approval.id}`,
  });
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

function createCollaborationInboxItem(message, sessionId) {
  return upsertInboxItem({
    sessionId,
    type: "collaboration",
    severity: message.severity,
    title: message.title,
    body: message.text,
    actionRef: { kind: "collaboration", id: message.id },
    dedupeKey: `${sessionId}:collaboration:${message.id}`,
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
  const inboxCreated = [];
  for (const sessionId of sessionIds) {
    const session = getOrCreateSession(sessionId);
    const historyItem = collaborationHistoryItem(message, sessionId);
    const idx = session.history.findIndex(existing => existing.id === historyItem.id);
    if (idx >= 0) session.history[idx] = historyItem;
    else session.history.push(historyItem);
    session.history = session.history.slice(-Number(config.historyLimit));
    const inboxItem = createCollaborationInboxItem(message, sessionId);
    inboxCreated.push(inboxItem);
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
  recordAudit("collaboration.message", `Collaboration message routed to ${sessionIds.length} session${sessionIds.length === 1 ? "" : "s"}`, { collaborationId: message.id, targetSessionIds: sessionIds });
  broadcast({
    type: "collaboration.message.created",
    collaborationMessage: message,
    commands: commandsCreated.map(publicCommand),
    inboxItems: inboxCreated.map(publicInboxItem),
  });
  return { message, commands: commandsCreated, inboxItems: inboxCreated };
}

function normalizeApprovalRecord(event) {
  const payload = event.payload || {};
  const source = payload.approval && typeof payload.approval === "object" ? payload.approval : payload;
  const now = Date.now();
  const id = String(source.id || payload.approvalId || event.id || `approval_${crypto.randomUUID()}`);
  const sessionId = typeof source.sessionId === "string" ? source.sessionId : event.sessionId;
  const choices = Array.isArray(source.choices) && source.choices.length
    ? source.choices.map(choice => String(choice)).filter(Boolean)
    : ["approve", "reject"];
  return {
    id,
    sessionId,
    title: String(source.title || "Approval needed"),
    body: String(source.body || source.summary || "Agent requested operator approval."),
    risk: String(source.risk || "medium"),
    choices: choices.length ? choices : ["approve", "reject"],
    status: String(source.status || "pending"),
    createdAt: Number(source.createdAt || event.timestamp || now),
    resolvedAt: source.resolvedAt ? Number(source.resolvedAt) : null,
    responseComment: typeof source.responseComment === "string" ? source.responseComment : null,
  };
}

function upsertApprovalFromEvent(event) {
  const next = normalizeApprovalRecord(event);
  if (!next.sessionId) return undefined;
  const existing = approvals.get(next.id);
  const approval = existing ? { ...existing, ...next, createdAt: existing.createdAt || next.createdAt } : next;
  approvals.set(approval.id, approval);
  if (approval.status === "pending") createApprovalInboxItem(approval);
  broadcast({ type: "approval.updated", sessionId: approval.sessionId, approval: publicApproval(approval) });
  return approval;
}

function commandDisplayType(command) {
  return String(command?.type || "command").replace(/_/g, " ");
}

function createToolErrorInbox(sessionId, tool = {}, error) {
  const label = sessionLabel(sessionId);
  const name = tool.name || "tool";
  const id = tool.id || `${name}:${Date.now()}`;
  return upsertInboxItem({
    sessionId,
    type: "tool_error",
    severity: "error",
    title: "Tool failed",
    body: `${name} failed for ${label}${error ? `: ${error}` : ""}`,
    actionRef: { kind: "session", id: sessionId },
    dedupeKey: `${sessionId}:tool_error:${id}`,
  });
}

function createHealthInboxForSession(session) {
  if (!session?.id) return;
  const health = deriveSessionHealth(session);
  const label = sessionLabel(session.id);
  if (health.state === "offline") {
    upsertInboxItem({
      sessionId: session.id,
      type: "offline",
      severity: "warning",
      title: "Agent offline",
      body: `${label} is offline.`,
      actionRef: { kind: "session", id: session.id },
      dedupeKey: `${session.id}:offline`,
    });
  } else if (health.state === "stale") {
    upsertInboxItem({
      sessionId: session.id,
      type: "stale",
      severity: "warning",
      title: "Agent stale",
      body: `${label} has missed heartbeat threshold.`,
      actionRef: { kind: "session", id: session.id },
      dedupeKey: `${session.id}:stale`,
    });
  }
}

function refreshAttentionInboxItems() {
  for (const session of sessions.values()) createHealthInboxForSession(session);
}

function processInboxForEvent(event, session) {
  const payload = event.payload || {};
  const type = event.type || "";
  if ((type === "session.tool_end" || event.legacyType === "tool_end") && payload.tool && (payload.tool.isError || payload.tool.status === "error")) {
    createToolErrorInbox(event.sessionId, payload.tool, payload.error || payload.tool.error);
  }
  if (type === "approval.requested" || type === "approval_requested") {
    upsertApprovalFromEvent(event);
  }
  if (type === "diff_review.requested" || type === "diff_review_requested") {
    const payload = event.payload || {};
    const record = payload.diffReview && typeof payload.diffReview === "object" ? payload.diffReview : payload;
    const id = String(record.id || payload.diffReviewId || "");
    if (!event.diffReview && id && !diffReviews.has(id)) upsertDiffReviewFromEvent(event);
  }
  createHealthInboxForSession(session);
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
  if (status === "failed" || status === "expired") createCommandFailureInbox(command, status);
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

function createCommandFailureInbox(command, reason = "failed") {
  if (!command || !command.sessionId) return undefined;
  const label = sessionLabel(command.sessionId);
  const actionRef = { kind: "command", id: command.id };
  return upsertInboxItem({
    sessionId: command.sessionId,
    type: "command_failure",
    severity: "error",
    title: reason === "expired" ? "Command expired" : "Command failed",
    body: `${commandDisplayType(command)} for ${label}: ${command.error || reason}`,
    actionRef,
    dedupeKey: `${command.sessionId}:command_failure:${command.id}`,
  });
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

function approvalResponseValue(body = {}) {
  return String(body.response || body.choice || body.decision || body.action || "").trim().toLowerCase();
}

function respondToApproval(approvalId, body = {}) {
  const approval = approvals.get(String(approvalId));
  if (!approval) return undefined;
  if (approval.status !== "pending") throw new Error("approval already resolved");
  const response = approvalResponseValue(body);
  if (response !== "approve" && response !== "reject") throw new Error("response must be approve or reject");
  if (Array.isArray(approval.choices) && approval.choices.length && !approval.choices.includes(response)) {
    throw new Error("response not allowed for approval");
  }
  const comment = typeof body.comment === "string" ? body.comment : typeof body.responseComment === "string" ? body.responseComment : "";
  const now = Date.now();
  approval.status = response === "approve" ? "approved" : "rejected";
  approval.resolvedAt = now;
  approval.responseComment = comment || null;
  approvals.set(approval.id, approval);
  const command = createCommand(approval.sessionId, "approval_response", {
    approvalId: approval.id,
    response,
    approved: response === "approve",
    comment,
    title: approval.title,
    risk: approval.risk,
  });
  upsertInboxItem({
    sessionId: approval.sessionId,
    type: "approval",
    severity: response === "approve" ? "info" : "warning",
    title: response === "approve" ? "Approval approved" : "Approval rejected",
    body: comment || approval.body,
    readAt: now,
    actionRef: { kind: "approval", id: approval.id },
    dedupeKey: `${approval.sessionId || "global"}:approval:${approval.id}`,
  });
  broadcast({ type: "approval.updated", sessionId: approval.sessionId, approval: publicApproval(approval), command: publicCommand(command) });
  return { approval, command };
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
  if (event.type === "diff_review.requested" || event.legacyType === "diff_review_requested") {
    const review = upsertDiffReviewFromEvent(event);
    event.diffReview = review;
    legacyEvent.diffReview = review;
  }
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
  if (event.type === "command.result" || event.legacyType === "command_received") {
    applyCommandResult(event);
  }
  session.lastEvent = event;
  processInboxForEvent(event, session);
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
  const pendingActionType = recentLastEvent ? session.lastEvent?.type : undefined;
  const hasPendingApproval = pendingApprovalCountForSession(session.id) > 0;
  const sessionDiffReviews = Array.from(diffReviews.values()).filter(review => review.sessionId === session.id);
  const hasPendingDiff = sessionDiffReviews.some(review => review.status === "pending") || (!sessionDiffReviews.length && (pendingActionType === "diff_review.requested" || pendingActionType === "diff_review_requested"));

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

function pathInside(root, child) {
  const relative = path.relative(root, child);
  return !relative || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function allowedWorkspaceRoot(cwd) {
  for (const root of config.agentCreation.workspaceRoots) {
    try {
      const stats = fs.statSync(root);
      if (!stats.isDirectory()) continue;
      const realRoot = fs.realpathSync(root);
      if (pathInside(realRoot, cwd)) return realRoot;
    } catch {}
  }
  return undefined;
}

function validateAgentCreationRequest(body = {}) {
  const cwd = resolveWorkspace(body.cwd ?? body.workspace);
  if (!config.agentCreation.workspaceRoots.length) throw new Error("workspace root allowlist is empty");
  const workspaceRoot = allowedWorkspaceRoot(cwd);
  if (!workspaceRoot) throw new Error("cwd outside configured workspace roots");
  return {
    cwd,
    workspaceRoot,
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
    workspaceRoot: request.workspaceRoot,
    name: request.name || null,
    model: request.model || null,
    hasInitialPrompt: Boolean(request.initialPrompt),
    ...extra,
  };
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
  const args = [...config.agentCreation.defaultArgs];
  const child = spawn(config.agentCreation.piCommand, args, {
    cwd: request.cwd,
    env,
    shell: false,
    windowsHide: true,
    detached: !config.agentCreation.testMode,
    stdio: config.agentCreation.testMode ? ["ignore", "pipe", "pipe"] : "ignore",
  });
  creation.pid = child.pid || null;
  creation.status = config.agentCreation.testMode ? "running" : "spawned";
  recordAudit("agent.create.spawned", `Agent creation spawned in ${request.cwd}`, agentCreationDetails(request, { creationId: creation.id, pid: creation.pid, testMode: creation.testMode }));
  broadcastAgentCreation(creation);

  if (!config.agentCreation.testMode) {
    child.once("error", error => {
      creation.status = "failed";
      creation.error = error.message;
      creation.finishedAt = Date.now();
      recordAudit("agent.create.failed", `Agent creation failed in ${request.cwd}: ${error.message}`, agentCreationDetails(request, { creationId: creation.id, error: error.message }));
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
      recordAudit(status === "succeeded" ? "agent.create.succeeded" : "agent.create.failed", `Agent creation ${status} in ${request.cwd}`, details);
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
      const session = sessions.get(sessionId);
      const publicBefore = session ? publicSession(session) : undefined;
      sessions.delete(sessionId);
      commandQueues.delete(sessionId);
      broadcast({ type: "session_removed", reason: "unregister", sessionId, session: publicBefore });
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

    if (req.method === "POST" && url.pathname === "/api/v2/inbox/read") {
      const body = await readBody(req);
      const ids = Array.isArray(body.ids) ? body.ids : body.id ? [body.id] : [];
      if (!ids.length) throw new Error("ids required");
      const updated = markInboxItemsRead(ids);
      sendJson(res, 200, { ok: true, inboxItems: updated.map(publicInboxItem) });
      return;
    }

    if (req.method === "GET" && url.pathname === "/api/v2/push/devices") {
      sendJson(res, 200, { ok: true, pushDevices: publicPushDevices(), provider: pushProviderStatus() });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/v2/push/devices") {
      const body = await readBody(req);
      const action = String(body.action || "register").trim().toLowerCase();
      const device = action === "disable" ? disablePushDevice(body.deviceId || body.id) : upsertPushDevice(body);
      if (!device) {
        sendJson(res, 404, { ok: false, error: "push device not found" });
        return;
      }
      sendJson(res, 200, { ok: true, pushDevice: publicPushDevice(device), provider: pushProviderStatus() });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/v2/agents/create") {
      const body = await readBody(req);
      if (!config.agentCreation.enabled) {
        recordAudit("agent.create.rejected", "Agent creation rejected: disabled", { reason: "disabled", cwd: typeof body.cwd === "string" ? capString(body.cwd, 2000) : null });
        sendJson(res, 403, { ok: false, error: "agent creation disabled" });
        return;
      }
      let request;
      try {
        request = validateAgentCreationRequest(body);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        recordAudit("agent.create.rejected", `Agent creation rejected: ${message}`, { reason: message });
        sendJson(res, 400, { ok: false, error: message });
        return;
      }
      const result = await startAgentCreation(request);
      sendJson(res, 200, { ok: true, ...result });
      return;
    }

    const approvalRespondMatch = url.pathname.match(/^\/api\/v2\/approvals\/([^/]+)\/respond$/);
    if (req.method === "POST" && approvalRespondMatch) {
      const body = await readBody(req);
      const result = respondToApproval(decodeURIComponent(approvalRespondMatch[1]), body);
      if (!result) {
        sendJson(res, 404, { error: "approval not found" });
        return;
      }
      sendJson(res, 200, { ok: true, approval: publicApproval(result.approval), command: publicCommand(result.command), commandId: result.command.id });
      return;
    }

    const diffRespondMatch = url.pathname.match(/^\/api\/v2\/diff-reviews\/([^/]+)\/respond$/);
    if (req.method === "POST" && diffRespondMatch) {
      const body = await readBody(req);
      const result = respondToDiffReview(decodeURIComponent(diffRespondMatch[1]), body);
      if (!result) {
        sendJson(res, 404, { error: "diff review not found" });
        return;
      }
      sendJson(res, 200, { ok: true, diffReview: publicDiffReview(result.review), command: publicCommand(result.command) });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/v2/collaboration/messages") {
      const body = await readBody(req);
      const result = routeCollaborationMessage(body);
      sendJson(res, 200, {
        ok: true,
        collaborationMessage: result.message,
        commands: result.commands.map(publicCommand),
        inboxItems: result.inboxItems.map(publicInboxItem),
      });
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
      const command = createCommand(sessionId, "user_message", { text });
      const session = getOrCreateSession(sessionId);
      const event = normalizeEvent({ type: "command_queued", command: { id: command.id, type: command.type, timestamp: command.createdAt } }, sessionId, "command_queued");
      session.lastEvent = event;
      broadcast({ type: "command_queued", sessionId, command: { id: command.id, type: command.type, timestamp: command.createdAt } });
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
      const payload = typeof body.modelId === "string" ? { modelId: body.modelId } : {};
      const command = createCommand(sessionId, action, payload);
      const session = getOrCreateSession(sessionId);
      const event = normalizeEvent({ type: "command_queued", command: { id: command.id, type: command.type, timestamp: command.createdAt } }, sessionId, "command_queued");
      session.lastEvent = event;
      broadcast({ type: "command_queued", sessionId, command: { id: command.id, type: command.type, timestamp: command.createdAt } });
      sendJson(res, 200, { ok: true, commandId: command.id });
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
      sendJson(res, 200, { ok: true, commands: deliverable });
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
