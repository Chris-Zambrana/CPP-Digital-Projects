# I2C IP Module Breakdown

This document describes the first-revision I2C master controller module structure, each module's role, and the main signals that move between modules.

The current design assumes the class SoC already has a simple bus bridge or slot interface. Because of that, the I2C core does not need to implement a full bus protocol internally. The top-level I2C core receives simple register access signals and exposes CPU-visible CSRs through `i2c_csr_map`.

The first revision uses a primitive command model. Software launches one I2C operation at a time, such as START, WRITE byte, READ byte with ACK/NACK, repeated START, or STOP. Complex transactions are built by software from those primitive commands. This keeps the RTL predictable for bring-up and makes the controller easier to verify.

Two I2C conventions are used throughout this document:

- SDA and SCL are open-drain style lines. The core drives a line low for `0` and releases it for `1`; external pull-ups create the high level.
- ACK is active-low. A receiver acknowledges by pulling SDA low during the ninth SCL pulse. A released/high SDA during the ACK bit means NACK.

## First-Revision Module List

Recommended modules:

| Module | Role |
| --- | --- |
| `top_i2c_core` | Top-level core wrapper. Connects the SoC slot interface, internal modules, and open-drain SDA/SCL pins. |
| `i2c_csr_map` | Implements the CPU-visible register map and converts register writes into control, FIFO, and command-launch signals. |
| `i2c_controller` | Main transaction FSM. Accepts primitive commands from the CSR map and sequences the byte engine through START, STOP, WRITE, READ, and repeated START operations. |
| `i2c_byte_engine` | Byte/bit-level I2C engine. Owns SCL timing counters, generates SDA/SCL behavior, shifts TX/RX bits, and handles ACK/NACK. |
| `i2c_open_drain_io` | Converts internal drive-low/release controls into open-drain SDA/SCL pin behavior and returns synchronized pin samples to the byte engine. |
| `fifo` | Small byte-wide FIFO used for TX and RX buffering. This can be one reusable FIFO module instantiated twice. |

Deferred modules:

| Module | Why Deferred |
| --- | --- |
| `irq_logic` | Interrupts can wait until polling-based command execution is proven. First revision does not include a top-level `irq` output. |
| `timeout_watchdog` | Clock-stretch timeout and stuck-bus recovery are useful, but the first RTL pass can focus on basic master transfers. |
| `arb_lost_detector` | Multi-master arbitration detection is not required for the first single-master bring-up path. |
| `bus_recovery_engine` | Automatic SCL pulsing to recover a stuck target is saved for a later robustness pass. |
| `timing_cfg_ext` | Separate setup/hold/high/low timing registers are deferred unless one divider is not enough for target timing margins. |

## `top_i2c_core`

### Role

`top_i2c_core` is the integration point for the core. It receives the simple slot-style register interface from the existing SoC bridge, connects those signals to `i2c_csr_map`, and wires the CSR map, controller, FIFOs, byte engine, open-drain IO block, and external I2C pins together.

For the first pass, the top-level declaration follows the class SoC signal naming directly:

```systemverilog
module top_i2c_core #(
    parameter int DATA_BITS = 32,
    parameter int CSR_COUNT = 5
)(
    input  wire        clk,
    input  wire        reset,

    // slot interface
    input  wire        cs,
    input  wire        read,
    input  wire        write,
    input  wire [$clog2(CSR_COUNT)-1:0] addr,
    input  wire [DATA_BITS-1:0] wr_data,
    output wire [DATA_BITS-1:0] rd_data,

    // i2c external interface
    output tri         i2c_scl,
    inout  tri         i2c_sda
);
```

Internally, the open-drain pins should be split into input samples and output-enable controls:

```systemverilog
logic sda_rx;
logic scl_tx_en; // 0 drives SCL low, 1 releases SCL
logic sda_tx_en; // 0 drives SDA low, 1 releases SDA
logic soft_reset;
logic core_reset;

assign core_reset = reset | soft_reset;
```

`soft_reset` comes from `i2c_csr_map` and should be routed to the runtime blocks that can hold in-progress transaction state: `i2c_controller`, `i2c_byte_engine`, `i2c_open_drain_io`, and both FIFO instances.

