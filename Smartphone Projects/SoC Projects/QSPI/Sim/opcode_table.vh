// qspi_opcode_table.vh
// -----------------------------------------------------------------------------
// QSPI opcode values and a compact, parameterized phase descriptor per opcode.
// This header is Verilog-friendly (no SystemVerilog structs) and portable.
// -----------------------------------------------------------------------------
// Depends on: qspi_definitions.vh for:
//   - `BITS_ADDR, `BITS_ALT, `IO_WIDTH_DEFAULT, `CPOL_0, `CPHA_0 (etc if used)
// You can safely include this in both RTL and TB.
// -----------------------------------------------------------------------------

`ifndef OPCODE_TABLE_VH
`define OPCODE_TABLE_VH

// -------------------------------
// IO width encodings (2 bits):
// 00=SINGLE(1b), 01=DUAL(2b), 10=QUAD(4b), 11=RESERVED
// -------------------------------
`define IO_WIDTH_1   2'b00
`define IO_WIDTH_2   2'b01
`define IO_WIDTH_4   2'b10

// -------------------------------
// Data direction for DATA phase:
// 0 = READ (slave drives data out to master)
// 1 = WRITE (slave receives/programs data from master)
// -------------------------------
`define DIR_READ   1'b0
`define DIR_WRITE  1'b1

// -------------------------------
// Packed descriptor bit layout (LSB..MSB):
// [ 0] HAS_ADDR       (1 bit)
// [ 1] HAS_ALT        (1 bit)
// [ 9:2] DUMMY_CYCLES (8 bits)   // number of SCLK sample edges to wait
// [11:10] IO_WIDTH_INSTR   (2 bits)   // IO width during INSTR
// [13:12] IO_WIDTH_ADDR    (2 bits)   // IO width during ADDR
// [15:14] IO_WIDTH_ALT     (2 bits)   // IO width during ALT
// [17:16] IO_WIDTH_DUMMY   (2 bits)   // IO width during DUMMY (usually same as DATA phase)
// [19:18] IO_WIDTH_DATA    (2 bits)   // IO width during DATA
// [20] DATA_DIR       (1 bit)    // 0=READ, 1=WRITE
// [31:21] RESERVED    (11 bits)  // reserved for future flags (DTR, 32-bit addr, etc.)
// Total: 32 bits
// -------------------------------

// Helpers to pack/unpack the descriptor
`define DESC( HasAddr, HasAlt, Dummy8, IInstr, IAddr, IAlt, IDummy, IData, Dir ) \
    { 11'b0, Dir[0], IData[1:0], IDummy[1:0], IAlt[1:0], IAddr[1:0], IInstr[1:0], Dummy8[7:0], HasAlt[0], HasAddr[0] }

`define DESC_HAS_ADDR(d)      ( (d)[0] )
`define DESC_HAS_ALT(d)       ( (d)[1] )
`define DESC_DUMMY(d)         ( (d)[9:2] )
`define DESC_IO_WIDTH_INSTR(d)     ( (d)[11:10] )
`define DESC_IO_WIDTH_ADDR(d)      ( (d)[13:12] )
`define DESC_IO_WIDTH_ALT(d)       ( (d)[15:14] )
`define DESC_IO_WIDTH_DUMMY(d)     ( (d)[17:16] )
`define DESC_IO_WIDTH_DATA(d)      ( (d)[19:18] )
`define DESC_DIR(d)           ( (d)[20] )

// -------------------------------
// Common opcodes (JEDEC-like)
// -------------------------------
`define OP_READ_FAST          8'h0B  // 1-1-1 Fast Read (dummy)
`define OP_READ_DUAL_IO       8'hBB  // 1-2-2 Fast Read Dual I/O (alt+dummy)
`define OP_READ_QUAD_IO       8'hEB  // 1-4-4 Fast Read Quad I/O (alt+dummy)
`define OP_WREN               8'h06  // Write Enable
`define OP_WRDI               8'h04  // Write Disable
`define OP_RDSR               8'h05  // Read Status Register
`define OP_WRSR               8'h01  // Write Status Register
`define OP_RDCR               8'h15  // Read Configuration Register
`define OP_RDID               8'h9F  // Read JEDEC ID

// -------------------------------
// Default phase widths for popular commands (tunable):
// Choose realistic but simple defaults. You can override in TB via `define`s.
// -------------------------------
`ifndef DUMMY_FAST_READ_1_1_1
`define DUMMY_FAST_READ_1_1_1   8    // 0x0B commonly 8 dummy cycles
`endif

`ifndef DUMMY_READ_1_1_4
`define DUMMY_READ_1_1_4        8    // 0x6B commonly 8 dummy cycles
`endif

`ifndef DUMMY_READ_1_4_4
`define DUMMY_READ_1_4_4        6    // 0xEB commonly 6 or 8; use 6 as a default
`endif

`ifndef ALT_BITS_DEFAULT
`define ALT_BITS_DEFAULT        `BITS_ALT  // often 8 for legacy "mode byte"
`endif

// -------------------------------
/* Descriptor suggestions per opcode.
 * NOTE:
 * - HAS_ADDR/HAS_ALT use the system-level ADDR_BITS/ALT_BITS. The header only
 *   tells you whether the phase exists; your slave should use `BITS_ADDR/ALT`.
 * - IO widths are explicitly encoded per phase.
 * - DATA_DIR: READ for read ops, WRITE for program ops, and READ for status/ID.
 */

// 0x0B: Fast Read (1-1-1), dummy, DATA=READ single
`define DESC_READ_FAST \
  `DESC( 1'b1, 1'b0, `DUMMY_FAST_READ_1_1_1[7:0], `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `DIR_READ )

