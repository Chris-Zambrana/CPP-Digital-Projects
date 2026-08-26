# I2C IP CSR Register Draft

This document is the first review draft for the CPU-facing CSR register map of the I2C master core. The goal is to expose enough software control for reliable bring-up, polling-based transfers, debug visibility, and later interrupt support without forcing software to bit-bang individual SCL/SDA phases.

The initial hardware model is intentionally byte-command based:

- Software writes one transmit byte or requests one receive byte at a time.
- `CONTROL.CMD` launches one primitive I2C operation at a time.
- Software polls `STATUS.DONE` first; interrupts are deferred until after polling is proven.
- The first revision includes small TX and RX FIFOs, matching the QSPI project style.

## Review Legend

Use the `Review Decision` column while walking through this draft:

- `Keep`
- `Remove`
- `Rename`
- `Change`
- `Defer`

## Register Summary

All CSRs are 32-bit, little-endian, word-aligned registers.

| Offset | Register | Access | Reset | Purpose | Review Decision |
| --- | --- | --- | --- | --- | --- |
| `0x00` | `CONTROL` | RW | `0x0000_0000` | Requests soft reset and launches primitive I2C commands. | TBD |
| `0x04` | `STATUS` | RO/W1C | `0x0000_0011` | Reports command readiness, completion, target ACK status, and software-visible FIFO state. | TBD |
| `0x08` | `CLK_DIV` | RW | TBD | Sets the I2C SCL rate from the SoC clock. | TBD |
| `0x0C` | `TXDATA` | WO | `0x0000_0000` | Write port into the transmit FIFO. | TBD |
| `0x10` | `RXDATA` | RO | `0x0000_0000` | Read port from the receive FIFO. | TBD |

## `CONTROL` Register

`CONTROL` contains pulse-like core-level controls. `SOFT_RESET` should self-clear in hardware. Writes to `CMD` values should be treated as command launch pulses, not stored state.

| Bit(s) | Field | Access | Reset | Description | Why Include It | Review Decision |
| --- | --- | --- | --- | --- | --- | --- |
| `0` | `SOFT_RESET` | W1P/RO0 | `0` | Write `1` to reset the controller FSM, byte engine, sticky status, and flush both FIFOs without resetting the full SoC. Hardware self-clears this bit. | Useful for recovery during board bring-up if a transaction fails. | TBD |
| `3:1` | `CMD` | WO/RO0 | `0x0` | Primitive I2C command launch field. See `CONTROL.CMD` encoding below. | Keeps command launch inside the control register and removes the standalone `CMD` CSR. | TBD |
| `31:4` | `RESERVED` | RO | `0` | Read as zero; ignore writes. | Leaves room for later control options. | TBD |

### `CONTROL.CMD` Encoding

Software should write one command value at a time when `STATUS.READY=1`. A command is launched by the CPU write access itself. This matters because `START` is encoded as `0b000`; writing `CONTROL.CMD=0b000` intentionally launches START rather than meaning "no command."

| Value | Name | Description | FIFO Use | Review Decision |
| --- | --- | --- | --- | --- |
| `0b000` | `START` | Generate an I2C START condition. | None | TBD |
| `0b001` | `WR` | Pop one byte from the TX FIFO, transmit it on SDA, then sample the target ACK/NACK bit. | Requires TX FIFO not empty internally. | TBD |
| `0b010` | `RD` | Receive one byte into the RX FIFO. Read ACK/NACK behavior is implementation-defined until we decide whether this aliases `RD_ACK` or `RD_NACK`. | Requires RX FIFO not full internally. | TBD |
| `0b011` | `STOP` | Generate an I2C STOP condition. | None | TBD |
| `0b100` | `RESTART` | Generate a repeated START condition while the bus is already owned by this controller. | None | TBD |
| `0b101` | `RD_ACK` | Receive one byte into the RX FIFO, then drive ACK on the ninth clock to request another byte. | Requires RX FIFO not full internally. | TBD |
| `0b110` | `RD_NACK` | Receive one byte into the RX FIFO, then drive NACK on the ninth clock to end the read burst. | Requires RX FIFO not full internally. | TBD |
| `0b111` | `RESERVED` | Invalid for first revision. | None | TBD |

Recommended rejected-command behavior:

- If not ready, missing required FIFO data, blocked by RX FIFO full, or invalid, do not launch the command.
- Do not set a software-visible error bit in the first revision; software is expected to follow `READY`, `TX_FULL`, and `RX_EMPTY`.
- A new accepted command should clear old `STATUS.DONE`.

## `STATUS` Register

