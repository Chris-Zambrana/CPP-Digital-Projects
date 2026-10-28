# QSPI IP Register Map Draft

This document defines the CPU-facing register map for the QSPI flash controller. The goal is to expose enough control for robust flash transactions without forcing software to bit-bang individual SPI edges.

The register map should let software:

- Configure SPI timing and operating mode.
- Launch flash commands.
- Provide command address, optional mode bits, transmit data, expected receive length, and dummy cycles.
- Poll on completion first, with interrupts reserved for a later revision.
- Inspect controller readiness and FIFO status.
- Safely perform read, erase, program, and later quad-mode transfers.

## Register Summary

| Word address | Register | Access | Purpose |
| --- | --- | --- | --- |
| `0x0` | `PULSE` | W | Write-only command pulse port for starting transactions. |
| `0x1` | `CONTROL` | W | Selects SPI clock/bit-order behavior and DDR mode. |
| `0x2` | `STATUS` | R | Reports controller readiness and FIFO status. |
| `0x3` | `DIVIDER_REG` | W | Sets QSPI SCK frequency derived from the SoC clock. |
| `0x4` | `CMD_CONF_REG` | W | Holds transaction format flags, address width, and per-phase IO widths. |
| `0x5` | `CMD_DATA_REG` | W | Holds the opcode, mode-bit value, and dummy-cycle count. |
| `0x6` | `FADDR` | W | Holds the flash byte address for address-based commands. |
| `0x7` | `TX_LEN` | W | Number of bytes software wants the controller to transmit after command/address. |
| `0x8` | `RX_LEN` | W | Number of bytes software wants the controller to receive. |
| `0x9` | `TX_DATA_REG` | W | Write port into the transmit FIFO. |
| `0xA` | `RX_DATA_REG` | R | Read port from the receive FIFO. |
| `0xB` | `CS_REG` | W | Selects which flash chip-select line is active during a transaction. |

The RTL uses these values as word-addressed CSR indices (`addr == 0` through `addr == 11`).

## `PULSE` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `QSPI_CSR_WIDTH-1:1` | `RESERVED` | Read as zero, ignored on write. | Reserved for future write-one command pulses. |
| `0` | `START` | Write-one pulse used after software has configured `CONTROL`, `CMD_CONF_REG`, `CMD_DATA_REG`, `FADDR`, `TX_LEN`, `RX_LEN`, `CS_REG`, and any needed `TX_DATA_REG`. When accepted with `STATUS.READY=1`, hardware snapshots the setup, asserts flash chip select, and begins the QSPI transaction. Hardware ignores writes when `STATUS.READY=0`. | Creates an explicit transaction boundary without risking accidental changes to persistent control bits. |

## `CONTROL` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `QSPI_CSR_WIDTH-1:4` | `RESERVED` | Read as zero, ignored on write. | Reserved for future controller options while keeping the first map small. |
| `3` | `DDR_EN` | Enables double-data-rate transfers when set. `0` selects single-data-rate operation. | Allows software to select SDR or DDR transfers without changing the command descriptor format. |
| `2` | `LSB_FIRST` | Optional bit-order control. Default `0` means MSB-first. | SPI flash commands are normally MSB-first, but keeping this bit gives the controller some reuse/debug flexibility. |
| `1` | `CPHA` | SPI clock phase. `0` means sample on the first active edge; `1` means sample on the second active edge. | Pairing CPHA with CPOL lets software select mode 0 (`CPOL=0`, `CPHA=0`) or mode 3 (`CPOL=1`, `CPHA=1`). |
| `0` | `CPOL` | SPI clock polarity. `0` means SCK idles low; `1` means SCK idles high. | The S25FL128S supports mode 0 and mode 3, so CPOL/CPHA bits make the mode explicit. |

Saved-for-later control fields:

- `AUTO_WIP_POLL`: hardware-assisted polling of SR1.WIP after program, erase, or register-write commands. Leave this out of the first control register until basic polling through software is proven.
- `IRQ_GLOBAL_EN`: top-level interrupt output enable. Save this until `IRQ_ENABLE` and `IRQ_STATUS` are implemented.

## `STATUS` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `QSPI_CSR_WIDTH-1:3` | `RESERVED` | Read as zero. | Reserved for future status. |
| `2` | `RX_EMPTY` | RX FIFO has no data available for the CPU to read. | This is the only RX FIFO flag software needs: if `RX_EMPTY=0`, software can read `RX_DATA_REG`. |
| `1` | `TX_FULL` | TX FIFO cannot accept another CPU write. | This is the only TX FIFO flag software needs: if `TX_FULL=0`, software can write `TX_DATA_REG`. |
| `0` | `READY` | Controller is idle and ready to accept a new transaction. | Software can check this before modifying command registers, loading FIFOs, or writing `PULSE.START`. |

Saved-for-later status fields:

- `FLASH_WIP`: cached SR1[0] Write-In-Progress bit after hardware status polling or status caching exists.
- `FLASH_WEL`: cached SR1[1] Write Enable Latch bit after hardware status polling or status caching exists.

## `DIVIDER_REG` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `QSPI_CSR_WIDTH-1:QSPI_DIVIDER_WIDTH` | `RESERVED` | Read as zero. | Keeps the register aligned while allowing the divider width to track the clock generator. |
| `QSPI_DIVIDER_WIDTH-1:0` | `DIVIDER` | Divides the SoC clock down to generate SCK. Exact formula should be documented once the clock generator is implemented. | Flash commands have max SCK limits. Bring-up should start slow, then increase gradually. |

Why this matters: the S25FL128S allows different max frequencies by command. Normal `READ 03h` is slower than `FAST_READ 0Bh`, and quad commands have their own limits. Software needs direct control so tests can start conservatively.

## `CMD_CONF_REG` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `QSPI_CSR_WIDTH-1:20` | `RESERVED` | Read as zero. | Reserved for future command configuration fields. |
| `19:18` | `ADDR_BIT_WIDTH` | Two-bit address-width selector. | Keeps address width with the command descriptor. |
| `17:15` | `DATA_IO_WIDTH` | Three-bit IO-width selector for the data phase. | Supports single-, dual-, and quad-lane data transfers. |
| `14:12` | `MODE_IO_WIDTH` | Three-bit IO-width selector for the mode phase. | Allows mode bits to be driven over the selected number of IO lines. |
| `11:9` | `ADDR_IO_WIDTH` | Three-bit IO-width selector for the address phase. | Distinguishes normal/quad-output reads from quad-I/O reads. |
| `8:6` | `CMD_IO_WIDTH` | Three-bit IO-width selector for the opcode phase. | Supports the configured command-phase lane width. |
| `5` | `HAS_RX_DATA` | Transaction includes a receive data phase. | Required for reads, status reads, ID reads, and config reads. |
| `4` | `HAS_TX_DATA` | Transaction includes software-provided transmit data after command/address/mode phases. | Required for page program, register write, and similar commands. |
| `3` | `HAS_DUMMY` | Transaction includes dummy cycles before read data. | Required for fast and quad reads. |
| `2` | `HAS_MODE` | Transaction includes a mode phase after the address phase and before dummy/read data. | Supports enhanced/continuous-read commands such as Quad I/O Read (`QIOR EBh`). |
| `1` | `HAS_ADDR` | Transaction includes an address phase. | Not all commands have addresses; for example `RDID` and `RDSR1` do not. |
| `0` | `HAS_OPCODE` | Transaction includes the opcode phase. | Allows command-only transactions to be represented explicitly. |

The exact bit positions are shown above. Packed from least-significant to most-significant bit, the fields are `HAS_OPCODE`, `HAS_ADDR`, `HAS_MODE`, `HAS_DUMMY`, `HAS_TX_DATA`, `HAS_RX_DATA`, `CMD_IO_WIDTH`, `ADDR_IO_WIDTH`, `MODE_IO_WIDTH`, `DATA_IO_WIDTH`, and `ADDR_BIT_WIDTH`.

