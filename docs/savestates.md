# MegaCD Savestates

This document captures the real MegaCD savestate surface in the savestate
worktree. The MiSTer `SS...` reservation, slot UI, and DDR transfer controller
now exist in this branch, but the implementation is still only as honest as
the state surfaces listed below.

## Target Guarantee

The intended v1 target is gameplay-correct restore:

- CPU execution must resume correctly on both 68Ks and the Genesis Z80
- RAM-backed game state must be restored exactly
- video, audio, and CD pipelines may need a short post-load settle period
- no claim is made for cycle-exact audio/video continuity

## Required State Inventory

The MegaCD core has to serialize more than RAM contents. The required mutable
state includes:

- Genesis main 68k CPU state
- Genesis Z80 CPU state
- Genesis work RAM and Z80 RAM
- Genesis VDP VRAM, CRAM, VSRAM, register file, DMA/FIFO/interrupt state
- Genesis control and bus-arbitration state in `rtl/GEN/gen.sv`
- YM2612 state needed for gameplay-safe restore
- Sega CD sub-68k CPU state
- Sega CD PRG-RAM, Word RAM, backup RAM, PCM RAM, and CDC RAM
- Sega CD ASIC timers, DMA state, IRQ state, and Word RAM mode state
- CDC, PCM, and CDDA internal state
- top-level CD handshake latches in `MegaCD.sv`

## Current Integration Status

This branch now has a working savestate request path:

- MiSTer slot UI and `SS3E000000:200000` reservation in `MegaCD.sv`
- a central DDR-backed savestate controller in `rtl/mcd_savestates.vhd`
- slot-validity scanning from the 64-bit MiSTer savestate headers
- paused save/load transfers for the currently wired CPU, control-state, and
  RAM blocks

The controller writes payload data first and commits the MiSTer savestate
header last, so partially written state should not be reported as valid.

Paused RAM plumbing is now wired for the following internal targets:

- `001` Genesis Z80 RAM
- `010` backup RAM
- `011` Word RAM bank 0
- `100` Word RAM bank 1
- `101` CDC RAM
- `110` PCM RAM
- `111` Genesis work RAM
- `1000` Sega CD PRG-RAM
- `1001` Genesis VRAM

The Genesis side also now exposes a staged Z80 CPU-state port built on the
existing `T80` `REG`/`DIR`/`DIRSet` hooks. That path can read the live Z80
register image and restore a staged image plus the local Z80 control/bank
register state.

The Genesis VDP now also has a dedicated savestate pause input and a paused
memory side port for its small dual-port memories. While `SS_PAUSE` is active,
the VDP's internal clocked state machines stop advancing and the savestate path
can access:

- CRAM, 64 raw entries
- VSRAM bank 0, 32 raw entries
- VSRAM bank 1, 32 raw entries

Current VDP paused-memory map:

- addresses `0x00`..`0x3f`: CRAM entries `0`..`63`, returned in normal 16-bit
  Genesis color packing
- addresses `0x40`..`0x5f`: raw VSRAM bank 0 entries `0`..`31`
- addresses `0x60`..`0x7f`: raw VSRAM bank 1 entries `0`..`31`
- addresses `0x80`..`0x8f`: VDP register file pairs `REG[0:1]` through
  `REG[30:31]`
- address `0x90`: `ADDR[15:0]`
- address `0x91`: `ADDR[16]`, `PENDING`, `CODE`, and paused CPU-port latch
  flags
- address `0x92`: paused FIFO pointer/count state plus `BR_N/BGACK_N_REG`
- address `0x93`: paused interrupt and latched display flags, read-only in the
  current implementation
- address `0x94`: `WHP_LATCH`, read-only in the current implementation

The Sega CD CDC now has a dedicated staged control-state serializer in addition
to its paused raw CDC RAM image. The controller can now capture and restore:

- host-facing register state such as `AR`, `IFCTRL`, `IFSTAT`, `CTRL0`, and
  `CTRL1`
- transfer engine state such as `DBC`, `DAC`, `TS`, `DT_EN`, `DTEN_N`,
  `WAIT_N`, and `FIFO_DATA0`
