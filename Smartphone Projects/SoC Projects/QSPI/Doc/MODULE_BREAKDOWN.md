# QSPI IP Module Breakdown

This document describes the first-revision QSPI controller module structure, each module's role, and the main signals that move between modules.

The current design assumes the class SoC already has a simple bus bridge. Because of that, the QSPI core does not need a separate `soc_bus_if` protocol adapter. The top-level QSPI core receives simple register access signals directly from the existing bridge.

The current design also avoids a full `qspi_phy` abstraction. The regular flash signals can be top-level ports constrained in the FPGA `.xdc`, while the flash SCK signal must be routed through the Xilinx 7-series `STARTUPE2` primitive because the Nexys A7 flash clock is a dedicated configuration clock path, not a normal user I/O pin.

## Port Type Convention

The declarations use Verilog `reg` for outputs that are assigned inside procedural blocks, such as FSM outputs, status bits, counters, registered configuration fields, and FIFO flags.

The declarations use Verilog `wire` for pure nets, especially top-level outputs driven by submodule instances or continuous assignments. Bidirectional flash data pins use `inout tri` because `qspi_io_ctrl` must release the bus during flash-driven read phases.

## First-Revision Module List

Recommended modules:

| Module | Role |
| --- | --- |
| `top_qspi_core` | Top-level core wrapper. Connects the SoC slot interface, internal modules, external flash pins, and eventually the `STARTUPE2` SCK path. |
| `qspi_csr_map` | Implements the CPU-visible register map and converts register writes into control/configuration signals. |
| `qspi_controller` | Main transaction FSM. Sequences opcode, address, optional mode, dummy, TX data, RX data, and completion. |
| `qspi_sclk_gen` | Generates QSPI SCK and edge strobes from the SoC clock and `CLK_DIV`. |
| `qspi_shift_reg` | Serializes outgoing bytes and deserializes incoming bytes for single/dual/quad-width phases. |
| `qspi_io_ctrl` | Controls IO0-IO3 output values and output enables, including bus turnaround between CPU-driven and flash-driven phases. |
| `fifo` | Small TX and RX FIFOs for decoupling CPU register access from SPI bit timing. This can be one reusable FIFO module instantiated twice. |
| `qspi_startupe2_sck` | Tiny wrapper around `STARTUPE2` to drive the dedicated flash SCK/CCLK path on Artix-7/Nexys A7. |

Deferred modules:

| Module | Why Deferred |
| --- | --- |
| `status_error_logic` | Detailed error decoding is saved for later. First revision only needs `STATUS.ERROR`. |
| `irq_logic` | Interrupts are saved for later. First revision uses polling. |
| `flash_status_cache` | Cached flash status is saved for later. First revision reads SR1/SR2/CR1 through normal commands and `RXDATA`. |
| `dma_engine` | High-throughput transfers can wait until basic software-driven transfers are working. |

## `top_qspi_core`

### Role

`top_qspi_core` is the integration point for the core. It receives the simple slot-style register interface from the existing SoC bridge, connects those signals to `qspi_csr_map`, and wires the controller, FIFOs, shifter, IO control, SCK generator, and external flash pins together.

For the first pass, the top-level declaration follows the class SoC signal naming directly:

```systemverilog
module top_qspi_core(
    input  wire        clk,
    input  wire        reset,

    // slot interface
    input  wire        cs,
    input  wire        read,
    input  wire        write,
    input  wire [$clog2(CSR_DEPTH)-1:0]  addr,
    input  wire [DATA_BITS-1:0] wr_data,
    output wire [DATA_BITS-1:0] rd_data,

    // qspi external interface
    output wire [QSPI_SLAVE_COUNT-1:0] qspi_cs,
    inout  tri  [3:0]  qspi_io
);
```

The generated `qspi_sclk` is an internal signal routed through `qspi_startupe2_sck`, because the Nexys A7 flash SCK path is not a normal user I/O pin.

### Inputs

