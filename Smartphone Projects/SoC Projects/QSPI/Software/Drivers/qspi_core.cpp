#include "qspi_core.h"

QspiCore::QspiCore(uint32_t core_base_addr)
    : base_addr(core_base_addr), cpol(0), cpha(0), lsb_first(0), ddr_en(0),
      dvsr(0), has_opcode(0), has_addr(0), has_mode(0), has_dummy(0),
      has_tx_data(0), has_rx_data(0), cmd_io_width(1), addr_io_width(1),
      mode_io_width(1), data_io_width(1), addr_bit_width(0), opcode(0),
      dummy_cycles(0), mode_bits(0), cs_n_data(0)
{
    set_freq(400000);
    set_mode(0, 0);
    set_rate(0);
    write_ss_n(0);
}

QspiCore::~QspiCore()
{

}

int QspiCore::ready() { return (io_read(base_addr, STATUS_REGISTER) & READY_BIT_FIELD) != 0; }

int QspiCore::done() { return (io_read(base_addr, STATUS_REGISTER) & DONE_BIT_FIELD) != 0; }

int QspiCore::error() { return (io_read(base_addr, STATUS_REGISTER) & ERROR_BIT_FIELD) != 0; }

int QspiCore::tx_fifo_full() { return (io_read(base_addr, STATUS_REGISTER) & TX_FIFO_FULL_BIT_FIELD) != 0; }

int QspiCore::rx_fifo_empty() { return (io_read(base_addr, STATUS_REGISTER) & RX_FIFO_EMPTY_BIT_FIELD) != 0; }

void QspiCore::start()
{
    io_write(base_addr, PULSE_REGISTER, START_PULSE_FIELD);
}

void QspiCore::restart()
{
    io_write(base_addr, PULSE_REGISTER, SOFT_RESTART_PULSE_FIELD);
}

void QspiCore::set_freq(int freq)
{
    if (freq <= 0) return;
    const uint32_t periods = static_cast<uint32_t>(
        (SYS_CLK_FREQ * 1000000UL) / (static_cast<unsigned long>(freq) * 2UL));
    dvsr = periods > 0 ? periods - 1U : 0U;
    io_write(base_addr, DIVIDER_REGISTER, dvsr);
}

void QspiCore::set_mode(int icpol, int icpha)
{
    cpol = icpol ? 1 : 0;
    cpha = icpha ? 1 : 0;
    const uint32_t ctrl_word = (static_cast<uint32_t>(ddr_en) << 3) |
                               (static_cast<uint32_t>(lsb_first) << 2) |
                               (static_cast<uint32_t>(cpha) << 1) |
                               static_cast<uint32_t>(cpol);
    io_write(base_addr, CONTROL_REGISTER, ctrl_word);
}

void QspiCore::set_lsb_first(int lsb_first_en)
{
    lsb_first = lsb_first_en ? 1 : 0;
    set_mode(cpol, cpha);
}

void QspiCore::set_rate(int rate)
{
    ddr_en = rate ? 1 : 0;
    set_mode(cpol, cpha);
}

void QspiCore::wr_flash_addr(uint32_t faddr)
{
    io_write(base_addr, FADDR_REGISTER, faddr);
}

void QspiCore::wr_tx_len(uint32_t tx_len)
{
    io_write(base_addr, TX_LEN_REG, tx_len);
}

void QspiCore::wr_rx_len(uint32_t rx_len)
{
    io_write(base_addr, RX_LEN_REG, rx_len);
}

void QspiCore::wr_opcode(int opcode_data)
{
    opcode = opcode_data & 0xff;
    io_write(base_addr, CMD_DATA_REG,
             static_cast<uint32_t>(opcode) |
             (static_cast<uint32_t>(dummy_cycles & 0xff) << 8) |
             (static_cast<uint32_t>(mode_bits & 0xff) << 24));
}

void QspiCore::wr_mode_bits(int mode_bits_data)
{
    mode_bits = mode_bits_data & 0xff;
    wr_opcode(opcode);
}

void QspiCore::wr_dummy_cycles(int dummy_cycles_num)
{
    dummy_cycles = dummy_cycles_num & 0xffff;
    wr_opcode(opcode);
}

void QspiCore::wr_tx_data(uint32_t tx_data)
{
    while (tx_fifo_full()) {}
    io_write(base_addr, TX_DATA_REG, tx_data);
}

uint32_t QspiCore::rd_rx_data()
{
    while (rx_fifo_empty()) {}
    return io_read(base_addr, RX_DATA_REG);
}

void QspiCore::write_ss_n(uint32_t cs_data)
{
    cs_n_data = cs_data;
    io_write(base_addr, CS_REG, cs_n_data);
}

void QspiCore::write_ss_n(int bit_value, int bit_pos)
{
    if (bit_pos < 0 || bit_pos >= 32) return;
    bit_write(ss_n_data, bit_pos, bit_value != 0);
    io_write(base_addr, CS_REG, cs_n_data);
}

void QspiCore::assert_ss(int cs_num)
{
    write_ss_n(0, cs_num);
}

void QspiCore::deassert_ss(int cs_num)
{
    write_ss_n(1, cs_num);
}

void QspiCore::configure_command(const qspi::CommandDescriptor &command)
{
    io_write(base_addr, CMD_CONF_REG, command.cmd_config);
    io_write(base_addr, CMD_DATA_REG, command.cmd_data);
    wr_tx_len(command.tx_len);
    wr_rx_len(command.rx_len);
}

int QspiCore::wait_done(unsigned long timeout_us)
{
    const unsigned long start_us = now_us();
    while (!ready()) {
        if (error()) return -2;
        if ((now_us() - start_us) >= timeout_us) return -1;
    }
    return error() ? -2 : 0;
}

int QspiCore::transfer()
{
    const int idle_status = wait_done();
    if (idle_status != 0) return idle_status;
    start();
    return wait_done();
}

