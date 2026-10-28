#define _DEBUG
#include "chu_init.h"
#include "qspi_core.h"
#include "qspi_commands.h"



QspiCore qspi_core(QSPI_CORE_BASE_ADDR);

int starts_with(const char *text, const char *prefix)
{
    while (*prefix != '\0') {
        if (*text++ != *prefix++) return 0;
    }
    return 1;
}

int is_reserved(const qspi::CommandDescriptor &command)
{
    return starts_with(command.name, "RESERVED_");
}

int is_safe_read(const qspi::CommandDescriptor &command)
{
    return command.rx_len != 0 && command.tx_len == 0;
}

void drain_rx(const qspi::CommandDescriptor &command, uint32_t &summary)
{
    summary = 0;
    for (uint32_t i = 0; i < command.rx_len; ++i) {
        const uint32_t value = qspi_core.rd_rx_data() & 0xff;
        if (i < 4) summary |= value << (8 * i);
    }
}

void test_command(const qspi::CommandDescriptor &command, int index)
{
    // Always configure every descriptor so the complete command table is
    // checked against the CPU-facing CSR interface.
    qspi_core.wr_flash_addr(0);
    qspi_core.configure_command(command);

    if (is_reserved(command)) {
        debug(command.name, index, -2); // reserved: not issued
        return;
    }

    // Commands with TX data, including program/register-write commands, are
    // deliberately not issued by this read-only sweep.
    if (!is_safe_read(command)) {
        debug(command.name, index, -3); // write/erase: not issued
        return;
    }

    const int result = qspi_core.transfer();
    if (result != 0) {
        debug(command.name, index, result);
        return;
    }

    uint32_t rx_summary = 0;
    drain_rx(command, rx_summary);
    debug(command.name, index, static_cast<int>(rx_summary));
}

void test_command_table()
{
    for (std::size_t i = 0; i < qspi::COMMAND_COUNT; ++i) {
        test_command(qspi::COMMANDS[i], static_cast<int>(i));
    }
}

int main()
{
    qspi_core.set_freq(400000);
    qspi_core.set_mode(0, 0);
    qspi_core.set_lsb_first(0);
    qspi_core.write_ss_n(0);

    while (!qspi_core.ready()) {}

    debug("QSPI command table test", 1, 0);
    test_command_table();

    // Keep the firmware alive for serial inspection without repeatedly
    // issuing flash commands or modifying nonvolatile memory.
    while (1) {
        sleep_ms(1000);
    }
}