| Signal | Width | Source | Description |
| --- | --- | --- | --- |
| `clk` | 1 | SoC | Main system clock for the QSPI controller. |
| `reset` | 1 | SoC | Core reset using the class SoC convention. Polarity should match the existing SoC reset style. |
| `cs` | 1 | SoC slot bridge | Selects this QSPI slot/register block. |
| `read` | 1 | SoC slot bridge | CPU register read strobe. |
| `write` | 1 | SoC slot bridge | CPU register write strobe. |
| `addr` | `$clog2(CSR_DEPTH)` | SoC slot bridge | Register address. Width tracks the number of CSR entries. |
| `wr_data` | `DATA_BITS` | SoC slot bridge | CPU write data. |

### Outputs

| Signal | Width | Destination | Description |
| --- | --- | --- | --- |
| `rd_data` | `DATA_BITS` | SoC slot bridge | CPU read data. |
| `qspi_cs` | `QSPI_SLAVE_COUNT` | Flash pin(s) | Active-low flash chip-select outputs. The selected device is driven low for a transaction and all other chip-selects remain high. |

### Bidirectional Ports

| Signal | Width | Direction | Description |
| --- | --- | --- | --- |
| `qspi_io` | 4 / `[3:0]` | `inout tri` | Bidirectional QSPI IO0-IO3 bus. Internally, `qspi_io_ctrl` derives output-enable behavior and provides separate pin-level TX/RX paths to the shifter. |

### Notes

- The SoC does not currently provide byte strobes like an AXI `WSTRB`, so no write strobe input is included. Add byte strobes later only if the bridge grows that feature.
- The external QSPI IO bus is a single `inout tri [3:0] qspi_io` port at the top level. Internally, `qspi_io_ctrl` should still split this into input, output, and output-enable controls.
- Nexys A7 flash SCK should be driven through `STARTUPE2.USRCCLKO`, not through a normal constrained top-level package pin.

## `qspi_csr_map`

### Role

`qspi_csr_map` implements the lean register map:

| Offset | Register |
| --- | --- |
| `0x00` | `CONTROL` |
| `0x04` | `STATUS` |
| `0x08` | `CLK_DIV` |
| `0x0C` | `CMD` |
| `0x10` | `FADDR` |
| `0x14` | `TX_LEN` |
| `0x18` | `RX_LEN` |
| `0x1C` | `DUMMY` |
| `0x20` | `TXDATA` |
| `0x24` | `RXDATA` |
| `0x28` | `CS_SELECT` |

It accepts CPU writes, returns CPU reads, exposes configuration fields to the controller, and converts `TXDATA`/`RXDATA` accesses into FIFO push/pop operations.

For the first pass, the top-level declaration follows the class SoC signal naming directly:

```systemverilog
module qspi_csr_map(
    input  wire        clk,
    input  wire        reset,

    // slot interface
    input  wire        cs,
    input  wire        read,
    input  wire        write,
    input  wire [$clog2(CSR_DEPTH)-1:0]  addr,
    input  wire [DATA_BITS-1:0] wr_data,
    output wire  [DATA_BITS-1:0] rd_data,

    // controller to register signals
    input wire ready,
    input wire done,
    input wire error,
    input wire fifo_tx_full,
    input wire fifo_rx_empty,
    input wire [7:0] fifo_rx_rbyte,

    // register to controller signals
    output wire start,
    output wire soft_reset,
    output wire cpol,
    output wire cpha,
    output wire lsb_first,
    output wire [DIVIDER_BITS-1:0] clk_div,
    output wire [7:0] opcode,
    output wire has_addr,
    output wire has_mode,
    output wire has_dummy,
    output wire has_tx_data,
    output wire has_rx_data,
    output wire [1:0] addr_bit_width,
    output wire [1:0] cmd_io_width,
    output wire [1:0] addr_io_width,
    output wire [1:0] mode_io_width,
    output wire [1:0] data_io_width,
    output wire [MAX_ADDR_BITS-1:0] flash_addr,
    output wire [CONST_DATA_LEN-1:0] tx_len,
    output wire [CONST_DATA_LEN-1:0] rx_len,
    output wire [DUMMY_COUNT-1:0] dummy_cycles,
    output wire [MODE_CYCLE_COUNT-1:0] mode_cycles,
    output wire [MODE_BITS-1:0] mode_bits,
    output wire [$clog2(QSPI_SLAVE_COUNT)-1:0] cs_num,
    output wire fifo_tx_wr,
    output wire [7:0] fifo_tx_wbyte,
    output wire fifo_rx_rd
);  
```

