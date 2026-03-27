# Remote Debug Bridge

This core now includes a mailbox-style debug bridge between MiSTer's HPS/Linux side and the running Sega CD FPGA core.

## Architecture Summary

### HPS to FPGA transport

- The bridge reuses the existing MiSTer `EXT_BUS` sideband path instead of inventing a second HPS transport.
- `rtl/hps_ext.v` now accepts two new user-IO commands:
  - `0x0044`: debug register read
  - `0x0045`: debug register write
- This matches how the existing Sega CD support already exchanges CD-sideband messages with `UIO_CD_GET` and `UIO_CD_SET`.
- On Linux, `linux/debug_bridge/mcd_debugd.cpp` talks to that path by using the same low-level SPI/GPO mechanism that Main_MiSTer uses for user-IO traffic.

### Mailbox model

- `rtl/mcd_debug_bridge.sv` implements a small mailbox register block.
- The HPS writes command parameters into registers, then writes a new `EXEC_ID` value to start the transaction.
- The bridge reports:
  - `busy`
  - `done`
  - `error`
  - `warning`
  - `read data`
- `DONE_ID` lets the Linux side match a completion to the command it started.

### Arbitration model

- SDRAM-backed targets use MiSTer's existing multi-port SDRAM fabric.
- Backup RAM uses the existing second port of the `dpram_dif` block RAM.
- Word RAM is single-port in this core, so the bridge only accesses it while the Sega CD side is quiesced.
- The bridge never silently downgrades a requested live access into a paused access.

### Pause and resume

- `pause` asserts a debug quiesce request.
- Genesis-side pause:
  - stops new 68k/Z80 bus activity once the Genesis buses are idle
  - acknowledges when the Genesis side is quiesced for debug-safe RAM access
- Sega CD-side pause:
  - waits for the ASIC/CD side to go idle
  - then gates the Sega CD execution enables and external write strobes
  - exposes direct paused-only Word RAM access

Important limitation:

- This is a memory-safe quiesce, not a full video-time freeze.
- Genesis video timing continues running.
- That is still honest for the current targets because the writers relevant to the exposed RAM targets are stopped before paused writes are allowed.

## Mailbox Commands

Implemented commands:

- `PAUSE`
- `RESUME`
- `SET_ACCESS_MODE`
- `GET_ACCESS_MODE`
- `GET_TARGET_CAPS`
- `READ8`
- `READ16`
- `READ32`
- `WRITE8`
- `WRITE16`
- `WRITE32`
- `READ_BLOCK`
- `SEARCH_BYTES`

`READ_BLOCK` is limited to 32 bytes in v1 because the mailbox data window is 16 x 16-bit words.
`SEARCH_BYTES` reuses that same 32-byte window to stage the search needle.

### `SEARCH_BYTES` contract

Inputs:

- `TARGET`: debug target to scan
- `ADDR`: inclusive start address within the target
- `LENGTH`: number of bytes to scan from `ADDR`
- `WDATA_LO[7:0]`: needle length in bytes
- `DATA[0..15]`: staged search bytes before `EXEC_ID`

Results:

- success with `STATUS.data_valid = 1` means a match was found
- `DATA[0]` and `DATA[1]` return the 32-bit match address
- success with `STATUS.data_valid = 0` means the range was scanned and no match was found

Limits:

- search needles are `1..32` bytes
- search length must be at least the needle length
- search follows the same live/paused read capability rules as `READ_BLOCK`

## Targets

The bridge exposes explicit targets instead of a flat address space.

| Target name | Target ID | Backing implementation | Notes |
| --- | --- | --- | --- |
| `md68k_ram` | `0x01` | Genesis 68k work RAM in SDRAM bank 0 | 64 KiB |
| `subcpu_ram` | `0x02` | Sega CD PRG-RAM path | Aliases `prgram` in this core |
| `wordram` | `0x03` | Two single-port Word RAM `spram` blocks | Physical bank view only |
| `prgram` | `0x04` | Sega CD PRG-RAM in SDRAM bank 2/3 or 0/1 | 512 KiB |
| `backup_ram` | `0x05` | Sega CD backup RAM `dpram_dif` | 8 KiB |

### Target mapping notes

- `subcpu_ram` and `prgram` are the same physical storage in this core revision.
- `wordram` is exposed as raw physical memory:
  - `0x00000` to `0x1FFFF`: physical bank 0
  - `0x20000` to `0x3FFFF`: physical bank 1
