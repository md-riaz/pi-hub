import React, { useEffect, useMemo, useRef, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import {
  Bot,
  CheckCircle2,
  ChevronLeft,
  Code2,
  Command,
  Copy,
  ExternalLink,
  FileText,
  FileUp,
  Folder,
  FolderOpen,
  GitBranch,
  Home,
  Image,
  KeyRound,
  MoreHorizontal,
  Paperclip,
  Pause,
  Play,
  Plus,
  RefreshCcw,
  Search,
  Send,
  Server,
  Sparkles,
  Square,
  Terminal,
  Wifi,
  X,
  Zap,
} from "lucide-react";

const C = {
  bg: "#07090D",
  panel: "#0D1117",
  panel2: "#111827",
  card: "#151D29",
  line: "#263140",
  softLine: "#1B2635",
  text: "#E7EDF7",
  text2: "#AAB6C8",
  text3: "#68768B",
  blue: "#67A7FF",
  green: "#5EE19A",
  yellow: "#F8C471",
  red: "#FF7A7A",
  purple: "#B794F4",
  cyan: "#65D7E0",
  orange: "#F59E55",
};

const modelOptions = ["Sonnet 4", "Opus 4.5", "GPT-5", "Haiku 4"];

const recentConnections = [
  { name: "Home Lab", url: "http://100.101.44.8:8787", token: "home-lab-token-demo" },
  { name: "VPS", url: "https://pi-hub.riyaz.dev", token: "vps-token-demo" },
  { name: "Office Tunnel", url: "http://192.168.1.100:8080", token: "office-token-demo" },
];

const remoteTree = {
  "/home/riaz": ["projects", "apps", "work", "labs", "Downloads"],
  "/home/riaz/projects": ["api-server", "notify-service", "theme-kit", "mini-banking-wallet"],
  "/home/riaz/apps": ["pi-hub", "flutter-starter", "pbx-mobile"],
  "/home/riaz/work": ["ipbx-sms", "fusionpbx-tools", "bandwidth-sandbox"],
  "/home/riaz/labs": ["theme-kit", "imagick-transformer", "svelte5-playground"],
  "/home/riaz/projects/api-server": ["src", "tests", "package.json", "README.md"],
  "/home/riaz/apps/pi-hub": ["lib", "android", "ios", "pubspec.yaml"],
  "/home/riaz/work/ipbx-sms": ["app", "routes", "tests", "composer.json"],
};

const sessionsSeed = [
  {
    id: "jwt",
    title: "JWT Refactor",
    dir: "/home/riaz/projects/api-server",
    repo: "api-server",
    branch: "feature/jwt-rotation",
    model: "Sonnet 4",
    state: "running",
    activity: "Running tests",
    files: ["auth.ts", "refresh-token.test.ts"],
    last: "36 tests passing, coverage still running",
    time: "now",
    unread: 4,
    accent: C.blue,
  },
  {
    id: "pbx",
    title: "PBX Attachments",
    dir: "/home/riaz/work/ipbx-sms",
    repo: "ipbx-sms",
    branch: "bandwidth-media-upload",
    model: "Opus 4.5",
    state: "tool",
    activity: "Verifying upload pipeline",
    files: ["BandwidthMediaUploader.php", "AcrobitsDecoder.php"],
    last: "php artisan test --filter=BandwidthMediaTest",
    time: "2m",
    unread: 2,
    accent: C.green,
  },
  {
    id: "flutter",
    title: "Flutter UI Cleanup",
    dir: "/home/riaz/apps/pi-hub",
    repo: "pi-hub",
    branch: "mobile-v7-ui",
    model: "Sonnet 4",
    state: "waiting",
    activity: "Waiting for guidance",
    files: ["SessionScreen.dart", "CompactTimeline.dart"],
    last: "Raw logs or grouped cards?",
    time: "8m",
    unread: 1,
    accent: C.yellow,
  },
  {
    id: "theme",
    title: "Theme Kit Generator",
    dir: "/home/riaz/labs/theme-kit",
    repo: "theme-kit",
    branch: "tokens-v2",
    model: "Haiku 4",
    state: "running",
    activity: "Generating Flutter ThemeData",
    files: ["pi_theme.dart", "pi_spacing.dart"],
    last: "token export in progress",
    time: "31m",
    unread: 7,
    accent: C.cyan,
  },
];

const baseEvents = {
  jwt: [
    { id: "e1", type: "user", text: "Refactor auth to use JWT access tokens with refresh token rotation. Keep changes minimal and run tests.", time: "14:31" },
    { id: "e2", type: "assistant", text: "I’ll inspect the current auth flow first, then update only the middleware and focused auth tests." },
    {
      id: "e3",
      type: "toolGroup",
      title: "Inspect auth flow",
      status: "done",
      collapsedLabel: "Read 2 files · searched TODOs",
      items: [
        { tool: "read_file", label: "src/auth/middleware.ts", meta: "0.3s" },
        { tool: "read_file", label: "src/auth/types.ts", meta: "0.2s" },
        { tool: "grep", label: "TODO|FIXME|HACK src/auth/", meta: "3 matches" },
      ],
    },
    { id: "e4", type: "assistant", text: "Current auth uses a long-lived static bearer token. I’m replacing it with a short-lived access token plus rotating refresh-token version checks." },
    { id: "e5", type: "edit", file: "src/auth/middleware.ts", added: 47, removed: 12, summary: "JWT validation, expired-token handling, refresh token version checks" },
    {
      id: "e6",
      type: "terminal",
      title: "npm test -- tests/auth --coverage",
      status: "running",
      summary: "36 passed · coverage running",
      lines: [
        "> project@2.1.0 test",
        "> jest tests/auth --coverage",
        "PASS tests/auth/login.test.ts",
        "PASS tests/auth/refresh-token.test.ts",
        "PASS tests/auth/middleware.test.ts",
        "Tests: 36 passed, 36 total",
        "Coverage: 91.4% statements | 88.2% branches",
        "running...",
      ],
    },
  ],
  pbx: [
    { id: "p1", type: "user", text: "Verify the Bandwidth media upload path with encrypted Acrobits attachments." },
    { id: "p2", type: "assistant", text: "I’m checking the decode pipeline, temp-file handling, and Bandwidth upload response mapping." },
    {
      id: "p3",
      type: "toolGroup",
      title: "Attachment pipeline",
      status: "running",
      collapsedLabel: "Read services · running focused test",
      items: [
        { tool: "read_file", label: "app/Services/AcrobitsAttachmentDecoder.php", meta: "done" },
        { tool: "read_file", label: "app/Services/BandwidthMediaUploader.php", meta: "done" },
        { tool: "bash", label: "php artisan test --filter=BandwidthMediaTest", meta: "live" },
      ],
    },
  ],
  flutter: [
    { id: "f1", type: "user", text: "Clean up the Pi Hub app UI. Make it feel like ChatGPT mobile, but optimize Pi stream data better than the TUI." },
    { id: "f2", type: "assistant", text: "I converted the session detail into a compact chat timeline with grouped tools, terminal summaries, diff cards, and a sticky multiline composer." },
    { id: "f3", type: "waiting", question: "Should the default stream hide raw terminal noise and show only compact grouped cards?", options: ["Compact by default", "Keep raw log toggle"] },
  ],
  theme: [
    { id: "t1", type: "user", text: "Generate a Flutter theme kit from our design tokens." },
    {
      id: "t2",
      type: "toolGroup",
      title: "Theme export",
      status: "running",
      collapsedLabel: "Read tokens · writing theme files",
      items: [
        { tool: "read_file", label: "tokens/pi-hub.dark.json", meta: "done" },
        { tool: "write_file", label: "lib/theme/pi_theme.dart", meta: "+184" },
        { tool: "write_file", label: "lib/theme/pi_spacing.dart", meta: "+42" },
      ],
    },
  ],
};

function Phone({ children }) {
  return (
    <div className="min-h-screen w-full bg-black text-white flex items-center justify-center p-4 font-sans">
      <div className="relative h-[860px] w-[390px] overflow-hidden rounded-[46px] border-[10px] border-[#1B1D22] shadow-2xl" style={{ background: C.bg }}>
        <div className="absolute left-1/2 top-0 z-50 h-7 w-32 -translate-x-1/2 rounded-b-3xl bg-black" />
        {children}
      </div>
    </div>
  );
}

function TopSafeBar() {
  return (
    <div className="h-11 px-5 flex items-center justify-between text-xs" style={{ background: C.bg }}>
      <span className="font-semibold">9:41</span>
      <div className="flex items-center gap-1 opacity-80">
        <span className="h-2.5 w-3 rounded-sm border border-white/80" />
        <span className="h-2.5 w-5 rounded-sm bg-white/80" />
      </div>
    </div>
  );
}

function StatusDot({ state, label }) {
  const map = {
    running: { color: C.green, label: "Running" },
    tool: { color: C.cyan, label: "Tool" },
    waiting: { color: C.yellow, label: "Waiting" },
    idle: { color: C.text3, label: "Idle" },
    error: { color: C.red, label: "Error" },
    live: { color: C.green, label: "Live" },
  };
  const cfg = map[state] || map.idle;
  return (
    <span className="inline-flex items-center gap-1.5 text-[11px] font-medium" style={{ color: cfg.color }}>
      <span className="h-1.5 w-1.5 rounded-full" style={{ background: cfg.color, boxShadow: state !== "idle" ? `0 0 10px ${cfg.color}` : "none" }} />
      {label || cfg.label}
    </span>
  );
}

function InputBlock({ icon: Icon, label, value, setValue, placeholder, password }) {
  return (
    <label className="block">
      <div className="mb-1.5 flex items-center gap-1.5 text-xs font-medium" style={{ color: C.text2 }}><Icon size={13} /> {label}</div>
      <input value={value} onChange={(e) => setValue(e.target.value)} type={password ? "password" : "text"} placeholder={placeholder} className="w-full rounded-2xl px-4 py-3.5 font-mono text-sm outline-none" style={{ background: C.panel, border: `1px solid ${C.line}`, color: C.text }} />
    </label>
  );
}

function ConnectionScreen({ onConnect }) {
  const [url, setUrl] = useState("http://100.101.44.8:8787");
  const [token, setToken] = useState("pi_hub_demo_token");
  const [busy, setBusy] = useState(false);
  const connect = () => {
    if (!url.trim() || !token.trim()) return;
    setBusy(true);
    setTimeout(() => {
      setBusy(false);
      onConnect({ url, token });
    }, 650);
  };
  return (
    <div className="h-full flex flex-col" style={{ background: C.bg }}>
      <TopSafeBar />
      <div className="flex-1 px-5 pt-10">
        <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }}>
          <div className="mx-auto mb-7 grid h-16 w-16 place-items-center rounded-[24px] font-mono text-3xl font-bold" style={{ background: "linear-gradient(135deg,#17243B,#281C45)", color: C.blue, border: `1px solid ${C.line}` }}>π</div>
          <h1 className="text-center text-3xl font-semibold tracking-tight">Pi Hub</h1>
          <p className="mx-auto mt-2 max-w-[280px] text-center text-sm leading-6" style={{ color: C.text3 }}>Connect to your hub server and control Pi sessions from your phone.</p>
        </motion.div>
        <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.08 }} className="mt-9 space-y-4">
          <InputBlock icon={Server} label="Server URL" value={url} setValue={setUrl} placeholder="http://host:port" />
          <InputBlock icon={KeyRound} label="Token" value={token} setValue={setToken} placeholder="Access token" password />
          <button onClick={connect} disabled={!url.trim() || !token.trim() || busy} className="flex w-full items-center justify-center gap-2 rounded-2xl py-4 text-sm font-bold transition active:scale-[.99]" style={{ background: url.trim() && token.trim() ? C.blue : C.card, color: url.trim() && token.trim() ? "#06111F" : C.text3 }}>
            {busy ? <RefreshCcw size={17} className="animate-spin" /> : <Wifi size={17} />}
            {busy ? "Connecting..." : "Connect"}
          </button>
        </motion.div>
        <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.14 }} className="mt-8">
          <div className="mb-2 text-xs font-semibold uppercase tracking-wider" style={{ color: C.text3 }}>Recent connections</div>
          <div className="space-y-2">
            {recentConnections.map((r) => (
              <button key={r.name} onClick={() => { setUrl(r.url); setToken(r.token); }} className="flex w-full items-center gap-3 rounded-2xl p-3 text-left" style={{ background: C.panel, border: `1px solid ${C.softLine}` }}>
                <div className="grid h-9 w-9 place-items-center rounded-xl" style={{ background: C.card, color: C.green }}><Server size={17} /></div>
                <div className="min-w-0 flex-1">
                  <div className="text-sm font-semibold">{r.name}</div>
                  <div className="truncate font-mono text-[11px]" style={{ color: C.text3 }}>{r.url}</div>
                </div>
                <ChevronLeft className="rotate-180" size={18} style={{ color: C.text3 }} />
              </button>
            ))}
          </div>
        </motion.div>
      </div>
    </div>
  );
}