For the first revision, `i2c_scl` is shown as `output tri` because this core is the only SCL driver and clock stretching is deferred. If clock stretching is added later, SCL should become `inout tri` so the core can observe when a target holds SCL low.

### Inputs

| Signal | Width | Source | Description |
| --- | --- | --- | --- |
| `clk` | 1 | SoC | Main system clock for the I2C controller. |
| `reset` | 1 | SoC | Core reset using the class SoC convention. Polarity should match the existing SoC reset style. |
| `cs` | 1 | SoC slot bridge | Selects this I2C slot/register block. |
| `read` | 1 | SoC slot bridge | CPU register read strobe. |
| `write` | 1 | SoC slot bridge | CPU register write strobe. |
| `addr` | `$clog2(CSR_COUNT)` | SoC slot bridge | Register address. Width tracks the number of CSR entries. |
| `wr_data` | `DATA_BITS` | SoC slot bridge | CPU write data. |

### Outputs

| Signal | Width | Destination | Description |
| --- | --- | --- | --- |
| `rd_data` | `DATA_BITS` | SoC slot bridge | CPU read data. |
| `i2c_scl` | 1 | I2C bus | Open-drain-style SCL output. The core drives this line low or releases it to high-Z. |

### Bidirectional Ports

| Signal | Width | Direction | Description |
| --- | --- | --- | --- |
| `i2c_sda` | 1 | `inout tri` | Open-drain I2C data line. The core only drives this line low or releases it. |

### Notes

- External pull-ups are required on both I2C lines. The FPGA should not drive a logic high onto SDA or SCL.
- Interrupt support is deferred, so `irq` is intentionally not part of the first-revision top-level port list.
- `i2c_scl` can be `output tri` for the first revision because the controller generates SCL and does not support target clock stretching yet.
- Route `soft_reset` to the controller, byte engine, open-drain IO block, TX FIFO, and RX FIFO. Do not use the CSR map's generated `soft_reset` to reset the CSR map in a way that prevents the pulse from being generated cleanly.
- Keep `top_i2c_core` mostly structural. Detailed command sequencing belongs in `i2c_controller`, and bit timing belongs in `i2c_byte_engine`.
- If the SoC bridge later grows byte strobes or bus error reporting, adapt those at the CSR map boundary without changing the byte engine.

## `i2c_csr_map`

### Role

`i2c_csr_map` implements the lean first-revision register map:

| Offset | Register |
| --- | --- |
| `0x00` | `CONTROL` |
| `0x04` | `STATUS` |
| `0x08` | `CLK_DIV` |
| `0x0C` | `TXDATA` |
| `0x10` | `RXDATA` |

It accepts CPU writes, returns CPU reads, exposes configuration fields to the controller and byte engine, and converts `TXDATA`/`RXDATA` accesses into FIFO push/pop operations.

For the first pass, the module declaration can follow this shape:

```systemverilog
module i2c_csr_map #(
    parameter int DATA_BITS = 32,
    parameter int CSR_COUNT = 5
)(
    input  wire        clk,
    input  wire        reset,

    // slot interface
    input  wire        cs,
    input  wire        read,
    input  wire        write,
    input  wire [$clog2(CSR_COUNT)-1:0] addr,
    input  wire [DATA_BITS-1:0] wr_data,
    output wire [DATA_BITS-1:0] rd_data,

    // controller/status inputs
    input  wire        ready,
    input  wire        done,
    input  wire        ack_error,
    input  wire        fifo_tx_full,
    input  wire        fifo_rx_empty,
    input  wire [7:0]  fifo_rx_rbyte,

    // control/configuration outputs
    output wire        soft_reset,
    output wire        cmd_wr,
    output wire [2:0]  cmd,
    output wire [15:0] clk_divider,

    // fifo controls
    output wire        fifo_tx_wr,
    output wire [7:0]  fifo_tx_wbyte,
    output wire        fifo_rx_rd
);
```

### Register Responsibilities

| Register | CSR Map Responsibility |
| --- | --- |
| `CONTROL` | Generate one-cycle `soft_reset` and `cmd_wr` pulses from CPU writes. Decode `CONTROL.CMD[2:0]`. |
| `STATUS` | Report live `READY`, `TX_FULL`, and `RX_EMPTY`; latch sticky `DONE` and `ACK_ERROR`; clear W1C bits on CPU writes. |
| `CLK_DIV` | Store the SCL divider used internally by `i2c_byte_engine`. |
| `TXDATA` | Push `wr_data[7:0]` into the TX FIFO when software writes this offset and the FIFO is not full. |
| `RXDATA` | Pop one byte from the RX FIFO on CPU reads when the FIFO is not empty; return the byte in `rd_data[7:0]`. |