### Inputs

| Signal | Width | Source | Description |
| --- | --- | --- | --- |
| `clk` | 1 | SoC | Register-map clock. |
| `reset` | 1 | SoC | Register-map reset using the class SoC reset convention. |
| `cs` | 1 | SoC slot bridge | Selects this CSR block for a register access. |
| `read` | 1 | SoC slot bridge | CPU read request for the selected CSR address. |
| `write` | 1 | SoC slot bridge | CPU write request for the selected CSR address. |
| `addr` | `$clog2(CSR_DEPTH)` | SoC slot bridge | Word-addressed CSR index. |
| `wr_data` | `DATA_BITS` | SoC slot bridge | CPU write data for CSR writes and `TXDATA` FIFO writes. |
| `ready` | 1 | Controller | Controller is idle and ready to accept a new transaction. Drives `STATUS.READY`. |
| `done` | 1 | Controller | Current or most recent transaction completed. Drives `STATUS.DONE`. |
| `error` | 1 | Controller | Controller detected a transaction error. Drives `STATUS.ERROR`. |
| `fifo_tx_full` | 1 | TX FIFO | TX FIFO cannot accept another CPU write. Drives `STATUS.TX_FULL`. |
| `fifo_rx_empty` | 1 | RX FIFO | RX FIFO has no data available for CPU reads. Drives `STATUS.RX_EMPTY`. |
| `fifo_rx_rbyte` | 8 | RX FIFO | Byte returned to the CSR map when `RXDATA` is read. |

### Outputs

| Signal | Width | Destination | Description |
| --- | --- | --- | --- |
| `rd_data` | `DATA_BITS` | SoC slot bridge | CPU read data from the selected CSR or `RXDATA`. |
| `start` | 1 | Controller | Pulse or control signal generated when CPU writes `CONTROL.START=1`. |
| `soft_reset` | 1 | Internal modules | Pulse or control signal generated when CPU writes `CONTROL.SOFT_RESET=1`. |
| `cpol` | 1 | SCK generator | SPI clock polarity from `CONTROL.CPOL`. |
| `cpha` | 1 | SCK generator | SPI clock phase from `CONTROL.CPHA`. |
| `lsb_first` | 1 | Shift register | Bit-order select from `CONTROL.LSB_FIRST`. Default should be MSB-first. |
| `clk_div` | `DIVIDER_BITS` | SCK generator | Clock divider value from `CLK_DIV`. |
| `opcode` | 8 | Controller | Flash instruction opcode from `CMD.OPCODE`. |
| `has_addr` | 1 | Controller | Command includes an address phase. |
| `has_mode` | 1 | Controller | Command includes a mode phase. |
| `has_dummy` | 1 | Controller | Command includes dummy cycles. |
| `has_tx_data` | 1 | Controller | Command includes a controller-to-flash payload phase. |
| `has_rx_data` | 1 | Controller | Command includes a flash-to-controller payload phase. |
| `addr_bit_width` | 2 | Controller | Address width selector from `CMD.ADDR_BIT_WIDTH`. Define encoding before RTL, for example none, 24-bit, 32-bit, and reserved. |
| `cmd_io_width` | 2 | Controller | IO width for the opcode phase. |
| `addr_io_width` | 2 | Controller | IO width for the address phase. |
| `mode_io_width` | 2 | Controller | IO width for the mode phase. |
| `data_io_width` | 2 | Controller | IO width for the data phase. |
| `flash_addr` | `MAX_ADDR_BITS` | Controller | Flash byte address from `FADDR`. |
| `tx_len` | `CONST_DATA_LEN` | Controller | Number of payload bytes to transmit after command/address/mode/dummy phases. |
| `rx_len` | `CONST_DATA_LEN` | Controller | Number of payload bytes to receive. |
| `dummy_cycles` | `DUMMY_COUNT` | Controller | Dummy-cycle count from `DUMMY`. |
| `mode_cycles` | `MODE_CYCLE_COUNT` | Controller | Mode-cycle count from `DUMMY`. |
| `mode_bits` | `MODE_BITS` | Controller | Mode-bit value from `DUMMY`. |
| `cs_num` | `$clog2(QSPI_SLAVE_COUNT)` | Controller | Selected flash device from `CS_SELECT.CS_NUM`. |
| `fifo_tx_wr` | 1 | TX FIFO | Push enable when CPU writes `TXDATA`. |
| `fifo_tx_wbyte` | 8 | TX FIFO | Data pushed into TX FIFO from `wr_data`. |
| `fifo_rx_rd` | 1 | RX FIFO | Pop enable when CPU reads `RXDATA`. |

