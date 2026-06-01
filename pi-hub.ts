import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { homedir, networkInterfaces } from "os";
import { existsSync, mkdirSync, readFileSync, writeFileSync, unlinkSync } from "fs";
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
		piCommand?: string;
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

interface PendingMobileInput {
	commandId: string;
	text: string;
	createdAt: number;
	hasAttachments: boolean;
	attachmentMode?: string;
}

const HUB_PROTOCOL_VERSION = 2;
const HUB_CLIENT_VERSION = "0.1.4";
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
		piCommand: "pi",
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

function manualServerStopPath(): string {
	return join(hubDir(), "server.manual-stop");
}

function isServerManuallyStopped(): boolean {
	return existsSync(manualServerStopPath());
}

function markServerManuallyStopped(): void {
	mkdirSync(hubDir(), { recursive: true });
	writeFileSync(manualServerStopPath(), new Date().toISOString());
}

function clearServerManualStop(): void {
	try { unlinkSync(manualServerStopPath()); } catch {}
}

function loadConfig(): PiHubConfig {
	mkdirSync(hubDir(), { recursive: true });
	let config = { ...DEFAULT_CONFIG };
	try {
		config = { ...config, ...JSON.parse(readFileSync(configPath(), "utf8")) };
	} catch {}
	if (!config.autoStartServer) clearServerManualStop();
	if (!config.token) {
		config.token = randomUUID().replace(/-/g, "") + randomUUID().replace(/-/g, "").slice(0, 16);
	}
	config.port = Number(config.port) || DEFAULT_CONFIG.port;
	config.historyLimit = Number(config.historyLimit) || DEFAULT_CONFIG.historyLimit;
	config.pollIntervalMs = Math.max(500, Number(config.pollIntervalMs) || DEFAULT_CONFIG.pollIntervalMs);
	writeFileSync(configPath(), JSON.stringify(config, null, 2));
	return config;
}

function serverAutoStartAllowed(config: PiHubConfig): boolean {
	return config.autoStartServer && !isServerManuallyStopped();
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
	if (isServerManuallyStopped()) {
		throw new Error("Pi Hub server was manually stopped. Run /hub start to enable auto-start again.");
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

function normalizeEchoText(text: string): string {
	return text
		.replace(/\[Image:[^\]]+\]/gi, "")
		.replace(/\[image\]/gi, "")
		.replace(/\[Image attachment:[^\]]+\]\s*[^\n]*/gi, "")
		.replace(/\s+/g, " ")
		.trim()
		.toLowerCase();
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
		if (item.type === "thinking" && typeof item.thinking === "string") return `[thinking]
${item.thinking}`;
		if (item.type === "toolCall") return `[tool_call ${String(item.id || item.name || "tool")} ${String(item.name || "tool")}] ${safeJson(item.arguments || {})}`;
		if (item.type === "toolResult") return contentToText(item.content ?? item.result ?? item.text);
		if (item.type === "image") return "[image]";
		if (typeof item.text === "string") return item.text;
		if (typeof item.content === "string" || Array.isArray(item.content)) return contentToText(item.content);
		return `[${String(item.type || "content")}] ${safeJson(item)}`;
	}).filter(Boolean).join("
");
}

function contentPartSummaries(content: unknown): Record<string, unknown>[] {
	if (!Array.isArray(content)) return [];
	return content.map((part) => {
		if (!part || typeof part !== "object") return { type: typeof part, text: String(part ?? "") };
		const item = part as Record<string, unknown>;
		return {
			type: String(item.type || "content"),
			id: typeof item.id === "string" ? item.id : undefined,
			name: typeof item.name === "string" ? item.name : undefined,
			text: typeof item.text === "string" ? item.text : undefined,
			thinking: typeof item.thinking === "string" ? item.thinking : undefined,
			arguments: item.arguments,
			content: item.content,
		};
	});
}

function toolCallSummaries(content: unknown): Record<string, unknown>[] {
	return contentPartSummaries(content).filter((part) => part.type === "toolCall").map((part) => ({
		id: part.id,
		name: part.name || "tool",
		arguments: part.arguments,
	}));
}

function imagePartCount(content: unknown): number {
	return contentPartSummaries(content).filter((part) => part.type === "image").length;
}