// 0xEB: Quad I/O Fast Read (1-4-4), ALT present, dummy, DATA=READ quad
`define DESC_READ_QUAD_IO \
  `DESC( 1'b1, 1'b1, `DUMMY_READ_1_4_4[7:0], `IO_WIDTH_1, `IO_WIDTH_4, `IO_WIDTH_4, `IO_WIDTH_4, `IO_WIDTH_4, `DIR_READ )

// 0xBB: Dual I/O Fast Read (1-2-2), ALT present, dummy, DATA=READ dual
`define DESC_READ_DUAL_IO \
  `DESC( 1'b1, 1'b1, `DUMMY_FAST_READ_1_1_1[7:0], `IO_WIDTH_1, `IO_WIDTH_2, `IO_WIDTH_2, `IO_WIDTH_2, `IO_WIDTH_2, `DIR_READ )

// 0x05: Read Status Register (1-1-1), DATA=READ single
`define DESC_RDSR \
  `DESC( 1'b0, 1'b0, 8'd0, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `DIR_READ )

// 0x02: Page Program (1-1-1), DATA=WRITE single
`define DESC_PP \
  `DESC( 1'b1, 1'b0, 8'd0, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `DIR_WRITE )

// 0x32: Quad Page Program (1-1-4), DATA=WRITE quad
`define DESC_PP_QUAD \
  `DESC( 1'b1, 1'b0, 8'd0, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_4, `IO_WIDTH_4, `DIR_WRITE )

// 0x20/0x52/0xD8: Erases - address only, no data; model as DATA=READ w/ zero bytes
`define DESC_ERASE_ADDR_ONLY \
  `DESC( 1'b1, 1'b0, 8'd0, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `DIR_READ )

// 0x06/0x04: WREN/WRDI - no addr, no data; treat as control (no data phase)
`define DESC_CTRL_NO_DATA \
  `DESC( 1'b0, 1'b0, 8'd0, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `DIR_READ )

// -------------------------------
// Central decode macro (case body snippet)
// Usage:
//   reg [31:0] desc;
//   always @* begin
//     case (opcode)
//       `OP_READ_SLOW:      desc = `DESC_READ_SLOW;
//       `OP_READ_FAST:      desc = `DESC_READ_FAST;
//       `OP_READ_QUAD_OUT:  desc = `DESC_READ_QUAD_OUT;
//       `OP_READ_QUAD_IO:   desc = `DESC_READ_QUAD_IO;
//       `OP_READ_DUAL_OUT:  desc = `DESC_READ_DUAL_OUT;
//       `OP_READ_DUAL_IO:   desc = `DESC_READ_DUAL_IO;
//       `OP_RDID:           desc = `DESC_RDID;
//       `OP_RDSR:           desc = `DESC_RDSR;
//       `OP_PP:             desc = `DESC_PP;
//       `OP_PP_QUAD:        desc = `DESC_PP_QUAD;
//       `OP_SECTOR_ERASE,
//       `OP_BLOCK_ERASE_32K,
//       `OP_BLOCK_ERASE_64K:desc = `DESC_ERASE_ADDR_ONLY;
//       `OP_WREN,
//       `OP_WRDI:           desc = `DESC_CTRL_NO_DATA;
//       default:                 desc = 32'b0; // unknown -> no phases
//     endcase
//   end
// -------------------------------

`endif // OPCODE_TABLE_VH