`cmd_wr` is not a CPU-visible CSR bit. It is an internal pulse generated by `i2c_csr_map` when software writes a valid `CONTROL.CMD` value. The CSR draft says that writing `CONTROL.CMD` launches one primitive I2C command; `cmd_wr` is the hardware handshake that carries that write event to `i2c_controller`.

This signal is useful because `command` itself is just the decoded 3-bit command value. Without a separate launch pulse, the controller would not know whether software just wrote a new command or whether the decoded command wires are simply holding their previous value.

Example:

```text
Cycle N:
  CPU writes CONTROL.CMD = WR.
  i2c_csr_map decodes command = WR.
  i2c_csr_map pulses cmd_wr = 1 for one clock.

Cycle N+1:
  command may still equal WR internally.
  cmd_wr returns to 0.
  i2c_controller knows not to launch WR again.
```

Without `cmd_wr`, holding `cmd = WR` for multiple clocks could look like repeated write-byte requests. With `cmd_wr`, the controller launches exactly once per accepted CPU command write.

### Inputs

| Signal | Width | Source | Description |
| --- | --- | --- | --- |
| `clk` | 1 | SoC | Main system clock. |
| `reset` | 1 | SoC | Core reset. |
| `cs` | 1 | SoC slot bridge | Selects this CSR block. |
| `read` | 1 | SoC slot bridge | Register read strobe. |
| `write` | 1 | SoC slot bridge | Register write strobe. |
| `addr` | `$clog2(CSR_COUNT)` | SoC slot bridge | Register index/address. |
| `wr_data` | `DATA_BITS` | SoC slot bridge | CPU write data. |
| `ready` | 1 | `i2c_controller` | High when a new primitive command can be accepted. |
| `done` | 1 | `i2c_controller` | Pulses or asserts when the last accepted command completes. |
| `ack_error` | 1 | `i2c_controller` | Indicates a transmitted byte was NACKed. |
| `fifo_tx_full` | 1 | TX FIFO | Prevents new TX byte writes. |
| `fifo_rx_empty` | 1 | RX FIFO | Indicates no RX byte is available. |
| `fifo_rx_rbyte` | 8 | RX FIFO | Byte returned to software through `RXDATA`. |

### Outputs

| Signal | Width | Destination | Description |
| --- | --- | --- | --- |
| `rd_data` | `DATA_BITS` | SoC slot bridge | Register readback data. |
| `soft_reset` | 1 | Internal modules | One-cycle reset pulse generated from `CONTROL.SOFT_RESET`. |
| `cmd_wr` | 1 | `i2c_controller` | One-cycle command launch pulse from a valid `CONTROL.CMD` write. |
| `cmd` | 3 | `i2c_controller` | Primitive command encoding. |
| `clk_divider` | 16 | `i2c_byte_engine` | Divider value for SCL timing. |
| `fifo_tx_wr` | 1 | TX FIFO | Push strobe for CPU-written TX bytes. |
| `fifo_tx_wbyte` | 8 | TX FIFO | Byte pushed into the TX FIFO. |
| `fifo_rx_rd` | 1 | RX FIFO | Pop strobe for CPU reads from `RXDATA`. |

### Notes

- A new accepted command should clear old `STATUS.DONE`.
- `STATUS.ACK_ERROR` should remain sticky until software clears it with W1C behavior.
- If software writes a command while the controller is not ready, the first revision can ignore it. A later revision may add `CMD_ERROR`.
- Upper bits of `TXDATA` and `RXDATA` are reserved and should read as zero.

## `i2c_controller`

### Role

`i2c_controller` is the command-level FSM. It accepts primitive commands from `i2c_csr_map`, checks whether the required FIFO condition is satisfied, and then launches the corresponding operation in `i2c_byte_engine`.

For the first pass, the module declaration can follow this shape:

