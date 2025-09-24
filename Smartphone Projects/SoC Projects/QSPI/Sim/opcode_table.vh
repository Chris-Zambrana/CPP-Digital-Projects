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
`define IO_WIDTH_0  `MODE_ZERO
`define IO_WIDTH_1  `MODE_SINGLE
`define IO_WIDTH_2  `MODE_DUAL  
`define IO_WIDTH_4  `MODE_QUAD  
                     
// -------------------------------
// Data direction for DATA phase:
// 0 = READ (slave drives data out to master)
// 1 = WRITE (slave receives/programs data from master)
// -------------------------------
`define READ   `DIR_READ
`define WRITE  `DIR_WRITE

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
// -------------------------------
// Common opcodes (JEDEC-like)
// -------------------------------
`define OP_READ_FAST          8'h0B  // 1-1-1 Fast Read (dummy)
`define OP_READ_DUAL_OUT      8'h3B  // 1-1-2 Fast Read Dual Output
`define OP_READ_QUAD_OUT      8'h6B  // 1-1-4 Fast Read Quad Output
`define OP_READ_DUAL_IO       8'hBB  // 1-2-2 Fast Read Dual I/O (alt+dummy)
`define OP_READ_QUAD_IO       8'hEB  // 1-4-4 Fast Read Quad I/O (alt+dummy)
`define OP_READ_FAST_DUAL      8'hBB  // 2-2-2 Read (alias to 0xBB in DPI mode)
`define OP_READ_FAST_QUAD      8'hEB  // 4-4-4 Read (alias to 0xEB in QPI mode)

// -------------------------------
// WRITE / PROGRAM opcode family (JEDEC-like defaults)
// -------------------------------
`define OP_PAGE_SINGLE_IO        8'h02  // 1-1-1 Page Program
`define OP_PAGE_DUAL_OUT    8'hA2  // 1-1-2 Dual Input Fast Program
`define OP_PAGE_QUAD_OUT    8'h32  // 1-1-4 Quad Input Fast Program
`define OP_PAGE_DUAL_IO     8'hD2  // 1-2-2 Dual I/O Fast Program
`define OP_PAGE_QUAD_IO     8'h3E  // 1-4-4 Quad I/O Fast Program
`define OP_PAGE_2_2_2       8'h82  // 2-2-2 Program (DPI/QPI mode)
`define OP_PAGE_4_4_4       8'h12  // 4-4-4 Program (some vendors use 0x38; use 0x12 here)


`define OP_DPI_EN          8'hE2  // Enable Dual Peripheral Interface (2-2-2 opcodes)
`define OP_QPI_EN          8'h38  // Enable Quad Peripheral Interface (4-4-4 opcodes)

// -------------------------------
// Default dummy cycles per opcode (override as needed)
// Reads often need dummy; writes generally do not.
// -------------------------------

// Reads
`ifndef DUMMY_READ_1_1_1
`define DUMMY_READ_1_1_1        8   // 0x0B Fast Read commonly 8 dummy cycles
`endif
`ifndef DUMMY_READ_1_1_2
`define DUMMY_READ_1_1_2        8   // 0x3B Dual Output Fast Read
`endif
`ifndef DUMMY_READ_1_1_4
`define DUMMY_READ_1_1_4        8   // 0x6B Quad Output Fast Read
`endif
`ifndef DUMMY_READ_1_2_2
`define DUMMY_READ_1_2_2        8   // 0xBB Dual I/O Fast Read (ALT + dummy)
`endif
`ifndef DUMMY_READ_1_4_4
`define DUMMY_READ_1_4_4        6   // 0xEB Quad I/O Fast Read (ALT + dummy) - 6 or 8 typical
`endif
`ifndef DUMMY_READ_2_2_2
`define DUMMY_READ_2_2_2        8   // 2-2-2 Fast Read (DPI mode)
`endif
`ifndef DUMMY_READ_4_4_4
`define DUMMY_READ_4_4_4        6   // 4-4-4 Fast Read (QPI mode) - 6 or 8 typical
`endif

// Writes (program) - typically no dummy cycles
`ifndef DUMMY_WRITE_1_1_1
`define DUMMY_WRITE_1_1_1       0
`endif
`ifndef DUMMY_WRITE_1_1_2
`define DUMMY_WRITE_1_1_2       0
`endif
`ifndef DUMMY_WRITE_1_1_4
`define DUMMY_WRITE_1_1_4       0
`endif
`ifndef DUMMY_WRITE_1_2_2
`define DUMMY_WRITE_1_2_2       0
`endif
`ifndef DUMMY_WRITE_1_4_4
`define DUMMY_WRITE_1_4_4       0
`endif
`ifndef DUMMY_WRITE_2_2_2
`define DUMMY_WRITE_2_2_2       0
`endif
`ifndef DUMMY_WRITE_4_4_4
`define DUMMY_WRITE_4_4_4       0
`endif

