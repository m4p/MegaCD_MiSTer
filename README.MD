# [Sega MegaCD](https://en.wikipedia.org/wiki/Sega_CD) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

# Installation
Place BIOS to MegaCD folder with name boot.rom

# Features
About 150 games tested without long playing, US/EU regions only.

### Known issues:
- Microcosm & Ultraverse Prime (US) - graphic glitch in game
- Supreme Warrior - Ying Heung (US) - can't select 2 disk

### Supported image formats:
- CUE + single image
- CUE + multiple images (image per track)
- CHD file

### ZIP
ZIP is supported but doesn't work due to long positioning time.
So DON'T zip the images!

### CD BIOS
support BIOS per game. Place cd_bios.rom in game's folder.

### Debug bridge
Remote memory inspection and control for the running core is documented in `docs/debug-bridge.md`.
The same document also includes build and runtime usage for `linux/debug_bridge/mcd_debugd`.
It also documents the browser-facing Python server in `linux/debug_bridge/mcd_debug_web.py`.
It also documents the local MCP server in `linux/debug_bridge/mcd_debug_mcp.py`.

### Savestates
MiSTer savestate support is implemented in this branch and documented in
`docs/savestates.md`.

Current contract:
- gameplay-correct restore is the target
- audio/video/CD pipelines may need a short settle period after load
- saves are only valid at the enforced paused/quiescent boundary

Current release status:
- the serializer/controller/UI path is wired in RTL
- real MiSTer hardware save/load smoke tests are still required before calling
  it production-ready

### Pier Solar
Place cartridge dump named cart.rom into game's folder
