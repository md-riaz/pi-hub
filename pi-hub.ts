import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { homedir, networkInterfaces } from "os";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { spawn, type ChildProcess } from "child_process";
import { randomUUID } from "crypto";

type HubItemKind = "user" | "assistant" | "tool" | "custom" | "system" | "bash";

interface PiHubConfig {
	enabled: boolean;
	host: string;
	port: number;
	token: string;
	historyLimit: number;
	autoStartServer: boolean;
	pollIntervalMs: number;
	agentCreation?: {
		enabled?: boolean;
		piCommand?: string;
		workspaceRoots?: string[];
		defaultArgs?: string[];
		testMode?: boolean;
	};
}

interface HubItem {
	id: string;
	kind: HubItemKind;
	role: string;
	timestamp: number;
	text: string;
	metadata?: Record<string, unknown>;
}

const HUB_PROTOCOL_VERSION = 2;
const HUB_CLIENT_VERSION = "0.1.0";
const HUB_CLIENT_NAME = "pi-hub-extension";

const DEFAULT_CONFIG: PiHubConfig = {
	enabled: true,
	host: "0.0.0.0",
	port: 17878,
	token: "",
	historyLimit: 500,
	autoStartServer: true,
	pollIntervalMs: 1500,
	agentCreation: {
		enabled: true,
		piCommand: "pi",
		workspaceRoots: [homedir()],
		defaultArgs: [],
		testMode: false,
	},
};

const __dirname = dirname(fileURLToPath(import.meta.url));

function agentDir(): string {
	return process.env.PI_HOME || join(homedir(), ".pi", "agent");
}

function hubDir(): string {
	return join(agentDir(), "pi-hub");
}

function configPath(): string {
	return join(hubDir(), "config.json");
}

function pidPath(): string {
	return join(hubDir(), "server.pid");
}

function loadConfig(): PiHubConfig {
	mkdirSync(hubDir(), { recursive: true });
	let config = { ...DEFAULT_CONFIG };
	try {
		config = { ...config, ...JSON.parse(readFileSync(configPath(), "utf8")) };
	} catch {}
	if (!config.token) {
		config.token = randomUUID().replace(/-/g, "") + randomUUID().replace(/-/g, "").slice(0, 16);
	}
	config.port = Number(config.port) || DEFAULT_CONFIG.port;
	config.historyLimit = Number(config.historyLimit) || DEFAULT_CONFIG.historyLimit;
	config.pollIntervalMs = Math.max(500, Number(config.pollIntervalMs) || DEFAULT_CONFIG.pollIntervalMs);
	writeFileSync(configPath(), JSON.stringify(config, null, 2));
	return config;
}

function serverBaseUrl(config: PiHubConfig): string {
	const host = config.host === "0.0.0.0" ? "127.0.0.1" : config.host;
	return `http://${host}:${config.port}`;
}

function getServerScript(): string {
	return join(__dirname, "pi-hub-server.mjs");
}

function isProcessRunning(pid: number): boolean {
	try {
		process.kill(pid, 0);
		return true;
	} catch {
		return false;
	}
}

function readPid(): number | null {
	try {
		const pid = Number(readFileSync(pidPath(), "utf8").trim());
		return Number.isFinite(pid) ? pid : null;
	} catch {
		return null;
	}
}

function getWindowsLauncherPath(): string {
	return join(hubDir(), "server-launch.vbs");
}

function quoteWindowsArg(value: string): string {
	return `"${value.replace(/"/g, '""')}"`;
}

function spawnServer(config: PiHubConfig): ChildProcess {
	mkdirSync(hubDir(), { recursive: true });
	const script = getServerScript();
	if (process.platform === "win32") {
		const commandLine = [quoteWindowsArg(process.execPath), quoteWindowsArg(script)].join(" ");
		const launcher = getWindowsLauncherPath();
		writeFileSync(
			launcher,
			[
				'Set WshShell = CreateObject("WScript.Shell")',
				`WshShell.Run "${commandLine.replace(/"/g, '""')}", 0, False`,
				'Set WshShell = Nothing',
				"",
			].join("\r\n"),
		);
		return spawn("wscript.exe", [launcher], {
			detached: true,
			stdio: "ignore",
			windowsHide: true,
			env: { ...process.env, PI_HOME: agentDir() },
		});
	}
	return spawn(process.execPath, [script], {
		detached: true,
		stdio: "ignore",
		windowsHide: true,
		env: { ...process.env, PI_HOME: agentDir() },
	});
}

