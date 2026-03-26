# Debug MCP Server Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a local Python MCP server that targets one configured MiSTer `mcd_debug_web.py` instance and exposes debug bridge operations as MCP tools.

**Architecture:** Build a dependency-free stdio MCP server in Python that speaks the MCP JSON-RPC protocol directly over `Content-Length` framed messages. The server will target a single configured `mcd_debug_web.py` base URL, translate MCP tool calls into HTTP requests against `/api/health`, `/api/targets`, and `/api/command`, and return structured JSON results.

**Tech Stack:** Python 3 standard library (`json`, `sys`, `urllib.request`, `argparse`, `threading`, `dataclasses`), existing `linux/debug_bridge/mcd_debug_web.py`.

---

### Task 1: Add the MCP transport and server skeleton

**Files:**
- Create: `linux/debug_bridge/mcd_debug_mcp.py`

**Step 1: Parse CLI arguments**

- Add `--base-url`
- Add `--timeout`
- Default base URL to `http://127.0.0.1:8080`

**Step 2: Implement stdio framing**

- Read `Content-Length` framed JSON-RPC messages from stdin
- Write framed JSON-RPC responses to stdout

**Step 3: Implement MCP initialization flow**

- Support `initialize`
- Support `notifications/initialized`
- Support `ping`

**Step 4: Add basic server metadata**

- Server name
- Server version
- Tools capability

**Step 5: Verify syntax**

Run: `python3 -m py_compile linux/debug_bridge/mcd_debug_mcp.py`
Expected: success

### Task 2: Add the HTTP bridge client

**Files:**
- Modify: `linux/debug_bridge/mcd_debug_mcp.py`

**Step 1: Add GET helper**

- Fetch `/api/health`
- Fetch `/api/targets`

**Step 2: Add POST helper**

- Send JSON to `/api/command`
- Parse JSON response

**Step 3: Normalize errors**

- Return clear transport failures
- Preserve backend errors from `mcd_debug_web.py`

**Step 4: Keep it single-target**

- Use one configured base URL for the whole server instance

**Step 5: Verify syntax**

Run: `python3 -m py_compile linux/debug_bridge/mcd_debug_mcp.py`
Expected: success

### Task 3: Expose useful MCP tools

**Files:**
- Modify: `linux/debug_bridge/mcd_debug_mcp.py`

**Step 1: Add tool listing**

- `health`
- `targets`
- `pause`
- `resume`
- `get_access_mode`
- `set_access_mode`
- `get_target_caps`
- `read_memory`
- `write_memory`
- `raw_command`

**Step 2: Add JSON Schemas**

- Exact argument schema for each tool
- Keep schemas narrow and explicit

**Step 3: Add tool dispatch**

- Map each tool to the right HTTP request
- Return structured JSON results

**Step 4: Add tool error handling**

- Mark tool failures as MCP tool errors
- Include backend payloads where useful

**Step 5: Verify syntax**

Run: `python3 -m py_compile linux/debug_bridge/mcd_debug_mcp.py`
Expected: success

### Task 4: Document usage

**Files:**
- Modify: `docs/debug-bridge.md`
- Modify: `README.MD`
- Modify: `linux/debug_bridge/Makefile`

**Step 1: Add a Makefile check target**

- Add `check-mcp`

**Step 2: Document local run usage**

- Show CLI invocation
- Show base URL configuration

**Step 3: Document MCP tool list**

- Tool names
- Expected arguments

**Step 4: Document intended setup**

- `mcd_debug_web.py` runs on MiSTer
- `mcd_debug_mcp.py` runs locally

**Step 5: Review for consistency**

- Keep docs aligned with implementation names and flags

### Task 5: Verify with a fake local HTTP backend

**Files:**
- No file changes required

**Step 1: Syntax-check the server**

Run: `python3 -m py_compile linux/debug_bridge/mcd_debug_mcp.py`
Expected: success

**Step 2: Start a fake backend in-process**

- Serve `/api/health`
- Serve `/api/targets`
- Serve `/api/command`

**Step 3: Launch the MCP server against that fake backend**

- Use `--base-url http://127.0.0.1:<port>`

**Step 4: Send framed MCP requests**

- `initialize`
- `tools/list`
- `tools/call` for at least one read-style tool

**Step 5: Commit**

```bash
git add README.MD docs/debug-bridge.md docs/plans/2026-03-26-debug-mcp-server.md linux/debug_bridge
git commit -m "feat: add MiSTer debug MCP server"
```