function SessionListScreen({ connection, sessions, openSession, onBroadcast, onNewSession, onDisconnect }) {
  const [q, setQ] = useState("");
  const filtered = sessions.filter((s) => `${s.title} ${s.activity} ${s.files.join(" ")} ${s.last} ${s.dir}`.toLowerCase().includes(q.toLowerCase()));
  return (
    <div className="relative h-full" style={{ background: C.bg }}>
      <TopSafeBar />
      <div className="border-b px-4 pb-3 pt-2" style={{ borderColor: C.softLine }}>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="grid h-8 w-8 place-items-center rounded-xl font-mono text-lg font-bold" style={{ background: "linear-gradient(135deg,#17243B,#281C45)", color: C.blue, border: `1px solid ${C.line}` }}>π</div>
            <div>
              <h1 className="text-lg font-semibold tracking-tight">Pi Hub</h1>
              <p className="max-w-[190px] truncate font-mono text-[10px]" style={{ color: C.text3 }}>{connection.url}</p>
            </div>
          </div>
          <button onClick={onDisconnect} className="rounded-full px-3 py-1.5 text-xs font-semibold" style={{ background: C.panel, color: C.text2, border: `1px solid ${C.softLine}` }}>
            <StatusDot state="live" />
          </button>
        </div>
        <div className="mt-3 flex items-center gap-2 rounded-2xl px-3 py-3 text-sm" style={{ background: C.panel2, color: C.text3, border: `1px solid ${C.softLine}` }}>
          <Search size={17} />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search sessions, files, outputs" className="flex-1 bg-transparent outline-none" style={{ color: C.text }} />
        </div>
        <div className="mt-3 flex gap-2 overflow-x-auto">
          {[["All", sessions.length], ["Running", sessions.filter((s) => s.state === "running" || s.state === "tool").length], ["Waiting", sessions.filter((s) => s.state === "waiting").length], ["Idle", sessions.filter((s) => s.state === "idle").length]].map(([label, count]) => (
            <span key={label} className="shrink-0 rounded-full px-3 py-1.5 text-[11px] font-medium" style={{ background: C.panel, border: `1px solid ${C.softLine}`, color: C.text2 }}>{label} {count}</span>
          ))}
        </div>
      </div>
      <div className="h-[calc(100%-145px)] overflow-y-auto pb-28">
        {filtered.map((s) => <SessionCard key={s.id} session={s} onOpen={openSession} />)}
      </div>
      <div className="absolute bottom-5 right-5 z-20 flex flex-col items-end gap-2">
        <button onClick={onNewSession} className="flex items-center gap-2 rounded-full px-4 py-3 text-sm font-bold shadow-xl active:scale-[.98]" style={{ background: C.green, color: "#06110B", boxShadow: "0 16px 40px rgba(94,225,154,.24)" }}><Plus size={17} /> New Session</button>
        <button onClick={onBroadcast} className="flex items-center gap-2 rounded-full px-4 py-3 text-sm font-bold shadow-xl active:scale-[.98]" style={{ background: C.blue, color: "#06111F", boxShadow: "0 16px 40px rgba(103,167,255,.28)" }}><Send size={17} /> Broadcast</button>
      </div>
    </div>
  );
}

