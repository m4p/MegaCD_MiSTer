# Debug Webserver Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Python HTTP server with a small browser UI that exposes the existing `mcd_debugd` functionality over the network on MiSTer.

**Architecture:** Keep `mcd_debugd` as the single mailbox transport implementation and build a thin Python web layer on top of it. The Python process serves static HTML and JSON endpoints, proxies requests to a local `mcd_debugd` instance over localhost TCP, and can manage that child process so operators only need to start one service.

**Tech Stack:** Python 3 standard library (`http.server`, `socket`, `subprocess`, `threading`, `json`), existing `linux/debug_bridge/mcd_debugd`, static HTML/CSS/JS.

---

### Task 1: Add the Python server skeleton

**Files:**
- Create: `linux/debug_bridge/mcd_debug_web.py`
- Modify: `linux/debug_bridge/.gitignore`

**Step 1: Write the server entry point**

- Parse CLI flags for HTTP bind/port and backend bind/port.
- Default HTTP bind to `127.0.0.1`.
- Default backend bind to `127.0.0.1`.

**Step 2: Add backend transport helpers**

- Implement a function that sends one newline-delimited JSON request to `mcd_debugd`.
- Return parsed JSON or a structured transport error.

**Step 3: Add child-process management**

- Start `mcd_debugd` as a child when requested.
- Stop it cleanly on exit.

**Step 4: Add `.gitignore` entries**

- Ignore Python cache files.

**Step 5: Verify syntax**

Run: `python3 -m py_compile linux/debug_bridge/mcd_debug_web.py`
Expected: success

### Task 2: Add HTTP API routes

**Files:**
- Modify: `linux/debug_bridge/mcd_debug_web.py`

**Step 1: Add health and metadata routes**

- `GET /api/health`
- `GET /api/targets`

**Step 2: Add a generic command proxy route**

- `POST /api/command`
- Accept the same JSON objects used by `mcd_debugd`.

**Step 3: Add response normalization**

- Preserve `mcd_debugd` success/error payloads.
- Return HTTP 400 for malformed JSON.
- Return HTTP 502 for backend transport failures.

**Step 4: Add serialization**

- Ensure requests are serialized through the existing daemon behavior.

**Step 5: Verify locally**

Run: `python3 linux/debug_bridge/mcd_debug_web.py --help`
Expected: usage text

### Task 3: Add a small browser UI

**Files:**
- Modify: `linux/debug_bridge/mcd_debug_web.py`

**Step 1: Serve a static HTML page**

- `GET /`
- Include controls for:
  - pause/resume
  - access mode
  - target capabilities
  - read/write requests

**Step 2: Add minimal JS**

- Use `fetch()` against `/api/command`.
- Render raw JSON results visibly.

**Step 3: Add guardrails**

- Default the form to safe operations.
- Require the user to choose target and width explicitly.

**Step 4: Keep it dependency-free**

- Inline CSS/JS instead of adding a frontend toolchain.

**Step 5: Verify syntax**

Run: `python3 -m py_compile linux/debug_bridge/mcd_debug_web.py`
Expected: success

### Task 4: Add operator documentation

**Files:**
- Modify: `docs/debug-bridge.md`
- Modify: `README.MD`

**Step 1: Document build and run commands**

- Show how to build `mcd_debugd`.
- Show how to run `mcd_debug_web.py`.

**Step 2: Document HTTP routes**

- `/`
- `/api/health`
- `/api/targets`
- `/api/command`

**Step 3: Document remote-use guidance**

- Explain localhost-default bind.
- Explain `--listen-all`.

**Step 4: Add browser usage examples**

- Read, write, pause, resume examples.

**Step 5: Review for consistency**

- Keep route names and flags aligned with implementation.

### Task 5: Verify end-to-end behavior available in this environment

**Files:**
- No file changes required

**Step 1: Compile the C++ backend**

Run: `make -C linux/debug_bridge CXX=clang++`
Expected: success

**Step 2: Syntax-check the Python server**

Run: `python3 -m py_compile linux/debug_bridge/mcd_debug_web.py`
Expected: success

**Step 3: Start the web server without hardware traffic**

Run: `python3 linux/debug_bridge/mcd_debug_web.py --help`
Expected: usage text

**Step 4: If safe, start with managed backend disabled**

Run: `python3 linux/debug_bridge/mcd_debug_web.py --no-spawn-backend`
Expected: server startup log

**Step 5: Commit**

```bash
git add README.MD docs/debug-bridge.md docs/plans/2026-03-26-debug-webserver.md linux/debug_bridge
git commit -m "feat: add debug bridge web server"
```
