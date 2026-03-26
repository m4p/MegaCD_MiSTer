# MegaCD Savestates Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add proper MiSTer savestates to the MegaCD core, targeting gameplay-correct restore even if audio/video/CD pipelines need a short post-load settle period.

**Architecture:** Follow the proven MiSTer pattern used by savestate-capable cores: a small UI/front-end for slot/save/load requests, a central savestate controller that owns pause/quiesce plus DDR slot transfers, and explicit per-module save/load ports for every mutable hardware block that affects emulation correctness. Reuse the existing debug pause groundwork where it is trustworthy, but do not expose `SS...` in `CONF_STR` until CPU, VDP, Sega CD ASIC, CDC, and all mutable RAM/peripheral state can be serialized and restored honestly.

**Tech Stack:** SystemVerilog, VHDL, MiSTer `hps_io`/DDRAM framework, Quartus project files, hardware-smoke validation on MiSTer.

---

### Task 1: Freeze the savestate contract and reference architecture

**Files:**
- Create: `MegaCD_MiSTer/docs/savestates.md`
- Modify: `MegaCD_MiSTer/docs/plans/2026-03-26-megacd-savestates.md`
- Reference: `/tmp/PSX_MiSTer_51659/PSX.sv`
- Reference: `/tmp/PSX_MiSTer_51659/rtl/savestate_ui.sv`
- Reference: `/tmp/PSX_MiSTer_51659/rtl/savestates.vhd`

**Step 1: Document the supported restore target**

Write down the v1 promise explicitly:
- gameplay-correct restore
- no claim of cycle-exact audio/video continuity
- save/load only at explicit quiescent pause points
- no user-visible `SS...` enablement before all required state types are wired

**Step 2: Document the real state inventory**

List every mutable block that must be restored:
- Genesis main 68k CPU state
- Genesis Z80 CPU state
- Genesis main RAM, Z80 RAM, VDP VRAM/CRAM/VSRAM
- VDP control/DMA/FIFO/interrupt state
- YM2612 / PSG state needed for gameplay-safe timers/IRQs
- Mega CD sub-68k CPU state
- PRG-RAM, Word RAM, backup RAM, PCM RAM, CDC RAM
- Sega CD ASIC register/DMA/timer/IRQ/communication state
- CDC, PCM, and CDDA state
- top-level CD handshake state in `MegaCD.sv`

**Step 3: Define the savestate address map**

Reserve fixed regions for:
- header/control words
- Genesis CPU state
- Z80 state
- Genesis video/audio/control state
- Sega CD CPU state
- Sega CD ASIC/CDC/PCM/CDDA state
- RAM images

### Task 2: Add the user-facing MiSTer savestate request path

**Files:**
- Create: `MegaCD_MiSTer/rtl/savestate_ui.sv`
- Modify: `MegaCD_MiSTer/MegaCD.sv`
- Modify: `MegaCD_MiSTer/files.qip`

**Step 1: Import a local savestate UI helper**

Create `rtl/savestate_ui.sv` based on the PSX helper, trimmed to:
- selected slot
- save request
- load request
- valid-slot indicators
- keyboard and OSD-triggered actions

Do not add rewind handling in v1.

**Step 2: Allocate status bits and OSD hooks**

Extend `CONF_STR` in `MegaCD.sv` with:
- slot select
- save/load OSD action bits
- optional auto-increment slot bit

Keep the `SS...` declaration disabled until the controller and serializers are complete.

**Step 3: Wire the UI into top level**

Add:
- `ss_slot`
- `ss_save`
- `ss_load`
- `ss_valid`
- `ss_status_update`

### Task 3: Add the central savestate controller skeleton

**Files:**
- Create: `MegaCD_MiSTer/rtl/mcd_savestates.vhd`
- Modify: `MegaCD_MiSTer/files.qip`
- Modify: `MegaCD_MiSTer/MegaCD.sv`

**Step 1: Create a controller with no shortcuts**

Its interface must include:
- save/load requests
- slot number
- valid-slot outputs
- pause request / pause granted
- DDRAM master port
- per-block `SS_Adr`, `SS_wren`, `SS_rden`, `SS_DataWrite`, `SS_DataRead`

**Step 2: Define controller states**

