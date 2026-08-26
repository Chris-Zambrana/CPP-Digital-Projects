# QSPI IP Register Map Draft

This document defines the CPU-facing register map for the QSPI flash controller. The goal is to expose enough control for robust flash transactions without forcing software to bit-bang individual SPI edges.

The register map should let software:

- Configure SPI timing and operating mode.
- Launch flash commands.
- Provide command address, optional mode bits, transmit data, expected receive length, and dummy cycles.
- Poll on completion first, with interrupts reserved for a later revision.
- Inspect controller errors and flash status.
- Safely perform read, erase, program, and later quad-mode transfers.

## Register Summary

| Offset | Register | Access | Purpose |
| --- | --- | --- | --- |
| `0x00` | `PULSE` | W | Write-only command pulse port for starting transactions and issuing soft reset. |
| `0x04` | `CONTROL` | W | Selects SPI clock/bit-order behavior. |
| `0x08` | `STATUS` | R | Reports controller ready/done/error state and FIFO readiness. |
| `0x0C` | `CLK_DIV` | W | Sets QSPI SCK frequency derived from the SoC clock. |
| `0x10` | `CMD` | W | Holds the flash instruction opcode and transaction format flags. |
| `0x14` | `FADDR` | W | Holds the flash byte address for address-based commands. |
| `0x18` | `TX_LEN` | W | Number of bytes software wants the controller to transmit after command/address. |
| `0x1C` | `RX_LEN` | W | Number of bytes software wants the controller to receive. |
| `0x20` | `DUMMY` | W | Number of dummy cycles inserted before read data. |
| `0x24` | `TXDATA` | W | Write port into the transmit FIFO. |
| `0x28` | `RXDATA` | R | Read port from the receive FIFO. |
| `0x2C` | `CS_SELECT` | W | Selects which flash chip-select line is active during a transaction. |

Offsets can change later to match the SoC bus alignment style, but the signals below are the important part.

## `PULSE` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `CSR_WIDTH-1:2` | `RESERVED` | Read as zero, ignored on write. | Reserved for future write-one command pulses. |
| `1` | `SOFT_RESET` | Write-one pulse that resets the controller FSM, FIFOs, sticky status, and IO controls without resetting the whole SoC. | Essential during bring-up and driver recovery while preserving persistent CSR configuration. |
| `0` | `START` | Write-one pulse used after software has configured `CONTROL`, `CMD`, `FADDR`, `TX_LEN`, `RX_LEN`, `DUMMY`, `CS_SELECT`, and any needed `TXDATA`. When accepted with `STATUS.READY=1`, hardware snapshots the setup, asserts flash chip select, and begins the QSPI transaction. Hardware ignores writes when `STATUS.READY=0`. | Creates an explicit transaction boundary without risking accidental changes to persistent control bits. |

## `CONTROL` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `CSR_WIDTH-1:3` | `RESERVED` | Read as zero, ignored on write. | Reserved for future controller options while keeping the first map small. |
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
| `CSR_WIDTH-1:5` | `RESERVED` | Read as zero. | Reserved for future status. |
| `4` | `RX_EMPTY` | RX FIFO has no data available for the CPU to read. | This is the only RX FIFO flag software needs: if `RX_EMPTY=0`, software can read `RXDATA`. |
| `3` | `TX_FULL` | TX FIFO cannot accept another CPU write. | This is the only TX FIFO flag software needs: if `TX_FULL=0`, software can write `TXDATA`. |
| `2` | `ERROR` | The controller detected a transaction error. | Gives software a fast common error check without requiring a detailed error register in the first revision. |
| `1` | `DONE` | Transaction completed. Write `1` to clear if sticky. | Polling-friendly completion signal. |
| `0` | `READY` | Controller is idle and ready to accept a new transaction. | Software can check this before modifying command registers, loading FIFOs, or writing `PULSE.START`. |

Saved-for-later status fields:

- `FLASH_WIP`: cached SR1[0] Write-In-Progress bit after hardware status polling or status caching exists.
- `FLASH_WEL`: cached SR1[1] Write Enable Latch bit after hardware status polling or status caching exists.

## `CLK_DIV` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `CSR_WIDTH-1:DIVIDER_BITS` | `RESERVED` | Read as zero. | Keeps the register aligned while allowing the divider width to track the clock generator. |
| `DIVIDER_BITS-1:0` | `DIVIDER` | Divides the SoC clock down to generate SCK. Exact formula should be documented once the clock generator is implemented. | Flash commands have max SCK limits. Bring-up should start slow, then increase gradually. |

Why this matters: the S25FL128S allows different max frequencies by command. Normal `READ 03h` is slower than `FAST_READ 0Bh`, and quad commands have their own limits. Software needs direct control so tests can start conservatively.