### Notes

- `START` and `SOFT_RESET` should behave like write-one pulse bits, not stored level bits.
- `STATUS.DONE` and `STATUS.ERROR` may be sticky until cleared. The clear behavior should be decided before RTL.
- If the SoC bridge only supports 32-bit accesses, define byte ordering clearly for `TXDATA` and `RXDATA`.

## `qspi_controller`

### Role

`qspi_controller` is the main transaction controller. It starts when `start` arrives, captures the current command descriptor, asserts CS#, and steps through phases:

1. Opcode phase.
2. Address phase, optional.
3. Mode phase, optional.
4. Dummy phase, optional.
5. TX data phase, optional.
6. RX data phase, optional.
7. Done/error cleanup.

```systemverilog
module qspi_controller(
    input  wire        clk,
    input  wire        reset,

    // register to controller signals
    input wire start,
    input wire soft_reset,
    input wire [7:0] opcode,
    input wire has_addr,
    input wire has_mode,
    input wire has_dummy,
    input wire has_tx_data,
    input wire has_rx_data,
    input wire [1:0] addr_bit_width,
    input wire [1:0] cmd_io_width,
    input wire [1:0] addr_io_width,
    input wire [1:0] mode_io_width,
    input wire [1:0] data_io_width,
    input wire [MAX_ADDR_BITS-1:0] flash_addr,
    input wire [$clog2(QSPI_SLAVE_COUNT)-1:0] cs_num,
    input wire [CONST_DATA_LEN-1:0] tx_len,
    input wire [CONST_DATA_LEN-1:0] rx_len,
    input wire [DUMMY_COUNT-1:0] dummy_cycles,
    input wire [MODE_CYCLE_COUNT-1:0] mode_cycles,
    input wire [MODE_BITS-1:0] mode_bits,

    // shift register to controller signals
    input wire shift_tx_byte_done,
    input wire shift_rx_byte_ready,
    input wire [7:0] shift_rx_byte,

    // fifo to controller signals
    input wire fifo_tx_empty,
    input wire [7:0] fifo_tx_rbyte,
    input wire fifo_rx_full,

    // controller to register signals
    output wire  ready,
    output wire  done,
    output wire  error,

    // controller to top-level flash interface signals
    output wire  [QSPI_SLAVE_COUNT-1:0] qspi_cs,

    // controller to clock generator signals
    output wire  sclk_en,

    // controller to shift register signals
    output wire  [3:0] phase,
    output wire  [1:0] current_bus_width,
    output wire  shift_tx_load,
    output wire  [7:0] shift_tx_byte,
    output wire  shift_rx_en,

    // controller to fifo signals
    output wire  fifo_tx_rd,
    output wire  fifo_rx_wr,
    output wire  [7:0] fifo_rx_wbyte

);  
```