```systemverilog
module i2c_controller(
    input  wire       clk,
    input  wire       reset,
    input  wire       soft_reset,

    // command interface from CSR map
    input  wire       cmd_wr,
    input  wire [2:0] cmd,

    // tx fifo interface
    input  wire       fifo_tx_empty,
    input  wire [7:0] fifo_tx_rdata,
    output wire       fifo_tx_rd,

    // rx fifo interface
    input  wire       fifo_rx_full,
    output wire       fifo_rx_wr,
    output wire [7:0] fifo_rx_wdata,

    // status back to CSR map
    output wire       ready,
    output wire       done,
    output wire       ack_error,

    // byte-engine interface
    input  wire       engine_ready,
    input  wire       engine_done,
    input  wire       engine_ack_error,
    input  wire [7:0] engine_rx_byte,
    output wire       engine_start,
    output wire [2:0] engine_cmd,
    output wire [7:0] engine_tx_byte,
    output wire       engine_ack_value
);
```

Supported first-revision commands:

| Command | Encoding | Controller Action |
| --- | --- | --- |
| `START` | `3'b000` | Generate an I2C START condition. |
| `WR` | `3'b001` | Pop one byte from TX FIFO, transmit it, and sample target ACK/NACK. |
| `RD` | `3'b010` | Receive one byte. This should alias either `RD_ACK` or `RD_NACK` after the read policy is finalized. |
| `STOP` | `3'b011` | Generate an I2C STOP condition. |
| `RESTART` | `3'b100` | Generate a repeated START condition while the controller owns the bus. |
| `RD_ACK` | `3'b101` | Receive one byte and drive ACK on the ninth clock. |
| `RD_NACK` | `3'b110` | Receive one byte and drive NACK on the ninth clock. |
| `RESERVED` | `3'b111` | Do not launch an operation. |

Recommended high-level FSM:

```text
IDLE
  -> ACCEPT_CMD
  -> START_OP / RESTART_OP / STOP_OP / WRITE_OP / READ_OP
  -> WAIT_ENGINE
  -> COMPLETE
  -> IDLE
```

`cmd_wr` has the same meaning here as it does in the CSR map: it is a one-cycle launch request. The controller samples `cmd` only when `cmd_wr` is high and `ready` is high.

The `engine_*` signals are the private interface between the command-level controller and the lower-level byte engine. The controller thinks in software commands like `WR` and `RD_NACK`; the byte engine thinks in bus operations like "shift this byte out" or "receive one byte and drive NACK." The `engine_*` signals are what translate between those two layers.

### Inputs

| Signal | Width | Source | Description |
| --- | --- | --- | --- |
| `clk` | 1 | SoC | Main system clock. |
| `reset` | 1 | SoC | Full hardware reset. |
| `soft_reset` | 1 | `i2c_csr_map` | Clears in-progress command/controller state without resetting the whole SoC. |
| `cmd_wr` | 1 | `i2c_csr_map` | Requests launch of a primitive command. |
| `cmd` | 3 | `i2c_csr_map` | Primitive command value. |
| `fifo_tx_empty` | 1 | TX FIFO | Blocks `WR` commands when no byte is available. |
| `fifo_tx_rdata` | 8 | TX FIFO | Byte transmitted for `WR`. |
| `fifo_rx_full` | 1 | RX FIFO | Blocks read commands when no RX storage is available. |
| `engine_ready` | 1 | `i2c_byte_engine` | Byte engine can accept a new operation. |
| `engine_done` | 1 | `i2c_byte_engine` | Current byte-engine operation completed. |
| `engine_ack_error` | 1 | `i2c_byte_engine` | Write operation received NACK. |
| `engine_rx_byte` | 8 | `i2c_byte_engine` | Received byte from a read operation. |

### Outputs

| Signal | Width | Destination | Description |
| --- | --- | --- | --- |
| `ready` | 1 | `i2c_csr_map` | High when the controller is idle and can accept a new command. |
| `done` | 1 | `i2c_csr_map` | Pulses when an accepted command completes. |
| `ack_error` | 1 | `i2c_csr_map` | Pulses or asserts when a write byte is NACKed. |
| `fifo_tx_rd` | 1 | TX FIFO | Pops a byte for an accepted `WR` command. |
| `fifo_rx_wr` | 1 | RX FIFO | Pushes a received byte after an accepted read command. |
| `fifo_rx_wdata` | 8 | RX FIFO | Byte pushed into the RX FIFO. |
| `engine_start` | 1 | `i2c_byte_engine` | One-cycle launch pulse for the byte engine. |
| `engine_cmd` | 3 | `i2c_byte_engine` | Byte-engine operation select. Connects to the byte engine's `cmd` input. |
| `engine_tx_byte` | 8 | `i2c_byte_engine` | Byte to transmit for write operations. |
| `engine_ack_value` | 1 | `i2c_byte_engine` | ACK value driven after read: `0` ACK, `1` NACK. |