function SessionCard({ session, onOpen }) {
  return (
    <button onClick={() => onOpen(session.id)} className="w-full border-b px-4 py-3 text-left active:scale-[.99]" style={{ borderColor: C.softLine }}>
      <div className="flex items-start gap-3">
        <div className="mt-0.5 h-10 w-10 shrink-0 rounded-2xl grid place-items-center" style={{ background: `${session.accent}1A`, border: `1px solid ${session.accent}44`, color: session.accent }}><Terminal size={18} /></div>
        <div className="min-w-0 flex-1">
          <div className="flex items-center justify-between gap-2"><h3 className="truncate text-sm font-semibold">{session.title}</h3><span className="shrink-0 text-[10px]" style={{ color: C.text3 }}>{session.time}</span></div>
          <div className="mt-1 flex items-center gap-2"><StatusDot state={session.state} /><span className="truncate text-xs font-medium" style={{ color: C.text2 }}>{session.activity}</span></div>
          <div className="mt-2 flex flex-wrap gap-1.5">{session.files.slice(0, 2).map((f) => <span key={f} className="rounded-md px-1.5 py-1 font-mono text-[10px]" style={{ background: C.card, color: C.text2 }}>{f}</span>)}</div>
          <p className="mt-2 truncate text-xs" style={{ color: C.text3 }}>{session.last}</p>
        </div>
        {session.unread > 0 && <div className="mt-4 grid h-5 min-w-5 place-items-center rounded-full px-1.5 text-[10px] font-bold" style={{ background: C.blue, color: "#06111F" }}>{session.unread}</div>}
      </div>
    </button>
  );
}