### Inputs

| Signal | Width | Source | Description |
| --- | --- | --- | --- |
| `clk` | 1 | SoC | Controller clock. |
| `reset` | 1 | SoC | Controller reset using the class SoC reset convention. |
| `start` | 1 | CSR map | Start transaction pulse from `CONTROL.START`. |
| `soft_reset` | 1 | CSR map | Internal controller reset pulse from `CONTROL.SOFT_RESET`. |
| `opcode` | 8 | CSR map | Flash opcode from `CMD.OPCODE`. |
| `has_addr` | 1 | CSR map | Command includes an address phase. |
| `has_mode` | 1 | CSR map | Command includes a mode phase. |
| `has_dummy` | 1 | CSR map | Command includes dummy cycles. |
| `has_tx_data` | 1 | CSR map | Command includes a transmit payload phase. |
| `has_rx_data` | 1 | CSR map | Command includes a receive payload phase. |
| `addr_bit_width` | 2 | CSR map | Address width selector. Define encoding before RTL, for example none, 24-bit, 32-bit, and reserved. |
| `cmd_io_width` | 2 | CSR map | IO width for opcode phase. |
| `addr_io_width` | 2 | CSR map | IO width for address phase. |
| `mode_io_width` | 2 | CSR map | IO width for mode phase. |
| `data_io_width` | 2 | CSR map | IO width for data phase. |
| `flash_addr` | `MAX_ADDR_BITS` | CSR map | Flash byte address. |
| `cs_num` | `$clog2(QSPI_SLAVE_COUNT)` | CSR map | Selected flash device. The controller snapshots this on `start`. |
| `tx_len` | `CONST_DATA_LEN` | CSR map | TX payload byte count. |
| `rx_len` | `CONST_DATA_LEN` | CSR map | RX payload byte count. |
| `dummy_cycles` | `DUMMY_COUNT` | CSR map | Dummy cycle count. |
| `mode_cycles` | `MODE_CYCLE_COUNT` | CSR map | Mode cycle count. |
| `mode_bits` | `MODE_BITS` | CSR map | Mode bit value. |
| `shift_tx_byte_done` | 1 | Shift register | Current transmitted byte is complete. The controller uses this to advance byte counters inside a phase. |
| `shift_rx_byte_ready` | 1 | Shift register | A complete received byte is available. |
| `shift_rx_byte` | 8 | Shift register | Received byte from flash. |
| `fifo_tx_empty` | 1 | TX FIFO | TX FIFO is empty from the controller side. Internal protection signal. |
| `fifo_tx_rbyte` | 8 | TX FIFO | Next TX payload byte popped from TX FIFO. |
| `fifo_rx_full` | 1 | RX FIFO | RX FIFO is full from the controller side. Internal protection signal. |

### Outputs

| Signal | Width | Destination | Description |
| --- | --- | --- | --- |
| `ready` | 1 | CSR map | Controller is idle and ready to accept a new transaction. Drives `STATUS.READY`. |
| `done` | 1 | CSR map | Transaction finished. Drives `STATUS.DONE`. |
| `error` | 1 | CSR map | Transaction failed. Drives `STATUS.ERROR`. |
| `qspi_cs` | `QSPI_SLAVE_COUNT` | Top-level flash interface | Active-low chip-select vector. The selected device is driven low during a transaction and all other devices stay high. |
| `sclk_en` | 1 | Clock generator | Allows SCK to toggle during active transfer phases. |
| `phase` | 4 | IO control / optional debug | Current transaction phase. IO control uses this to decide when to drive or release the bus. |
| `current_bus_width` | 2 | Shift register / IO control | Bus width for the current phase. |
| `shift_tx_load` | 1 | Shift register | Load a byte/field into the shifter. |
| `shift_tx_byte` | 8 | Shift register | Byte or mode/opcode/address segment to transmit. |
| `shift_rx_en` | 1 | Shift register | Enable receive shifting during RX phases. |
| `fifo_tx_rd` | 1 | TX FIFO | Pop/read enable for the next TX payload byte. |
| `fifo_rx_wr` | 1 | RX FIFO | Push/write enable for a received byte. |
| `fifo_rx_wbyte` | 8 | RX FIFO | Received byte to store in RX FIFO. |