- sector/header decode state such as `HEAD0..3`, `PT`, `WA`, `WORD_CNT`,
  `RAM_POS`, `DEC_POS`, `DEC_DAT`, `DEC_HEAD01`, and `DEC_HEAD23`

Current CDC serializer word map:

- word `0`: address/index and host I/O edge state plus transfer-engine control
- word `1`: `IFCTRL`, `IFSTAT`, `CTRL0`, `CTRL1`
- word `2`: `STAT0`, `STAT2`, `STAT3`, `HEAD0`
- word `3`: `HEAD1`, `HEAD2`, `HEAD3`
- word `4`: `DBC`, `DAC`
- word `5`: `PT`, `WA`
- word `6`: `DEC_HEAD01`, `DEC_HEAD23`
- word `7`: `DEC_DAT`, `FIFO_DATA0`
- word `8`: `WORD_CNT`, `RAM_POS`
- word `9`: `DEC_POS`

The Sega CD PCM block now also exposes a staged control-state serializer in
addition to the existing paused PCM RAM image. The current v1 surface captures
the gameplay-relevant playback state:

- PCM control registers `WB`, `CB`, `ONOFF`, `CHOFF`
- per-channel `ENV`, `PAN`, `FD`, `LS`, and `ST` registers
- per-channel playback accumulators `WRA[0..7]`
- in-flight mixer state `CH`, `STEP`, `LSUM`, `RSUM`, `LOUT`, `ROUT`, and the
  current `RAM_DI` sample byte

The PCM serializer intentionally does not preserve the internal CE generator
phase. That means audio may need a short post-load settle window, but channel
positions and playback state are restored explicitly.

Current PCM serializer word map:

- word `0`: host I/O edge state plus `WB`, `CB`, `ONOFF`, `CHOFF`, `STEP`,
  `CH`, and the current readback `DO`
- words `1`..`4`: packed `ENV`/`PAN` pairs for channels `0`..`7`
- words `5`..`12`: `FD` and `LS` pairs for channels `0`..`7`
- words `13`..`14`: `ST[0..7]`
- words `15`..`22`: `WRA[0..7]`
- word `23`: `LSUM`
- word `24`: `RSUM`
- word `25`: `LOUT`, `ROUT`
- word `26`: current `RAM_DI`

The Sega CD CDDA path now also exposes a paused direct serializer that covers
both the wrapper state in `CDDA.vhd` and the backing FIFO in `CDDA_FIFO.v`.
That surface captures:

- wrapper control state such as `CD_WR_OLD`, `LR`, `RD_REQ`, `WR_REQ`, `ATT`,
  `ATT_CUR`, `FIFO_D`, `OUTL`, and `OUTR`
- the full FIFO state: `OLD_WRITE`, `OLD_READ`, `FILLED_COUNT`, `READ_ADDR`,
  `WRITE_ADDR`, `Q`, `BUFFER_Q`, and all queued 32-bit audio words

The CDDA serializer still does not preserve the internal CE generator phase, so
post-load audio can settle by up to a sample interval. The buffered stream
contents and attenuation state are restored explicitly.

Current CDDA serializer word map:

- word `0`: wrapper control/state bits plus `ATT` and `ATT_CUR`
- word `1`: `FIFO_D`
- word `2`: `OUTL`, `OUTR`
- word `3`: FIFO control word `0` (`OLD_WRITE`, `OLD_READ`, `FILLED_COUNT`,
  `READ_ADDR`)
- word `4`: FIFO control word `1` (`WRITE_ADDR`)
- word `5`: FIFO `Q`
- word `6`: FIFO `BUFFER_Q`
- words `7`..`1286`: FIFO buffer entries `0`..`1279`

The Sega CD ASIC now also exposes a staged paused serializer for its
gameplay-critical persistent control state. This block intentionally targets
the state that still matters once the paused save boundary has quiesced the
ASIC, not every transient internal microstep. The controller can now capture
and restore:

- Genesis-visible GA control state such as `SRES`, `SBRQ`, `IFL2`, `BK`, `WP`,
  `HIB`, `CFM`, and the eight command registers `CC[0..7]`
- Sub-CPU-visible GA state such as `RES0`, LEDs, `PM`, `CFS`, `CS[0..7]`,
  `IEN`, `DD`, `DMAA`, `HOCK`, stamp/image control registers, font registers,
  and subcode address state
- timer and interrupt bookkeeping such as `TM`, `TIMER`, `TIME_CLK_CNT`, `SW`,
  `INT_PEND`, and the edge-detect helper latches used to avoid duplicate IRQ
  events after restore
- CDD command/status latches `CDDC` and `CDDS`
- the full 64-word subcode ring buffer `SBA[0..63]` plus its write/count
  position state

This serializer does not attempt to preserve arbitrary in-flight DMA,
graphics-stamp, PCM-DMA, or halt-engine microstate. That is deliberate: the
save path only proceeds after `DEBUG_IDLE` reports those engines idle, so the
snapshot contract is "persistent ASIC state at a clean paused boundary", not
"resume the middle of an internal ASIC microsequence".

Current ASIC serializer word map:

- word `0`: reset, LED, Word RAM ownership, IRQ edge-helper, CDC helper, and
  reset sequencer state
- word `1`: font colors, `PM`, `BK`, `DD`, `IEN`, `INT_PEND`, `MODE`, `HOCK`,
  and stamp-control flags
- word `2`: `WP`, `TM`, `GRON`, `VCS`, `LN`, `DOT`, and `SAOR`
- word `3`: `TIMER`, `TIME_CLK_CNT`, and stop-watch `SW`
- word `4`: `HIB`, `CFM`, `CFS`
- word `5`: `HD`, `DMAA`
- word `6`: `DMA_ADDR`, `HW`
- word `7`: `VW`, `VDOTS`, `TVBA`
- word `8`: `SMBA`, `ISA`, `STA`
- word `9`: `SB`, `SC_CNT`
- words `10`..`11`: `CDDS`
- words `12`..`13`: `CDDC`
- words `14`..`17`: `CC[0..7]`
- words `18`..`21`: `CS[0..7]`
- words `22`..`53`: `SBA[0..63]`

The Genesis pause boundary now also requires the VDP to report an idle state:

- no active DMA
- empty VDP FIFO
- no pending control-port second word
- idle data-transfer engines

The top level now also serializes the MegaCD-side CD handshake latches that
live outside the Sega CD block proper. While savestate pause is active, the
top-level CDD/CDC handshake helpers stop advancing and the controller can
capture and restore:

- `cd_in[48:0]`
- `scd_cdd_stat[39:0]`
- `scd_cdd_dm`
- `scd_cdd_rec`
- `cd_out48_last`
- `scd_cdd_send_old`
- the `scd_cdd_rec` pulse countdown
- `rst_old` for reset-edge detection
- `cdc_wr`
- `cdc_d`
- the `cdc_wr` pulse countdown

The Genesis PSG now also exposes a staged paused serializer built directly on
the `jt89` core. This block restores the actual tone/noise generator state
rather than trying to replay register writes after load. The controller can now
capture and restore:

- tone periods `tone0..2`
- volume registers `vol0..3`
- noise control register `ctrl3`
- PSG register index state `regn`
- internal divider phase `clk_div`, `cen_16`, and `cen_4`
- the three tone-generator counters and output bits
- the noise LFSR contents and counter
- the write-edge helper `last_wr`

The serializer intentionally does not replay the transient `clr_noise` pulse.
Instead it restores the actual noise LFSR state directly, which avoids
fabricating a second noise-clear event after load.

Current PSG serializer word map:

- word `0`: `tone0`, `tone1`, `tone2`, and `ctrl3[1:0]`
- word `1`: `vol0..3`, `regn`, `clk_div`, `ctrl3[2]`, `last_wr`, `cen_16`,
  and `cen_4`
- word `2`: tone-generator `0`/`1` counters and outputs plus tone-generator
  `2` counter
