import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { homedir } from "os";
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

function contentToText(content: unknown): string {
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";
	return content.map((part) => {
		if (!part || typeof part !== "object") return "";
		const item = part as Record<string, unknown>;
		if (item.type === "text" && typeof item.text === "string") return item.text;
		if (item.type === "thinking" && typeof item.thinking === "string") return `[thinking]\n${item.thinking}`;
		if (item.type === "toolCall") return `[tool_call ${String(item.name || "tool")}] ${JSON.stringify(item.arguments || {})}`;
		if (item.type === "image") return "[image]";
		return "";
	}).filter(Boolean).join("\n");
}

function messageToItem(entryOrMessage: any, fallbackId?: string): HubItem | null {
	const message = entryOrMessage?.message || entryOrMessage;
	if (!message || typeof message !== "object") return null;
	const id = entryOrMessage?.id || fallbackId || `${message.role || "message"}-${message.timestamp || Date.now()}-${Math.random().toString(36).slice(2)}`;
	const timestamp = Number(message.timestamp || (entryOrMessage?.timestamp ? Date.parse(entryOrMessage.timestamp) : Date.now())) || Date.now();
	const role = String(message.role || entryOrMessage?.type || "message");

	if (role === "user") {
		return { id, kind: "user", role, timestamp, text: contentToText(message.content) };
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
	return null;
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

function availableModelSummaries(ctx: ExtensionContext): Array<{ id: string; name: string; provider?: string }> {
	try {
		return ctx.modelRegistry.getAvailable().map((model: any) => ({
			id: String(model.id),
			name: String(model.name || model.id),
			provider: typeof model.provider === "string" ? model.provider : undefined,
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

function currentSessionInfo(ctx: ExtensionContext, config: PiHubConfig, status: string) {
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
		history: sessionHistory(ctx, config.historyLimit),
		...clientMetadata(),
	};
}

function assistantPartialToItem(message: any): HubItem | null {
	const item = messageToItem(message, `live-${Date.now()}`);
	if (!item) return null;
	return { ...item, id: "live-assistant", timestamp: Date.now() };
}

function networkHint(config: PiHubConfig): string {
	const local = serverBaseUrl(config);
	return `Pi Hub server: ${local}\nToken: ${config.token}\nAndroid emulator: http://10.0.2.2:${config.port}\nPhone on LAN: use Windows VM IP with port ${config.port}; allow firewall if needed.`;
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

	async function handleApprovalResponse(command: any): Promise<void> {
		const approvalId = command?.approvalId;
		const response = String(command?.response || "");
		const comment = typeof command?.comment === "string" ? command.comment : "";
		const fallback = async (error?: unknown) => {
			notifyFallback([
				`Approval ${approvalId || "request"}: ${response || "response received"}`,
				comment ? `Comment: ${comment}` : "",
				error instanceof Error ? `Pi approval API unavailable: ${error.message}` : "",
			].filter(Boolean).join("\n"), response === "reject" ? "warning" : "info");
			await sendEvent({
				type: "approval_response_fallback",
				approvalId,
				response,
				comment,
				appliedToPiApi: false,
				error: error instanceof Error ? error.message : undefined,
			});
		};
		const ctx = liveCtx();
		const api = (ctx as any)?.approvals || (pi as any).approvals || (ctx as any)?.approvalManager || (pi as any).approvalManager;
		const responder = api?.respond || api?.resolve || api?.submitResponse;
		if (typeof responder !== "function") {
			await fallback();
			return;
		}
		try {
			await Promise.resolve(responder.call(api, { approvalId, response, approved: response === "approve", comment }));
		} catch (error) {
			await fallback(error);
		}
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
			await post(config, "/api/register", { session: { ...currentSessionInfo(ctx, config, currentStatus()), startedAt }, ...clientMetadata() });
			setUiStatus("Hub ✓");
		} catch (error) {
			serverOk = false;
			setUiStatus("Hub ✗");
			if (ctx.hasUI) {
				ctx.ui.notify(`Pi Hub unavailable: ${error instanceof Error ? error.message : String(error)}`, "warning");
			}
		}
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
						await Promise.resolve(pi.sendUserMessage(command.text));
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

					if (command?.type === "approval_response") {
						await handleApprovalResponse(command);
						await sendCommandResult(command, true);
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
		presenceTimer = setInterval(() => void sendPresence(), 10_000);
		pollTimer = setInterval(() => void pollCommands(), config.pollIntervalMs);
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
			item: { id: `input-${Date.now()}`, kind: "user", role: "user", timestamp: Date.now(), text: event.text },
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

	pi.registerCommand("hub", {
		description: "Pi Hub dashboard bridge: /hub [status|info|start]",
		getArgumentCompletions(prefix: string) {
			return ["status", "info", "start"].filter((item) => item.startsWith(prefix)).map((value) => ({ value, label: value }));
		},
		async handler(args, ctx) {
			const sub = args.trim().toLowerCase();
			if (sub === "start") {
				try {
					await ensureServer(config);
					serverOk = true;
					await register(ctx);
					ctx.ui.notify(`Pi Hub started.\n\n${networkHint(config)}`, "info");
				} catch (error) {
					ctx.ui.notify(`Pi Hub start failed: ${error instanceof Error ? error.message : String(error)}`, "error");
				}
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
			ctx.ui.notify("Unknown /hub command. Use /hub, /hub info, or /hub start.", "warning");
		},
	});
}