Implement state enums for:
- idle
- request pause
- wait idle
- save header
- save blocks
- load header
- load blocks
- settle / reset release

**Step 3: Keep it dark until complete**

Do not connect it to `CONF_STR` or expose slots as valid until:
- the header read path works
- the block iteration works
- at least one serializer path is complete and tested

### Task 4: Add a trustworthy savestate pause/quiesce boundary

**Files:**
- Modify: `MegaCD_MiSTer/rtl/GEN/gen.sv`
- Modify: `MegaCD_MiSTer/rtl/MCD/MCD.vhd`
- Modify: `MegaCD_MiSTer/rtl/MCD/ASIC.vhd`
- Modify: `MegaCD_MiSTer/MegaCD.sv`

**Step 1: Split debug-pause and savestate-pause semantics**

Add dedicated savestate signals instead of overloading the debug bridge:
- `SS_PAUSE_REQ`
- `SS_PAUSE_ACK`

**Step 2: Make Genesis pause land on a safe bus boundary**

The Genesis side must:
- stop accepting new MBUS/ZBUS ownership changes once save is requested
- finish any in-flight 68k/Z80 bus work
- hold CPU clocks only after bus idle
- expose `SS_PAUSE_ACK`

**Step 3: Make Sega CD pause land on a safe ASIC boundary**

The Sega CD side must:
- wait for no active PRG/WordRAM/CDC/PCM/graphics DMA transaction
- freeze sub-CPU progression only after that point
- expose `SS_PAUSE_ACK`

### Task 5: Implement raw RAM image save/load blocks

**Files:**
- Modify: `MegaCD_MiSTer/MegaCD.sv`
- Modify: `MegaCD_MiSTer/rtl/MCD/MCD.vhd`
- Modify: `MegaCD_MiSTer/rtl/mcd_debug_bridge.sv` (only if existing memory ports can be reused cleanly)

**Step 1: Save/load Genesis work RAM and PRG-RAM**

Use existing SDRAM ports to serialize:
- Genesis main RAM
- Sega CD PRG-RAM

**Step 2: Save/load BRAM-backed memories**

Add explicit save/load accessors for:
- backup RAM
- Z80 RAM
- PCM RAM
- CDC RAM

**Step 3: Save/load Word RAM**

Use the existing paused-only debug-style access path in `MCD.vhd` as the basis for a sequential savestate transfer path.

### Task 6: Add main 68k and sub-68k savestate ports

**Files:**
- Modify: `MegaCD_MiSTer/rtl/FX68K/fx68k.sv`
- Modify: `MegaCD_MiSTer/rtl/MCD/MC68K.vhd`
- Modify: `MegaCD_MiSTer/rtl/GEN/gen.sv`
- Modify: `MegaCD_MiSTer/rtl/MCD/MCD.vhd`

**Step 1: Define a compact register image for `fx68k`**

Include at minimum:
- D0-D7
- A0-A7
- PC
- SR/CCR
- supervisor/user stack selection state
- instruction prefetch / microstate required for post-load correctness

**Step 2: Add explicit save/load ports**

Expose:
- `SS_Adr`
- `SS_wren`
- `SS_rden`
- `SS_DataWrite`
- `SS_DataRead`
- `loading_savestate`

**Step 3: Reuse for both 68k instances**

Use the same mechanism for:
- Genesis main 68k in `gen.sv`
- Sega CD sub-68k via `MC68K.vhd`

### Task 7: Add Z80 savestate ports

**Files:**
- Modify: `MegaCD_MiSTer/rtl/GEN/T80/T80.vhd`
- Modify: `MegaCD_MiSTer/rtl/GEN/T80/T80_Reg.vhd`
- Modify: `MegaCD_MiSTer/rtl/GEN/T80/T80pa.vhd`
- Modify: `MegaCD_MiSTer/rtl/GEN/gen.sv`

**Step 1: Decide the serialization layer**

Prefer serializing at the register-file / control-state level instead of reconstructing from external pins.

**Step 2: Capture gameplay-critical Z80 state**

Include:
- AF/BC/DE/HL and alternate sets
- IX/IY/SP/PC
- I/R
- interrupt flip-flops
- IM mode
- bus/request state that affects resumption

**Step 3: Thread load gating correctly**

Make sure `loading_savestate` can write state without normal instruction advancement.