async function waitForServer(config: PiHubConfig, timeoutMs = 5000): Promise<void> {
	const start = Date.now();
	while (Date.now() - start < timeoutMs) {
		try {
			const response = await fetch(`${serverBaseUrl(config)}/api/health?token=${encodeURIComponent(config.token)}`, {
				signal: AbortSignal.timeout(1000),
			});
			if (response.ok) return;
		} catch {}
		await new Promise((resolve) => setTimeout(resolve, 150));
	}
	throw new Error("Pi Hub server did not start within timeout");
}

async function ensureServer(config: PiHubConfig): Promise<void> {
	try {
		const response = await fetch(`${serverBaseUrl(config)}/api/health?token=${encodeURIComponent(config.token)}`, {
			signal: AbortSignal.timeout(1000),
		});
		if (response.ok) return;
	} catch {}

	const pid = readPid();
	if (pid && isProcessRunning(pid)) {
		await waitForServer(config, 3000);
		return;
	}

	if (!config.autoStartServer) {
		throw new Error("Pi Hub server is not running and autoStartServer=false");
	}

	const child = spawnServer(config);
	child.unref();
	await waitForServer(config, 7000);
}

async function post(config: PiHubConfig, path: string, body: unknown): Promise<void> {
	const response = await fetch(`${serverBaseUrl(config)}${path}`, {
		method: "POST",
		headers: {
			"content-type": "application/json",
			authorization: `Bearer ${config.token}`,
		},
		body: JSON.stringify(body),
		signal: AbortSignal.timeout(5000),
	});
	if (!response.ok) {
		throw new Error(`${response.status}: ${await response.text()}`);
	}
}

async function getJson(config: PiHubConfig, path: string): Promise<any> {
	const url = new URL(`${serverBaseUrl(config)}${path}`);
	url.searchParams.set("token", config.token);
	const response = await fetch(url, { signal: AbortSignal.timeout(5000) });
	if (!response.ok) throw new Error(`${response.status}: ${await response.text()}`);
	return response.json();
}

function safeJson(value: unknown): string {
	try {
		return JSON.stringify(value, null, 2);
	} catch {
		return String(value);
	}
}

function contentToText(content: unknown): string {
	if (typeof content === "string") return content;
	if (content === undefined || content === null) return "";
	if (!Array.isArray(content)) return safeJson(content);
	return content.map((part) => {
		if (typeof part === "string") return part;
		if (!part || typeof part !== "object") return String(part ?? "");
		const item = part as Record<string, unknown>;
		if (item.type === "text" && typeof item.text === "string") return item.text;
		if (item.type === "thinking" && typeof item.thinking === "string") return `[thinking]\n${item.thinking}`;
		if (item.type === "toolCall") return `[tool_call ${String(item.name || "tool")}] ${safeJson(item.arguments || {})}`;
		if (item.type === "toolResult") return contentToText(item.content ?? item.result ?? item.text);
		if (item.type === "image") return "[image]";
		if (typeof item.text === "string") return item.text;
		if (typeof item.content === "string" || Array.isArray(item.content)) return contentToText(item.content);
		return `[${String(item.type || "content")}] ${safeJson(item)}`;
	}).filter(Boolean).join("\n");
}

