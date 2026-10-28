#ifndef QSPI_COMMANDS_H
#define QSPI_COMMANDS_H

#include <cstddef>
#include <cstdint>

/*
 * Command descriptors for the S25FL128S/S25FL256S flash.
 *
 * This table covers both local datasheets: the older Spansion
 * S25FL128S_256S_00_06 and the newer Infineon Rev. *T document.  The only
 * opcode-set difference is 18h: it is ECCRD in the newer document and RFU
 * (reserved) in the older one.  Both entries are retained below so the
 * selected device revision is explicit.  Do not issue RESERVED_18_LEGACY on
 * a device that supports ECCRD, or ECCRD on the older device.
 *
 * Bus-width encoding used by CMD_CONFIG:
 *   1 = single, 2 = dual, 3 = quad, 0 = reserved/unused
 * Address-width encoding used by CMD_CONFIG:
 *   0 = no address, 1 = 24-bit address, 2 = 32-bit address
 *
 * CMD_CONFIG layout (matches REGISTER_MAP.md):
 *   [19:18] address bit width
 *   [17:15] data width
 *   [14:12] mode width
 *   [11:9]  address width
 *   [8:6]   command width
 *   [5]     has RX data
 *   [4]     has TX data
 *   [3]     has dummy cycles
 *   [2]     has mode bits
 *   [1]     has address
 *   [0]     has opcode
 *
 * CMD_DATA layout:
 *   [31:24] mode bits
 *   [23:16] mode cycles
 *   [15:8]  dummy cycles
 *   [7:0]   opcode
 *
 * The command table stores default transfer lengths as well.  Software may
 * replace rx_len/tx_len for variable-length reads and page programs.
 */
