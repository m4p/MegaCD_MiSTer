# MiSTer Sega CD Debug Bridge Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a safe remote peek/poke bridge for the MiSTer Sega CD core that can read and write selected memory targets over the existing HPS sideband, with explicit pause/live policy and honest per-target capability reporting.

**Architecture:** Reuse the existing `EXT_BUS` path already wired through `hps_io`/`hps_ext` instead of inventing a new HPS bridge. Add a register mailbox on `EXT_BUS`, a debug transaction engine in the FPGA top level, a real pause handshake into `gen.sv` and `MCD`, and a standalone MiSTer-side daemon that uses the same SPI-style transport as upstream `Main_MiSTer`.

**Tech Stack:** SystemVerilog, VHDL, MiSTer HPS/FPGA SPI sideband transport, POSIX sockets, minimal C++ userspace on MiSTer Linux.

---

### Task 1: Define the mailbox/register protocol and target policy

**Files:**
- Modify: `MegaCD_MiSTer/rtl/hps_ext.v`
- Create: `MegaCD_MiSTer/rtl/mcd_debug_pkg.sv`
- Create: `MegaCD_MiSTer/docs/debug-bridge.md`

**Step 1: Add shared constants**

Create a small SV package with:
- debug `EXT_BUS` command IDs
- mailbox register indexes
- debug command IDs
- target IDs
- capability bit definitions
- error codes

**Step 2: Document target mapping**

Record the real mapping used by this core:
- `md68k_ram` -> Genesis work RAM in `sdram` bank 1
- `subcpu_ram` -> alias of `prgram`
- `prgram` -> Sega CD PRG-RAM in `sdram` bank 0
- `wordram` -> raw physical Word RAM (2M linear view, not host-window remapped)
- `bram` / `backup_ram` -> Sega CD backup RAM in top-level `dpram_dif`

**Step 3: Define the capability table**

Ship only what the RTL proves:
- `md68k_ram`: live read, paused read, paused write
- `subcpu_ram`/`prgram`: live read, paused read, paused write
- `wordram`: paused read, paused write
- `backup_ram`: live read, paused read, paused write

### Task 2: Extend `hps_ext` into a generic debug mailbox transport

**Files:**
- Modify: `MegaCD_MiSTer/rtl/hps_ext.v`
- Modify: `MegaCD_MiSTer/MegaCD.sv`

**Step 1: Keep existing CD commands untouched**

Leave `UIO_CD_GET`/`UIO_CD_SET` behavior intact.

**Step 2: Add debug register read/write commands**

Add new `EXT_BUS` commands:
- `DBG_REG_GET`
- `DBG_REG_SET`

Protocol shape:
- `GET`: command word, register index word, register value word
- `SET`: command word, register index word, register value word

**Step 3: Wire a generic register bus out of `hps_ext`**

Add outputs/inputs for:
- `dbg_reg_wr`
- `dbg_reg_addr`
- `dbg_reg_wdata`
- `dbg_reg_rdata`

### Task 3: Add the FPGA debug engine and mailbox state

**Files:**
- Create: `MegaCD_MiSTer/rtl/mcd_debug_bridge.sv`
- Modify: `MegaCD_MiSTer/MegaCD.sv`
- Modify: `MegaCD_MiSTer/files.qip`

**Step 1: Implement mailbox registers**

Expose registers for:
- protocol/version
- status
- last error
- access mode
- command
- target
- address low/high
- transfer length
- write data words
- read data words / block window
- exec sequence / done sequence

**Step 2: Implement command state machine**

Handle:
- `PAUSE`
- `RESUME`
- `SET_ACCESS_MODE`
- `GET_ACCESS_MODE`
- `GET_TARGET_CAPS`
- `READ8/16/32`
- `WRITE8/16/32`
- `READ_BLOCK` (small bounded chunk for v1)

**Step 3: Report busy/done/error honestly**

Status bits must distinguish:
- busy
- done
- error
- warning
- paused state
- current access mode

### Task 4: Add a real pause handshake