- The `wordram` view does not pretend to be the current logical CPU mapping in 1M/2M modes.

## Access Modes and Capabilities

The bridge tracks a global policy mode:

- `paused`
- `live`

Per-target capabilities are queried from Linux and reported as:

- `supports_live_read`
- `supports_live_write`
- `supports_paused_read`
- `supports_paused_write`

Current v1 capability classification:

| Target | Live read | Live write | Paused read | Paused write | Semantics |
| --- | --- | --- | --- | --- | --- |
| `md68k_ram` | yes | no | yes | yes | arbitrated current value |
| `subcpu_ram` | yes | no | yes | yes | arbitrated current value |
| `prgram` | yes | no | yes | yes | arbitrated current value |
| `wordram` | no | no | yes | yes | raw physical mapping |
| `backup_ram` | yes | no | yes | yes | arbitrated current value |

### Honesty rules in this implementation

- Live reads are only advertised where the existing RAM fabric can return a safe current value.
- Live writes are not advertised for any v1 target.
- If the client asks for a live write anyway, the request fails with an explicit error.
- `wordram` is paused-only because the core's implementation is single-port and heavily time-multiplexed.

## Register Block

The mailbox registers live behind `DBG_REG_GET` and `DBG_REG_SET`.

| Register | Index | Description |
| --- | --- | --- |
| `VERSION` | `0` | protocol version |
| `STATUS` | `1` | busy/done/error/pause/data-valid flags |
| `ERROR` | `2` | error code |
| `WARNING` | `3` | warning code |
| `ACCESS_MODE` | `4` | active access mode |
| `COMMAND` | `5` | mailbox command |
| `TARGET` | `6` | target ID |
| `ADDR_LO` | `7` | address low 16 bits |
| `ADDR_HI` | `8` | address high 16 bits |
| `LENGTH_LO` | `9` | block/search length low 16 bits |
| `LENGTH_HI` | `10` | block/search length high 16 bits |
| `WDATA_LO` | `11` | write data low 16 bits, or search needle length in bits `[7:0]` |
| `WDATA_HI` | `12` | write data high 16 bits |
| `EXEC_ID` | `13` | write a new ID to execute |
| `DONE_ID` | `14` | completed ID |
| `DATA[0..15]` | `16..31` | read result window, or staged search bytes while idle |

## Linux-side Daemon

Source:

- `linux/debug_bridge/mcd_debugd.cpp`

Build:

```sh
cd linux/debug_bridge
make
```

Run locally only:

```sh
./mcd_debugd
```

Run on all interfaces:

```sh
./mcd_debugd --listen-all --port 24512
```

Test a single request from the shell without opening a TCP port:

```sh
./mcd_debugd --command '{"cmd":"get_target_caps"}'
```

Search for a byte sequence:

```sh
./mcd_debugd --command '{"cmd":"search_bytes","target":"prgram","addr":0,"length":65536,"data":[78,117]}'
```

`mcd_debugd` must run on the MiSTer itself and needs `/dev/mem` access.

## Python Web Server

Source:

- `linux/debug_bridge/mcd_debug_web.py`

What it does:

- serves a small browser UI at `/`
- exposes HTTP JSON endpoints
- proxies requests to `mcd_debugd`
- can start a local `mcd_debugd` child automatically so operators only need one command

Default behavior:

- HTTP server binds to `127.0.0.1:8080`
- backend target is `127.0.0.1:24512`
- backend spawning is enabled

Run with managed backend:

```sh
cd linux/debug_bridge
make
python3 mcd_debug_web.py
```

Run the web server on all interfaces:

```sh
python3 mcd_debug_web.py --listen-all --port 8080
```

Run the web server against an already-running backend:

```sh
python3 mcd_debug_web.py --no-spawn-backend --backend-host 127.0.0.1 --backend-port 24512
```

Syntax-check the Python server:

```sh
python3 -m py_compile linux/debug_bridge/mcd_debug_web.py
```

