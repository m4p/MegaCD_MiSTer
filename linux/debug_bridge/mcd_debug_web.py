#!/usr/bin/env python3

import argparse
import atexit
import json
import socket
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


TARGETS = [
    {
        "name": "md68k_ram",
        "label": "MD 68k RAM",
        "note": "Genesis main 68k work RAM",
    },
    {
        "name": "subcpu_ram",
        "label": "Sub-CPU RAM",
        "note": "Alias of PRG-RAM in this core",
    },
    {
        "name": "wordram",
        "label": "Word RAM",
        "note": "Physical banks only, paused-only in v1",
    },
    {
        "name": "prgram",
        "label": "PRG-RAM",
        "note": "Sega CD PRG-RAM",
    },
    {
        "name": "backup_ram",
        "label": "Backup RAM",
        "note": "Sega CD backup RAM",
    },
]


HTML_PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MiSTer MegaCD Debug Bridge</title>
  <style>
    :root {
      --bg: #f3ead9;
      --panel: #fffaf0;
      --ink: #1f1b17;
      --muted: #6e6257;
      --line: #d9c9b1;
      --accent: #006d77;
      --accent-2: #c97d3a;
      --danger: #a33c2e;
      --ok: #2f7d32;
      --shadow: rgba(31, 27, 23, 0.08);
      --mono: "SFMono-Regular", "Menlo", "Consolas", monospace;
      --sans: "Avenir Next", "Helvetica Neue", sans-serif;
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      font-family: var(--sans);
      color: var(--ink);
      background:
        radial-gradient(circle at top left, rgba(201, 125, 58, 0.15), transparent 22rem),
        linear-gradient(180deg, #f8f1e5 0%, var(--bg) 55%, #efe2cd 100%);
      min-height: 100vh;
    }

    .shell {
      max-width: 1180px;
      margin: 0 auto;
      padding: 24px 18px 40px;
    }

    .hero {
      display: grid;
      grid-template-columns: 1.3fr 0.7fr;
      gap: 18px;
      margin-bottom: 18px;
    }

    .card {
      background: color-mix(in srgb, var(--panel) 92%, white 8%);
      border: 1px solid var(--line);
      border-radius: 18px;
      box-shadow: 0 12px 30px var(--shadow);
      padding: 18px;
    }

    h1, h2, h3 {
      margin: 0 0 10px;
      line-height: 1.05;
      letter-spacing: -0.02em;
    }

    h1 {
      font-size: clamp(1.9rem, 4vw, 3.2rem);
      max-width: 12ch;
    }

    p {
      margin: 0;
      color: var(--muted);
      line-height: 1.45;
    }

    .grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 18px;
    }

    .status-strip {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      margin-top: 14px;
    }

    .pill {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 8px 12px;
      border-radius: 999px;
      background: rgba(0, 109, 119, 0.08);
      border: 1px solid rgba(0, 109, 119, 0.16);
      font-size: 0.95rem;
    }

    .pill.bad {
      background: rgba(163, 60, 46, 0.08);
      border-color: rgba(163, 60, 46, 0.16);
    }

    .pill.good {
      background: rgba(47, 125, 50, 0.08);
      border-color: rgba(47, 125, 50, 0.16);
    }

    .toolbar, .form-grid {
      display: grid;
      gap: 12px;
    }

    .toolbar {
      grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
      margin-top: 14px;
    }

    .form-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    label {
      display: grid;
      gap: 6px;
      font-size: 0.9rem;
      color: var(--muted);
    }

    input, select, textarea, button {
      font: inherit;
    }

    input, select, textarea {
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 12px;
      padding: 10px 12px;
      background: #fffdf9;
      color: var(--ink);
    }

    textarea {
      min-height: 132px;
      resize: vertical;
      font-family: var(--mono);
      font-size: 0.92rem;
    }

    button {
      border: 0;
      border-radius: 14px;
      padding: 11px 14px;
      background: var(--accent);
      color: white;
      cursor: pointer;
      font-weight: 600;
      box-shadow: inset 0 -1px 0 rgba(0, 0, 0, 0.18);
      transition: transform 120ms ease, opacity 120ms ease;
    }

    button:hover { transform: translateY(-1px); }
    button:disabled { opacity: 0.5; cursor: default; transform: none; }
    button.secondary { background: var(--accent-2); }
    button.ghost {
      background: transparent;
      color: var(--ink);
      border: 1px solid var(--line);
      box-shadow: none;
    }
    button.danger { background: var(--danger); }

    .button-row {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      margin-top: 14px;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.92rem;
    }

    th, td {
      text-align: left;
      padding: 10px 8px;
      border-top: 1px solid var(--line);
      vertical-align: top;
    }

    th {
      color: var(--muted);
      font-weight: 600;
      font-size: 0.82rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    .mono {
      font-family: var(--mono);
      font-size: 0.9rem;
    }

    pre {
      margin: 0;
      padding: 14px;
      border-radius: 14px;
      background: #201a16;
      color: #f4ede5;
      overflow: auto;
      font-family: var(--mono);
      font-size: 0.9rem;
      line-height: 1.45;
      min-height: 220px;
    }

    .small {
      font-size: 0.88rem;
      color: var(--muted);
    }

    @media (max-width: 900px) {
      .hero, .grid, .form-grid {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body>
  <div class="shell">
    <section class="hero">
      <article class="card">
        <h1>MegaCD debug bridge web console</h1>
        <p>
          Thin HTTP layer over <span class="mono">mcd_debugd</span>. Safe by default: local-only bind, explicit
          paused workflow for writes, and capability-driven live access.
        </p>
        <div class="status-strip" id="statusStrip">
          <span class="pill">Loading status…</span>
        </div>
        <div class="button-row">
          <button id="refreshStatus">Refresh Status</button>
          <button class="ghost" id="refreshCaps">Refresh Capabilities</button>
        </div>
      </article>
      <aside class="card">
        <h2>Safety notes</h2>
        <p class="small">
          Writes should use <span class="mono">pause</span> plus <span class="mono">paused</span> mode unless a target
          explicitly reports live-write support. In v1, no targets advertise live writes.
        </p>
      </aside>
    </section>

    <section class="grid">
      <article class="card">
        <h2>Control</h2>
        <div class="toolbar">
          <button id="pauseBtn">Pause</button>
          <button class="secondary" id="resumeBtn">Resume</button>
          <button class="ghost" id="modeReadBtn">Get Mode</button>
        </div>
        <div class="form-grid" style="margin-top:14px">
          <label>
            Access Mode
            <select id="accessMode">
              <option value="paused">paused</option>
              <option value="live">live</option>
            </select>
          </label>
        </div>
        <div class="button-row">
          <button id="modeSetBtn">Set Access Mode</button>
        </div>
      </article>

      <article class="card">
        <h2>Memory Request</h2>
        <div class="form-grid">
          <label>
            Command
            <select id="command">
              <option value="read8">read8</option>
              <option value="read16">read16</option>
              <option value="read32">read32</option>
              <option value="read_block">read_block</option>
              <option value="write8">write8</option>
              <option value="write16">write16</option>
              <option value="write32">write32</option>
            </select>
          </label>
          <label>
            Target
            <select id="target"></select>
          </label>
          <label>
            Address
            <input id="addr" type="text" value="0" spellcheck="false">
          </label>
          <label id="valueField">
            Value
            <input id="value" type="text" value="0" spellcheck="false">
          </label>
          <label id="lengthField" style="display:none">
            Length
            <input id="length" type="number" min="1" max="32" value="16">
          </label>
        </div>
        <div class="button-row">
          <button id="sendBtn">Send Request</button>
        </div>
      </article>

      <article class="card">
        <h2>Targets</h2>
        <div style="overflow:auto">
          <table>
            <thead>
              <tr>
                <th>Target</th>
                <th>Live R</th>
                <th>Live W</th>
                <th>Paused R</th>
                <th>Paused W</th>
                <th>Notes</th>
              </tr>
            </thead>
            <tbody id="targetsBody">
              <tr><td colspan="6">Loading…</td></tr>
            </tbody>
          </table>
        </div>
      </article>

      <article class="card">
        <h2>Raw JSON</h2>
        <label>
          Request
          <textarea id="rawJson">{&quot;cmd&quot;:&quot;get_target_caps&quot;}</textarea>
        </label>
        <div class="button-row">
          <button class="ghost" id="rawSendBtn">POST /api/command</button>
        </div>
      </article>
    </section>

    <section class="card" style="margin-top:18px">
      <h2>Response</h2>
      <pre id="output">Waiting for first request…</pre>
    </section>
  </div>

  <script>
    const state = {
      targets: [],
      caps: {}
    };

    const els = {
      statusStrip: document.getElementById("statusStrip"),
      output: document.getElementById("output"),
      target: document.getElementById("target"),
      command: document.getElementById("command"),
      valueField: document.getElementById("valueField"),
      lengthField: document.getElementById("lengthField"),
      targetsBody: document.getElementById("targetsBody"),
      rawJson: document.getElementById("rawJson")
    };

    function pretty(value) {
      return JSON.stringify(value, null, 2);
    }

    async function api(path, options = {}) {
      const response = await fetch(path, {
        headers: { "Content-Type": "application/json" },
        ...options
      });
      const data = await response.json();
      return { response, data };
    }

    function setOutput(data) {
      els.output.textContent = pretty(data);
    }

    function parseMaybeNumber(value) {
      const trimmed = value.trim();
      if (!trimmed) return 0;
      if (/^0x/i.test(trimmed)) return Number.parseInt(trimmed, 16);
      return Number.parseInt(trimmed, 10);
    }

    function renderStatus(data) {
      const pills = [];
      pills.push(`<span class="pill ${data.ok ? "good" : "bad"}">HTTP ${data.ok ? "ready" : "degraded"}</span>`);
      pills.push(`<span class="pill ${data.backend_running ? "good" : "bad"}">Backend process ${data.backend_running ? "up" : "down"}</span>`);
      pills.push(`<span class="pill ${data.backend_connected ? "good" : "bad"}">Backend link ${data.backend_connected ? "ok" : "failed"}</span>`);
      if (data.access_mode) pills.push(`<span class="pill">Mode ${data.access_mode}</span>`);
      if (data.backend_error) pills.push(`<span class="pill bad">${data.backend_error}</span>`);
      els.statusStrip.innerHTML = pills.join("");
    }

    function renderTargets(targets) {
      state.targets = targets;
      state.caps = Object.fromEntries(targets.map((target) => [target.name, target]));

      els.target.innerHTML = targets
        .map((target) => `<option value="${target.name}">${target.name}</option>`)
        .join("");

      els.targetsBody.innerHTML = targets
        .map((target) => `
          <tr>
            <td class="mono">${target.name}</td>
            <td>${target.supports_live_read ? "yes" : "no"}</td>
            <td>${target.supports_live_write ? "yes" : "no"}</td>
            <td>${target.supports_paused_read ? "yes" : "no"}</td>
            <td>${target.supports_paused_write ? "yes" : "no"}</td>
            <td>${target.note || ""}</td>
          </tr>
        `)
        .join("");
    }

    function syncCommandFields() {
      const command = els.command.value;
      const isWrite = command.startsWith("write");
      const isBlock = command === "read_block";
      els.valueField.style.display = isWrite ? "grid" : "none";
      els.lengthField.style.display = isBlock ? "grid" : "none";
    }

    async function refreshStatus() {
      const { data } = await api("/api/health");
      renderStatus(data);
      setOutput(data);
    }

    async function refreshTargets() {
      const { data } = await api("/api/targets");
      if (data.ok && Array.isArray(data.targets)) {
        renderTargets(data.targets);
      }
      setOutput(data);
    }

    async function sendCommand(payload) {
      const { data } = await api("/api/command", {
        method: "POST",
        body: JSON.stringify(payload)
      });
      setOutput(data);
      await refreshStatus();
      return data;
    }

    document.getElementById("pauseBtn").addEventListener("click", () => sendCommand({ cmd: "pause" }));
    document.getElementById("resumeBtn").addEventListener("click", () => sendCommand({ cmd: "resume" }));
    document.getElementById("modeReadBtn").addEventListener("click", () => sendCommand({ cmd: "get_access_mode" }));
    document.getElementById("modeSetBtn").addEventListener("click", () => sendCommand({
      cmd: "set_access_mode",
      mode: document.getElementById("accessMode").value
    }));
    document.getElementById("refreshStatus").addEventListener("click", refreshStatus);
    document.getElementById("refreshCaps").addEventListener("click", refreshTargets);

    document.getElementById("sendBtn").addEventListener("click", () => {
      const command = els.command.value;
      const payload = {
        cmd: command,
        target: els.target.value,
        addr: parseMaybeNumber(document.getElementById("addr").value)
      };
      if (command === "read_block") {
        payload.length = parseMaybeNumber(document.getElementById("length").value);
      }
      if (command.startsWith("write")) {
        payload.value = parseMaybeNumber(document.getElementById("value").value);
      }
      sendCommand(payload);
    });

    document.getElementById("rawSendBtn").addEventListener("click", () => {
      try {
        const payload = JSON.parse(els.rawJson.value);
        sendCommand(payload);
      } catch (error) {
        setOutput({ ok: false, error: String(error) });
      }
    });

    els.command.addEventListener("change", syncCommandFields);
    syncCommandFields();
    refreshStatus().catch((error) => setOutput({ ok: false, error: String(error) }));
    refreshTargets().catch((error) => setOutput({ ok: false, error: String(error) }));
  </script>
</body>
</html>
"""


class BackendError(RuntimeError):
    pass


class DebugBackendClient:
    def __init__(self, host: str, port: int, timeout_ms: int):
        self.host = host
        self.port = port
        self.timeout = timeout_ms / 1000.0
        self._lock = threading.Lock()

    def command(self, payload: dict) -> dict:
        request = json.dumps(payload, separators=(",", ":")) + "\n"
        with self._lock:
            try:
                with socket.create_connection((self.host, self.port), timeout=self.timeout) as sock:
                    sock.settimeout(self.timeout)
                    sock.sendall(request.encode("utf-8"))
                    response = self._readline(sock)
            except OSError as exc:
                raise BackendError(str(exc)) from exc

        try:
            return json.loads(response)
        except json.JSONDecodeError as exc:
            raise BackendError(f"invalid backend JSON: {exc}") from exc

    def ping(self) -> dict:
        return self.command({"cmd": "get_access_mode"})

    @staticmethod
    def _readline(sock: socket.socket) -> str:
        chunks = []
        while True:
            chunk = sock.recv(4096)
            if not chunk:
                break
            chunks.append(chunk)
            if b"\n" in chunk:
                break
        data = b"".join(chunks)
        line = data.split(b"\n", 1)[0].strip()
        if not line:
            raise BackendError("empty backend response")
        return line.decode("utf-8")


class ManagedBackend:
    def __init__(
        self,
        backend_path: Path,
        backend_host: str,
        backend_port: int,
        backend_timeout_ms: int,
        spawn_backend: bool,
    ):
        self.backend_path = backend_path
        self.backend_host = backend_host
        self.backend_port = backend_port
        self.backend_timeout_ms = backend_timeout_ms
        self.spawn_backend = spawn_backend
        self.process = None
        self._spawned = False

    def start(self):
        if not self.spawn_backend:
            return
        if self.process is not None:
            return
        if not self.backend_path.exists():
            raise RuntimeError(f"backend binary not found: {self.backend_path}")

        cmd = [
            str(self.backend_path),
            "--bind",
            self.backend_host,
            "--port",
            str(self.backend_port),
            "--timeout-ms",
            str(self.backend_timeout_ms),
        ]
        self.process = subprocess.Popen(cmd)
        self._spawned = True
        self._wait_ready()

    def _wait_ready(self):
        deadline = time.time() + 3.0
        while time.time() < deadline:
            if self.process is not None and self.process.poll() is not None:
                raise RuntimeError(f"backend exited early with code {self.process.returncode}")
            try:
                with socket.create_connection((self.backend_host, self.backend_port), timeout=0.2):
                    return
            except OSError:
                time.sleep(0.1)
        raise RuntimeError("backend did not become ready in time")

    def stop(self):
        if not self._spawned or self.process is None:
            return
        if self.process.poll() is not None:
            return
        self.process.terminate()
        try:
            self.process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=2)

    def is_running(self) -> bool:
        return self.process is not None and self.process.poll() is None


class WebApp:
    def __init__(self, args):
        script_dir = Path(__file__).resolve().parent
        backend_path = Path(args.backend_path) if args.backend_path else script_dir / "mcd_debugd"
        self.backend = ManagedBackend(
            backend_path=backend_path,
            backend_host=args.backend_host,
            backend_port=args.backend_port,
            backend_timeout_ms=args.backend_timeout_ms,
            spawn_backend=args.spawn_backend,
        )
        self.client = DebugBackendClient(args.backend_host, args.backend_port, args.backend_timeout_ms)

    def start(self):
        self.backend.start()

    def stop(self):
        self.backend.stop()

    def health(self) -> tuple[int, dict]:
        payload = {
            "ok": True,
            "backend_running": self.backend.is_running() if self.backend.spawn_backend else True,
            "backend_connected": False,
            "backend_host": self.client.host,
            "backend_port": self.client.port,
        }
        try:
            response = self.client.ping()
            payload["backend_connected"] = True
            if response.get("ok") and "access_mode" in response:
                payload["access_mode"] = response["access_mode"]
            else:
                payload["ok"] = False
                payload["backend_reply"] = response
                return 503, payload
            return 200, payload
        except BackendError as exc:
            payload["ok"] = False
            payload["backend_error"] = str(exc)
            return 503, payload

    def targets(self) -> tuple[int, dict]:
        try:
            response = self.client.command({"cmd": "get_target_caps"})
        except BackendError as exc:
            return 502, {"ok": False, "error": str(exc), "error_code": "transport"}

        if not response.get("ok"):
            return 200, response

        caps_by_name = response.get("targets", {})
        targets = []
        for target in TARGETS:
            merged = dict(target)
            merged.update(caps_by_name.get(target["name"], {}))
            targets.append(merged)
        return 200, {"ok": True, "targets": targets}

    def command(self, payload: dict) -> tuple[int, dict]:
        try:
            response = self.client.command(payload)
        except BackendError as exc:
            return 502, {"ok": False, "error": str(exc), "error_code": "transport"}
        return 200, response


def build_handler(app: WebApp):
    class Handler(BaseHTTPRequestHandler):
        server_version = "mcd_debug_web/0.1"

        def do_GET(self):
            parsed = urlparse(self.path)
            if parsed.path == "/":
                self._send_html(200, HTML_PAGE)
                return
            if parsed.path == "/api/health":
                status, payload = app.health()
                self._send_json(status, payload)
                return
            if parsed.path == "/api/targets":
                status, payload = app.targets()
                self._send_json(status, payload)
                return
            self._send_json(404, {"ok": False, "error": "not_found"})

        def do_POST(self):
            parsed = urlparse(self.path)
            if parsed.path != "/api/command":
                self._send_json(404, {"ok": False, "error": "not_found"})
                return

            payload, error = self._read_json_body()
            if error is not None:
                self._send_json(400, {"ok": False, "error": error, "error_code": "invalid_json"})
                return
            if not isinstance(payload, dict):
                self._send_json(400, {"ok": False, "error": "request body must be a JSON object", "error_code": "invalid_json"})
                return

            status, response = app.command(payload)
            self._send_json(status, response)

        def _read_json_body(self):
            try:
                length = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                return None, "invalid content-length"

            body = self.rfile.read(length) if length else b"{}"
            try:
                return json.loads(body.decode("utf-8")), None
            except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                return None, str(exc)

        def _send_html(self, status: int, html: str):
            encoded = html.encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)

        def _send_json(self, status: int, payload: dict):
            encoded = (json.dumps(payload, indent=2, sort_keys=False) + "\n").encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)

        def log_message(self, fmt, *args):
            sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), fmt % args))

    return Handler


def parse_args():
    parser = argparse.ArgumentParser(description="HTTP bridge and small UI for mcd_debugd")
    parser.add_argument("--bind", default="127.0.0.1", help="HTTP bind host, default: 127.0.0.1")
    parser.add_argument("--listen-all", action="store_true", help="Bind HTTP server to 0.0.0.0")
    parser.add_argument("--port", type=int, default=8080, help="HTTP listen port, default: 8080")
    parser.add_argument("--backend-host", default="127.0.0.1", help="Backend mcd_debugd host, default: 127.0.0.1")
    parser.add_argument("--backend-port", type=int, default=24512, help="Backend mcd_debugd port, default: 24512")
    parser.add_argument("--backend-timeout-ms", type=int, default=750, help="Backend request timeout in ms")
    parser.add_argument("--backend-path", help="Path to mcd_debugd binary, default: sibling mcd_debugd")
    parser.add_argument(
        "--no-spawn-backend",
        dest="spawn_backend",
        action="store_false",
        help="Do not launch mcd_debugd automatically",
    )
    parser.set_defaults(spawn_backend=True)
    args = parser.parse_args()
    if args.listen_all:
        args.bind = "0.0.0.0"
    return args


def main():
    args = parse_args()
    app = WebApp(args)
    app.start()
    atexit.register(app.stop)

    handler = build_handler(app)
    server = ThreadingHTTPServer((args.bind, args.port), handler)
    try:
        print(f"mcd_debug_web listening on http://{args.bind}:{args.port}")
        print(f"backend target {args.backend_host}:{args.backend_port} spawn={args.spawn_backend}")
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        app.stop()


if __name__ == "__main__":
    main()