**Files:**
- Modify: `MegaCD_MiSTer/rtl/GEN/gen.sv`
- Modify: `MegaCD_MiSTer/rtl/MCD/ASIC.vhd`
- Modify: `MegaCD_MiSTer/rtl/MCD/MCD.vhd`
- Modify: `MegaCD_MiSTer/MegaCD.sv`

**Step 1: Add `gen.sv` pause request/ack**

Implement:
- `PAUSE_REQ`
- `PAUSE_ACK`

Rules:
- finish any in-flight MBUS/ZBUS work
- refuse new MBUS/ZBUS work once pause is latched
- stop 68k/Z80 clock enables only after the idle boundary is reached

**Step 2: Add `MCD`/`ASIC` pause request/idle**

Implement:
- an ASIC idle indication derived from the existing PRG/WordRAM/DMA/PCM/halt state machines
- a `MCD` pause input that disables internal progression only after the idle condition is met
- output quiescing for PRG/WordRAM/BRAM writes while paused

**Step 3: Make paused mode explicit**

The bridge should only execute paused-only targets when both the Genesis and Mega CD sides report paused/idle.

### Task 5: Add target backends and arbitration

**Files:**
- Modify: `MegaCD_MiSTer/MegaCD.sv`
- Modify: `MegaCD_MiSTer/rtl/MCD/MCD.vhd`

**Step 1: Share the spare SDRAM port with debug**

Refactor `sdram` port 2 muxing so debug accesses can use it when ROM download/save traffic is idle.

Use it for:
- `md68k_ram`
- `prgram`
- `subcpu_ram` alias

**Step 2: Share backup RAM port B with debug**

Refactor the existing `dpram_dif` port B mux so the debug engine can read/write backup RAM when SD save/load is not using that port.

**Step 3: Add raw Word RAM paused access**

Expose a small debug port into `MCD.vhd` that directly multiplexes the physical Word RAM blocks while paused.

### Task 6: Add the MiSTer-side daemon and CLI

**Files:**
- Create: `MegaCD_MiSTer/linux/debug_bridge/Makefile`
- Create: `MegaCD_MiSTer/linux/debug_bridge/mister_fpga_io.cpp`
- Create: `MegaCD_MiSTer/linux/debug_bridge/mister_fpga_io.h`
- Create: `MegaCD_MiSTer/linux/debug_bridge/megacd_debugd.cpp`
- Create: `MegaCD_MiSTer/linux/debug_bridge/megacd_debugctl.cpp`

**Step 1: Reuse upstream MiSTer transport style**

Mirror the needed pieces of `fpga_io.cpp`/`spi.cpp` from upstream `Main_MiSTer` so the daemon talks to the core the same way `support/megacd/megacd.cpp` talks to `UIO_CD_GET`/`UIO_CD_SET`.

**Step 2: Implement a serialized mailbox client**

One in-process mutex, one outstanding transaction at a time, timeout-based polling on `busy/done`.

**Step 3: Expose newline-delimited JSON over TCP**

Support:
- bind address/port config
- localhost by default
- commands matching the requested API
- explicit JSON errors for unsupported targets/modes/timeouts

**Step 4: Add a small CLI**

Provide a thin local client for smoke testing:
- `get_target_caps`
- `pause`
- `resume`
- `read16`
- `write16`

### Task 7: Document and verify

**Files:**
- Create: `MegaCD_MiSTer/docs/debug-bridge.md`
- Modify: `MegaCD_MiSTer/README.MD`

**Step 1: Document the architecture**

Cover:
- HPS transport
- mailbox registers
- pause semantics
- target mapping
- capability bits
- access-mode behavior
- live-mode limitations

**Step 2: Add usage examples**

Show JSON requests/responses for:
- pause/resume
- caps query
- live read
- paused write
- rejected live write

**Step 3: Run verification commands**

Use the available local checks:
- `iverilog`/`verilator` if present for new SV syntax sanity
- compile the daemon with `make`
- at minimum run syntax-oriented checks and capture failures honestly if the toolchain is absent