### HTTP routes

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/` | browser UI |
| `GET` | `/api/health` | web/backend status |
| `GET` | `/api/targets` | target metadata plus capability query |
| `POST` | `/api/command` | proxy one `mcd_debugd` JSON command |

### HTTP examples

Browser UI:

```text
http://127.0.0.1:8080/
```

Health:

```sh
curl http://127.0.0.1:8080/api/health
```

Targets:

```sh
curl http://127.0.0.1:8080/api/targets
```

Pause:

```sh
curl -X POST http://127.0.0.1:8080/api/command \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"pause"}'
```

Paused read:

```sh
curl -X POST http://127.0.0.1:8080/api/command \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"read16","target":"wordram","addr":4096}'
```

Live-read mode switch:

```sh
curl -X POST http://127.0.0.1:8080/api/command \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"set_access_mode","mode":"live"}'
```

Search for a byte sequence:

```sh
curl -X POST http://127.0.0.1:8080/api/command \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"search_bytes","target":"prgram","addr":0,"length":65536,"data":[78,117]}'
```

## Local MCP Server

Source:

- `linux/debug_bridge/mcd_debug_mcp.py`

What it does:

- runs locally on your workstation as a stdio MCP server
- targets one configured `mcd_debug_web.py` base URL
- exposes MiSTer debug bridge operations as MCP tools
- does not access `/dev/mem` directly

Recommended topology:

- MiSTer: run `mcd_debug_web.py`
- local machine: run `mcd_debug_mcp.py --base-url http://<mister-host>:8080`

Build and checks:

```sh
cd linux/debug_bridge
make check-mcp
```

Run manually:

```sh
python3 linux/debug_bridge/mcd_debug_mcp.py --base-url http://mister.local:8080
```

The MCP server uses stdio, so it is meant to be launched by an MCP-capable client rather than visited in a browser.

Example client-style command configuration:

```json
{
  "command": "python3",
  "args": [
    "/absolute/path/to/MegaCD_MiSTer/linux/debug_bridge/mcd_debug_mcp.py",
    "--base-url",
    "http://mister.local:8080"
  ]
}
```

### MCP tools

| Tool | Purpose |
| --- | --- |
| `health` | Fetch `/api/health` from the configured MiSTer |
| `targets` | Fetch `/api/targets` |
| `pause` | Pause the core |
| `resume` | Resume the core |
| `get_access_mode` | Read the current access mode |
| `set_access_mode` | Set `paused` or `live` |
| `get_target_caps` | Get all target caps or one target |
| `read_memory` | Read 8/16/32/block data |
| `write_memory` | Write 8/16/32 data |
| `search_bytes` | Search a target range for the first matching byte sequence |
| `raw_command` | Pass a raw command object through to `/api/command` |

### MCP tool argument notes

- `read_memory`
  - `target`: one of `md68k_ram`, `subcpu_ram`, `wordram`, `prgram`, `backup_ram`
  - `addr`: non-negative integer
  - `width`: `8`, `16`, `32`, or `block`
  - `length`: required only for `block`, max `32`
- `write_memory`
  - `width`: `8`, `16`, or `32`
  - `value`: non-negative integer
- `search_bytes`
  - `target`: one of `md68k_ram`, `subcpu_ram`, `wordram`, `prgram`, `backup_ram`
  - `addr`: non-negative integer
  - `length`: positive integer byte span to scan
  - `data`: integer array of `1..32` bytes, each `0..255`
- `raw_command`
  - `command`: raw JSON object matching the web bridge request format

## Usage

### Quick start

1. Build on the MiSTer:

```sh
cd linux/debug_bridge
make
```

2. Start the daemon with the default local-only bind:

```sh
./mcd_debugd
```

3. In another shell, query capabilities first:

```sh
printf '%s\n' '{"cmd":"get_target_caps"}' | nc 127.0.0.1 24512
```

### Recommended paused workflow

Use this when you need deterministic writes or access to paused-only targets such as `wordram`.

```sh
printf '%s\n' '{"cmd":"pause"}' | nc 127.0.0.1 24512
printf '%s\n' '{"cmd":"set_access_mode","mode":"paused"}' | nc 127.0.0.1 24512
printf '%s\n' '{"cmd":"read16","target":"wordram","addr":4096}' | nc 127.0.0.1 24512
printf '%s\n' '{"cmd":"write16","target":"prgram","addr":8192,"value":4660}' | nc 127.0.0.1 24512
printf '%s\n' '{"cmd":"resume"}' | nc 127.0.0.1 24512
```

Operational rules:

- Always pause before writing unless the target explicitly reports `supports_live_write`.
- Do not assume `set_access_mode` pauses the core. It only changes the bridge policy.
- Keep the pause window short. The bridge is designed for inspection and targeted edits, not for leaving the core quiesced indefinitely.

### Recommended live-read workflow

Use this for targets that report `supports_live_read: true`.