- word `3`: tone-generator `2` output, noise LFSR contents, and noise counter

The Genesis FM path now also exposes a staged paused serializer built directly
on the JT12 YM2612 implementation. This block restores the live synthesized
state rather than trying to rebuild it from register writes. The controller can
now capture and restore:

- MMR/front-end control state such as selected register, timer reloads and IRQ
  enables, DAC/PCM input state, LFO control, CSM/effect flags, divider/busy
  state, and CH3 special-mode frequency latches
- the full JT12 register image, including channel/operator register files,
  key-on sequencing, channel scan position, and left/right routing state
- timer core state from both YM2612 timers
- LFO progression state
- phase-generator state, including per-operator phase history and detune/pitch
  modulation pipeline state
- envelope-generator state, including counters, envelope state machines, SSG-EG
  state, and in-flight attenuation pipeline values
- operator pipeline state, including feedback/modulation history, sign/exponent
  pipeline state, and the current operator output pipeline registers

The serializer intentionally does not preserve the final audio mixer and output
interpolator settling state. That is within the branch's stated contract:
gameplay-critical FM timers, phase, envelopes, and operator outputs are
restored explicitly, while the last few mixed audio samples may settle for a
short interval after load.

Current FM serializer block facts:

- packed size: `89` dwords in the central controller block image
- packed sources, in order: JT12 MMR, register path, timers, LFO, phase
  generator, envelope generator, and operator pipeline state
- restore behavior: staged writes followed by a final commit strobe so partially
  written FM state is not applied live

Current Z80 serializer word map:

- word `0`: local control image, including `Z80_RESET_N`, `Z80_BUSRQ_N`,
  `Z80_BR_N`, `Z80_BGACK_N`, `Z80_BGACK_DIS`, and `BAR[23:15]`; bit `31` is a
  write-only commit strobe
- words `1`..`7`: packed `T80` `REG` image, padded to 224 bits

Current controller block order is:

- Genesis Z80 state
- Genesis main 68k state
- Sega CD sub-68k state
- Genesis VDP paused state block
- Sega CD CDC control-state block
- Sega CD PCM control-state block
- Sega CD CDDA control/FIFO state block
- Sega CD ASIC persistent control-state block
- Genesis Z80 RAM
- backup RAM
- Word RAM bank 0
- Word RAM bank 1
- CDC RAM
- PCM RAM
- Genesis work RAM
- Sega CD PRG-RAM
- Genesis VRAM
- top-level CD handshake state
- Genesis PSG state
- Genesis FM state

## Remaining Release Blockers

No known gameplay-critical mutable block from the inventory above is
intentionally left unserialized in this branch anymore. The remaining blockers
are verification and release confidence, not an identified missing state
surface.

The remaining Sega CD ASIC limitation is narrower now: saves are only valid at
the enforced idle boundary, and the serializer does not claim to restore an
arbitrary in-flight DMA/graphics/PCM-DMA microstep. That is an explicit design
choice, not a hidden downgrade.

The MiSTer savestate UI and reserved storage are wired, but the feature still
requires real MiSTer hardware save/load smoke tests before it can be claimed as
proper MegaCD savestate support.

Local HDL verification is also still bounded by the available non-Quartus
tooling:

- the new JT12/FM serializer path passes targeted `iverilog` and `verilator`
  checks
- `mcd_savestates.vhd`, `CDC.vhd`, `PCM.vhd`, `CDDA.vhd`, and `ASIC.vhd` now
  analyze cleanly with `ghdl` in isolation
- full stand-alone `ghdl` analysis of `vdp.vhd` and the whole top-level Sega CD
  graph still depends on MiSTer/Quartus memory primitives such as
  `DualPortRAM`, `obj_cache`, and the `altera_mf` library, so that level of
  verification still needs the normal core build flow

The implementation is only complete enough for release when:

1. the paused save boundary is proven safe on both the Genesis and Sega CD sides
2. at least one full hardware save/load smoke test passes on MiSTer
3. the normal Quartus/MiSTer build flow accepts the full branch without
   integration regressions