### Notes

- FIFO checks should happen before launching the byte engine.
- `reset` and `soft_reset` should both return the controller FSM to idle and clear any partially accepted command.
- A rejected command should not pulse `done`.
- Keep command policy here, but keep SCL/SDA phase timing inside `i2c_byte_engine`.
- For first hardware bring-up, software should issue one command and poll completion before issuing the next command.

## `i2c_byte_engine`

### Role

`i2c_byte_engine` performs the actual I2C line sequencing. It converts controller requests into SDA/SCL drive-low or release behavior, using an internal divider counter based on `clk_divider`.

The reason this module exists is to keep bit timing out of the command controller. I2C is simple at the software-command level, but each command expands into a careful sequence of SDA/SCL changes:

- START means SDA falls while SCL is released high, then SCL is pulled low.
- WRITE means eight data bits are placed on SDA while SCL is low and sampled by the target while SCL is high.
- ACK sampling means the master releases SDA for the ninth clock and reads whether the target pulled it low.
- READ means the master releases SDA for eight clocks, samples target data, then drives ACK or NACK on the ninth clock.
- STOP means SDA rises while SCL is released high.

Putting those details in `i2c_byte_engine` gives us a clean boundary: `i2c_controller` decides what command happens next, while `i2c_byte_engine` decides exactly how the pins move for that command.

For the first pass, the module declaration can follow this shape:

```systemverilog
module i2c_byte_engine(
    input  wire       clk,
    input  wire       reset,
    input  wire       soft_reset,

    // operation request from controller
    input  wire       start,
    input  wire [2:0] cmd,
    input  wire [7:0] tx_byte,
    input  wire       ack_value,

    // timing configuration
    input  wire [15:0] clk_divider,

    // sampled bus input
    input  wire       sda_rx,

    // open-drain controls
    output wire       scl_tx_en,
    output wire       sda_tx_en,

    // result back to controller
    output wire       ready,
    output wire       done,
    output wire       ack_error,
    output wire [7:0] rx_byte
);
```

First-revision operations:

| Operation | Behavior |
| --- | --- |
| `START` | While SCL is released high, pull SDA low, then pull SCL low to own the bus. |
| `STOP` | With SCL low and SDA low, release SCL high, then release SDA high. |
| `RESTART` | Generate a START condition without first returning to idle. |
| `WRITE_BYTE` | Shift out 8 bits MSB-first, then release SDA and sample ACK on the ninth clock. |
| `READ_BYTE` | Release SDA, sample 8 bits MSB-first, then drive ACK or NACK on the ninth clock. |

Recommended internal FSM:

```text
IDLE
  -> START_A / START_B
  -> STOP_A / STOP_B
  -> BIT_SETUP
  -> BIT_SAMPLE
  -> ACK_SETUP
  -> ACK_SAMPLE_OR_DRIVE
  -> DONE
```

Recommended internal timing counters:

```text
quarter_count = clk_divider + 1
half_count    = 2 * (clk_divider + 1)
```

The byte engine uses these counts differently depending on its current state:

| State Type | Timing Wait | Example Use |
| --- | --- | --- |
| Quarter-cycle phase | `quarter_count` | Normal WRITE/READ bit setup, hold, sample, and high-hold phases. |
| Half-cycle phase | `half_count` | START, STOP, and RESTART sub-states where SDA must transition while SCL is stable high. |

This keeps the timing decision local to the same FSM that controls `scl_tx_en` and `sda_tx_en`.

### Inputs