function messageToItem(entryOrMessage: any, fallbackId?: string): HubItem | null {
	const message = entryOrMessage?.message || entryOrMessage;
	if (!message || typeof message !== "object") return null;
	const id = entryOrMessage?.id || fallbackId || `${message.role || "message"}-${message.timestamp || Date.now()}-${Math.random().toString(36).slice(2)}`;
	const timestamp = Number(message.timestamp || (entryOrMessage?.timestamp ? Date.parse(entryOrMessage.timestamp) : Date.now())) || Date.now();
	const role = String(message.role || entryOrMessage?.type || "message");

	if (role === "user") {
		return { id, kind: "user", role, timestamp, text: contentToText(message.content), metadata: { rawContent: message.content, contentParts: contentPartSummaries(message.content), imageCount: imagePartCount(message.content) } };
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
				contentParts: contentPartSummaries(message.content),
				toolCalls: toolCallSummaries(message.content),
				imageCount: imagePartCount(message.content),
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
				rawContent: message.content,
				contentParts: contentPartSummaries(message.content),
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

function slashCommandSummaries(pi: ExtensionAPI): Array<{ name: string; description?: string; argumentCompletions?: Array<{ value: string; label?: string }> }> {
	try {
		return pi.getCommands().map((command: any) => {
			let argumentCompletions: Array<{ value: string; label?: string }> = [];
			if (typeof command.getArgumentCompletions === "function") {
				try {
					const raw = command.getArgumentCompletions("");
					if (Array.isArray(raw)) {
						argumentCompletions = raw.map((item: any) => {
							if (typeof item === "string") return { value: item, label: item };
							return { value: String(item?.value || item?.label || ""), label: typeof item?.label === "string" ? item.label : undefined };
						}).filter((item) => item.value);
					}
				} catch {}
			}
			return {
				name: String(command.invocationName || command.name || ""),
				description: typeof command.description === "string" ? command.description : undefined,
				argumentCompletions,
			};
		}).filter(command => command.name);
	} catch {
		return [];
	}
}

function currentTodos(ctx: ExtensionContext): unknown[] {
	const sources = [
		(ctx as any).todos,
		(ctx as any).todoList,
		(ctx as any).tasks,
		(ctx as any).taskList,
		(ctx as any).session?.todos,
		(ctx as any).sessionManager?.getTodos?.(),
		(ctx as any).sessionManager?.getTasks?.(),
	];
	for (const source of sources) {
		try {
			const value = typeof source === "function" ? source.call(ctx) : source;
			if (Array.isArray(value)) return value;
		} catch {}
	}
	return [];
}

function currentSessionInfo(ctx: ExtensionContext, config: PiHubConfig, status: string, slashCommands: ReturnType<typeof slashCommandSummaries> = [], availableModels: ReturnType<typeof availableModelSummaries> = []) {
	return {
		id: ctx.sessionManager.getSessionId(),
		name: ctx.sessionManager.getSessionName(),
		cwd: ctx.cwd,
		model: ctx.model?.id || "unknown",
		pid: process.pid,
		startedAt: Date.now(),
		status,
		contextUsage: ctx.getContextUsage?.(),
		availableModels,
		slashCommands,
		todos: currentTodos(ctx),
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

function networkHint(config: PiHubConfig): string {
	const lanIPs = getLocalAddresses();
	const lanUrls = lanIPs.map((ip: string) => `http://${ip}:${config.port}`).join(", ") || "none detected";
	return [
		`Local server: http://127.0.0.1:${config.port}`,
		`Connect in app: ${lanUrls}`,
		`Token: ${config.token}`,
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
	let monitorTimer: ReturnType<typeof setInterval> | null = null;
	let presenceInFlight = false;
	let pollInFlight = false;
	let monitorInFlight = false;
	const toolNames = new Map<string, string>();
	const pendingMobileInputs: PendingMobileInput[] = [];
	let serverOk = false;
	let cachedSlashCommands: ReturnType<typeof slashCommandSummaries> | null = null;
	let cachedAvailableModels: ReturnType<typeof availableModelSummaries> | null = null;

	function sessionSlashCommands(): ReturnType<typeof slashCommandSummaries> {
		cachedSlashCommands ??= slashCommandSummaries(pi);
		return cachedSlashCommands;
	}

	function sessionAvailableModels(ctx: ExtensionContext): ReturnType<typeof availableModelSummaries> {
		cachedAvailableModels ??= availableModelSummaries(ctx);
		return cachedAvailableModels;
	}

	function rememberMobileInput(command: any): PendingMobileInput {
		const pending = {
			commandId: String(command.id),
			text: String(command.text || ""),
			createdAt: Date.now(),
			hasAttachments: Array.isArray(command.attachments) && command.attachments.some((part: any) => part?.type === "image"),
			attachmentMode: typeof command.attachmentMode === "string" ? command.attachmentMode : undefined,
		};
		pendingMobileInputs.push(pending);
		while (pendingMobileInputs.length > 25) pendingMobileInputs.shift();
		return pending;
	}

	function mobileEchoMetadata(text: string): Record<string, unknown> | undefined {
		const cutoff = Date.now() - 120_000;
		for (let i = pendingMobileInputs.length - 1; i >= 0; i--) {
			const pending = pendingMobileInputs[i];
			if (pending.createdAt < cutoff) {
				pendingMobileInputs.splice(i, 1);
				continue;
			}
			if (normalizeEchoText(text) !== normalizeEchoText(pending.text)) continue;
			return {
				source: "mobile",
				commandId: pending.commandId,
				commandType: "user_message",
				hasAttachments: pending.hasAttachments,
				attachmentMode: pending.attachmentMode,
			};
		}
		return undefined;
	}

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

	async function handleSlashCommand(command: any): Promise<void> {
	const text = typeof command?.text === "string" ? command.text.trim() : "";
	if (!text.startsWith("/")) throw new Error("slash command text required");
	const withoutSlash = text.slice(1).trim();
	const [name = "", ...restParts] = withoutSlash.split(/\s+/);
	if (!name) throw new Error("slash command name required");
	const args = restParts.join(" ");
	const ctx = liveCtx();
	if (!ctx) throw new Error("session not available");
	const slash = sessionSlashCommands().find((candidate) => candidate.name === name || candidate.name === `/${name}`);
	if (!slash) throw new Error(`Slash command /${name} is not available`);

	if (name === "hub") {
		const sub = args.trim().toLowerCase();
		if (sub === "start") {
			clearServerManualStop();
			await ensureServer(config);
			serverOk = true;
			startBackgroundLoops();
			await register(ctx);
			notifyFallback(`Pi Hub started.\n\n${networkHint(config)}`, "info");
		} else if (sub === "stop") {
			await disconnectSession();
			notifyFallback("Disconnected this session from Pi Hub. Server still running for other sessions.", "info");
		} else if (sub === "server stop") {
			markServerManuallyStopped();
			const pid = readPid();
			await disconnectSession();
			if (pid && isProcessRunning(pid)) process.kill(pid);
		} else if (sub === "info" || sub === "status" || !sub) {
			const pid = readPid();
			notifyFallback([
				"═══ Pi Hub ═══",
				`Status: ${serverOk ? "connected" : "not connected"}`,
				`PID: ${pid ?? "unknown"}`,
				`Config: ${configPath()}`,
				"",
				networkHint(config),
			].join("\n"), serverOk ? "info" : "warning");
		} else {
			throw new Error("Unknown /hub command. Use: /hub info, /hub start, /hub stop, /hub server stop");
		}
	} else if (name === "compact") {
		ctx.compact();
	} else {
		throw new Error(`Remote execution for /${name} is not supported yet. Use the Pi TUI for this slash command.`);
	}

	await sendEvent({
		type: "input",
		item: {
			id: `slash-input-${command.id || Date.now()}`,
			kind: "user",
			role: "user",
			timestamp: Date.now(),
			text,
			metadata: { source: "mobile", commandId: command.id, slash: true },
		},
		source: "mobile",
		commandId: command.id,
	});
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

	async function monitorServer(): Promise<void> {
		if (monitorInFlight || !config.enabled || serverOk || !serverAutoStartAllowed(config)) return;
		const ctx = liveCtx();
		if (!ctx) return;
		monitorInFlight = true;
		try {
			await ensureServer(config);
			serverOk = true;
			await register(ctx);
			setUiStatus("Hub ✓");
		} catch {
			serverOk = false;
			setUiStatus("Hub ✗");
		} finally {
			monitorInFlight = false;
		}
	}

	async function sendPresence(): Promise<void> {
		const ctx = liveCtx();
		if (presenceInFlight || !ctx || !serverOk) return;
		presenceInFlight = true;
		try {
			await post(config, "/api/presence", {
				sessionId: ctx.sessionManager.getSessionId(),
				name: ctx.sessionManager.getSessionName(),
				cwd: ctx.cwd,
				model: ctx.model?.id || "unknown",
				status: currentStatus(),
				contextUsage: ctx.getContextUsage?.(),
				availableModels: sessionAvailableModels(ctx),
				slashCommands: sessionSlashCommands(),
				todos: currentTodos(ctx),
				...clientMetadata(),
			});
		} catch {
			serverOk = false;
			setUiStatus("Hub ✗");
		} finally {
			presenceInFlight = false;
		}
	}

	async function register(ctx: ExtensionContext): Promise<void> {
		if (!config.enabled) return;
		try {
			await ensureServer(config);
			serverOk = true;
			await post(config, "/api/register", { session: { ...currentSessionInfo(ctx, config, currentStatus(), sessionSlashCommands(), sessionAvailableModels(ctx)), startedAt }, ...clientMetadata() });
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
		if (monitorTimer) clearInterval(monitorTimer);
		presenceTimer = setInterval(() => void sendPresence(), 10_000);
		pollTimer = setInterval(() => void pollCommands(), config.pollIntervalMs);
		monitorTimer = setInterval(() => void monitorServer(), 15_000);
		void monitorServer();
		void sendPresence();
		void pollCommands();
	}

	async function pollCommands(): Promise<void> {
		const ctx = liveCtx();
		if (pollInFlight || !ctx || !serverOk || !sessionId) return;
		pollInFlight = true;
		try {
			const data = await getJson(config, `/api/poll?sessionId=${encodeURIComponent(sessionId)}`);
			const commands = Array.isArray(data?.commands) ? data.commands : [];
			for (const command of commands) {
				try {
					if (command?.type === "slash_command") {
						await handleSlashCommand(command);
						await sendCommandResult(command, true);
						continue;
					}

					if (command?.type === "user_message") {
						if (typeof command.text !== "string" || !command.text.trim()) throw new Error("text required");
						rememberMobileInput(command);
						const content = Array.isArray(command.attachments) && command.attachments.length > 0
							? command.attachments
							: command.text;
						await Promise.resolve(pi.sendUserMessage(content, ctx.isIdle() ? undefined : { deliverAs: "followUp" }));
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
		} finally {
			pollInFlight = false;
		}
	}

	pi.on("session_start", (_event, ctx) => {
		if (!config.enabled) return;
		ctxRef = ctx;
		sessionId = ctx.sessionManager.getSessionId();
		startedAt = Date.now();
		status = "idle";
		toolNames.clear();
		cachedSlashCommands = null;
		cachedAvailableModels = null;
		if (connectTimer) clearTimeout(connectTimer);
		connectTimer = setTimeout(() => void register(ctx), 0);
		startBackgroundLoops();
	});

	pi.on("session_shutdown", async () => {
		if (connectTimer) clearTimeout(connectTimer);
		if (presenceTimer) clearInterval(presenceTimer);
		if (pollTimer) clearInterval(pollTimer);
		if (monitorTimer) clearInterval(monitorTimer);
		if (config.enabled && sessionId && serverOk) {
			try { await post(config, "/api/unregister", { sessionId }); } catch {}
		}
		ctxRef = null;
		sessionId = null;
		serverOk = false;
		toolNames.clear();
	});

	pi.on("input", (event) => {
		const echoMetadata = mobileEchoMetadata(event.text);
		void sendEvent({
			type: "input",
			item: {
				id: echoMetadata?.commandId ? `input-${echoMetadata.commandId}` : `input-${Date.now()}`,
				kind: "user",
				role: "user",
				timestamp: Date.now(),
				text: event.text,
				metadata: echoMetadata || { source: event.source },
			},
			source: echoMetadata ? "mobile" : event.source,
			commandId: echoMetadata?.commandId,
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
		if (item?.kind === "user") {
			const echoMetadata = mobileEchoMetadata(item.text);
			if (echoMetadata) {
				item.id = `user-${echoMetadata.commandId}`;
				item.metadata = { ...(item.metadata || {}), ...echoMetadata };
			}
		}
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
		if (monitorTimer) clearInterval(monitorTimer);
		presenceTimer = null;
		pollTimer = null;
		monitorTimer = null;
	}

	pi.registerCommand("hub", {
		description: "Pi Hub: /hub [info|start|stop|server stop]",
		getArgumentCompletions(prefix: string) {
			return ["status", "info", "start", "stop", "server stop"].filter((item) => item.startsWith(prefix)).map((value) => ({ value, label: value }));
		},
		async handler(args, ctx) {
			const sub = args.trim().toLowerCase();
			if (sub === "start") {
				try {
					clearServerManualStop();
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
				markServerManuallyStopped();
				const pid = readPid();
				if (pid && isProcessRunning(pid)) {
					await disconnectSession();
					try {
						process.kill(pid);
						ctx.ui.notify(`Pi Hub server killed (PID ${pid}). Auto-restart disabled until /hub start.`, "info");
					} catch (error) {
						ctx.ui.notify(`Failed to kill server (PID ${pid}): ${error instanceof Error ? error.message : String(error)}`, "error");
					}
				} else {
					await disconnectSession();
					ctx.ui.notify("Pi Hub server is not running. Auto-restart disabled until /hub start.", "warning");
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
			ctx.ui.notify("Unknown /hub command. Use: /hub info, /hub start, /hub stop, /hub server stop", "warning");
		},
	});
}