function messageToItem(entryOrMessage: any, fallbackId?: string): HubItem | null {
	const message = entryOrMessage?.message || entryOrMessage;
	if (!message || typeof message !== "object") return null;
	const id = entryOrMessage?.id || fallbackId || `${message.role || "message"}-${message.timestamp || Date.now()}-${Math.random().toString(36).slice(2)}`;
	const timestamp = Number(message.timestamp || (entryOrMessage?.timestamp ? Date.parse(entryOrMessage.timestamp) : Date.now())) || Date.now();
	const role = String(message.role || entryOrMessage?.type || "message");

	if (role === "user") {
		return { id, kind: "user", role, timestamp, text: contentToText(message.content), metadata: { rawContent: message.content } };
	}
	if (role === "assistant") {
		return {
			id,
			kind: "assistant",
			role,
			timestamp,
			text: contentToText(message.content),
			metadata: {
				provider: message.provider,
				model: message.model,
				stopReason: message.stopReason,
				usage: message.usage,
				errorMessage: message.errorMessage,
				rawContent: message.content,
			},
		};
	}
	if (role === "toolResult") {
		return {
			id,
			kind: "tool",
			role,
			timestamp,
			text: contentToText(message.content),
			metadata: {
				toolCallId: message.toolCallId,
				toolName: message.toolName,
				isError: message.isError,
				details: message.details,
			},
		};
	}
	if (role === "custom") {
		return {
			id,
			kind: "custom",
			role,
			timestamp,
			text: contentToText(message.content),
			metadata: { customType: message.customType, display: message.display, details: message.details },
		};
	}
	if (role === "bashExecution") {
		return {
			id,
			kind: "bash",
			role,
			timestamp,
			text: `$ ${message.command}\n${message.output || ""}`,
			metadata: { exitCode: message.exitCode, cancelled: message.cancelled, truncated: message.truncated, excludeFromContext: message.excludeFromContext },
		};
	}
	if (entryOrMessage?.type === "compaction" || entryOrMessage?.type === "branch_summary") {
		return { id, kind: "system", role: entryOrMessage.type, timestamp, text: String(entryOrMessage.summary || "") };
	}
	if (entryOrMessage?.type === "custom_message") {
		return {
			id,
			kind: "custom",
			role: "custom_message",
			timestamp,
			text: contentToText(entryOrMessage.content),
			metadata: { customType: entryOrMessage.customType, display: entryOrMessage.display, details: entryOrMessage.details },
		};
	}
	return {
		id,
		kind: "custom",
		role,
		timestamp,
		text: contentToText(message.content ?? entryOrMessage?.content ?? entryOrMessage),
		metadata: { rawEntry: entryOrMessage, rawMessage: message },
	};
}

function sessionHistory(ctx: ExtensionContext, limit: number): HubItem[] {
	try {
		return ctx.sessionManager.getEntries()
			.map((entry) => messageToItem(entry))
			.filter((item): item is HubItem => Boolean(item))
			.slice(-limit);
	} catch {
		return [];
	}
}

function availableModelSummaries(ctx: ExtensionContext): Array<{ id: string; name: string; provider?: string; input?: string[] }> {
	try {
		return ctx.modelRegistry.getAvailable().map((model: any) => ({
			id: String(model.id),
			name: String(model.name || model.id),
			provider: typeof model.provider === "string" ? model.provider : undefined,
			input: Array.isArray(model.input) ? model.input.map((item: unknown) => String(item)) : undefined,
		}));
	} catch {
		return [];
	}
}

function clientMetadata() {
	return {
		protocolVersion: HUB_PROTOCOL_VERSION,
		clientVersion: HUB_CLIENT_VERSION,
		clientName: HUB_CLIENT_NAME,
	};
}

function slashCommandSummaries(pi: ExtensionAPI): Array<{ name: string; description?: string }> {
	try {
		return pi.getCommands().map((command: any) => ({
			name: String(command.invocationName || command.name || ""),
			description: typeof command.description === "string" ? command.description : undefined,
		})).filter(command => command.name);
	} catch {
		return [];
	}
}

function currentSessionInfo(ctx: ExtensionContext, config: PiHubConfig, status: string, slashCommands: Array<{ name: string; description?: string }> = []) {
	return {
		id: ctx.sessionManager.getSessionId(),
		name: ctx.sessionManager.getSessionName(),
		cwd: ctx.cwd,
		model: ctx.model?.id || "unknown",
		pid: process.pid,
		startedAt: Date.now(),
		status,
		contextUsage: ctx.getContextUsage?.(),
		availableModels: availableModelSummaries(ctx),
		slashCommands,
		history: sessionHistory(ctx, config.historyLimit),
		...clientMetadata(),
	};
}

