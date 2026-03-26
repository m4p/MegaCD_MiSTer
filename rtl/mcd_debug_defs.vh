`ifndef MCD_DEBUG_DEFS_VH
`define MCD_DEBUG_DEFS_VH

// HPS EXT_BUS command ids. Pick values outside the standard UIO command range
// already handled by hps_io.
`define MCD_EXT_DBG_REG_GET 16'h0044
`define MCD_EXT_DBG_REG_SET 16'h0045

// Mailbox register indices.
`define MCD_DBG_REG_VERSION      6'd0
`define MCD_DBG_REG_STATUS       6'd1
`define MCD_DBG_REG_ERROR        6'd2
`define MCD_DBG_REG_WARNING      6'd3
`define MCD_DBG_REG_ACCESS_MODE  6'd4
`define MCD_DBG_REG_COMMAND      6'd5
`define MCD_DBG_REG_TARGET       6'd6
`define MCD_DBG_REG_ADDR_LO      6'd7
`define MCD_DBG_REG_ADDR_HI      6'd8
`define MCD_DBG_REG_LENGTH_LO    6'd9
`define MCD_DBG_REG_LENGTH_HI    6'd10
`define MCD_DBG_REG_WDATA_LO     6'd11
`define MCD_DBG_REG_WDATA_HI     6'd12
`define MCD_DBG_REG_EXEC_ID      6'd13
`define MCD_DBG_REG_DONE_ID      6'd14
`define MCD_DBG_REG_DATA_BASE    6'd16
`define MCD_DBG_REG_DATA_LAST    6'd31

// Protocol version.
`define MCD_DBG_VERSION 16'h0001

// Debug commands.
`define MCD_DBG_CMD_NONE            8'h00
`define MCD_DBG_CMD_PAUSE           8'h01
`define MCD_DBG_CMD_RESUME          8'h02
`define MCD_DBG_CMD_SET_ACCESS_MODE 8'h03
`define MCD_DBG_CMD_GET_ACCESS_MODE 8'h04
`define MCD_DBG_CMD_GET_TARGET_CAPS 8'h05
`define MCD_DBG_CMD_READ8           8'h10
`define MCD_DBG_CMD_READ16          8'h11
`define MCD_DBG_CMD_READ32          8'h12
`define MCD_DBG_CMD_WRITE8          8'h20
`define MCD_DBG_CMD_WRITE16         8'h21
`define MCD_DBG_CMD_WRITE32         8'h22
`define MCD_DBG_CMD_READ_BLOCK      8'h30

// Access modes.
`define MCD_DBG_ACCESS_PAUSED 16'h0000
`define MCD_DBG_ACCESS_LIVE   16'h0001

// Target ids.
`define MCD_DBG_TARGET_MD68K_RAM  8'h01
`define MCD_DBG_TARGET_SUBCPU_RAM 8'h02
`define MCD_DBG_TARGET_WORDRAM    8'h03
`define MCD_DBG_TARGET_PRGRAM     8'h04
`define MCD_DBG_TARGET_BACKUP_RAM 8'h05

// Capability bits.
`define MCD_DBG_CAP_LIVE_READ      16'h0001
`define MCD_DBG_CAP_LIVE_WRITE     16'h0002
`define MCD_DBG_CAP_PAUSED_READ    16'h0004
`define MCD_DBG_CAP_PAUSED_WRITE   16'h0008
`define MCD_DBG_CAP_COHERENT       16'h0010
`define MCD_DBG_CAP_ARBITRATED     16'h0020
`define MCD_DBG_CAP_RAW_PHYSICAL   16'h0040

// Status bits.
`define MCD_DBG_STATUS_BUSY         16'h0001
`define MCD_DBG_STATUS_DONE         16'h0002
`define MCD_DBG_STATUS_ERROR        16'h0004
`define MCD_DBG_STATUS_PAUSED       16'h0008
`define MCD_DBG_STATUS_PAUSE_WAIT   16'h0010
`define MCD_DBG_STATUS_MODE_LIVE    16'h0020
`define MCD_DBG_STATUS_WARNING      16'h0040
`define MCD_DBG_STATUS_DATA_VALID   16'h0080

// Warning codes.
`define MCD_DBG_WARN_NONE                 16'h0000
`define MCD_DBG_WARN_ARBITRATED_VALUE     16'h0001
`define MCD_DBG_WARN_RAW_PHYSICAL_MAPPING 16'h0002

// Error codes.
`define MCD_DBG_ERR_NONE                16'h0000
`define MCD_DBG_ERR_INVALID_CMD         16'h0001
`define MCD_DBG_ERR_INVALID_TARGET      16'h0002
`define MCD_DBG_ERR_INVALID_ADDR        16'h0003
`define MCD_DBG_ERR_NOT_PAUSED          16'h0004
`define MCD_DBG_ERR_LIVE_UNSUPPORTED    16'h0005
`define MCD_DBG_ERR_PAUSED_UNSUPPORTED  16'h0006
`define MCD_DBG_ERR_ALIGNMENT           16'h0007
`define MCD_DBG_ERR_LENGTH              16'h0008
`define MCD_DBG_ERR_TRANSPORT_BUSY      16'h0009
`define MCD_DBG_ERR_TARGET_BUSY         16'h000A
`define MCD_DBG_ERR_INVALID_MODE        16'h000B

`endif