```sh
printf '%s\n' '{"cmd":"set_access_mode","mode":"live"}' | nc 127.0.0.1 24512
printf '%s\n' '{"cmd":"read16","target":"md68k_ram","addr":65520}' | nc 127.0.0.1 24512
printf '%s\n' '{"cmd":"read_block","target":"backup_ram","addr":0,"length":16}' | nc 127.0.0.1 24512
printf '%s\n' '{"cmd":"search_bytes","target":"prgram","addr":0,"length":65536,"data":[78,117]}' | nc 127.0.0.1 24512
```

Operational rules:

- Treat live reads as current arbitrated values, not a coherent snapshot.
- If a target does not advertise live-read support, switch to paused mode instead of retrying.

### Local shell mode

`--command` is useful for one-off checks, and `--stdio` is useful for scripted sessions without opening a TCP listener.

```sh
./mcd_debugd --command '{"cmd":"get_access_mode"}'

cat <<'EOF' | ./mcd_debugd --stdio
{"cmd":"get_target_caps","target":"backup_ram"}
{"cmd":"get_access_mode"}
EOF
```

### Remote exposure

The daemon defaults to `127.0.0.1` on purpose.

- Recommended: leave it local-only and tunnel it if you need remote access.
- If you intentionally expose it on the LAN, use:

```sh
./mcd_debugd --listen-all --port 24512
```

- Do not expose it to untrusted networks. The interface can modify live core memory.

For the browser-based workflow, the same rule applies:

- Recommended: keep `mcd_debug_web.py` on `127.0.0.1` and tunnel it if needed.
- If you intentionally expose it on the LAN, use:

```sh
python3 linux/debug_bridge/mcd_debug_web.py --listen-all --port 8080
```

- There is no built-in authentication in v1.

## TCP Protocol

- newline-delimited JSON
- one request object per line
- one response object per line
- requests are serialized inside the daemon, so only one FPGA mailbox transaction is active at a time

Default bind:

- `127.0.0.1:24512`

### Example requests

```json
{"cmd":"pause"}
{"cmd":"resume"}
{"cmd":"set_access_mode","mode":"paused"}
{"cmd":"set_access_mode","mode":"live"}
{"cmd":"get_access_mode"}
{"cmd":"get_target_caps"}
{"cmd":"get_target_caps","target":"wordram"}
{"cmd":"read16","target":"wordram","addr":4096}
{"cmd":"write16","target":"md68k_ram","addr":65520,"value":3}
{"cmd":"read_block","target":"backup_ram","addr":0,"length":16}
```

### Example responses

Paused mode read:

```json
{"ok":true,"target":"wordram","addr":4096,"executed_mode":"paused","paused":true,"pause_wait":false,"warning":"raw_physical_mapping","value":4660}
```

Live read:

```json
{"ok":true,"target":"md68k_ram","addr":32,"executed_mode":"live","paused":false,"pause_wait":false,"warning":"arbitrated_current_value","value":43981}
```

Rejected live write:

```json
{"ok":false,"error":"live_unsupported","error_code":"live_unsupported","executed_mode":"live","paused":false,"pause_wait":false}
```

Capability query:

```json
{
  "ok": true,
  "targets": {
    "md68k_ram": {
      "supports_live_read": true,
      "supports_live_write": false,
      "supports_paused_read": true,
      "supports_paused_write": true,
      "coherence": "arbitrated_current_value",
      "note": "Genesis main 68k work RAM"
    }
  }
}
```

## Error Handling

Common error names:

- `invalid_cmd`
- `invalid_target`
- `invalid_addr`
- `not_paused`
- `live_unsupported`
- `paused_unsupported`
- `alignment`
- `length`
- `transport_busy`
- `target_busy`
- `invalid_mode`

Warnings:

- `arbitrated_current_value`
- `raw_physical_mapping`

## Test Checklist

- Confirm `pause` returns successfully and `resume` clears the paused state.
- In paused mode, read and write a known `md68k_ram` address and confirm the value sticks.
- In live mode, read a known `md68k_ram` or `prgram` location repeatedly and confirm the bridge does not deadlock.
- Verify `wordram` live access fails cleanly with `live_unsupported`.
- Verify any live write request fails cleanly in v1.
- Verify `read_block` rejects lengths above 32 bytes.
- Verify odd-address `read16` and `write16` requests fail with `alignment`.
- Verify invalid target names and out-of-range addresses return explicit errors.
- Verify `get_target_caps` matches the real implementation table above.