`ifndef DUMMY_DPI_EN
`define DUMMY_DPI_EN       0
`endif
`ifndef DUMMY_QPI_EN
`define DUMMY_QPI_EN       0
`endif

// Helpers to pack/unpack the descriptor
`define DESC( HasAddr, HasAlt, HasData, Dummy8, IO_Instr, IO_Addr, IO_Alt, IO_Dummy, IO_Data, Dir ) \
    { 10'b0, Dir[0], IO_Data[1:0], IO_Dummy[1:0], IO_Alt[1:0], IO_Addr[1:0], IO_Instr[1:0], Dummy8[7:0], HasData[0], HasAlt[0], HasAddr[0] }

`define DESC_HAS_ADDR(d)      ( (d)[0] )
`define DESC_HAS_ALT(d)       ( (d)[1] )
`define DESC_HAS_DATA(d)      ( (d)[2] )
`define DESC_DUMMY(d)         ( (d)[10:3] )
`define DESC_IO_WIDTH_INSTR(d)     ( (d)[12:11] )
`define DESC_IO_WIDTH_ADDR(d)      ( (d)[14:13] )
`define DESC_IO_WIDTH_ALT(d)       ( (d)[16:15] )
`define DESC_IO_WIDTH_DUMMY(d)     ( (d)[18:17] )
`define DESC_IO_WIDTH_DATA(d)      ( (d)[20:19] )
`define DESC_DIR(d)           ( (d)[21] )

// -------------------------------
// Descriptor macros for the added READ opcodes
// -------------------------------

// 0x3B: Dual Output Fast Read (1-1-2), dummy, DATA=READ dual
`undef  DESC_READ_DUAL_OUT
`define DESC_READ_DUAL_OUT \
  `DESC( 1'b1, 1'b0, 1'b1, `DUMMY_READ_1_1_2[7:0], `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_0, `IO_WIDTH_2, `IO_WIDTH_2, `READ )

// 0x0B: Fast Read (1-1-1), dummy, DATA=READ single
`undef  DESC_READ_FAST
`define DESC_READ_FAST \
  `DESC( 1'b1, 1'b0, 1'b1, `DUMMY_READ_1_1_1[7:0], `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_0, `IO_WIDTH_1, `IO_WIDTH_1, `READ )

// 0x6B: Quad Output Fast Read (1-1-4), dummy, DATA=READ quad
`undef  DESC_READ_QUAD_OUT
`define DESC_READ_QUAD_OUT \
  `DESC( 1'b1, 1'b0, 1'b1, `DUMMY_READ_1_1_4[7:0], `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_0, `IO_WIDTH_4, `IO_WIDTH_4, `READ )

// 0xBB: Dual I/O Fast Read (1-2-2), ALT+dum, DATA=READ dual
`undef  DESC_READ_DUAL_IO
`define DESC_READ_DUAL_IO \
  `DESC( 1'b1, 1'b1, 1'b1, `DUMMY_READ_1_2_2[7:0], `IO_WIDTH_1, `IO_WIDTH_2, `IO_WIDTH_2, `IO_WIDTH_2, `IO_WIDTH_2, `READ )

// 0xEB: Quad I/O Fast Read (1-4-4), ALT+dum, DATA=READ quad
`undef  DESC_READ_QUAD_IO
`define DESC_READ_QUAD_IO \
  `DESC( 1'b1, 1'b1, 1'b1, `DUMMY_READ_1_4_4[7:0], `IO_WIDTH_1, `IO_WIDTH_4, `IO_WIDTH_4, `IO_WIDTH_4, `IO_WIDTH_4, `READ )

// 2-2-2 Read (alias to 0xBB when in DPI/QPI mode)
`undef  DESC_READ_2_2_2
`define DESC_READ_2_2_2 \
  `DESC( 1'b1, 1'b0, 1'b1, `DUMMY_READ_2_2_2[7:0], `IO_WIDTH_2, `IO_WIDTH_2, `IO_WIDTH_0, `IO_WIDTH_2, `IO_WIDTH_2, `READ )

// 4-4-4 Read (alias to 0xEB when in QPI mode)
`undef  DESC_READ_4_4_4
`define DESC_READ_4_4_4 \
  `DESC( 1'b1, 1'b0, 1'b1, `DUMMY_READ_4_4_4[7:0], `IO_WIDTH_4, `IO_WIDTH_4, `IO_WIDTH_0, `IO_WIDTH_4, `IO_WIDTH_4, `READ )

// -------------------------------
// Descriptor macros for WRITE / PROGRAM opcodes
// (Programs generally: HAS_ADDR=1, HAS_ALT=0, no dummy)
// -------------------------------

// 0x02: Page Program (1-1-1)
`undef  DESC_WRITE_1_1_1
`define DESC_WRITE_1_1_1 \
  `DESC( 1'b1, 1'b0, 1'b1, `DUMMY_WRITE_1_1_1[7:0], `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_0, `IO_WIDTH_0, `IO_WIDTH_1, `WRITE )