function assistantPartialToItem(message: any): HubItem | null {
	const item = messageToItem(message, `live-${Date.now()}`);
	if (!item) return null;
	return { ...item, id: "live-assistant", timestamp: Date.now() };
}

function getLocalAddresses(): string[] {
	const nets = networkInterfaces();
	const out: string[] = [];
	for (const net of Object.values(nets)) {
		for (const addr of net || []) {
			if (addr.family === "IPv4" && !addr.internal) out.push(addr.address);
		}
	}
	return out;
}

function firewallHint(config: PiHubConfig): string {
	const port = config.port;
	const platform = process.platform;

	let cmd: string;
	if (platform === "win32") {
		cmd = `netsh advfirewall firewall add rule name="Pi Hub TCP ${port}" dir=in action=allow protocol=TCP localport=${port}`;
	} else if (platform === "darwin") {
		cmd = `echo 'pass in proto tcp from any to any port ${port}' | sudo pfctl -f -`;
	} else {
		// Linux and others
		cmd = `sudo ufw allow ${port}/tcp`;
	}

	return [
		`Run this once to allow inbound TCP ${port}:`,
		cmd,
		"",
		"If this is a VPS/cloud host, also allow the same TCP port in the provider firewall/security group.",
	].join("\n");
}

function networkHint(config: PiHubConfig): string {
	const lanIPs = getLocalAddresses();
	const lanUrls = lanIPs.map((ip: string) => `http://${ip}:${config.port}`).join(", ") || "none detected";
	return [
		`Local server: http://127.0.0.1:${config.port}`,
		`Connect in app: ${lanUrls}`,
		`Token: ${config.token}`,
		"",
		firewallHint(config),
	].join("\n");
}