Saved-for-later command fields:

- `EXPECT_WIP`: command is expected to start a long internal flash operation after the bus transaction completes. This is useful once hardware auto-WIP polling, flash-ready interrupts, or command-aware timeout handling exists.

## `CMD_DATA_REG` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `QSPI_CSR_WIDTH-1:8+QSPI_MODE_WIDTH+QSPI_DUMMY_COUNT_WIDTH` | `RESERVED` | Read as zero. | Reserved for future command-data fields. |
| `8+QSPI_MODE_WIDTH+QSPI_DUMMY_COUNT_WIDTH-1:8+QSPI_MODE_WIDTH` | `DUMMY_CYCLES` | Number of SCK cycles inserted between address/mode phases and read data. | Fast and quad reads require latency cycles depending on command and SCK speed. |
| `8+QSPI_MODE_WIDTH-1:8` | `MODE_BITS` | Optional mode-bit value driven during the mode phase. | Supports quad-I/O continuous-read commands without custom HDL per command. |
| `7:0` | `OPCODE` | Flash instruction byte, such as `9Fh`, `05h`, `03h`, `0Bh`, `02h`, `20h`, or `D8h`. | Keeps the hardware generic. Software can issue many commands without new HDL. |

The exact bit positions are shown above. Packed from least-significant to most-significant bit, the fields are `OPCODE`, `MODE_BITS`, and `DUMMY_CYCLES`.

## `FADDR` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `MAX_ADDR_BITS-1:0` | `FLASH_ADDR` | Byte address sent during the address phase. The active address width is selected by `CMD_CONF_REG.ADDR_BIT_WIDTH`, so the serialized address can vary by flash/device mode. | Read, program, and erase commands all need a target flash address. |

Why this matters: using a byte address register keeps software simple and lets the hardware serialize either 24 or 32 address bits depending on the command descriptor.

## `TX_LEN` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `CSR_WIDTH-1:CONST_DATA_LEN` | `RESERVED` | Read as zero. | Future larger transfers or DMA fields. |
| `CONST_DATA_LEN-1:0` | `tx_len` | Number of data bytes to transmit after opcode/address/dummy phases. | Needed for page program and register writes. |

Why this matters: `TX_LEN` should not include opcode or address bytes. It only describes the payload software writes into `TX_DATA_REG`.

## `RX_LEN` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `CSR_WIDTH-1:CONST_DATA_LEN` | `RESERVED` | Read as zero. | Future larger transfers or DMA fields. |
| `CONST_DATA_LEN-1:0` | `rx_len` | Number of bytes to receive during the data phase. | Required for ID reads, status reads, memory reads, and readback verification. |

Why this matters: fixed receive length makes the transaction finite, which is easier to verify than open-ended flash reads.

## `TX_DATA_REG` Register

Recommended behavior:

- Write-only CPU port into the transmit FIFO.
- A 32-bit write may push 1 to 4 bytes depending on byte enables and bus design.
- Data should be transmitted MSB-first within each byte, but byte order from a 32-bit CPU write must be explicitly documented.

Why include it:

- Page program and register write commands need payload bytes.
- A FIFO prevents software from racing the SPI clock one byte at a time.
- FIFO depth can be small at first, then expanded later.

## `RX_DATA_REG` Register

Recommended behavior:

- Read-only CPU port from the receive FIFO.
- A 32-bit read may pop 1 to 4 bytes depending on the chosen bus behavior.
- Empty reads should either return zero with an underrun error or be blocked by software checking `STATUS.RX_EMPTY == 0` first.

Why include it:

- Flash reads, status reads, and ID reads all need a clean receive path.
- Using a FIFO makes reads of arbitrary length practical.