`STATUS` mixes live read-only state with sticky write-one-to-clear event and error bits. Software should clear sticky bits by writing `1` to the affected bit positions.

Recommended first-pass behavior:

- `READY`, `TX_FULL`, and `RX_EMPTY` are live RO status bits.
- `DONE` and `ACK_ERROR` are sticky W1C bits.
- A new accepted `CONTROL.CMD` write should clear old `DONE`, but should not automatically clear old error bits unless we decide that policy during review.

| Bit(s) | Field | Access | Reset | Description | Why Include It | Review Decision |
| --- | --- | --- | --- | --- | --- | --- |
| `0` | `READY` | RO | `1` | Controller is idle and ready to accept a new `CONTROL.CMD` write. | Gives polling software a positive ready/acceptance check before launching the next operation. | TBD |
| `1` | `DONE` | W1C | `0` | Last accepted command completed. | Primary polling completion bit. | TBD |
| `2` | `ACK_ERROR` | W1C | `0` | A transmitted byte was NACKed during the ACK bit. | Required for normal I2C error handling and device-presence detection. | TBD |
| `3` | `TX_FULL` | RO | `0` | TX FIFO cannot accept another CPU write. | Software checks this before writing `TXDATA`. | TBD |
| `4` | `RX_EMPTY` | RO | `1` | RX FIFO has no bytes available for CPU reads. | Software checks this before reading `RXDATA`. | TBD |
| `31:5` | `RESERVED` | RO | `0` | Read as zero; ignore writes. | Future status and error causes. | TBD |

## `CLK_DIV` Register

`CLK_DIV` sets the SCL period generated by the four-phase bit engine.

Proposed formula:

```text
f_scl = f_clk / (4 * (DIVIDER + 1))
```

| Bit(s) | Field | Access | Reset | Description | Why Include It | Review Decision |
| --- | --- | --- | --- | --- | --- | --- |
| `15:0` | `DIVIDER` | RW | TBD | Divider used by the SCL phase generator. Larger values create slower I2C clocks. | Lets software start conservatively, then move toward standard-mode or fast-mode timing. | TBD |
| `31:16` | `RESERVED` | RO | `0` | Read as zero; ignore writes. | Keeps the register aligned and leaves expansion room. | TBD |

Open review item: choose reset value based on the actual SoC clock. A conservative reset should target a slow SCL rate that is safe for bring-up.

## `TXDATA` Register

`TXDATA` is the CPU write port into the transmit FIFO. The controller pops one byte for each accepted `CONTROL.CMD=WR` command.

| Bit(s) | Field | Access | Reset | Description | Why Include It | Review Decision |
| --- | --- | --- | --- | --- | --- | --- |
| `7:0` | `TX_BYTE` | WO | `0x00` | Byte pushed into the TX FIFO when software writes `TXDATA`. | Required for address bytes, register offsets, and write payloads. | TBD |
| `31:8` | `RESERVED` | RO | `0` | Read as zero; ignore writes. | Keeps software accesses 32-bit aligned. | TBD |

Recommended behavior:

- Software should check `STATUS.TX_FULL == 0` before writing `TXDATA`.
- Writes while `TX_FULL=1` should be ignored, unless the CSR bridge can reject the access cleanly.
- For the class SoC bus style, a 32-bit write pushes `wr_data[7:0]` as one byte. Upper bits are ignored.

## `RXDATA` Register

`RXDATA` is the CPU read port from the receive FIFO. The controller pushes one byte for each successful `CONTROL.CMD=RD`, `CONTROL.CMD=RD_ACK`, or `CONTROL.CMD=RD_NACK` command.

| Bit(s) | Field | Access | Reset | Description | Why Include It | Review Decision |
| --- | --- | --- | --- | --- | --- | --- |
| `7:0` | `RX_BYTE` | RO | `0x00` | Byte popped from the RX FIFO when software reads `RXDATA`. Valid when `STATUS.RX_EMPTY=0`. | Required readback path for target data. | TBD |
| `31:8` | `RESERVED` | RO | `0` | Read as zero. | Keeps software accesses 32-bit aligned. | TBD |

Recommended behavior:

- Software should check `STATUS.RX_EMPTY == 0` before reading `RXDATA`.
- Reads while `RX_EMPTY=1` should return zero, unless the CSR bridge can reject the access cleanly.
- For the class SoC bus style, a 32-bit read returns one byte in `rd_data[7:0]`. Upper bits return zero.

## Deferred or Optional Registers

These are not proposed as first-revision CSRs unless we decide they are worth reserving now.