export default function piHubExtension(pi: ExtensionAPI) {
	const config = loadConfig();
	let ctxRef: ExtensionContext | null = null;
	let sessionId: string | null = null;
	let status = "idle";
	let startedAt = Date.now();
	let connectTimer: ReturnType<typeof setTimeout> | null = null;
	let presenceTimer: ReturnType<typeof setInterval> | null = null;
	let pollTimer: ReturnType<typeof setInterval> | null = null;
	const toolNames = new Map<string, string>();
	let serverOk = false;

	function liveCtx(): ExtensionContext | null {
		if (!ctxRef || !sessionId) return null;
		try {
			if (ctxRef.sessionManager.getSessionId() !== sessionId) return null;
			return ctxRef;
		} catch {
			return null;
		}
	}

	function setUiStatus(text: string | undefined) {
		const ctx = liveCtx();
		if (!ctx?.hasUI) return;
		try { ctx.ui.setStatus("pi-hub", text); } catch {}
	}

	function currentStatus(): string {
		const runningTool = toolNames.values().next().value;
		return runningTool ? `tool:${runningTool}` : status;
	}

	function notifyFallback(message: string, level: "info" | "warning" | "error" = "info"): void {
		const ctx = liveCtx();
		try {
			if (ctx?.hasUI) ctx.ui.notify(message, level);
		} catch {}
	}

	async function sendEvent(event: Record<string, unknown>): Promise<void> {
		if (!config.enabled || !sessionId || !serverOk) return;
		try {
			await post(config, "/api/event", { sessionId, event });
		} catch {
			serverOk = false;
			setUiStatus("Hub ✗");
		}
	}

	async function sendCommandResult(command: any, applied: boolean, error?: unknown): Promise<void> {
		const commandId = command?.id;
		const type = String(command?.type || "unknown");
		const errorMessage = error instanceof Error ? error.message : (typeof error === "string" ? error : applied ? undefined : "Command was not applied");
		const payload: Record<string, unknown> = {
			type: "command_received",
			command: {
				id: commandId,
				type,
				timestamp: command?.timestamp,
				modelId: command?.modelId,
				applied,
			},
			commandId,
			commandType: type,
			applied,
		};
		if (errorMessage) {
			(payload.command as Record<string, unknown>).error = errorMessage;
			payload.error = errorMessage;
		}
		await sendEvent(payload);
	}

	async function handleCollaborationMessage(command: any): Promise<void> {
		const text = typeof command?.text === "string" ? command.text.trim() : "";
		if (!text) throw new Error("collaboration message text required");
		const collaborationId = String(command?.collaborationId || command?.id || "unknown");
		const title = typeof command?.title === "string" && command.title.trim() ? command.title.trim() : "Collaboration message";
		const origin = command?.origin && typeof command.origin === "object" ? command.origin : { kind: "operator", id: "mobile" };
		const ctx = liveCtx();
		const api = (ctx as any)?.collaboration || (pi as any).collaboration || (ctx as any)?.messageRouter || (pi as any).messageRouter;
		const injector = api?.injectMessage || api?.sendMessage || api?.notify;
		let appliedToPiApi = false;
		let fallbackError: string | undefined;
		if (typeof injector === "function") {
			try {
				await Promise.resolve(injector.call(api, { collaborationId, title, text, origin }));
				appliedToPiApi = true;
			} catch (error) {
				fallbackError = error instanceof Error ? error.message : String(error);
			}
		}
		if (!appliedToPiApi) {
			notifyFallback([title, text, fallbackError ? `Pi collaboration API unavailable: ${fallbackError}` : ""].filter(Boolean).join("\n"), "info");
		}
		await sendEvent({
			type: "collaboration_message",
			collaborationId,
			title,
			text,
			origin,
			appliedToPiApi,
			error: fallbackError,
		});
	}

	async function sendPresence(): Promise<void> {
		const ctx = liveCtx();
		if (!ctx || !serverOk) return;
		try {
			await post(config, "/api/presence", {
				sessionId: ctx.sessionManager.getSessionId(),
				name: ctx.sessionManager.getSessionName(),
				cwd: ctx.cwd,
				model: ctx.model?.id || "unknown",
				status: currentStatus(),
				contextUsage: ctx.getContextUsage?.(),
				availableModels: availableModelSummaries(ctx),
				slashCommands: slashCommandSummaries(pi),
				...clientMetadata(),
			});
		} catch {
			serverOk = false;
			setUiStatus("Hub ✗");
		}
	}

	async function register(ctx: ExtensionContext): Promise<void> {
		if (!config.enabled) return;
		try {
			await ensureServer(config);
			serverOk = true;
			await post(config, "/api/register", { session: { ...currentSessionInfo(ctx, config, currentStatus(), slashCommandSummaries(pi)), startedAt }, ...clientMetadata() });
			setUiStatus("Hub ✓");
			void pollCommands();
		} catch (error) {
			serverOk = false;
			setUiStatus("Hub ✗");
			if (ctx.hasUI) {
				ctx.ui.notify(`Pi Hub unavailable: ${error instanceof Error ? error.message : String(error)}`, "warning");
			}
		}
	}

	function startBackgroundLoops(): void {
		if (presenceTimer) clearInterval(presenceTimer);
		if (pollTimer) clearInterval(pollTimer);
		presenceTimer = setInterval(() => void sendPresence(), 10_000);
		pollTimer = setInterval(() => void pollCommands(), config.pollIntervalMs);
		void sendPresence();
		void pollCommands();
	}

	async function pollCommands(): Promise<void> {
		const ctx = liveCtx();
		if (!ctx || !serverOk || !sessionId) return;
		try {
			const data = await getJson(config, `/api/poll?sessionId=${encodeURIComponent(sessionId)}`);
			const commands = Array.isArray(data?.commands) ? data.commands : [];
			for (const command of commands) {
				try {
					if (command?.type === "user_message") {
						if (typeof command.text !== "string" || !command.text.trim()) throw new Error("text required");
						const content = Array.isArray(command.attachments) && command.attachments.length > 0
							? command.attachments
							: command.text;
						await Promise.resolve(pi.sendUserMessage(content));
						await sendEvent({
							type: "input",
							item: {
								id: `command-input-${command.id}`,
								kind: "user",
								role: "user",
								timestamp: Date.now(),
								text: command.text,
								metadata: { source: "mobile", commandId: command.id },
							},
							source: "mobile",
							commandId: command.id,
						});
						await sendCommandResult(command, true);
						continue;
					}

					if (command?.type === "abort") {
						await Promise.resolve(ctx.abort());
						await sendCommandResult(command, true);
						continue;
					}

					if (command?.type === "compact") {
						await Promise.resolve(ctx.compact());
						await sendCommandResult(command, true);
						continue;
					}

					if (command?.type === "set_model") {
						if (typeof command.modelId !== "string" || !command.modelId) throw new Error("modelId required");
						const model = ctx.modelRegistry.getAvailable().find((candidate: any) => candidate.id === command.modelId);
						if (!model) throw new Error(`Model ${command.modelId} is not available`);
						await Promise.resolve(pi.setModel(model));
						await sendCommandResult(command, true);
						continue;
					}

					if (command?.type === "shutdown") {
						await sendCommandResult(command, true);
						ctx.shutdown();
						continue;
					}

					if (command?.type === "diff_review_response") {
						const action = String(command.action || command.status || "comment");
						const diffReviewId = String(command.diffReviewId || command.id || "unknown");
						if (ctx.hasUI) {
							const comment = typeof command.comment === "string" && command.comment.trim() ? `\n${command.comment.trim()}` : "";
							ctx.ui.notify(`Diff review ${diffReviewId}: ${action}${comment}`, action === "changes_requested" || action === "request_changes" ? "warning" : "info");
						}
						await sendEvent({ type: "diff_review_response", diffReviewId, action, status: command.status, comment: command.comment });
						await sendCommandResult(command, true);
						continue;
					}

					if (command?.type === "collaboration_message") {
						await handleCollaborationMessage(command);
						await sendCommandResult(command, true);
						continue;
					}
					throw new Error(`Unsupported command type: ${String(command?.type || "unknown")}`);
				} catch (error) {
					await sendCommandResult(command, false, error);
				}
			}
		} catch {
			serverOk = false;
			setUiStatus("Hub ✗");
		}
	}

	pi.on("session_start", (_event, ctx) => {
		if (!config.enabled) return;
		ctxRef = ctx;
		sessionId = ctx.sessionManager.getSessionId();
		startedAt = Date.now();
		status = "idle";
		toolNames.clear();
		if (connectTimer) clearTimeout(connectTimer);
		connectTimer = setTimeout(() => void register(ctx), 0);
		startBackgroundLoops();
	});

	pi.on("session_shutdown", async () => {
		if (connectTimer) clearTimeout(connectTimer);
		if (presenceTimer) clearInterval(presenceTimer);
		if (pollTimer) clearInterval(pollTimer);
		if (config.enabled && sessionId && serverOk) {
			try { await post(config, "/api/unregister", { sessionId }); } catch {}
		}
		ctxRef = null;
		sessionId = null;
		serverOk = false;
		toolNames.clear();
	});

	pi.on("input", (event) => {
		void sendEvent({
			type: "input",
			item: {
				id: `input-${Date.now()}`,
				kind: "user",
				role: "user",
				timestamp: Date.now(),
				text: event.text,
				metadata: { source: event.source },
			},
			source: event.source,
		});
	});

	pi.on("agent_start", () => {
		status = "thinking";
		void sendEvent({ type: "agent_start" });
	});

	pi.on("agent_end", () => {
		status = "idle";
		toolNames.clear();
		void sendEvent({ type: "agent_end" });
		void sendPresence();
	});

	pi.on("message_update", (event) => {
		const item = assistantPartialToItem((event as any).message);
		if (item) void sendEvent({ type: "message_update", item, streamEvent: (event as any).assistantMessageEvent?.type });
	});

	pi.on("message_end", (event) => {
		const item = messageToItem((event as any).message);
		if (item) void sendEvent({ type: "message_end", item });
	});

	pi.on("tool_execution_start", (event) => {
		toolNames.set(event.toolCallId, event.toolName);
		void sendEvent({
			type: "tool_start",
			tool: { id: event.toolCallId, name: event.toolName, args: event.args, startedAt: Date.now() },
		});
	});

	pi.on("tool_execution_update", (event) => {
		void sendEvent({
			type: "tool_update",
			tool: { id: event.toolCallId, name: event.toolName, args: event.args, partialResult: event.partialResult, updatedAt: Date.now() },
		});
	});

	pi.on("tool_execution_end", (event) => {
		toolNames.delete(event.toolCallId);
		void sendEvent({
			type: "tool_end",
			tool: { id: event.toolCallId, name: event.toolName, result: event.result, isError: event.isError, endedAt: Date.now() },
		});
	});

	pi.on("model_select", (event) => {
		void sendEvent({ type: "model_select", model: (event as any).model?.id });
		void sendPresence();
	});

	pi.on("thinking_level_select", (event) => {
		void sendEvent({ type: "thinking_level_select", level: (event as any).level });
	});

	async function disconnectSession(): Promise<void> {
		if (sessionId && serverOk) {
			try { await post(config, "/api/unregister", { sessionId }); } catch {}
		}
		serverOk = false;
		setUiStatus("Hub ✗");
		if (presenceTimer) clearInterval(presenceTimer);
		if (pollTimer) clearInterval(pollTimer);
		presenceTimer = null;
		pollTimer = null;
	}

	pi.registerCommand("hub", {
		description: "Pi Hub: /hub [info|start|stop|server stop|firewall]",
		getArgumentCompletions(prefix: string) {
			return ["status", "info", "start", "stop", "server stop", "firewall"].filter((item) => item.startsWith(prefix)).map((value) => ({ value, label: value }));
		},
		async handler(args, ctx) {
			const sub = args.trim().toLowerCase();
			if (sub === "start") {
				try {
					await ensureServer(config);
					serverOk = true;
					startBackgroundLoops();
					await register(ctx);
					ctx.ui.notify(`Pi Hub started.\n\n${networkHint(config)}`, "info");
				} catch (error) {
					ctx.ui.notify(`Pi Hub start failed: ${error instanceof Error ? error.message : String(error)}`, "error");
				}
				return;
			}
			if (sub === "stop") {
				if (!serverOk) {
					ctx.ui.notify("This session is not connected to Pi Hub.", "warning");
					return;
				}
				await disconnectSession();
				ctx.ui.notify("Disconnected this session from Pi Hub. Server still running for other sessions.\nUse /hub start to reconnect, or /hub server stop to kill the server.", "info");
				return;
			}
			if (sub === "server stop") {
				const pid = readPid();
				if (pid && isProcessRunning(pid)) {
					await disconnectSession();
					try {
						process.kill(pid);
						ctx.ui.notify(`Pi Hub server killed (PID ${pid}). All sessions disconnected.`, "info");
					} catch (error) {
						ctx.ui.notify(`Failed to kill server (PID ${pid}): ${error instanceof Error ? error.message : String(error)}`, "error");
					}
				} else {
					await disconnectSession();
					ctx.ui.notify("Pi Hub server is not running.", "warning");
				}
				return;
			}
			if (sub === "firewall") {
				ctx.ui.notify(firewallHint(config), "info");
				return;
			}
			if (sub === "info" || sub === "status" || !sub) {
				const pid = readPid();
				ctx.ui.notify([
					"═══ Pi Hub ═══",
					`Status: ${serverOk ? "connected" : "not connected"}`,
					`PID: ${pid ?? "unknown"}`,
					`Config: ${configPath()}`,
					"",
					networkHint(config),
				].join("\n"), serverOk ? "info" : "warning");
				return;
			}
			ctx.ui.notify("Unknown /hub command. Use: /hub info, /hub start, /hub stop, /hub server stop, /hub firewall", "warning");
		},
	});
}