## `CS_REG` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `QSPI_CSR_WIDTH-1:$clog2(QSPI_SLAVE_COUNT)` | `RESERVED` | Read as zero. | Reserved for future chip-select behavior such as per-device mode or timing. |
| `$clog2(QSPI_SLAVE_COUNT)-1:0` | `CS_NUM` | Selects which flash device is targeted by the next transaction. The selected chip-select is driven active during the command; all other chip-selects remain inactive. | Allows the same QSPI controller to talk to more than one flash device without adding separate controller instances. |

## Deferred Registers

These registers are intentionally left out of the lean first implementation:

| Register | Purpose |
| --- | --- |
| `IRQ_ENABLE` | Enables interrupt-driven operation after polling is proven. |
| `IRQ_STATUS` | Reports latched interrupt causes after interrupt-driven operation is added. |
| `FLASH_STATUS` | Caches SR1/SR2/CR1 after hardware status caching or auto-WIP polling exists. |
| `ERROR_STATUS` | Provides detailed error causes if later revisions add explicit error reporting. |
| `SCRATCH` or `VERSION` | Provides bus-test or IP-identification convenience if needed later. |
| `TIMEOUT` | Hardware timeout limit for transactions. Later this can also limit auto-WIP polling. Strongly recommended before hardware bring-up. |
| `FIFO_CTRL` | FIFO flush bits and RX/TX threshold configuration. Useful once interrupts or longer transfers are added. |
| `XFER_COUNT` | Actual bytes transmitted/received in the last transaction. Helpful for debug. |
| `CS_TIMING` | Setup/hold/deselect timing around CS#. Useful if timing needs tightening later. |
| `DEVICE_ID0/1` | Cached JEDEC ID/CFI bytes after a helper identify command. Nice for software convenience. |
| `DMA_ADDR` / `DMA_LEN` / `DMA_CTRL` | Future high-throughput memory read/program path. Not needed for MVP. |

## Recommended First Revision

For the first HDL implementation, keep the hardware smaller:

- Include only `PULSE`, `CONTROL`, `STATUS`, `DIVIDER_REG`, `CMD_CONF_REG`, `CMD_DATA_REG`, `FADDR`, `TX_LEN`, `RX_LEN`, `TX_DATA_REG`, `RX_DATA_REG`, and `CS_REG`.
- Defer interrupts, including any global IRQ enable bit, until polling is proven.
- Defer cached `FLASH_STATUS` until status-read helper logic or auto-WIP polling exists.
- Defer dual/quad fields internally if desired, but reserve the bits now so the software interface does not churn later.

## Example CPU Flow: Read JEDEC ID

1. Set `DIVIDER_REG` to a conservative SCK rate.
2. Write `CMD_DATA_REG.OPCODE = 0x9F` and set `CMD_CONF_REG.HAS_OPCODE = 1`, `CMD_CONF_REG.HAS_RX_DATA = 1`, with no address or dummy phase.
3. Set `RX_LEN = 3` or longer if reading extended ID/CFI bytes.
4. Confirm `STATUS.READY = 1`, then write `PULSE.START = 1`.
5. Poll `STATUS.READY` until the transaction is complete.
6. Read bytes from `RX_DATA_REG` while `STATUS.RX_EMPTY == 0`.

## Example CPU Flow: Page Program

1. Confirm address is in the reserved scratch region.
2. Issue `WREN 0x06` as a command-only transaction.
3. Optionally read `RDSR1` and confirm WEL is set.
4. Fill `TX_DATA_REG` with the page payload.
5. Program with `PP 0x02`, address enabled, `TX_LEN` set, no receive data.
6. Poll flash WIP through repeated `RDSR1` commands. Hardware auto-WIP polling is a later enhancement.
7. Read back and compare.

## Design Principle

The register map should describe transactions, not waveforms. Software should say: opcode, address, optional mode bits, bus widths, dummy cycles, transmit length, receive length, start. Hardware should own CS#, SCK, IO direction, shifting, FIFO movement, and error detection.