### Notes

- The controller should reject `START` while not ready by setting `error` or ignoring it. Which behavior we want should be decided before RTL.
- The controller should snapshot `cs_num` when `START` is accepted so software cannot change the target device mid-transaction.
- `fifo_tx_empty` and `fifo_rx_full` are internal protection signals. They do not need to be exposed in `STATUS`.
- For MVP, all first commands can use single-bit opcode/address/data phases except later quad read/program expansion.

## `qspi_sclk_gen`

### Role

`qspi_sclk_gen` creates the internal QSPI clock and semantic timing strobes used by the shifter.

```systemverilog
module qspi_sclk_gen(
    input  wire clk,
    input  wire reset,

    // register to SCK generator signals
    input  wire soft_reset,
    input  wire [DIVIDER_BITS-1:0] clk_div,
    input  wire cpol,
    input  wire cpha,

    // controller to SCK generator signals
    input  wire sclk_en,

    // SCK generator to shift register / flash clock path signals
    output wire qspi_sclk,
    output wire drive_tick,
    output wire sample_tick
);
```

### Inputs

| Signal | Width | Source | Description |
| --- | --- | --- | --- |
| `clk` | 1 | SoC | Main clock. |
| `reset` | 1 | SoC | SCK-generator reset using the class SoC reset convention. |
| `soft_reset` | 1 | CSR map | Reset SCK-generator state without resetting the full SoC. |
| `clk_div` | `DIVIDER_BITS` | CSR map | Divider value from `CLK_DIV.DIVIDER`. |
| `cpol` | 1 | CSR map | Idle SCK polarity from `CONTROL.CPOL`. |
| `cpha` | 1 | CSR map | Clock phase from `CONTROL.CPHA`; affects drive/sample tick timing. |
| `sclk_en` | 1 | Controller | Enables SCK generation during an active transaction. |

### Outputs

| Signal | Width | Destination | Description |
| --- | --- | --- | --- |
| `qspi_sclk` | 1 | `qspi_startupe2_sck` / top-level flash SCK path | Internal flash clock sent toward the flash SCK path. |
| `drive_tick` | 1 | Shift register | One-cycle strobe telling the shifter to drive/advance output data. Depends on CPOL/CPHA. |
| `sample_tick` | 1 | Shift register | One-cycle strobe telling the shifter to sample input data. Depends on CPOL/CPHA. |

### Notes

- For mode 0, SCK idles low, data is sampled on rising edge, and output changes on falling edge.
- For mode 3, SCK idles high, data is still sampled on rising edge for the S25FL128S SDR protocol, but first-edge handling differs because the idle level is high.
- Keep SCK stopped at the CPOL idle value when CS# is inactive.

## `qspi_shift_reg`

### Role

`qspi_shift_reg` converts bytes/fields into serial, dual, or quad output bits and reconstructs received serial/dual/quad input bits into bytes.

For first revision, it can support single-bit only. The interface should still leave room for dual/quad width because the register map already describes bus width per phase.

```systemverilog
module qspi_shift_reg(
    input  wire clk,
    input  wire reset,

    // register to shift register signals
    input  wire soft_reset,
    input  wire lsb_first,

    // controller to shift register signals
    input  wire [3:0] phase,
    input  wire [1:0] current_bus_width,
    input  wire shift_tx_load,
    input  wire [DATA_BITS-1:0] shift_tx_byte,
    input  wire shift_rx_en,

    // SCK generator to shift register signals
    input  wire drive_tick,
    input  wire sample_tick,

    // IO control to shift register signals
    input  wire [3:0] io_rx,

    // shift register to controller signals
    output wire shift_tx_byte_done,
    output wire shift_rx_byte_ready,
    output wire [DATA_BITS-1:0] shift_rx_byte,

    // shift register to IO control signals
    output wire  [3:0] io_tx
);
```

