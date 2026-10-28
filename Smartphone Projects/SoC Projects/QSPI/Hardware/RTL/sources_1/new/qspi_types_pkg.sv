package qspi_types_pkg;

    typedef enum logic [3:0] {
        CTRL_IDLE,
        CTRL_PRELOAD,
        CTRL_CS_SETUP,
        CTRL_INSTRUCTION,
        CTRL_ADDRESS,
        CTRL_MODE,
        CTRL_DUMMY,
        CTRL_TX_DATA,
        CTRL_RX_DATA,
        CTRL_CS_HOLD,
        CTRL_CYCLE_DELAY
    } state_type;   

    typedef enum logic {
        RATE_SDR,
        RATE_DDR 
    } rate_type;

endpackage