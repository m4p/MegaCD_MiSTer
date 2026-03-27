# MiSTer Sega CD Debug Byte Search Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a byte-pattern search command that can locate the first occurrence of reverse-engineered code or data in a debug target and expose it consistently through the FPGA mailbox, MiSTer daemon, web API/UI, and MCP server.

**Architecture:** Extend the existing mailbox with a `SEARCH_BYTES` command that reuses the 32-byte data window as command input for the needle, scans a requested target/range in the FPGA bridge, and returns a found/not-found result plus the first match address. Mirror that contract in the daemon JSON API, the web server, and the MCP tool surface.

**Tech Stack:** SystemVerilog, existing MiSTer HPS mailbox transport, C++17, Python 3, browser JavaScript, MCP JSON-RPC.

---

### Task 1: Define the mailbox contract for search

**Files:**
- Modify: `MegaCD_MiSTer/rtl/mcd_debug_defs.vh`
- Modify: `MegaCD_MiSTer/docs/debug-bridge.md`

**Step 1: Add the command id**

Define a new mailbox opcode for byte search.

**Step 2: Define parameter/result semantics**

Document:
- `TARGET`: target to scan
- `ADDR`: inclusive search start
- `LENGTH`: byte span to scan
- `WDATA_LO[7:0]`: needle length in bytes
- `DATA[0..15]`: needle bytes before execution

Document results:
- `STATUS.data_valid = 1` when a match is found
- `DATA[0..1]` return the first match address
- success with `data_valid = 0` means not found

**Step 3: Document limits**

Specify:
- needle length `1..32`
- range length must be at least the needle length
- search uses the same live/paused capability rules as reads

### Task 2: Implement FPGA byte search

**Files:**
- Modify: `MegaCD_MiSTer/rtl/mcd_debug_bridge.sv`

**Step 1: Allow the data window to accept host-written needle bytes**

When idle, writes to `DATA[0..15]` should populate the internal window so the host can stage a search pattern.

**Step 2: Snapshot search inputs on execute**

On `EXEC_ID`:
- copy the staged needle bytes into search state
- decode needle length from `WDATA_LO[7:0]`
- validate target/mode/range/needle length

**Step 3: Add search state machine flow**

Implement a sliding-window search that:
- reads bytes through the existing SDRAM/BRAM/Word RAM backends
- compares sequentially against the staged needle
- stops on the first match
- returns success without `data_valid` when no match exists in the range

**Step 4: Return the first match address**

On match:
- set `data_window[0]` and `data_window[1]` to the 32-bit address
- set `data_valid`
- finish successfully

### Task 3: Extend the MiSTer daemon

**Files:**
- Modify: `MegaCD_MiSTer/linux/debug_bridge/mcd_debugd.cpp`

**Step 1: Add mailbox support for staging data-window bytes**

Add helpers to:
- write arbitrary bytes into `DATA[0..15]`
- decode search results from `DATA[0..1]`

**Step 2: Add JSON command handling**

Support:
- `{"cmd":"search_bytes","target":"...","addr":N,"length":N,"data":[...]}`

Validate:
- byte array length `1..32`
- each byte `0..255`
- non-negative address and range

**Step 3: Return structured search results**

Return:
- `found`
- `match_addr` when found
- echoed `target`, `addr`, `length`, and `data`
- normal warning/mode metadata

### Task 4: Extend the web API and UI

**Files:**
- Modify: `MegaCD_MiSTer/linux/debug_bridge/mcd_debug_web.py`

**Step 1: Keep the HTTP proxy generic**

Ensure the proxy continues forwarding `search_bytes` without special casing in the backend client path.

**Step 2: Add a search form**

Add UI controls for:
- target
- start address
- search length
- hex byte sequence

**Step 3: Normalize UI input**

Parse common hex input such as:
- `12 34 56 78`
- `12,34,56,78`
- `0x12 0x34`

Send the parsed bytes as the `data` array.

### Task 5: Extend MCP

**Files:**
- Modify: `MegaCD_MiSTer/linux/debug_bridge/mcd_debug_mcp.py`

**Step 1: Add a dedicated tool**

Expose `search_bytes` with arguments:
- `target`
- `addr`
- `length`
- `data`

**Step 2: Validate tool input**

Reject:
- empty arrays
- arrays longer than 32 bytes
- values outside `0..255`

**Step 3: Forward to the HTTP bridge**

Call `/api/command` with the daemon payload and return the structured backend response.

### Task 6: Verify and document

**Files:**
- Modify: `MegaCD_MiSTer/docs/debug-bridge.md`

**Step 1: Rebuild the daemon**

Run: `make -C linux/debug_bridge`
Expected: `mcd_debugd` builds successfully.

**Step 2: Syntax-check Python**

Run: `python3 -m py_compile linux/debug_bridge/mcd_debug_web.py linux/debug_bridge/mcd_debug_mcp.py`
Expected: no output.

**Step 3: Smoke-test the daemon JSON path**

Run a local command example:

```sh
./linux/debug_bridge/mcd_debugd --command '{"cmd":"search_bytes","target":"md68k_ram","addr":0,"length":256,"data":[0,1,2,3]}'
```

Expected:
- parses cleanly
- reaches the new command path
- returns structured success/error JSON depending on hardware availability

