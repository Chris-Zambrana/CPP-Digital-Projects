// opcode_table.vh
// -----------------------------------------------------------------------------
// QSPI opcode values and a compact, parameterized phase descriptor per opcode.
// This header is Verilog-friendly (no SystemVerilog structs) and portable.
// -----------------------------------------------------------------------------
// Depends on: qspi_definitions.vh for:
//   - `BITS_ADDR, `BITS_ALT, `IO_WIDTH_DEFAULT, `CPOL_0, `CPHA_0 (etc if used)
// You can safely include this in both RTL and TB.
// -----------------------------------------------------------------------------

`include "qspi_definitions.vh" 

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
`define DESC( HasAddr, HasAlt, Dummy8, IO_Instr, IO_Addr, IO_Alt, IO_Dummy, IO_Data, Dir ) \
    { 11'b0, Dir[0], IO_Data[1:0], IO_Dummy[1:0], IO_Alt[1:0], IO_Addr[1:0], IO_Instr[1:0], Dummy8[7:0], HasAlt[0], HasAddr[0] }

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

//Reads
`define OP_READ_FAST          8'h0B  // 1-1-1 Fast Read (dummy)
`define OP_READ_DUAL_OUT      8'h3B  // 1-1-2 Fast Read Dual Output
`define OP_READ_QUAD_OUT      8'h6B  // 1-1-4 Fast Read Quad Output
`define OP_READ_DUAL_IO       8'hBB  // 1-2-2 Fast Read Dual I/O (alt+dummy)
`define OP_READ_QUAD_IO       8'hEB  // 1-4-4 Fast Read Quad I/O (alt+dummy)
`define OP_READ_FAST_DUAL     8'hBB  // 2-2-2
`define OP_READ_FAST_QUAD     8'hEB  // 4-4-4

// Writes
`define OP_PAGE               8'h02  // 1-1-1 Page Program
`define OP_PAGE_DUAL_IN    8'hA2  // 1-1-2 Dual Input Fast Program
`define OP_PAGE_QUAD_IN    8'h32  // 1-1-4 Quad Input Fast Program
`define OP_PAGE_DUAL_IO    8'hD2  // 1-2-2 Dual I/O Fast Program
`define OP_PAGE_QUAD_IO    8'h38  // 1-4-4 Quad I/O Fast Program
`define OP_PAGE_2_2_2      8'h82  // 2-2-2 Program
`define OP_PAGE_4_4_4      8'h12  // 4-4-4 Program (some devices also use 0x38)


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

// 0x6B: Quad Output Fast Read (1-1-4), dummy, DATA=READ quad
`define DESC_READ_QUAD_OUT \
  `DESC( 1'b1, 1'b0, `DUMMY_READ_1_1_4[7:0], `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_4, `IO_WIDTH_4, `DIR_READ )

// 0xEB: Quad I/O Fast Read (1-4-4), ALT present, dummy, DATA=READ quad
`define DESC_READ_QUAD_IO \
  `DESC( 1'b1, 1'b1, `DUMMY_READ_1_4_4[7:0], `IO_WIDTH_1, `IO_WIDTH_4, `IO_WIDTH_4, `IO_WIDTH_4, `IO_WIDTH_4, `DIR_READ )

// 0x3B: Dual Output Fast Read (1-1-2), dummy, DATA=READ dual
`define DESC_READ_DUAL_OUT \
  `DESC( 1'b1, 1'b0, `DUMMY_FAST_READ_1_1_1[7:0], `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_2, `IO_WIDTH_2, `DIR_READ )

// 0xBB: Dual I/O Fast Read (1-2-2), ALT present, dummy, DATA=READ dual
`define DESC_READ_DUAL_IO \
  `DESC( 1'b1, 1'b1, `DUMMY_FAST_READ_1_1_1[7:0], `IO_WIDTH_1, `IO_WIDTH_2, `IO_WIDTH_2, `IO_WIDTH_2, `IO_WIDTH_2, `DIR_READ )

// -------------------------------
// Central decode macro (case body snippet)
// Usage:
//   reg [31:0] desc;
//   always @* begin
//     case (opcode)
//       `OP_READ_FAST:      desc = `DESC_READ_FAST;
//       `OP_READ_QUAD_OUT:  desc = `DESC_READ_QUAD_OUT;
//       `OP_READ_QUAD_IO:   desc = `DESC_READ_QUAD_IO;
//       `OP_READ_DUAL_OUT:  desc = `DESC_READ_DUAL_OUT;
//       `OP_READ_DUAL_IO:   desc = `DESC_READ_DUAL_IO;
//       `OP_RDID:           desc = `DESC_RDID;
//       `OP_RDSR:           desc = `DESC_RDSR;
//       `OP_WREN,
//       `OP_WRDI:           desc = `DESC_CTRL_NO_DATA;
//       default:                 desc = 32'b0; // unknown -> no phases
//     endcase
//   end
// -------------------------------

`endif // OPCODE_TABLE_VH