### Task 8: Add Genesis VDP savestate ports

**Files:**
- Modify: `MegaCD_MiSTer/rtl/GEN/vdp.vhd`
- Modify: `MegaCD_MiSTer/rtl/GEN/gen.sv`

**Step 1: Save/load VDP memories**

Add sequential save/load access for:
- VRAM
- CRAM
- VSRAM

**Step 2: Save/load VDP control state**

Capture:
- register file
- pending code/address latch state
- DMA source/count state
- FIFO contents and queue state
- H/V interrupt pending state
- line/frame counters needed to resume safely

**Step 3: Allow post-load settle**

If exact pixel pipeline restart is not practical, document that restore resumes from a clean paused point and video may need up to a frame to settle.

### Task 9: Add Genesis sound/control savestate ports

**Files:**
- Modify: `MegaCD_MiSTer/rtl/GEN/gen.sv`
- Modify: `MegaCD_MiSTer/rtl/GEN/jt12/*` (only if required)
- Modify: `MegaCD_MiSTer/rtl/GEN/gen_io.sv`

**Step 1: Save/load gameplay-relevant control state**

Capture:
- bus arbitration flags
- reset/bus-request flags
- bank register
- controller/IO registers

**Step 2: Save/load YM2612 and PSG state needed for correct resume**

At minimum capture:
- register contents
- timer state
- IRQ-relevant state

If full operator phase restore is too invasive for v1, document the reduced guarantee explicitly and verify it does not break gameplay logic.

### Task 10: Add Sega CD ASIC, CDC, PCM, and CDDA savestate ports

**Files:**
- Modify: `MegaCD_MiSTer/rtl/MCD/ASIC.vhd`
- Modify: `MegaCD_MiSTer/rtl/MCD/CDC.vhd`
- Modify: `MegaCD_MiSTer/rtl/MCD/PCM.vhd`
- Modify: `MegaCD_MiSTer/rtl/MCD/CDDA.vhd`
- Modify: `MegaCD_MiSTer/rtl/MCD/MCD.vhd`
- Modify: `MegaCD_MiSTer/MegaCD.sv`

**Step 1: Save/load ASIC state**

Capture:
- register block
- timers / IRQ pending bits
- DMA / halt / bus ownership state
- Word RAM mode / return flags
- CDD communication latches

**Step 2: Save/load CDC state**

Capture:
- command/status registers
- FIFO/RAM pointers
- pending transfer state
- interrupt state

**Step 3: Save/load PCM and CDDA state**

Capture:
- PCM channel regs, cursors, accumulators
- CDDA FIFO / attenuation / sample position

### Task 11: Add top-level CD handshake savestate state

**Files:**
- Modify: `MegaCD_MiSTer/MegaCD.sv`
- Modify: `MegaCD_MiSTer/rtl/hps_ext.v` (only if needed for slot-valid probing)

**Step 1: Save/load host-visible CD handshake latches**

Capture:
- `cd_in`
- `cd_out`
- `scd_cdd_stat`
- `scd_cdd_dm`
- `scd_cdd_rec`
- `cd_out48_last`
- `cdc_wr`
- `cdc_d`

**Step 2: Verify HPS-side CD flow is stateless enough**

Confirm that after FPGA restore:
- mounted disc state is unchanged
- restored CDD/CDC state is sufficient for continued streaming
- no extra HPS-side serializer is needed

### Task 12: Turn on `SS...` and validate on hardware

**Files:**
- Modify: `MegaCD_MiSTer/MegaCD.sv`
- Modify: `MegaCD_MiSTer/README.MD`
- Create: `MegaCD_MiSTer/docs/savestates.md`

**Step 1: Enable MiSTer savestate declaration**

Only after the controller and serializers are complete, add:
- `SS3E000000:<size>` to `CONF_STR`

**Step 2: Document limitations honestly**

Record:
- gameplay-correct target
- expected post-load AV/audio settle
- unsupported cases, if any

**Step 3: Run the hardware checklist**

Verify on a real MiSTer:
- save in gameplay, load same slot, game continues correctly
- both 68Ks and Z80 resume without divergence
- VDP output re-stabilizes
- Sega CD data streaming resumes
- backup RAM and Word RAM contents survive
- repeated save/load cycles do not deadlock
- invalid/empty slots fail cleanly