function NewSessionSheet({ open, onClose, onStart }) {
  const [path, setPath] = useState("/home/riaz/projects/api-server");
  const [prompt, setPrompt] = useState("Analyze the project and suggest the next safest improvement.");
  const [model, setModel] = useState("Sonnet 4");
  const [browseOpen, setBrowseOpen] = useState(false);
  const start = () => {
    if (!path.trim() || !prompt.trim()) return;
    onStart({ path, prompt, model });
    onClose();
  };
  return (
    <>
      <AnimatePresence>
        {open && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="absolute inset-0 z-50 flex items-end bg-black/60" onClick={onClose}>
            <motion.div initial={{ y: 560 }} animate={{ y: 0 }} exit={{ y: 560 }} transition={{ type: "spring", damping: 30, stiffness: 260 }} className="max-h-[88%] w-full rounded-t-[32px] p-4" style={{ background: C.panel, borderTop: `1px solid ${C.line}` }} onClick={(e) => e.stopPropagation()}>
              <div className="mx-auto mb-4 h-1 w-10 rounded-full bg-white/20" />
              <div className="mb-4 flex items-center justify-between"><div><h3 className="text-base font-semibold">Start New Pi Session</h3><p className="text-xs" style={{ color: C.text3 }}>Select a remote directory, then send the first prompt</p></div><button onClick={onClose} className="grid h-9 w-9 place-items-center rounded-full" style={{ background: C.card }}><X size={18} /></button></div>
              <label className="mb-1.5 block text-xs font-medium" style={{ color: C.text2 }}>Working directory</label>
              <div className="mb-3 flex gap-2"><div className="min-w-0 flex-1 rounded-2xl px-3 py-3 font-mono text-xs" style={{ background: C.card, border: `1px solid ${C.line}`, color: C.text }}>{path}</div><button onClick={() => setBrowseOpen(true)} className="rounded-2xl px-3 text-xs font-bold" style={{ background: C.blue, color: "#06111F" }}>Browse</button></div>
              <label className="mb-1.5 block text-xs font-medium" style={{ color: C.text2 }}>Initial prompt</label>
              <textarea value={prompt} onChange={(e) => setPrompt(e.target.value)} className="mb-3 h-28 w-full resize-none rounded-2xl p-3 text-sm outline-none" style={{ background: C.card, border: `1px solid ${C.line}`, color: C.text }} placeholder="Tell Pi what to do in this directory..." />
              <label className="mb-1.5 block text-xs font-medium" style={{ color: C.text2 }}>Model</label>
              <div className="mb-4 flex gap-2 overflow-x-auto">{modelOptions.map((m) => <button key={m} onClick={() => setModel(m)} className="shrink-0 rounded-full px-3 py-2 text-xs font-semibold" style={{ background: model === m ? `${C.green}1C` : C.card, border: `1px solid ${model === m ? C.green + "66" : C.softLine}`, color: model === m ? C.green : C.text2 }}>{m}</button>)}</div>
              <button onClick={start} disabled={!path.trim() || !prompt.trim()} className="flex w-full items-center justify-center gap-2 rounded-2xl py-3.5 text-sm font-bold" style={{ background: path.trim() && prompt.trim() ? C.green : C.card, color: path.trim() && prompt.trim() ? "#06110B" : C.text3 }}><Play size={17} /> Start Pi Session</button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
      <RemotePathBrowser open={browseOpen} onClose={() => setBrowseOpen(false)} selectedPath={path} onSelect={(p) => { setPath(p); setBrowseOpen(false); }} />
    </>
  );
}

function RemotePathBrowser({ open, onClose, selectedPath, onSelect }) {
  const [current, setCurrent] = useState("/home/riaz");
  const entries = remoteTree[current] || [];
  const parent = current.split("/").slice(0, -1).join("/") || "/";
  const isFolder = (path, name) => remoteTree[`${path}/${name}`] || !name.includes(".");
  return (
    <AnimatePresence>
      {open && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="absolute inset-0 z-[70] flex items-end bg-black/70" onClick={onClose}>
          <motion.div initial={{ y: 620 }} animate={{ y: 0 }} exit={{ y: 620 }} transition={{ type: "spring", damping: 30, stiffness: 260 }} className="h-[86%] w-full overflow-hidden rounded-t-[32px]" style={{ background: C.bg, borderTop: `1px solid ${C.line}` }} onClick={(e) => e.stopPropagation()}>
            <div className="border-b p-4" style={{ borderColor: C.softLine }}>
              <div className="mb-3 flex items-center justify-between"><div><h3 className="text-base font-semibold">Remote Workspace</h3><p className="font-mono text-[11px]" style={{ color: C.text3 }}>{current}</p></div><button onClick={onClose} className="grid h-9 w-9 place-items-center rounded-full" style={{ background: C.card }}><X size={18} /></button></div>
              <div className="flex gap-2"><button onClick={() => setCurrent("/home/riaz")} className="flex items-center gap-1 rounded-full px-3 py-1.5 text-xs" style={{ background: C.panel, color: C.text2, border: `1px solid ${C.softLine}` }}><Home size={13} /> Home</button>{current !== "/home/riaz" && <button onClick={() => setCurrent(parent || "/home/riaz")} className="rounded-full px-3 py-1.5 text-xs" style={{ background: C.panel, color: C.text2, border: `1px solid ${C.softLine}` }}>Up</button>}</div>
            </div>
            <div className="h-[calc(100%-155px)] overflow-y-auto p-3">
              {entries.map((name) => {
                const full = `${current}/${name}`;
                const folder = isFolder(current, name);
                return <button key={full} onClick={() => folder ? setCurrent(full) : null} className="mb-2 flex w-full items-center gap-3 rounded-2xl p-3 text-left" style={{ background: selectedPath === full ? `${C.green}14` : C.panel, border: `1px solid ${selectedPath === full ? C.green + "66" : C.softLine}` }}><div className="grid h-10 w-10 place-items-center rounded-2xl" style={{ background: C.card, color: folder ? C.blue : C.text3 }}>{folder ? <FolderOpen size={18} /> : <FileText size={18} />}</div><div className="min-w-0 flex-1"><div className="truncate text-sm font-semibold">{name}</div><div className="truncate font-mono text-[10px]" style={{ color: C.text3 }}>{full}</div></div>{folder && <ChevronLeft className="rotate-180" size={18} style={{ color: C.text3 }} />}</button>;
              })}
            </div>
            <div className="border-t p-4" style={{ borderColor: C.softLine }}><div className="mb-3 rounded-2xl p-3 font-mono text-xs" style={{ background: C.panel, border: `1px solid ${C.softLine}`, color: C.text2 }}>{current}</div><button onClick={() => onSelect(current)} className="w-full rounded-2xl py-3.5 text-sm font-bold" style={{ background: C.green, color: "#06110B" }}>Select this directory</button></div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

function BroadcastSheet({ open, onClose, sessions, onSend }) {
  const [prompt, setPrompt] = useState("Continue with tests and summarize the result.");
  const [selected, setSelected] = useState(() => new Set(["jwt", "pbx"]));
  const [model, setModel] = useState("Use current");
  useEffect(() => { if (open) setSelected(new Set(["jwt", "pbx"])); }, [open]);
  const toggle = (id) => setSelected((prev) => { const next = new Set(prev); next.has(id) ? next.delete(id) : next.add(id); return next; });
  const send = () => { if (!prompt.trim() || selected.size === 0) return; onSend({ prompt: prompt.trim(), sessionIds: [...selected], model }); onClose(); };
  return (
    <AnimatePresence>
      {open && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="absolute inset-0 z-50 flex items-end bg-black/60" onClick={onClose}>
          <motion.div initial={{ y: 520 }} animate={{ y: 0 }} exit={{ y: 520 }} transition={{ type: "spring", damping: 30, stiffness: 260 }} className="max-h-[86%] w-full rounded-t-[32px] p-4" style={{ background: C.panel, borderTop: `1px solid ${C.line}` }} onClick={(e) => e.stopPropagation()}>
            <div className="mx-auto mb-4 h-1 w-10 rounded-full bg-white/20" />
            <div className="mb-4 flex items-center justify-between"><div><h3 className="text-base font-semibold">Broadcast Prompt</h3><p className="text-xs" style={{ color: C.text3 }}>Send same instruction to multiple Pi sessions</p></div><button onClick={onClose} className="grid h-9 w-9 place-items-center rounded-full" style={{ background: C.card }}><X size={18} /></button></div>
            <textarea value={prompt} onChange={(e) => setPrompt(e.target.value)} className="mb-3 h-24 w-full resize-none rounded-2xl p-3 text-sm outline-none" style={{ background: C.card, border: `1px solid ${C.line}`, color: C.text }} placeholder="Type broadcast message..." />
            <div className="mb-3 flex gap-2 overflow-x-auto">{["Use current", ...modelOptions].map((m) => <button key={m} onClick={() => setModel(m)} className="shrink-0 rounded-full px-3 py-2 text-xs font-semibold" style={{ background: model === m ? `${C.blue}1C` : C.card, border: `1px solid ${model === m ? C.blue + "66" : C.softLine}`, color: model === m ? C.blue : C.text2 }}>{m}</button>)}</div>
            <div className="mb-2 flex items-center justify-between"><span className="text-xs font-semibold uppercase tracking-wider" style={{ color: C.text3 }}>Sessions</span><span className="text-xs" style={{ color: C.text3 }}>{selected.size} selected</span></div>
            <div className="max-h-64 overflow-y-auto space-y-2 pr-1">{sessions.map((s) => { const checked = selected.has(s.id); return <button key={s.id} onClick={() => toggle(s.id)} className="flex w-full items-center gap-3 rounded-2xl p-3 text-left" style={{ background: checked ? `${C.blue}12` : C.card, border: `1px solid ${checked ? C.blue + "55" : C.softLine}` }}><div className="grid h-6 w-6 place-items-center rounded-lg" style={{ background: checked ? C.blue : C.panel2, color: checked ? "#06111F" : C.text3 }}>{checked && <CheckCircle2 size={16} />}</div><div className="min-w-0 flex-1"><div className="truncate text-sm font-semibold">{s.title}</div><div className="truncate text-xs" style={{ color: C.text3 }}>{s.activity}</div></div><StatusDot state={s.state} /></button>; })}</div>
            <button onClick={send} disabled={!prompt.trim() || selected.size === 0} className="mt-4 flex w-full items-center justify-center gap-2 rounded-2xl py-3.5 text-sm font-bold" style={{ background: prompt.trim() && selected.size ? C.blue : C.card, color: prompt.trim() && selected.size ? "#06111F" : C.text3 }}><Send size={17} /> Send to {selected.size || 0} sessions</button>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

function SessionScreen({ session, events, setEvents, goBack, updateSessionModel }) {
  const [model, setModel] = useState(session.model);
  const [diff, setDiff] = useState(null);
  const [streamingId, setStreamingId] = useState(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const scrollRef = useRef(null);
  useEffect(() => { updateSessionModel(session.id, model); }, [model]);
  useEffect(() => { scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" }); }, [events, streamingId]);
  const append = (items) => setEvents((prev) => ({ ...prev, [session.id]: [...(prev[session.id] || []), ...items] }));
  const simulateReply = (prompt) => {
    const user = { id: `u-${Date.now()}`, type: "user", text: prompt, time: "now" };
    const thinking = { id: `a-${Date.now()}`, type: "assistant", text: "Understood. I’ll continue from the current state and keep the stream compact." };
    append([user, thinking]); setStreamingId(thinking.id);
    setTimeout(() => { setStreamingId(null); append([{ id: `g-${Date.now()}`, type: "toolGroup", title: "Edge-case pass", status: "done", collapsedLabel: "Search tests · read file · run suite", items: [{ tool: "grep", label: "auth.test.ts refresh token", meta: "4 matches" }, { tool: "read_file", label: "tests/auth/refresh-token.test.ts", meta: "0.2s" }, { tool: "bash", label: "npm test -- tests/auth", meta: "started" }] }]); }, 900);
    setTimeout(() => append([{ id: `m-${Date.now()}`, type: "assistant", text: "Found missing cases: expired token, reused refresh token, malformed JWT, and concurrent refresh. I’m adding tests now." }]), 1650);
    setTimeout(() => append([{ id: `ed-${Date.now()}`, type: "edit", file: "tests/auth/refresh-token.test.ts", added: 63, removed: 0, summary: "Adds 12 tests covering replay, expiry, malformed JWT, and concurrent refresh." }]), 2450);
    setTimeout(() => append([{ id: `term-${Date.now()}`, type: "terminal", title: "npm test -- tests/auth", status: "done", summary: "36 passed · 0 failed", lines: ["PASS tests/auth/login.test.ts", "PASS tests/auth/refresh-token.test.ts", "PASS tests/auth/middleware.test.ts", "Tests: 36 passed", "Time: 3.241s"] }]), 3300);
    setTimeout(() => append([{ id: `done-${Date.now()}`, type: "assistant", text: "Done. Added 12 tests and reran the suite. 36/36 tests passing." }]), 4100);
  };
  const addAttachment = (title) => append([{ id: `att-${Date.now()}`, type: "user", text: `[${title}] attached to this session.`, time: "now" }]);
  return (
    <div className="relative flex h-full flex-col" style={{ background: C.bg }}>
      <TopSafeBar />
      <div className="flex items-center gap-2 border-b px-3 pb-2 pt-1" style={{ borderColor: C.softLine }}>
        <button onClick={goBack} className="grid h-9 w-9 place-items-center rounded-full active:scale-95" style={{ background: C.panel }}><ChevronLeft size={22} /></button>
        <div className="min-w-0 flex-1"><div className="flex items-center gap-2"><h2 className="truncate text-sm font-semibold">{session.title}</h2><StatusDot state={session.state} /></div><p className="truncate font-mono text-[10px]" style={{ color: C.text3 }}>{session.dir}</p></div>
        <button className="grid h-9 w-9 place-items-center rounded-full" style={{ background: C.panel }}><Pause size={17} style={{ color: C.yellow }} /></button>
        <button onClick={() => setMenuOpen(true)} className="grid h-9 w-9 place-items-center rounded-full" style={{ background: C.panel }}><MoreHorizontal size={19} /></button>
      </div>
      <div className="flex items-center gap-2 overflow-x-auto border-b px-3 py-2" style={{ borderColor: C.softLine }}><Chip icon={GitBranch} text={session.branch} /><Chip icon={Sparkles} text={model} /><Chip icon={Folder} text={session.repo} /><Chip icon={Zap} text="Compact stream" /></div>
      <div ref={scrollRef} className="flex-1 overflow-y-auto py-3 pb-2">{(events[session.id] || []).map((e) => <EventRenderer key={e.id} e={e} onDiff={setDiff} quickReply={simulateReply} streamingId={streamingId} />)}</div>
      <Composer onSend={simulateReply} model={model} setModel={setModel} addAttachment={addAttachment} />
      <DiffDrawer diff={diff} onClose={() => setDiff(null)} />
      <SessionMenu open={menuOpen} onClose={() => setMenuOpen(false)} model={model} setModel={setModel} />
    </div>
  );
}

function Chip({ icon: Icon, text }) { return <span className="inline-flex shrink-0 items-center gap-1.5 rounded-full px-3 py-1.5 text-[11px]" style={{ background: C.panel, border: `1px solid ${C.softLine}`, color: C.text2 }}><Icon size={13} /> {text}</span>; }
function UserBubble({ text, time }) { return <div className="flex justify-end px-3 py-1.5"><div className="max-w-[84%] rounded-[22px] rounded-br-lg px-4 py-3 text-sm leading-relaxed shadow-sm" style={{ background: C.blue, color: "#06111F" }}><p className="whitespace-pre-wrap">{text}</p>{time && <div className="mt-1 text-right text-[10px] opacity-60">{time}</div>}</div></div>; }
function AssistantBubble({ text, streaming }) { return <div className="px-3 py-1.5"><div className="rounded-[22px] rounded-tl-lg px-4 py-3 text-sm leading-relaxed" style={{ background: C.panel, border: `1px solid ${C.softLine}`, color: C.text }}><div className="mb-1 flex items-center gap-1.5 text-[10px] font-semibold uppercase tracking-wider" style={{ color: C.cyan }}><Bot size={12} /> Pi</div><p className="whitespace-pre-wrap">{text}{streaming && <span className="ml-1 animate-pulse">▋</span>}</p></div></div>; }
function ToolGlyph({ tool }) { const map = { read_file: FileText, bash: Terminal, grep: Search, write_file: Code2, git_diff: GitBranch }; const Icon = map[tool] || Command; return <Icon size={13} />; }

function ToolGroupCard({ e }) {
  const [open, setOpen] = useState(false); const live = e.status === "running"; const shown = open ? e.items : e.items.slice(0, 3);
  return <div className="px-3 py-1.5"><div className="rounded-2xl p-3" style={{ background: C.card, border: `1px solid ${live ? C.cyan + "55" : C.softLine}` }}><button onClick={() => setOpen(!open)} className="mb-2 flex w-full items-center justify-between gap-2 text-left"><div className="flex items-center gap-2"><div className="grid h-7 w-7 place-items-center rounded-xl" style={{ background: live ? `${C.cyan}1A` : `${C.green}1A`, color: live ? C.cyan : C.green }}>{live ? <RefreshCcw size={14} className="animate-spin" /> : <CheckCircle2 size={14} />}</div><div><h4 className="text-xs font-semibold">{e.title}</h4><p className="text-[10px]" style={{ color: C.text3 }}>{e.collapsedLabel || `${e.items.length} operations`}</p></div></div><span className="text-[10px] font-mono" style={{ color: C.text3 }}>{open ? "hide" : "expand"}</span></button><div className="space-y-1.5">{shown.map((it, idx) => <div key={idx} className="flex items-center gap-2 rounded-xl px-2 py-1.5" style={{ background: C.panel }}><span style={{ color: C.blue }}><ToolGlyph tool={it.tool} /></span><span className="min-w-0 flex-1 truncate font-mono text-[11px]" style={{ color: C.text2 }}>{it.label}</span><span className="shrink-0 font-mono text-[10px]" style={{ color: C.text3 }}>{it.meta}</span></div>)}</div></div></div>;
}

function TerminalCard({ e }) {
  const [open, setOpen] = useState(false); const visible = open ? e.lines : e.lines.slice(-4); const ok = e.status === "done";
  return <div className="px-3 py-1.5"><div className="overflow-hidden rounded-2xl" style={{ background: "#05070A", border: `1px solid ${ok ? C.green + "44" : C.cyan + "44"}` }}><button onClick={() => setOpen(!open)} className="flex w-full items-center justify-between gap-2 px-3 py-2 text-left" style={{ background: C.card }}><div className="min-w-0 flex items-center gap-2"><Terminal size={14} style={{ color: ok ? C.green : C.cyan }} /><span className="truncate font-mono text-[11px]">{e.title}</span></div><span className="shrink-0 text-[10px]" style={{ color: ok ? C.green : C.cyan }}>{open ? "hide" : "expand"}</span></button><div className="border-b px-3 py-2 text-xs font-semibold" style={{ borderColor: C.softLine, color: ok ? C.green : C.cyan }}>{e.summary}</div><div className="px-3 py-2 font-mono text-[11px] leading-5">{visible.map((l, i) => <div key={i} className="truncate" style={{ color: l.includes("PASS") || l.includes("passed") ? C.green : l.includes("running") ? C.cyan : C.text2 }}>{l}</div>)}</div></div></div>;
}
function EditCard({ e, onDiff }) { return <div className="px-3 py-1.5"><div className="rounded-2xl p-3" style={{ background: "rgba(103,167,255,.08)", border: `1px solid ${C.blue}33` }}><div className="flex items-start gap-3"><div className="grid h-9 w-9 shrink-0 place-items-center rounded-2xl" style={{ background: `${C.blue}1A`, color: C.blue }}><Code2 size={16} /></div><div className="min-w-0 flex-1"><div className="flex items-center justify-between gap-2"><h4 className="text-sm font-semibold">Modified file</h4><div className="flex gap-2 font-mono text-xs"><span style={{ color: C.green }}>+{e.added}</span><span style={{ color: C.red }}>-{e.removed}</span></div></div><p className="mt-1 truncate font-mono text-xs" style={{ color: C.text2 }}>{e.file}</p><p className="mt-2 text-xs leading-relaxed" style={{ color: C.text3 }}>{e.summary}</p><button onClick={() => onDiff(e)} className="mt-3 flex items-center gap-1 rounded-full px-3 py-1.5 text-xs font-semibold" style={{ background: C.blue, color: "#06111F" }}>View diff <ExternalLink size={13} /></button></div></div></div></div>; }
function WaitingCard({ e, quickReply }) { return <div className="px-3 py-1.5"><div className="rounded-2xl p-3" style={{ background: `${C.yellow}12`, border: `1px solid ${C.yellow}44` }}><h4 className="text-sm font-semibold" style={{ color: C.yellow }}>Waiting for guidance</h4><p className="mt-1 text-sm leading-relaxed">{e.question}</p><div className="mt-3 flex flex-wrap gap-2">{e.options.map((o) => <button key={o} onClick={() => quickReply(o)} className="rounded-full px-3 py-1.5 text-xs font-semibold" style={{ background: C.card, color: C.text2 }}>{o}</button>)}</div></div></div>; }
function EventRenderer({ e, onDiff, quickReply, streamingId }) { if (e.type === "user") return <UserBubble text={e.text} time={e.time} />; if (e.type === "assistant") return <AssistantBubble text={e.text} streaming={streamingId === e.id} />; if (e.type === "toolGroup") return <ToolGroupCard e={e} />; if (e.type === "terminal") return <TerminalCard e={e} />; if (e.type === "edit") return <EditCard e={e} onDiff={onDiff} />; if (e.type === "waiting") return <WaitingCard e={e} quickReply={quickReply} />; return null; }

function Composer({ onSend, model, setModel, addAttachment }) {
  const [text, setText] = useState(""); const [modelOpen, setModelOpen] = useState(false); const [attachOpen, setAttachOpen] = useState(false); const [slashOpen, setSlashOpen] = useState(false); const canSend = text.trim().length > 0; const send = () => { if (!canSend) return; onSend(text.trim()); setText(""); };
  return <><div className="border-t p-3" style={{ background: "rgba(7,9,13,.98)", borderColor: C.softLine }}><div className="rounded-[26px] p-2" style={{ background: C.panel, border: `1px solid ${C.line}` }}><textarea value={text} onChange={(e) => setText(e.target.value)} placeholder="Steer this Pi session..." rows={1} className="max-h-32 min-h-[42px] w-full resize-none bg-transparent px-3 py-2 text-sm leading-6 outline-none" style={{ color: C.text }} onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(); } }} /><div className="flex items-center justify-between px-1 pb-1"><div className="flex items-center gap-1"><button onClick={() => setAttachOpen(true)} className="grid h-9 w-9 place-items-center rounded-full" style={{ color: C.text2 }}><Paperclip size={18} /></button><button onClick={() => setSlashOpen(true)} className="grid h-9 w-9 place-items-center rounded-full" style={{ color: C.text2 }}><Command size={18} /></button><button onClick={() => setModelOpen(true)} className="rounded-full px-3 py-2 text-xs font-semibold" style={{ background: C.card, color: C.text2 }}>{model} ▾</button></div><button onClick={send} disabled={!canSend} className="grid h-9 w-9 place-items-center rounded-full" style={{ background: canSend ? C.blue : C.card, color: canSend ? "#06111F" : C.text3 }}><Send size={17} /></button></div></div></div><ModelSheet open={modelOpen} onClose={() => setModelOpen(false)} model={model} setModel={setModel} /><AttachmentSheet open={attachOpen} onClose={() => setAttachOpen(false)} onPick={addAttachment} /><SlashSheet open={slashOpen} onClose={() => setSlashOpen(false)} onCommand={(cmd) => setText((v) => v ? `${v}\n${cmd}` : cmd)} /></>;
}
function ModelSheet({ open, onClose, model, setModel }) { return <AnimatePresence>{open && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="absolute inset-0 z-50 flex items-end bg-black/55" onClick={onClose}><motion.div initial={{ y: 260 }} animate={{ y: 0 }} exit={{ y: 260 }} className="w-full rounded-t-[32px] p-4" style={{ background: C.panel, borderTop: `1px solid ${C.line}` }} onClick={(e) => e.stopPropagation()}><div className="mx-auto mb-4 h-1 w-10 rounded-full bg-white/20" /><h3 className="mb-3 text-base font-semibold">Switch model</h3><div className="space-y-2">{modelOptions.map((m) => <button key={m} onClick={() => { setModel(m); onClose(); }} className="flex w-full items-center justify-between rounded-2xl p-4 text-left" style={{ background: model === m ? `${C.blue}18` : C.card, border: `1px solid ${model === m ? C.blue + "66" : C.softLine}` }}><div><div className="text-sm font-semibold">{m}</div><div className="text-xs" style={{ color: C.text3 }}>{m.includes("Opus") ? "Best reasoning" : m.includes("Haiku") ? "Fast" : "Balanced coding"}</div></div>{model === m && <CheckCircle2 size={18} style={{ color: C.blue }} />}</button>)}</div></motion.div></motion.div>}</AnimatePresence>; }
function AttachmentSheet({ open, onClose, onPick }) { const items = [["Attach file", FileUp], ["Attach screenshot", Image], ["Attach repo file", FileText], ["Attach latest log", Terminal], ["Attach diff", GitBranch]]; return <AnimatePresence>{open && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="absolute inset-0 z-50 flex items-end bg-black/55" onClick={onClose}><motion.div initial={{ y: 280 }} animate={{ y: 0 }} exit={{ y: 280 }} className="w-full rounded-t-[32px] p-4" style={{ background: C.panel, borderTop: `1px solid ${C.line}` }} onClick={(e) => e.stopPropagation()}><div className="mx-auto mb-4 h-1 w-10 rounded-full bg-white/20" /><h3 className="mb-3 text-base font-semibold">Add context</h3><div className="grid grid-cols-1 gap-2">{items.map(([title, Icon]) => <button key={title} onClick={() => { onPick(title); onClose(); }} className="flex items-center gap-3 rounded-2xl p-4 text-left" style={{ background: C.card, border: `1px solid ${C.softLine}` }}><div className="grid h-10 w-10 place-items-center rounded-2xl" style={{ background: C.panel2, color: C.blue }}><Icon size={18} /></div><span className="text-sm font-semibold">{title}</span></button>)}</div></motion.div></motion.div>}</AnimatePresence>; }
function SlashSheet({ open, onClose, onCommand }) { const cmds = ["/model", "/status", "/compact", "/tree", "/diff", "/stop"]; return <AnimatePresence>{open && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="absolute inset-0 z-50 flex items-end bg-black/55" onClick={onClose}><motion.div initial={{ y: 260 }} animate={{ y: 0 }} exit={{ y: 260 }} className="w-full rounded-t-[32px] p-4" style={{ background: C.panel, borderTop: `1px solid ${C.line}` }} onClick={(e) => e.stopPropagation()}><div className="mx-auto mb-4 h-1 w-10 rounded-full bg-white/20" /><h3 className="mb-3 text-base font-semibold">Slash commands</h3><div className="grid grid-cols-2 gap-2">{cmds.map((cmd) => <button key={cmd} onClick={() => { onCommand(cmd); onClose(); }} className="rounded-2xl p-3 text-left font-mono text-sm" style={{ background: C.card, border: `1px solid ${C.softLine}`, color: C.cyan }}>{cmd}</button>)}</div></motion.div></motion.div>}</AnimatePresence>; }
function SessionMenu({ open, onClose, model, setModel }) { const [modelOpen, setModelOpen] = useState(false); const actions = [["Pause Session", Pause], ["Stop Session", Square], ["Switch Model", Sparkles], ["Copy Session ID", Copy]]; return <><AnimatePresence>{open && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="absolute inset-0 z-50 flex items-end bg-black/55" onClick={onClose}><motion.div initial={{ y: 260 }} animate={{ y: 0 }} exit={{ y: 260 }} className="w-full rounded-t-[32px] p-4" style={{ background: C.panel, borderTop: `1px solid ${C.line}` }} onClick={(e) => e.stopPropagation()}><div className="mx-auto mb-4 h-1 w-10 rounded-full bg-white/20" /><div className="space-y-2">{actions.map(([label, Icon]) => <button key={label} onClick={() => { if (label === "Switch Model") setModelOpen(true); }} className="flex w-full items-center gap-3 rounded-2xl p-4 text-left" style={{ background: C.card, border: `1px solid ${C.softLine}` }}><Icon size={18} style={{ color: label.includes("Stop") ? C.red : C.text2 }} /><span className="text-sm font-semibold">{label}</span></button>)}</div></motion.div></motion.div>}</AnimatePresence><ModelSheet open={modelOpen} onClose={() => setModelOpen(false)} model={model} setModel={setModel} /></>; }
function DiffDrawer({ diff, onClose }) { const lines = [[" ", "import jwt from 'jsonwebtoken';"], ["+", "import { refreshTokenStore } from './token-store';"], ["-", "const token = req.headers.authorization?.split(' ')[1];"], ["+", "const accessToken = req.headers.authorization?.split(' ')[1];"], ["+", "if (!accessToken) return res.status(401).json({ error: 'No token' });"], ["-", "const decoded = jwt.verify(token, AUTH_SECRET);"], ["+", "const decoded = jwt.verify(accessToken, AUTH_SECRET, { ignoreExpiration: false });"], ["+", "await refreshTokenStore.assertVersion(decoded.userId, decoded.tokenVersion);"]]; return <AnimatePresence>{diff && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="absolute inset-0 z-50 flex flex-col bg-black/60" onClick={onClose}><motion.div initial={{ y: "100%" }} animate={{ y: 0 }} exit={{ y: "100%" }} className="mt-auto h-[76%] rounded-t-[32px] overflow-hidden" style={{ background: C.bg, borderTop: `1px solid ${C.line}` }} onClick={(e) => e.stopPropagation()}><div className="flex items-center gap-3 border-b p-4" style={{ borderColor: C.softLine }}><button onClick={onClose} className="grid h-9 w-9 place-items-center rounded-full" style={{ background: C.card }}><X size={18} /></button><div className="min-w-0 flex-1"><h3 className="truncate text-sm font-semibold">{diff.file}</h3><p className="font-mono text-xs"><span style={{ color: C.green }}>+{diff.added}</span> <span style={{ color: C.red }}>-{diff.removed}</span></p></div><button className="rounded-full px-3 py-1.5 text-xs font-semibold" style={{ background: C.card, color: C.text2 }}><Copy size={13} /></button></div><div className="h-full overflow-auto pb-20 font-mono text-xs leading-7" style={{ background: "#05070A" }}>{lines.map(([mark, text], i) => { const add = mark === "+"; const del = mark === "-"; return <div key={i} className="flex" style={{ background: add ? "rgba(94,225,154,.10)" : del ? "rgba(255,122,122,.10)" : "transparent" }}><span className="w-8 shrink-0 text-center" style={{ color: add ? C.green : del ? C.red : C.text3 }}>{mark}</span><span className="whitespace-pre pr-4" style={{ color: add ? C.green : del ? C.red : C.text2 }}>{text}</span></div>; })}</div></motion.div></motion.div>}</AnimatePresence>; }

export default function App() {
  const [connected, setConnected] = useState(false);
  const [connection, setConnection] = useState(null);
  const [sessions, setSessions] = useState(sessionsSeed);
  const [events, setEvents] = useState(baseEvents);
  const [selected, setSelected] = useState(null);
  const [broadcastOpen, setBroadcastOpen] = useState(false);
  const [newSessionOpen, setNewSessionOpen] = useState(false);
  const selectedSession = useMemo(() => sessions.find((s) => s.id === selected), [sessions, selected]);
  const openSession = (id) => { setSelected(id); setSessions((prev) => prev.map((s) => s.id === id ? { ...s, unread: 0 } : s)); };
  const updateSessionModel = (id, model) => setSessions((prev) => prev.map((s) => s.id === id ? { ...s, model } : s));
  const startNewSession = ({ path, prompt, model }) => {
    const now = Date.now();
    const repo = path.split("/").filter(Boolean).pop() || "workspace";
    const id = `session-${now}`;
    const title = prompt.split("\n")[0].slice(0, 26) || repo;
    const newSession = { id, title, dir: path, repo, branch: "main", model, state: "running", activity: "Starting Pi session", files: [repo], last: "Reading repository structure", time: "now", unread: 0, accent: C.orange };
    setSessions((prev) => [newSession, ...prev]);
    setEvents((prev) => ({ ...prev, [id]: [
      { id: `${id}-u`, type: "user", text: prompt, time: "now" },
      { id: `${id}-a`, type: "assistant", text: `Starting a new Pi session in ${path}. I’ll read the repository structure first, then plan the safest next action.` },
      { id: `${id}-tools`, type: "toolGroup", title: "Bootstrap workspace", status: "running", collapsedLabel: "pwd · list files · inspect repo", items: [
        { tool: "bash", label: "pwd", meta: "live" },
        { tool: "bash", label: "find . -maxdepth 2 -type f", meta: "queued" },
        { tool: "read_file", label: "README.md", meta: "queued" },
      ] },
    ] }));
    setSelected(id);
  };
  const sendBroadcast = ({ prompt, sessionIds, model }) => {
    const now = Date.now();
    setEvents((prev) => {
      const next = { ...prev };
      sessionIds.forEach((id) => {
        next[id] = [ ...(next[id] || []), { id: `b-u-${now}-${id}`, type: "user", text: `[Broadcast${model !== "Use current" ? ` · ${model}` : ""}] ${prompt}`, time: "now" }, { id: `b-a-${now}-${id}`, type: "assistant", text: "Received broadcast instruction. I’ll apply it to this session and keep the output compact." } ];
      });
      return next;
    });
    setSessions((prev) => prev.map((s) => sessionIds.includes(s.id) ? { ...s, unread: s.unread + 1, last: `Broadcast: ${prompt}`, time: "now", state: s.state === "idle" ? "running" : s.state } : s));
  };
  return (
    <Phone>
      <div className="relative h-full overflow-hidden" style={{ background: C.bg, color: C.text }}>
        <AnimatePresence mode="wait">
          {!connected ? (
            <motion.div key="connect" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="absolute inset-0"><ConnectionScreen onConnect={(c) => { setConnection(c); setConnected(true); }} /></motion.div>
          ) : selectedSession ? (
            <motion.div key="session" initial={{ x: 80, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={{ x: 80, opacity: 0 }} className="absolute inset-0"><SessionScreen session={selectedSession} events={events} setEvents={setEvents} goBack={() => setSelected(null)} updateSessionModel={updateSessionModel} /></motion.div>
          ) : (
            <motion.div key="list" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="absolute inset-0"><SessionListScreen connection={connection} sessions={sessions} openSession={openSession} onBroadcast={() => setBroadcastOpen(true)} onNewSession={() => setNewSessionOpen(true)} onDisconnect={() => { setConnected(false); setSelected(null); }} /></motion.div>
          )}
        </AnimatePresence>
        <BroadcastSheet open={broadcastOpen} onClose={() => setBroadcastOpen(false)} sessions={sessions} onSend={sendBroadcast} />
        <NewSessionSheet open={newSessionOpen} onClose={() => setNewSessionOpen(false)} onStart={startNewSession} />
      </div>
    </Phone>
  );
}