| Signal | Width | Source | Description |
| --- | --- | --- | --- |
| `clk` | 1 | SoC | Main system clock. |
| `reset` | 1 | SoC | Full hardware reset. |
| `soft_reset` | 1 | `i2c_csr_map` | Clears timing counters, bit counters, shift state, and releases SDA/SCL. |
| `start` | 1 | `i2c_controller` | One-cycle request to begin one low-level bus operation. This is the byte-engine equivalent of `cmd_wr`. |
| `cmd` | 3 | `i2c_controller` | Selects the low-level operation: START, STOP, RESTART, WRITE_BYTE, or READ_BYTE. |
| `tx_byte` | 8 | `i2c_controller` | Byte shifted out during `WRITE_BYTE`. Ignored for START, STOP, and read operations. |
| `ack_value` | 1 | `i2c_controller` | ACK/NACK driven after `READ_BYTE`: `0` ACK, `1` NACK. Ignored for write operations. |
| `clk_divider` | 16 | `i2c_csr_map` | Divider used by the byte engine to compute quarter-cycle and half-cycle timing waits. |
| `sda_rx` | 1 | `i2c_open_drain_io` | Sampled external SDA level. |

### Outputs

| Signal | Width | Destination | Description |
| --- | --- | --- | --- |
| `ready` | 1 | `i2c_controller` | High when idle and able to accept a new operation. |
| `done` | 1 | `i2c_controller` | Pulses when the requested operation completes. |
| `ack_error` | 1 | `i2c_controller` | High or pulsed when a write byte receives NACK. |
| `rx_byte` | 8 | `i2c_controller` | Byte assembled during read operations. |
| `scl_tx_en` | 1 | `i2c_open_drain_io` | `0` drives SCL low, `1` releases SCL. |
| `sda_tx_en` | 1 | `i2c_open_drain_io` | `0` drives SDA low, `1` releases SDA. |

### Notes

- The byte engine must never drive SDA or SCL high. It only drives low or releases.
- `reset` and `soft_reset` should force `scl_tx_en = 1` and `sda_tx_en = 1` so both I2C lines are released.
- The byte engine owns the SCL timing counter. Normal bit phases wait one quarter-cycle count; START, STOP, and RESTART sub-states can wait two quarter-cycle counts for half-cycle timing.
- ACK is active-low in I2C. A sampled `sda_rx == 1` during the ACK bit means NACK and should produce `ack_error`.
- The first revision can assume single-master operation. Arbitration checks can be layered in later by comparing intended released/high bits against sampled SDA.
- If clock stretching support is added later, the engine should gain an `scl_i` input and wait while `scl_i == 0` during high phases.

## `i2c_open_drain_io`

### Role

`i2c_open_drain_io` contains the pin-facing open-drain behavior for SDA and SCL. It converts internal output-enable controls into tri-state pin assignments and synchronizes sampled SDA back into the core clock domain.

For FPGA top-level use, the pin-drive behavior should be equivalent to:

```systemverilog
assign i2c_scl = scl_tx_en ? 1'bz : 1'b0;
assign i2c_sda = sda_tx_en ? 1'bz : 1'b0;

assign sda_rx = i2c_sda;
```

The assignment above shows the logical behavior. In the RTL implementation, `sda_rx` should be synchronized before the byte engine samples it, because SDA is an external asynchronous input.

Because SCL is an `output tri` in the first revision, this module does not need to return an external `scl_i` sample. If target clock stretching is added later, `i2c_scl` should become `inout tri` and this block should add a synchronized `scl_i` output.

For the first pass, the module declaration can follow this shape:

```systemverilog
module i2c_open_drain_io(
    input  wire clk,
    input  wire reset,
    input  wire soft_reset,

    // drive-low/release controls from byte engine
    input  wire scl_tx_en,
    input  wire sda_tx_en,

    // sampled bus input back to byte engine
    output wire sda_rx,

    // external I2C pins
    output tri  i2c_scl,
    inout  tri  i2c_sda
);
```

### Inputs

| Signal | Width | Source | Description |
| --- | --- | --- | --- |
| `clk` | 1 | SoC | Main system clock for input synchronization. |
| `reset` | 1 | SoC | Full hardware reset. |
| `soft_reset` | 1 | `i2c_csr_map` | Clears SDA input synchronizer state and keeps reset behavior aligned with the rest of the I2C core. |
| `scl_tx_en` | 1 | `i2c_byte_engine` | SCL release/drive-low control. |
| `sda_tx_en` | 1 | `i2c_byte_engine` | SDA release/drive-low control. |

