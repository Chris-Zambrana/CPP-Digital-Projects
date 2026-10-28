#ifndef __QSPI_CORE_H__
#define __QSPI_CORE_H__

#include "chu_init.h"
#include "qspi_commands.h"

class QspiCore
{
    public:

    enum CSR_REGISTER_FIELDS {
        PULSE_REGISTER = 0,
        CONTROL_REGISTER = 1,
        STATUS_REGISTER = 2,
        DIVIDER_REGISTER = 3,
        CMD_CONF_REG = 4,
        CMD_DATA_REG = 5,
        FADDR_REGISTER = 6,
        TX_LEN_REG = 7,
        RX_LEN_REG = 8,
        TX_DATA_REG = 9,
        RX_DATA_REG = 10,
        CS_REG = 11
    };

    enum MASK_FIELDS {
        READY_BIT_FIELD = 0x00000001,
        TX_FIFO_FULL_BIT_FIELD = 0x00000002,
        RX_FIFO_EMPTY_BIT_FIELD = 0x00000004,
    };

    enum PULSE_REGISTER_FIELDS {
        START_PULSE_FIELD = 0x00000001,
        SOFT_RESTART_PULSE_FIELD = 0x00000002,
    };

    QspiCore(uint32_t core_base_addr);
    ~QspiCore();

    int ready();
    
    void start();

    void restart();

    void set_freq(int freq);

    void set_mode(int icpol, int icpha);
    
    void set_lsb_first(int lsb_first);

    // rate == 0 selects SDR; rate != 0 selects DDR.
    void set_rate(int rate);

    void wr_flash_addr(uint32_t faddr);

    void wr_tx_len(uint32_t tx_len);

    void wr_rx_len(uint32_t rx_len);

    void wr_opcode(int opcode_data);

    void wr_mode_bits(int mode_bits_data);

    void wr_dummy_cycles(int dummy_cycles_num);

    void wr_tx_data(uint32_t tx_data);

    uint32_t rd_rx_data();

    // Configure the complete command descriptor in one operation.
    void configure_command(const qspi::CommandDescriptor &command);

    // Wait for the controller to return to READY. Returns 0 on success
    // and -1 on timeout.
    int wait_ready(unsigned long timeout_us = 1000000UL);

    // Issue a configured transaction and wait for completion.
    int transfer();

    int tx_fifo_full();

    int rx_fifo_empty();

    void write_ss_n(uint32_t cs_data);

    void write_ss_n(int bit_value, int bit_pos);

    void assert_ss(int cs_num);

    void deassert_ss(int cs_num);



    private:
        uint32_t base_addr;

        int cpol, cpha, lsb_first, ddr_en;

        uint32_t dvsr;

        int has_opcode, has_addr, has_mode, has_dummy, has_tx_data, has_rx_data;
        int cmd_io_width, addr_io_width, mode_io_width, data_io_width;
        int addr_bit_width;

        int opcode, dummy_cycles, mode_bits;

        uint32_t cs_n_data;
};

#endif /* __QSPI_CORE_H__ */