### Inputs

| Signal | Width | Source | Description |
| --- | --- | --- | --- |
| `clk` | 1 | SoC | Main clock. |
| `reset` | 1 | SoC | Shifter reset using the class SoC reset convention. |
| `soft_reset` | 1 | CSR map | Reset shifter state without resetting the full SoC. |
| `lsb_first` | 1 | CSR map | Bit-order selection. Default should be MSB-first. |
| `phase` | 4 | Controller | Current transaction phase. |
| `current_bus_width` | 2 | Controller | Single/dual/quad width for this phase. |
| `shift_tx_load` | 1 | Controller | Load a new transmit byte into the shifter. |
| `shift_tx_byte` | 8 | Controller | Byte to transmit. |
| `shift_rx_en` | 1 | Controller | Enable receive shifting. |
| `drive_tick` | 1 | SCK generator | Advance output strobe. |
| `sample_tick` | 1 | SCK generator | Sample input strobe. |
| `io_rx` | 4 | IO control | Current pin-level IO values. |

### Outputs

| Signal | Width | Destination | Description |
| --- | --- | --- | --- |
| `shift_tx_byte_done` | 1 | Controller | Current transmit byte transfer is complete. |
| `shift_rx_byte_ready` | 1 | Controller | Received byte is valid. |
| `shift_rx_byte` | 8 | Controller | Received byte assembled from sampled IO pins. |
| `io_tx` | 4 | IO control | Pin-level output values for IO0-IO3. |

### Notes

- For single-bit SPI output, use IO0 as SI/MOSI.
- For single-bit SPI input, use IO1 as SO/MISO.
- For quad output/input, use IO0-IO3 as nibbles.
- Bus-width encoding should match `CMD_*_BUS_WIDTH` fields.

## `qspi_io_ctrl`

### Role

`qspi_io_ctrl` owns the output enables and output values for IO0-IO3. It prevents bus contention by driving lines only during host-output phases and releasing lines during flash-output phases.

```systemverilog
module qspi_io_ctrl(
    // controller to IO control signals
    input  wire [3:0] phase,
    input  wire [1:0] current_bus_width,

    // shift register to IO control signals
    input  wire [3:0] io_tx,

    // IO control to shift register signals
    output wire [3:0] io_rx,

    // qspi external interface
    inout  tri  [3:0] qspi_io
);
```

### Inputs

| Signal | Width | Source | Description |
| --- | --- | --- | --- |
| `phase` | 4 | Controller | Current transaction phase. Used to decide whether the core should drive or release the IO bus. |
| `current_bus_width` | 2 | Controller | Active bus width. Used to decide how many IO lines are driven during output phases. |
| `io_tx` | 4 | Shift register | Pin-level output values from the shifter. |

### Outputs

| Signal | Width | Destination | Description |
| --- | --- | --- | --- |
| `io_rx` | 4 | Shift register | Raw pin-level IO values sampled from `qspi_io`. This is not an assembled received byte; the shift register converts these pin samples into `shift_rx_byte`. |

### Bidirectional Ports

| Signal | Width | Direction | Description |
| --- | --- | --- | --- |
| `qspi_io` | 4 | `inout tri` | Physical bidirectional QSPI IO0-IO3 bus. `qspi_io_ctrl` drives this bus during host-output phases and releases it during flash-output phases. |

### Notes

- During single-bit command/address/TX phases, drive IO0 and release IO1-IO3 unless the command requires otherwise.
- During single-bit read phases, release IO lines and sample IO1.
- During quad input/program phases, drive IO0-IO3.
- During quad output/read phases, release IO0-IO3.
- Internal output-enable logic should be derived from `phase` and `current_bus_width`; no external `drive_en` or `qspi_io_oe` port is needed for the first revision.