| Register | Purpose | Suggested Decision |
| --- | --- | --- |
| `FIFO_CTRL` | Explicit FIFO flush bits and thresholds beyond the basic soft-reset flush behavior. | Defer |
| `FIFO_STATUS` | TX/RX FIFO level reporting beyond the basic full/empty bits in `STATUS`. | Defer |
| `IRQ_ENABLE` | Interrupt mask for done, error, RX threshold, TX threshold, or FIFO events. | Defer |
| `IRQ_STATUS` | Latched interrupt causes. | Defer |
| `TIMEOUT` | Configurable clock-stretch or bus-wait timeout. | Defer |
| `PRESENCE` | IP identity/version register. Removed from first revision; reconsider only if the driver needs bus probing. | Remove |
| `ARB_LOST` status | Arbitration-lost detection for multi-master operation. | Defer |
| `BUS_BUSY` status | External bus-occupied observation. Removed from first revision because this controller is scoped as a single-master open-drain design. | Remove |
| `BUS_STUCK` status | Sticky physical bus-stuck indication. Removed from first revision; reconsider with timeout or bus recovery. | Remove |
| `BUS_RECOVERY` | Hardware-assisted SCL pulsing to free a stuck target. | Defer |
| `FILTER_CFG` | SDA/SCL input deglitch filter length. | Consider if board noise becomes an issue |
| `TIMING_CFG` | Separate high/low/setup/hold timing instead of one `CLK_DIV`. | Defer unless standard/fast-mode timing margins require it |
| `DEBUG_STATE` | Encoded controller FSM and byte-engine state. | Consider for bring-up only |
| `SCRATCH` | Read/write software scratch register for bus tests. | Optional |

## Recommended First RTL Revision

Recommended keep set for the first coding pass:

- `CONTROL`
- `STATUS`
- `CLK_DIV`
- `TXDATA`
- `RXDATA`

Recommended decision points before RTL:

- Decide TX/RX FIFO depth.
- Decide whether failed `TXDATA` writes or empty `RXDATA` reads are silently ignored or rejected by the CSR bridge.
- Decide the exact `CLK_DIV` reset value from the SoC clock.

## Example Software Flow

The examples below assume small helper routines in the C++ driver:

- `waitReady()`: poll until `STATUS.READY == 1`.
- `waitDone()`: poll until `STATUS.DONE == 1`, then clear `DONE` by writing `1` to `STATUS.DONE`.
- `clearAckError()`: clear sticky `STATUS.ACK_ERROR` by writing `1` to that bit.
- `writeTx(byte)`: wait until `STATUS.TX_FULL == 0`, then write `TXDATA.TX_BYTE`.
- `issue(cmd)`: call `waitReady()`, write `CONTROL.CMD`, then call `waitDone()`.

Because `ACK_ERROR` is sticky, software should clear it before a `WR` command when it wants to know whether that specific byte was acknowledged.

### Write One Target Register

For a 7-bit I2C device address `addr7`, target register `reg`, and data byte `value`:

1. `issue(START)`.
2. `writeTx({addr7, 1'b0})`.
3. `clearAckError()`.
4. `issue(WR)`.
5. Check `STATUS.ACK_ERROR`; abort on NACK.
6. `writeTx(reg)`.
7. `clearAckError()`.
8. `issue(WR)`.
9. Check `STATUS.ACK_ERROR`; abort on NACK.
10. `writeTx(value)`.
11. `clearAckError()`.
12. `issue(WR)`.
13. Check `STATUS.ACK_ERROR`; abort on NACK.
14. `issue(STOP)`.

### Read One Target Register

For a one-byte register read from 7-bit I2C device address `addr7`:

1. `issue(START)`.
2. `writeTx({addr7, 1'b0})`.
3. `clearAckError()`.
4. `issue(WR)`.
5. Check `STATUS.ACK_ERROR`; abort on NACK.
6. `writeTx(reg)`.
7. `clearAckError()`.
8. `issue(WR)`.
9. Check `STATUS.ACK_ERROR`; abort on NACK.
10. `issue(RESTART)`.
11. `writeTx({addr7, 1'b1})`.
12. `clearAckError()`.
13. `issue(WR)`.
14. Check `STATUS.ACK_ERROR`; abort on NACK.
15. `issue(RD_NACK)`.
16. Poll until `STATUS.RX_EMPTY == 0`.
17. Read `RXDATA.RX_BYTE`.
18. `issue(STOP)`.

For multi-byte reads, use `RD_ACK` for each byte except the final byte, then use `RD_NACK` for the last byte before `STOP`.