### Outputs

| Signal | Width | Destination | Description |
| --- | --- | --- | --- |
| `sda_rx` | 1 | `i2c_byte_engine` | Synchronized sampled SDA level. |

### Output Ports

| Signal | Width | Direction | Description |
| --- | --- | --- | --- |
| `i2c_scl` | 1 | `output tri` | External open-drain-style SCL pin. The core drives low or releases high-Z. |

### Bidirectional Ports

| Signal | Width | Direction | Description |
| --- | --- | --- | --- |
| `i2c_sda` | 1 | `inout tri` | External open-drain SDA pin. |

### Notes

- This module is the only place that should directly touch top-level tri-state I2C ports.
- Use a small synchronizer on SDA before the byte engine consumes it.
- The naming convention is active-high release enable: `*_tx_en = 1` releases the line, and `*_tx_en = 0` drives the line low.
- `soft_reset` is included for synchronizer cleanup and consistency, but the byte engine is still responsible for releasing the lines by driving `scl_tx_en = 1` and `sda_tx_en = 1`.
- Optional input glitch filtering can be added here later if board noise or slow edges become a problem.

## `i2c_fifo`

### Role

`i2c_fifo` buffers payload data between the CPU register interface and the controller.

Use one TX FIFO and one RX FIFO:

- TX FIFO: CPU writes through `TXDATA`; controller pops bytes during TX data phases.
- RX FIFO: controller pushes received bytes; CPU reads through `RXDATA`.

```systemverilog
module i2c_fifo(
    input  wire clk,
    input  wire reset,

    // register/controller to FIFO signals
    input  wire soft_reset,
    input  wire wr,
    input  wire rd,
    input  wire [7:0] wr_data,

    // FIFO to register/controller signals
    output wire [7:0] rd_data,
    output wire full,
    output wire empty
);
```

### Inputs

| Signal | Width | Source | Description |
| --- | --- | --- | --- |
| `clk` | 1 | SoC | FIFO clock. |
| `reset` | 1 | SoC | FIFO reset using the class SoC reset convention. |
| `soft_reset` | 1 | CSR map | Flush FIFO contents. |
| `wr` | 1 | Producer | Push enable. CPU for TX FIFO, controller for RX FIFO. |
| `rd` | 1 | Consumer | Pop enable. Controller for TX FIFO, CPU for RX FIFO. |
| `wr_data` | 8 | Producer | Data byte to push. |

### Outputs

| Signal | Width | Destination | Description |
| --- | --- | --- | --- |
| `rd_data` | 8 | Consumer | Data byte popped or presented at FIFO head. |
| `full` | 1 | CSR map / controller | FIFO is full. CPU-visible for TX FIFO as `STATUS.TX_FULL`. |
| `empty` | 1 | CSR map / controller | FIFO is empty. CPU-visible for RX FIFO as `STATUS.RX_EMPTY`. |

### Notes

- Internally, the controller needs TX empty and RX full even though the CPU-facing status only exposes TX full and RX empty.
- FIFO payload granularity is 8-bit bytes. The CSR map handles any packing/unpacking needed for 32-bit CPU accesses.
- The same reusable FIFO module is instantiated twice. For the TX FIFO, `full` connects to `fifo_tx_full` and `empty` connects to `fifo_tx_empty`. For the RX FIFO, `full` connects to `fifo_rx_full` and `empty` connects to `fifo_rx_empty`.

## Recommended Implementation Order

1. Define shared constants for register offsets, status bits, command encodings, and byte-engine operation encodings.
2. Implement and test `i2c_fifo`.
3. Implement `i2c_csr_map` reset values, register reads/writes, W1C status bits, and FIFO push/pop controls.
4. Implement `i2c_open_drain_io` and confirm released lines read high with pull-ups in simulation/testbench.
5. Implement `i2c_byte_engine` timing counters, START, STOP, WRITE, READ, ACK, and NACK behavior.
6. Verify the internal divider formula and SCL timing in the byte-engine testbench.
7. Implement `i2c_controller` command acceptance, FIFO checks, and byte-engine launch sequencing.
8. Wire `top_i2c_core`.
9. Build a self-checking testbench with a simple I2C target model.
10. Run polling-based software bring-up against the Nexys A7 I2C temperature sensor.