## `fifo`

### Role

`fifo` buffers payload data between the CPU register interface and the controller.

Use one TX FIFO and one RX FIFO:

- TX FIFO: CPU writes through `TXDATA`; controller pops bytes during TX data phases.
- RX FIFO: controller pushes received bytes; CPU reads through `RXDATA`.

```systemverilog
module fifo(
    input  wire clk,
    input  wire reset,

    // register/controller to FIFO signals
    input  wire soft_reset,
    input  wire wr,
    input  wire rd,
    input  wire [FIFO_WIDTH-1:0] wr_data,

    // FIFO to register/controller signals
    output wire [FIFO_WIDTH-1:0] rd_data,
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

## `qspi_startupe2_sck`

### Role

`qspi_startupe2_sck` is a tiny Artix-7/Nexys A7-specific wrapper around the Xilinx `STARTUPE2` primitive. It routes the internally generated QSPI clock to the dedicated FPGA configuration clock path connected to the S25FL128S SCK pin.

```systemverilog
module qspi_startupe2_sck(
    input wire qspi_sclk
);
```

### Inputs

| Signal | Width | Source | Description |
| --- | --- | --- | --- |
| `qspi_sclk` | 1 | SCK generator | Internal generated flash SCK from `qspi_sclk_gen`. This connects to `STARTUPE2.USRCCLKO`. |

### Outputs

No normal fabric output is required for flash SCK. The primitive drives the dedicated configuration clock path internally.

### Important `STARTUPE2` Ports

| Port | Direction | Purpose |
| --- | --- | --- |
| `USRCCLKO` | Input to primitive | User-generated clock that drives the dedicated CCLK/SCK path. Connect `qspi_sclk` here. |
| `USRCCLKTS` | Input to primitive | Tri-state control for the user CCLK path. For the first revision, tie this low (`1'b0`) so user logic always owns the flash SCK path after configuration. |

### Notes

- This is why the Nexys A7 constraint file does not show a normal external package pin for flash SCK.
- Flash CS# and IO0-IO3 can be normal constrained top-level pins after FPGA configuration.
- No separate `sck_drive_en` signal is needed in the first revision. `qspi_sclk_gen.sclk_en` controls whether SCK toggles, while `qspi_sclk_gen` holds `qspi_sclk` at the CPOL idle level when disabled.
- Releasing the CCLK path through `USRCCLKTS=1` is useful for more advanced configuration or reconfiguration flows, but it is unnecessary for this software-driven flash controller bring-up.
- Keep this wrapper tiny so the QSPI controller itself remains mostly board-independent.

## High-Level Data Flow

CPU write path for page program:

1. CPU writes payload bytes/words to `TXDATA`.
2. `qspi_csr_map` pushes data into TX FIFO.
3. CPU writes command descriptor registers.
4. CPU writes `CONTROL.START`.
5. `qspi_controller` asserts CS#, sends opcode/address, pops TX FIFO data, and tells `qspi_shift_reg` to serialize it.
6. `qspi_io_ctrl` drives IO0 or IO0-IO3 depending on the active phase.
7. `qspi_sclk_gen` clocks the transaction through `qspi_startupe2_sck` and `STARTUPE2`.
8. `qspi_controller` deasserts CS# and sets `STATUS.DONE` or `STATUS.ERROR`.

CPU read path for flash read:

1. CPU writes command descriptor registers.
2. CPU writes `CONTROL.START`.
3. `qspi_controller` sends opcode/address/dummy cycles.
4. `qspi_io_ctrl` releases the read data lines.
5. `qspi_shift_reg` samples flash data and assembles bytes.
6. `qspi_controller` pushes received bytes into RX FIFO.
7. CPU polls `STATUS.RX_EMPTY == 0` and reads `RXDATA`.
8. `qspi_controller` sets `STATUS.DONE` or `STATUS.ERROR`.