// 0xA2: Dual Input Fast Program (1-1-2)
`undef  DESC_WRITE_1_1_2
`define DESC_WRITE_1_1_2 \
  `DESC( 1'b1, 1'b0, 1'b1, `DUMMY_WRITE_1_1_2[7:0], `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_0, `IO_WIDTH_0, `IO_WIDTH_2, `WRITE )

// 0x32: Quad Input Fast Program (1-1-4)
`undef  DESC_WRITE_1_1_4
`define DESC_WRITE_1_1_4 \
  `DESC( 1'b1, 1'b0, 1'b1, `DUMMY_WRITE_1_1_4[7:0], `IO_WIDTH_1, `IO_WIDTH_1, `IO_WIDTH_0, `IO_WIDTH_0, `IO_WIDTH_4, `WRITE )

// 0xD2: Dual I/O Fast Program (1-2-2)
`undef  DESC_WRITE_1_2_2
`define DESC_WRITE_1_2_2 \
  `DESC( 1'b1, 1'b0, 1'b1, `DUMMY_WRITE_1_2_2[7:0], `IO_WIDTH_1, `IO_WIDTH_2, `IO_WIDTH_0, `IO_WIDTH_0, `IO_WIDTH_2, `WRITE )

// 0x3E: Quad I/O Fast Program (1-4-4)
`undef  DESC_WRITE_1_4_4
`define DESC_WRITE_1_4_4 \
  `DESC( 1'b1, 1'b0, 1'b1, `DUMMY_WRITE_1_4_4[7:0], `IO_WIDTH_1, `IO_WIDTH_4, `IO_WIDTH_0, `IO_WIDTH_0, `IO_WIDTH_4, `WRITE )

// 0x82: Program (2-2-2) - DPI mode
`undef  DESC_WRITE_2_2_2
`define DESC_WRITE_2_2_2 \
  `DESC( 1'b1, 1'b0, 1'b1, `DUMMY_WRITE_2_2_2[7:0], `IO_WIDTH_2, `IO_WIDTH_2, `IO_WIDTH_0, `IO_WIDTH_0, `IO_WIDTH_2, `WRITE )

// 0x12: Program (4-4-4) - QPI mode
`undef  DESC_WRITE_4_4_4
`define DESC_WRITE_4_4_4 \
  `DESC( 1'b1, 1'b0, 1'b1, `DUMMY_WRITE_4_4_4[7:0], `IO_WIDTH_4, `IO_WIDTH_4, `IO_WIDTH_0, `IO_WIDTH_0, `IO_WIDTH_4, `WRITE )

`undef  DESC_DPI_EN
`define DESC_DPI_EN \
  `DESC( 1'b0, 1'b0, 1'b0, `DUMMY_DPI_EN, `IO_WIDTH_1, `IO_WIDTH_0, `IO_WIDTH_0, `IO_WIDTH_0, `IO_WIDTH_0, `READ )

`undef  DESC_QPI_EN
`define DESC_QPI_EN \ 
  `DESC( 1'b0, 1'b0, 1'b0, `DUMMY_QPI_EN, `IO_WIDTH_1, `IO_WIDTH_4, `IO_WIDTH_0, `IO_WIDTH_0, `IO_WIDTH_4, `READ )

// -------------------------------
// Decode snippet expansion: map opcodes -> descriptors
// -------------------------------
// Example usage:
//   reg [31:0] desc;
//   always @* begin
//     case (opcode)
//       // Reads
//       `OP_READ_FAST:         desc = `DESC_READ_FAST;
//       `OP_READ_DUAL_OUT:     desc = `DESC_READ_DUAL_OUT;
//       `OP_READ_QUAD_OUT:     desc = `DESC_READ_QUAD_OUT;
//       `OP_READ_DUAL_IO:      desc = `DESC_READ_DUAL_IO;
//       `OP_READ_QUAD_IO:      desc = `DESC_READ_QUAD_IO;
//       `OP_READ_FAST_DUAL:    desc = `DESC_READ_2_2_2;  // DPI
//       `OP_READ_FAST_QUAD:    desc = `DESC_READ_4_4_4;  // QPI
//
//       // Writes
//       `OP_PROGRAM_QUAD_IO:   desc = `DESC_WRITE_1_4_4;
//       `OP_PROGRAM_2_2_2:     desc = `DESC_WRITE_2_2_2;
//       `OP_PROGRAM_4_4_4:     desc = `DESC_WRITE_4_4_4;
//
//       // Control/status examples (define elsewhere if you use them):
//       // `OP_RDID:           desc = `DESC_RDID;
//       // `OP_RDSR:           desc = `DESC_RDSR;
//       // `OP_WREN,
//       // `OP_WRDI:           desc = `DESC_CTRL_NO_DATA;
//
//       default:               desc = 32'b0; // unknown -> no phases
//     endcase
//   end

`endif // OPCODE_TABLE_VH