## `CMD` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `CSR_WIDTH-1:23` | `RESERVED` | Read as zero. | Future command options. |
| `22:21` | `DATA_BUS_WIDTH` | Bus width used during data phase. | Needed to reuse the same engine for single, dual, and quad data transfers. |
| `20:19` | `MODE_BUS_WIDTH` | Bus width used during the optional mode phase. | Allows the same command descriptor to handle quad-I/O commands whose mode bits are driven over IO0-IO3. |
| `18:17` | `ADDR_BUS_WIDTH` | Bus width used during address phase. Single for normal/quad-output reads, quad for quad-I/O reads. | Distinguishes `QOR 6Bh` from `QIOR EBh`. |
| `16:15` | `CMD_BUS_WIDTH` | Bus width used during opcode phase. Usually single. | Flash instructions are normally sent single-bit on SI/IO0, even for quad commands. Keep this explicit for future compatibility. |
| `14:13` | `ADDR_BIT_WIDTH` | `00` = none, `01` = 24-bit, `10` = 32-bit, `11` reserved. | Keeps address width with the command descriptor, which is clearer than hiding it in global control state. |
| `12` | `HAS_RX_DATA` | Transaction includes a receive data phase. | Required for reads, status reads, ID reads, and config reads. |
| `11` | `HAS_TX_DATA` | Transaction includes software-provided transmit data after command/address/mode phases. | Required for page program, register write, and similar commands. |
| `10` | `HAS_DUMMY` | Transaction includes dummy cycles before read data. | Required for fast and quad reads. |
| `9` | `HAS_MODE` | Transaction includes a mode phase after the address phase and before dummy/read data. | Needed later for enhanced/continuous read commands such as Quad I/O Read (`QIOR EBh`). Basic MVP commands leave this clear. |
| `8` | `HAS_ADDR` | Transaction includes an address phase. | Not all commands have addresses; for example `RDID` and `RDSR1` do not. |
| `7:0` | `OPCODE` | Flash instruction byte, such as `9Fh`, `05h`, `03h`, `0Bh`, `02h`, `20h`, `D8h`. | Keeps the hardware generic. Software can issue many commands without new HDL. |

Saved-for-later command fields:

- `EXPECT_WIP`: command is expected to start a long internal flash operation after the bus transaction completes. This is useful once hardware auto-WIP polling, flash-ready interrupts, or command-aware timeout handling exists.

## `FADDR` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `MAX_ADDR_BITS-1:0` | `FLASH_ADDR` | Byte address sent during the address phase. The active address width is selected by `CMD.ADDR_BIT_WIDTH`, so the serialized address can vary by flash/device mode. | Read, program, and erase commands all need a target flash address. |

Why this matters: using a byte address register keeps software simple and lets the hardware serialize either 24 or 32 address bits depending on the command descriptor.

## `TX_LEN` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `CSR_WIDTH-1:CONST_DATA_LEN` | `RESERVED` | Read as zero. | Future larger transfers or DMA fields. |
| `CONST_DATA_LEN-1:0` | `tx_len` | Number of data bytes to transmit after opcode/address/dummy phases. | Needed for page program and register writes. |

Why this matters: `TX_LEN` should not include opcode or address bytes. It only describes the payload software writes into `TXDATA`.

## `RX_LEN` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `CSR_WIDTH-1:CONST_DATA_LEN` | `RESERVED` | Read as zero. | Future larger transfers or DMA fields. |
| `CONST_DATA_LEN-1:0` | `rx_len` | Number of bytes to receive during the data phase. | Required for ID reads, status reads, memory reads, and readback verification. |

Why this matters: fixed receive length makes the transaction finite, which is easier to verify than open-ended flash reads.

## `DUMMY` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `CSR_WIDTH-1:DUMMY_COUNT+MODE_CYCLE_COUNT+MODE_BITS` | `RESERVED` | Read as zero. | Future latency controls. |
| `DUMMY_COUNT+MODE_CYCLE_COUNT+MODE_BITS-1:DUMMY_COUNT+MODE_CYCLE_COUNT` | `MODE_BITS` | Optional mode-bit value driven during mode cycles. | Allows quad-I/O continuous-read support without custom HDL per command. |
| `DUMMY_COUNT+MODE_CYCLE_COUNT-1:DUMMY_COUNT` | `MODE_CYCLES` | Optional count for mode/continuous-read bits in quad-I/O commands. | Useful later for `QIOR EBh`; can be zero for MVP. |
| `DUMMY_COUNT-1:0` | `DUMMY_CYCLES` | Number of SCK cycles inserted between address/mode phases and read data. | Fast and quad reads require latency cycles depending on command and SCK speed. |

## `TXDATA` Register

Recommended behavior:

- Write-only CPU port into the transmit FIFO.
- A 32-bit write may push 1 to 4 bytes depending on byte enables and bus design.
- Data should be transmitted MSB-first within each byte, but byte order from a 32-bit CPU write must be explicitly documented.

Why include it:

- Page program and register write commands need payload bytes.
- A FIFO prevents software from racing the SPI clock one byte at a time.
- FIFO depth can be small at first, then expanded later.

## `RXDATA` Register

Recommended behavior:

- Read-only CPU port from the receive FIFO.
- A 32-bit read may pop 1 to 4 bytes depending on the chosen bus behavior.
- Empty reads should either return zero with an underrun error or be blocked by software checking `STATUS.RX_EMPTY == 0` first.

Why include it:

- Flash reads, status reads, and ID reads all need a clean receive path.
- Using a FIFO makes reads of arbitrary length practical.

## `CS_SELECT` Register

Recommended fields:

| Bit(s) | Field | Description | Why Include It |
| --- | --- | --- | --- |
| `CSR_WIDTH-1:$clog2(QSPI_SLAVE_COUNT)` | `RESERVED` | Read as zero. | Reserved for future chip-select behavior such as per-device mode or timing. |
| `$clog2(QSPI_SLAVE_COUNT)-1:0` | `CS_NUM` | Selects which flash device is targeted by the next transaction. The selected chip-select is driven active during the command; all other chip-selects remain inactive. | Allows the same QSPI controller to talk to more than one flash device without adding separate controller instances. |

## Deferred Registers

These registers are intentionally left out of the lean first implementation:

| Register | Purpose |
| --- | --- |
| `IRQ_ENABLE` | Enables interrupt-driven operation after polling is proven. |
| `IRQ_STATUS` | Reports latched interrupt causes after interrupt-driven operation is added. |
| `FLASH_STATUS` | Caches SR1/SR2/CR1 after hardware status caching or auto-WIP polling exists. |
| `ERROR_STATUS` | Provides detailed error causes if `STATUS.ERROR` is not enough during later bring-up. |
| `SCRATCH` or `VERSION` | Provides bus-test or IP-identification convenience if needed later. |
| `TIMEOUT` | Hardware timeout limit for transactions. Later this can also limit auto-WIP polling. Strongly recommended before hardware bring-up. |
| `FIFO_CTRL` | FIFO flush bits and RX/TX threshold configuration. Useful once interrupts or longer transfers are added. |
| `XFER_COUNT` | Actual bytes transmitted/received in the last transaction. Helpful for debug. |
| `CS_TIMING` | Setup/hold/deselect timing around CS#. Useful if timing needs tightening later. |
| `DEVICE_ID0/1` | Cached JEDEC ID/CFI bytes after a helper identify command. Nice for software convenience. |
| `DMA_ADDR` / `DMA_LEN` / `DMA_CTRL` | Future high-throughput memory read/program path. Not needed for MVP. |

## Recommended First Revision

For the first HDL implementation, keep the hardware smaller:

- Include only `CONTROL`, `STATUS`, `PULSE`, `CLK_DIV`, `CMD`, `FADDR`, `TX_LEN`, `RX_LEN`, `DUMMY`, `TXDATA`, `RXDATA`, and `CS_SELECT`.
- Defer interrupts, including any global IRQ enable bit, until polling is proven.
- Defer cached `FLASH_STATUS` until status-read helper logic or auto-WIP polling exists.
- Defer dual/quad fields internally if desired, but reserve the bits now so the software interface does not churn later.

## Example CPU Flow: Read JEDEC ID

1. Set `CLK_DIV` to a conservative SCK rate.
2. Write `CMD.OPCODE = 0x9F`, `HAS_RX_DATA = 1`, no address, no dummy.
3. Set `RX_LEN = 3` or longer if reading extended ID/CFI bytes.
4. Confirm `STATUS.READY = 1`, then write `PULSE.START = 1`.
5. Poll `STATUS.DONE` or `STATUS.ERROR`.
6. Read bytes from `RXDATA` while `STATUS.RX_EMPTY == 0`.

## Example CPU Flow: Page Program

1. Confirm address is in the reserved scratch region.
2. Issue `WREN 0x06` as a command-only transaction.
3. Optionally read `RDSR1` and confirm WEL is set.
4. Fill `TXDATA` with the page payload.
5. Program with `PP 0x02`, address enabled, `TX_LEN` set, no receive data.
6. Poll flash WIP through repeated `RDSR1` commands. Hardware auto-WIP polling is a later enhancement.
7. Read back and compare.

## Design Principle

The register map should describe transactions, not waveforms. Software should say: opcode, address, optional mode bits, bus widths, dummy cycles, transmit length, receive length, start. Hardware should own CS#, SCK, IO direction, shifting, FIFO movement, and error detection.