namespace qspi {

enum class BusWidth : uint32_t {
    SINGLE = 1,
    DUAL   = 2,
    QUAD   = 3
};

enum class AddressWidth : uint32_t {
    NONE = 0,
    BITS_24 = 1,
    BITS_32 = 2
};

struct CommandDescriptor {
    const char *name;
    bool has_opcode;
    uint32_t cmd_config;
    uint32_t cmd_data;
    uint32_t tx_len;
    uint32_t rx_len;
};

constexpr uint32_t pack_cmd_config(
    uint8_t opcode,
    bool has_addr,
    bool has_mode,
    bool has_dummy,
    bool has_tx_data,
    bool has_rx_data,
    AddressWidth addr_bits,
    BusWidth cmd_width,
    BusWidth addr_width,
    BusWidth mode_width,
    BusWidth data_width)
{
    (void)opcode;
    return 1u
        | (static_cast<uint32_t>(has_addr)     << 1)
        | (static_cast<uint32_t>(has_mode)     << 2)
        | (static_cast<uint32_t>(has_dummy)    << 3)
        | (static_cast<uint32_t>(has_tx_data)  << 4)
        | (static_cast<uint32_t>(has_rx_data)  << 5)
        | (static_cast<uint32_t>(cmd_width)    << 6)
        | (static_cast<uint32_t>(addr_width)   << 9)
        | (static_cast<uint32_t>(mode_width)   << 12)
        | (static_cast<uint32_t>(data_width)   << 15)
        | (static_cast<uint32_t>(addr_bits)    << 18);
}

constexpr uint32_t pack_cmd_data(uint8_t opcode, uint16_t dummy_cycles,
                                 uint8_t mode_cycles = 0,
                                 uint8_t mode_bits = 0)
{
    return static_cast<uint32_t>(opcode)
        | (static_cast<uint32_t>(dummy_cycles & 0xff) << 8)
        | (static_cast<uint32_t>(mode_cycles) << 16)
        | (static_cast<uint32_t>(mode_bits) << 24);
}

/* Common command-construction shorthand. */
#define QSPI_CMD(n, op, a, m, d, tx, rx, ab, cw, aw, mw, dw, dc, mc, mb, tl, rl) \
    { n, true, pack_cmd_config(op, a, m, d, tx, rx, ab, cw, aw, mw, dw), \
      pack_cmd_data(op, dc, mc, mb), tl, rl }

/*
 * Every opcode in the two datasheet command tables is represented below.
 * Lengths are
 * minimum/default lengths; callers must replace them for streaming reads and
 * page-sized program operations.  Address-bearing register/protection
 * commands use the 32-bit address phase required by the device.
 */
constexpr CommandDescriptor COMMANDS[] = {
    QSPI_CMD("WRR",        0x01, false, false, false, true,  false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 2, 0),
    QSPI_CMD("PP",         0x02, true,  false, false, true,  false, AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 1, 0),
    QSPI_CMD("READ",       0x03, true,  false, false, false, true,  AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 1),
    QSPI_CMD("WRDI",       0x04, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("RDSR1",      0x05, false, false, false, false, true,  AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 1),
    QSPI_CMD("WREN",       0x06, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("RDSR2",      0x07, false, false, false, false, true,  AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 1),
    QSPI_CMD("FAST_READ",  0x0B, true,  false, true,  false, true,  AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 8, 0, 0, 0, 1),
    QSPI_CMD("4FAST_READ", 0x0C, true,  false, true,  false, true,  AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 8, 0, 0, 0, 1),
    QSPI_CMD("DDRFR",      0x0D, true,  false, true,  false, true,  AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 4, 0, 0, 0, 1),
    QSPI_CMD("4DDRFR",     0x0E, true,  false, true,  false, true,  AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 4, 0, 0, 0, 1),
    QSPI_CMD("4PP",        0x12, true,  false, false, true,  false, AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 1, 0),
    QSPI_CMD("4READ",      0x13, true,  false, false, false, true,  AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 1),
    QSPI_CMD("ABRD",       0x14, false, false, false, false, true,  AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 4),
    QSPI_CMD("ABWR",       0x15, false, false, false, true,  false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 4, 0),
    QSPI_CMD("BRRD",       0x16, false, false, false, false, true,  AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 1),
    QSPI_CMD("BRWR",       0x17, false, false, false, true,  false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 1, 0),
    QSPI_CMD("ECCRD",      0x18, true,  false, false, false, true,  AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 1),
    QSPI_CMD("RESERVED_18_LEGACY", 0x18, false, false, false, false, false, AddressWidth::NONE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("P4E",        0x20, true,  false, false, false, false, AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("4P4E",       0x21, true,  false, false, false, false, AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("ASPRD",      0x2B, false, false, false, false, true,  AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 2),
    QSPI_CMD("ASPP",       0x2F, false, false, false, true,  false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 2, 0),
    QSPI_CMD("CLSR",       0x30, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("QPP",        0x32, true,  false, false, true,  false, AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::QUAD,   0, 0, 0, 1, 0),
    QSPI_CMD("4QPP",       0x34, true,  false, false, true,  false, AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::QUAD,   0, 0, 0, 1, 0),
    QSPI_CMD("RDCR",       0x35, false, false, false, false, true,  AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 1),
    QSPI_CMD("QPP_ALT",    0x38, true,  false, false, true,  false, AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::QUAD,   0, 0, 0, 1, 0),
    QSPI_CMD("DOR",        0x3B, true,  false, true,  false, true,  AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::DUAL,   8, 0, 0, 0, 1),
    QSPI_CMD("4DOR",       0x3C, true,  false, true,  false, true,  AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::DUAL,   8, 0, 0, 0, 1),
    QSPI_CMD("DLPRD",      0x41, false, false, false, false, true,  AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 8),
    QSPI_CMD("OTPP",       0x42, true,  false, false, true,  false, AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 1, 0),
    QSPI_CMD("PNVDLR",     0x43, false, false, false, true,  false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 1, 0),
    QSPI_CMD("WVDLR",      0x4A, false, false, false, true,  false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 1, 0),
    QSPI_CMD("OTPR",       0x4B, true,  false, false, false, true,  AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 1),
    QSPI_CMD("BE",         0x60, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("QOR",        0x6B, true,  false, true,  false, true,  AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::QUAD,   8, 0, 0, 0, 1),
    QSPI_CMD("4QOR",       0x6C, true,  false, true,  false, true,  AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::QUAD,   8, 0, 0, 0, 1),
    QSPI_CMD("ERSP",       0x75, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("ERRS",       0x7A, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("PGSP",       0x85, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("PGRS",       0x8A, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("READ_ID",    0x90, true,  false, true,  false, true,  AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 8, 0, 0, 0, 1),
    QSPI_CMD("RDID",       0x9F, false, false, false, false, true,  AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 3),
    QSPI_CMD("MPM",        0xA3, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("PLBWR",      0xA6, false, false, false, true,  false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 1, 0),
    QSPI_CMD("PLBRD",      0xA7, false, false, false, false, true,  AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 1),
    QSPI_CMD("RES",        0xAB, true,  false, true,  false, true,  AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 8, 0, 0, 0, 1),
    QSPI_CMD("BRAC",       0xB9, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("DIOR",       0xBB, true,  false, true,  false, true,  AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::DUAL,   BusWidth::SINGLE, BusWidth::DUAL,   4, 0, 0, 0, 1),
    QSPI_CMD("4DIOR",      0xBC, true,  false, true,  false, true,  AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::DUAL,   BusWidth::SINGLE, BusWidth::DUAL,   4, 0, 0, 0, 1),
    QSPI_CMD("DDRDIOR",    0xBD, true,  true,  true,  false, true,  AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::DUAL,   BusWidth::DUAL,   BusWidth::DUAL,   4, 2, 0xA5, 0, 1),
    QSPI_CMD("4DDRDIOR",   0xBE, true,  true,  true,  false, true,  AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::DUAL,   BusWidth::DUAL,   BusWidth::DUAL,   4, 2, 0xA5, 0, 1),
    QSPI_CMD("BE_ALT",     0xC7, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("SE",         0xD8, true,  false, false, false, false, AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("4SE",        0xDC, true,  false, false, false, false, AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("DYBRD",      0xE0, true,  false, false, false, true,  AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 1),
    QSPI_CMD("DYBWR",      0xE1, true,  false, false, true,  false, AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 1, 0),
    QSPI_CMD("PPBRD",      0xE2, true,  false, false, false, true,  AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 1),
    QSPI_CMD("PPBP",       0xE3, true,  false, false, true,  false, AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 1, 0),
    QSPI_CMD("PPBE",       0xE4, true,  false, false, false, false, AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("RESERVED_E5",0xE5, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("RESERVED_E6",0xE6, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("PASSRD",     0xE7, false, false, false, false, true,  AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 8),
    QSPI_CMD("PASSP",      0xE8, false, false, false, true,  false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 8, 0),
    QSPI_CMD("PASSU",      0xE9, false, false, false, true,  false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 8, 0),
    QSPI_CMD("QIOR",       0xEB, true,  true,  true,  false, true,  AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::QUAD,   BusWidth::QUAD,   BusWidth::QUAD,   6, 2, 0xA5, 0, 1),
    QSPI_CMD("4QIOR",      0xEC, true,  true,  true,  false, true,  AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::QUAD,   BusWidth::QUAD,   BusWidth::QUAD,   6, 2, 0xA5, 0, 1),
    QSPI_CMD("DDRQIOR",    0xED, true,  true,  true,  false, true,  AddressWidth::BITS_24,  BusWidth::SINGLE, BusWidth::QUAD,   BusWidth::QUAD,   BusWidth::QUAD,   6, 1, 0xA5, 0, 1),
    QSPI_CMD("4DDRQIOR",   0xEE, true,  true,  true,  false, true,  AddressWidth::BITS_32,  BusWidth::SINGLE, BusWidth::QUAD,   BusWidth::QUAD,   BusWidth::QUAD,   6, 1, 0xA5, 0, 1),
    QSPI_CMD("RESET",      0xF0, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0),
    QSPI_CMD("MBR",        0xFF, false, false, false, false, false, AddressWidth::NONE,    BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, BusWidth::SINGLE, 0, 0, 0, 0, 0)
};

constexpr std::size_t COMMAND_COUNT = sizeof(COMMANDS) / sizeof(COMMANDS[0]);

inline const CommandDescriptor *find_command(const char *name)
{
    if (name == nullptr) return nullptr;
    for (std::size_t i = 0; i < COMMAND_COUNT; ++i) {
        const char *a = COMMANDS[i].name;
        const char *b = name;
        while (*a != '\0' && *a == *b) { ++a; ++b; }
        if (*a == '\0' && *b == '\0') return &COMMANDS[i];
    }
    return nullptr;
}

#undef QSPI_CMD

} // namespace qspi

#endif // QSPI_COMMANDS_H
