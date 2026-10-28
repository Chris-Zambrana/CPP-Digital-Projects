//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Command: generate_target bd_3914.bd
//Design : bd_3914
//Purpose: IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "bd_3914,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=bd_3914,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=8,numReposBlks=8,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=0,numPkgbdBlks=0,bdsource=SBD,synth_mode=OOC_per_IP}" *) (* HW_HANDOFF = "cpu.hwdef" *) 
module bd_3914
   (Clk,
    IO_addr_strobe,
    IO_address,
    IO_byte_enable,
    IO_read_data,
    IO_read_strobe,
    IO_ready,
    IO_write_data,
    IO_write_strobe,
    Reset);
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.CLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.CLK, ASSOCIATED_ASYNC_RESET Reset, CLK_DOMAIN bd_3914_Clk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) input Clk;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mcsio_bus:1.0 IO ADDR_STROBE" *) output IO_addr_strobe;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mcsio_bus:1.0 IO ADDRESS" *) output [31:0]IO_address;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mcsio_bus:1.0 IO BYTE_ENABLE" *) output [3:0]IO_byte_enable;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mcsio_bus:1.0 IO READ_DATA" *) input [31:0]IO_read_data;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mcsio_bus:1.0 IO READ_STROBE" *) output IO_read_strobe;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mcsio_bus:1.0 IO READY" *) input IO_ready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mcsio_bus:1.0 IO WRITE_DATA" *) output [31:0]IO_write_data;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mcsio_bus:1.0 IO WRITE_STROBE" *) output IO_write_strobe;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RESET RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RESET, INSERT_VIP 0, POLARITY ACTIVE_HIGH" *) input Reset;

  wire Clk1;
  wire [0:0]IO_Rst;
  wire [0:0]LMB_Rst1;
  wire MB_Reset;
  wire Reset;
  wire [0:31]dlmb_ABUS;
  wire dlmb_ADDRSTROBE;
  wire [0:3]dlmb_BE;
  wire dlmb_CE;
  wire [0:31]dlmb_READDBUS;
  wire dlmb_READSTROBE;
  wire dlmb_READY;
  wire dlmb_UE;
  wire dlmb_WAIT;
  wire [0:31]dlmb_WRITEDBUS;
  wire dlmb_WRITESTROBE;
  wire [0:31]dlmb_port_ADDR;
  wire dlmb_port_CLK;
  wire [0:31]dlmb_port_DIN;
  wire [31:0]dlmb_port_DOUT;
  wire dlmb_port_EN;
  wire dlmb_port_RST;
  wire [0:3]dlmb_port_WE;
  wire [0:31]dlmb_sl_0_ABUS;
  wire dlmb_sl_0_ADDRSTROBE;
  wire [0:3]dlmb_sl_0_BE;
  wire dlmb_sl_0_CE;
  wire [0:31]dlmb_sl_0_READDBUS;
  wire dlmb_sl_0_READSTROBE;
  wire dlmb_sl_0_READY;
  wire dlmb_sl_0_UE;
  wire dlmb_sl_0_WAIT;
  wire [0:31]dlmb_sl_0_WRITEDBUS;
  wire dlmb_sl_0_WRITESTROBE;
  wire dlmb_sl_1_CE;
  wire [0:31]dlmb_sl_1_READDBUS;
  wire dlmb_sl_1_READY;
  wire dlmb_sl_1_UE;
  wire dlmb_sl_1_WAIT;
  wire [0:31]ilmb_ABUS;
  wire ilmb_ADDRSTROBE;
  wire ilmb_CE;
  wire [0:31]ilmb_READDBUS;
  wire ilmb_READSTROBE;
  wire ilmb_READY;
  wire ilmb_UE;
  wire ilmb_WAIT;
  wire [0:31]ilmb_port_ADDR;
  wire ilmb_port_CLK;
  wire [0:31]ilmb_port_DIN;
  wire [31:0]ilmb_port_DOUT;
  wire ilmb_port_EN;
  wire ilmb_port_RST;
  wire [0:3]ilmb_port_WE;
  wire [0:31]ilmb_sl_0_ABUS;
  wire ilmb_sl_0_ADDRSTROBE;
  wire [0:3]ilmb_sl_0_BE;
  wire ilmb_sl_0_CE;
  wire [0:31]ilmb_sl_0_READDBUS;
  wire ilmb_sl_0_READSTROBE;
  wire ilmb_sl_0_READY;
  wire ilmb_sl_0_UE;
  wire ilmb_sl_0_WAIT;
  wire [0:31]ilmb_sl_0_WRITEDBUS;
  wire ilmb_sl_0_WRITESTROBE;
  wire [31:0]iomodule_0_IO_ADDRESS;
  wire iomodule_0_IO_ADDR_STROBE;
  wire [3:0]iomodule_0_IO_BYTE_ENABLE;
  wire iomodule_0_IO_READY;
  wire [31:0]iomodule_0_IO_READ_DATA;
  wire iomodule_0_IO_READ_STROBE;
  wire [31:0]iomodule_0_IO_WRITE_DATA;
  wire iomodule_0_IO_WRITE_STROBE;

  assign Clk1 = Clk;
  assign IO_addr_strobe = iomodule_0_IO_ADDR_STROBE;
  assign IO_address[31:0] = iomodule_0_IO_ADDRESS;
  assign IO_byte_enable[3:0] = iomodule_0_IO_BYTE_ENABLE;
  assign IO_read_strobe = iomodule_0_IO_READ_STROBE;
  assign IO_write_data[31:0] = iomodule_0_IO_WRITE_DATA;
  assign IO_write_strobe = iomodule_0_IO_WRITE_STROBE;
  assign iomodule_0_IO_READY = IO_ready;
  assign iomodule_0_IO_READ_DATA = IO_read_data[31:0];
  bd_3914_dlmb_0 dlmb
       (.LMB_ABus(dlmb_sl_0_ABUS),
        .LMB_AddrStrobe(dlmb_sl_0_ADDRSTROBE),
        .LMB_BE(dlmb_sl_0_BE),
        .LMB_CE(dlmb_CE),
        .LMB_Clk(Clk1),
        .LMB_ReadDBus(dlmb_READDBUS),
        .LMB_ReadStrobe(dlmb_sl_0_READSTROBE),
        .LMB_Ready(dlmb_READY),
        .LMB_UE(dlmb_UE),
        .LMB_Wait(dlmb_WAIT),
        .LMB_WriteDBus(dlmb_sl_0_WRITEDBUS),
        .LMB_WriteStrobe(dlmb_sl_0_WRITESTROBE),
        .M_ABus(dlmb_ABUS),
        .M_AddrStrobe(dlmb_ADDRSTROBE),
        .M_BE(dlmb_BE),
        .M_DBus(dlmb_WRITEDBUS),
        .M_ReadStrobe(dlmb_READSTROBE),
        .M_WriteStrobe(dlmb_WRITESTROBE),
        .SYS_Rst(LMB_Rst1),
        .Sl_CE({dlmb_sl_0_CE,dlmb_sl_1_CE}),
        .Sl_DBus({dlmb_sl_0_READDBUS,dlmb_sl_1_READDBUS}),
        .Sl_Ready({dlmb_sl_0_READY,dlmb_sl_1_READY}),
        .Sl_UE({dlmb_sl_0_UE,dlmb_sl_1_UE}),
        .Sl_Wait({dlmb_sl_0_WAIT,dlmb_sl_1_WAIT}));
  (* BMM_INFO_ADDRESS_SPACE = "byte  0x00000000 32 > bd_3914 lmb_bram_I" *) 
  (* KEEP_HIERARCHY = "yes" *) 
  bd_3914_dlmb_cntlr_0 dlmb_cntlr
       (.BRAM_Addr_A(dlmb_port_ADDR),
        .BRAM_Clk_A(dlmb_port_CLK),
        .BRAM_Din_A({dlmb_port_DOUT[31],dlmb_port_DOUT[30],dlmb_port_DOUT[29],dlmb_port_DOUT[28],dlmb_port_DOUT[27],dlmb_port_DOUT[26],dlmb_port_DOUT[25],dlmb_port_DOUT[24],dlmb_port_DOUT[23],dlmb_port_DOUT[22],dlmb_port_DOUT[21],dlmb_port_DOUT[20],dlmb_port_DOUT[19],dlmb_port_DOUT[18],dlmb_port_DOUT[17],dlmb_port_DOUT[16],dlmb_port_DOUT[15],dlmb_port_DOUT[14],dlmb_port_DOUT[13],dlmb_port_DOUT[12],dlmb_port_DOUT[11],dlmb_port_DOUT[10],dlmb_port_DOUT[9],dlmb_port_DOUT[8],dlmb_port_DOUT[7],dlmb_port_DOUT[6],dlmb_port_DOUT[5],dlmb_port_DOUT[4],dlmb_port_DOUT[3],dlmb_port_DOUT[2],dlmb_port_DOUT[1],dlmb_port_DOUT[0]}),
        .BRAM_Dout_A(dlmb_port_DIN),
        .BRAM_EN_A(dlmb_port_EN),
        .BRAM_Rst_A(dlmb_port_RST),
        .BRAM_WEN_A(dlmb_port_WE),
        .LMB_ABus(dlmb_sl_0_ABUS),
        .LMB_AddrStrobe(dlmb_sl_0_ADDRSTROBE),
        .LMB_BE(dlmb_sl_0_BE),
        .LMB_Clk(Clk1),
        .LMB_ReadStrobe(dlmb_sl_0_READSTROBE),
        .LMB_Rst(LMB_Rst1),
        .LMB_WriteDBus(dlmb_sl_0_WRITEDBUS),
        .LMB_WriteStrobe(dlmb_sl_0_WRITESTROBE),
        .Sl_CE(dlmb_sl_0_CE),
        .Sl_DBus(dlmb_sl_0_READDBUS),
        .Sl_Ready(dlmb_sl_0_READY),
        .Sl_UE(dlmb_sl_0_UE),
        .Sl_Wait(dlmb_sl_0_WAIT));
  bd_3914_ilmb_0 ilmb
       (.LMB_ABus(ilmb_sl_0_ABUS),
        .LMB_AddrStrobe(ilmb_sl_0_ADDRSTROBE),
        .LMB_BE(ilmb_sl_0_BE),
        .LMB_CE(ilmb_CE),
        .LMB_Clk(Clk1),
        .LMB_ReadDBus(ilmb_READDBUS),
        .LMB_ReadStrobe(ilmb_sl_0_READSTROBE),
        .LMB_Ready(ilmb_READY),
        .LMB_UE(ilmb_UE),
        .LMB_Wait(ilmb_WAIT),
        .LMB_WriteDBus(ilmb_sl_0_WRITEDBUS),
        .LMB_WriteStrobe(ilmb_sl_0_WRITESTROBE),
        .M_ABus(ilmb_ABUS),
        .M_AddrStrobe(ilmb_ADDRSTROBE),
        .M_BE({1'b0,1'b0,1'b0,1'b0}),
        .M_DBus({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .M_ReadStrobe(ilmb_READSTROBE),
        .M_WriteStrobe(1'b0),
        .SYS_Rst(LMB_Rst1),
        .Sl_CE(ilmb_sl_0_CE),
        .Sl_DBus(ilmb_sl_0_READDBUS),
        .Sl_Ready(ilmb_sl_0_READY),
        .Sl_UE(ilmb_sl_0_UE),
        .Sl_Wait(ilmb_sl_0_WAIT));
  bd_3914_ilmb_cntlr_0 ilmb_cntlr
       (.BRAM_Addr_A(ilmb_port_ADDR),
        .BRAM_Clk_A(ilmb_port_CLK),
        .BRAM_Din_A({ilmb_port_DOUT[31],ilmb_port_DOUT[30],ilmb_port_DOUT[29],ilmb_port_DOUT[28],ilmb_port_DOUT[27],ilmb_port_DOUT[26],ilmb_port_DOUT[25],ilmb_port_DOUT[24],ilmb_port_DOUT[23],ilmb_port_DOUT[22],ilmb_port_DOUT[21],ilmb_port_DOUT[20],ilmb_port_DOUT[19],ilmb_port_DOUT[18],ilmb_port_DOUT[17],ilmb_port_DOUT[16],ilmb_port_DOUT[15],ilmb_port_DOUT[14],ilmb_port_DOUT[13],ilmb_port_DOUT[12],ilmb_port_DOUT[11],ilmb_port_DOUT[10],ilmb_port_DOUT[9],ilmb_port_DOUT[8],ilmb_port_DOUT[7],ilmb_port_DOUT[6],ilmb_port_DOUT[5],ilmb_port_DOUT[4],ilmb_port_DOUT[3],ilmb_port_DOUT[2],ilmb_port_DOUT[1],ilmb_port_DOUT[0]}),
        .BRAM_Dout_A(ilmb_port_DIN),
        .BRAM_EN_A(ilmb_port_EN),
        .BRAM_Rst_A(ilmb_port_RST),
        .BRAM_WEN_A(ilmb_port_WE),
        .LMB_ABus(ilmb_sl_0_ABUS),
        .LMB_AddrStrobe(ilmb_sl_0_ADDRSTROBE),
        .LMB_BE(ilmb_sl_0_BE),
        .LMB_Clk(Clk1),
        .LMB_ReadStrobe(ilmb_sl_0_READSTROBE),
        .LMB_Rst(LMB_Rst1),
        .LMB_WriteDBus(ilmb_sl_0_WRITEDBUS),
        .LMB_WriteStrobe(ilmb_sl_0_WRITESTROBE),
        .Sl_CE(ilmb_sl_0_CE),
        .Sl_DBus(ilmb_sl_0_READDBUS),
        .Sl_Ready(ilmb_sl_0_READY),
        .Sl_UE(ilmb_sl_0_UE),
        .Sl_Wait(ilmb_sl_0_WAIT));
  bd_3914_iomodule_0_0 iomodule_0
       (.Clk(Clk1),
        .IO_Addr_Strobe(iomodule_0_IO_ADDR_STROBE),
        .IO_Address(iomodule_0_IO_ADDRESS),
        .IO_Byte_Enable(iomodule_0_IO_BYTE_ENABLE),
        .IO_Read_Data(iomodule_0_IO_READ_DATA),
        .IO_Read_Strobe(iomodule_0_IO_READ_STROBE),
        .IO_Ready(iomodule_0_IO_READY),
        .IO_Write_Data(iomodule_0_IO_WRITE_DATA),
        .IO_Write_Strobe(iomodule_0_IO_WRITE_STROBE),
        .LMB_ABus(dlmb_sl_0_ABUS),
        .LMB_AddrStrobe(dlmb_sl_0_ADDRSTROBE),
        .LMB_BE(dlmb_sl_0_BE),
        .LMB_ReadStrobe(dlmb_sl_0_READSTROBE),
        .LMB_WriteDBus(dlmb_sl_0_WRITEDBUS),
        .LMB_WriteStrobe(dlmb_sl_0_WRITESTROBE),
        .Rst(IO_Rst),
        .Sl_CE(dlmb_sl_1_CE),
        .Sl_DBus(dlmb_sl_1_READDBUS),
        .Sl_Ready(dlmb_sl_1_READY),
        .Sl_UE(dlmb_sl_1_UE),
        .Sl_Wait(dlmb_sl_1_WAIT));
  bd_3914_lmb_bram_I_0 lmb_bram_I
       (.addra({dlmb_port_ADDR[0],dlmb_port_ADDR[1],dlmb_port_ADDR[2],dlmb_port_ADDR[3],dlmb_port_ADDR[4],dlmb_port_ADDR[5],dlmb_port_ADDR[6],dlmb_port_ADDR[7],dlmb_port_ADDR[8],dlmb_port_ADDR[9],dlmb_port_ADDR[10],dlmb_port_ADDR[11],dlmb_port_ADDR[12],dlmb_port_ADDR[13],dlmb_port_ADDR[14],dlmb_port_ADDR[15],dlmb_port_ADDR[16],dlmb_port_ADDR[17],dlmb_port_ADDR[18],dlmb_port_ADDR[19],dlmb_port_ADDR[20],dlmb_port_ADDR[21],dlmb_port_ADDR[22],dlmb_port_ADDR[23],dlmb_port_ADDR[24],dlmb_port_ADDR[25],dlmb_port_ADDR[26],dlmb_port_ADDR[27],dlmb_port_ADDR[28],dlmb_port_ADDR[29],dlmb_port_ADDR[30],dlmb_port_ADDR[31]}),
        .addrb({ilmb_port_ADDR[0],ilmb_port_ADDR[1],ilmb_port_ADDR[2],ilmb_port_ADDR[3],ilmb_port_ADDR[4],ilmb_port_ADDR[5],ilmb_port_ADDR[6],ilmb_port_ADDR[7],ilmb_port_ADDR[8],ilmb_port_ADDR[9],ilmb_port_ADDR[10],ilmb_port_ADDR[11],ilmb_port_ADDR[12],ilmb_port_ADDR[13],ilmb_port_ADDR[14],ilmb_port_ADDR[15],ilmb_port_ADDR[16],ilmb_port_ADDR[17],ilmb_port_ADDR[18],ilmb_port_ADDR[19],ilmb_port_ADDR[20],ilmb_port_ADDR[21],ilmb_port_ADDR[22],ilmb_port_ADDR[23],ilmb_port_ADDR[24],ilmb_port_ADDR[25],ilmb_port_ADDR[26],ilmb_port_ADDR[27],ilmb_port_ADDR[28],ilmb_port_ADDR[29],ilmb_port_ADDR[30],ilmb_port_ADDR[31]}),
        .clka(dlmb_port_CLK),
        .clkb(ilmb_port_CLK),
        .dina({dlmb_port_DIN[0],dlmb_port_DIN[1],dlmb_port_DIN[2],dlmb_port_DIN[3],dlmb_port_DIN[4],dlmb_port_DIN[5],dlmb_port_DIN[6],dlmb_port_DIN[7],dlmb_port_DIN[8],dlmb_port_DIN[9],dlmb_port_DIN[10],dlmb_port_DIN[11],dlmb_port_DIN[12],dlmb_port_DIN[13],dlmb_port_DIN[14],dlmb_port_DIN[15],dlmb_port_DIN[16],dlmb_port_DIN[17],dlmb_port_DIN[18],dlmb_port_DIN[19],dlmb_port_DIN[20],dlmb_port_DIN[21],dlmb_port_DIN[22],dlmb_port_DIN[23],dlmb_port_DIN[24],dlmb_port_DIN[25],dlmb_port_DIN[26],dlmb_port_DIN[27],dlmb_port_DIN[28],dlmb_port_DIN[29],dlmb_port_DIN[30],dlmb_port_DIN[31]}),
        .dinb({ilmb_port_DIN[0],ilmb_port_DIN[1],ilmb_port_DIN[2],ilmb_port_DIN[3],ilmb_port_DIN[4],ilmb_port_DIN[5],ilmb_port_DIN[6],ilmb_port_DIN[7],ilmb_port_DIN[8],ilmb_port_DIN[9],ilmb_port_DIN[10],ilmb_port_DIN[11],ilmb_port_DIN[12],ilmb_port_DIN[13],ilmb_port_DIN[14],ilmb_port_DIN[15],ilmb_port_DIN[16],ilmb_port_DIN[17],ilmb_port_DIN[18],ilmb_port_DIN[19],ilmb_port_DIN[20],ilmb_port_DIN[21],ilmb_port_DIN[22],ilmb_port_DIN[23],ilmb_port_DIN[24],ilmb_port_DIN[25],ilmb_port_DIN[26],ilmb_port_DIN[27],ilmb_port_DIN[28],ilmb_port_DIN[29],ilmb_port_DIN[30],ilmb_port_DIN[31]}),
        .douta(dlmb_port_DOUT),
        .doutb(ilmb_port_DOUT),
        .ena(dlmb_port_EN),
        .enb(ilmb_port_EN),
        .rsta(dlmb_port_RST),
        .rstb(ilmb_port_RST),
        .wea({dlmb_port_WE[0],dlmb_port_WE[1],dlmb_port_WE[2],dlmb_port_WE[3]}),
        .web({ilmb_port_WE[0],ilmb_port_WE[1],ilmb_port_WE[2],ilmb_port_WE[3]}));
  (* BMM_INFO_PROCESSOR = "microblaze-le > bd_3914 dlmb_cntlr" *) 
  (* KEEP_HIERARCHY = "yes" *) 
  bd_3914_microblaze_I_0 microblaze_I
       (.Byte_Enable(dlmb_BE),
        .Clk(Clk1),
        .DCE(dlmb_CE),
        .DReady(dlmb_READY),
        .DUE(dlmb_UE),
        .DWait(dlmb_WAIT),
        .D_AS(dlmb_ADDRSTROBE),
        .Data_Addr(dlmb_ABUS),
        .Data_Read(dlmb_READDBUS),
        .Data_Write(dlmb_WRITEDBUS),
        .ICE(ilmb_CE),
        .IFetch(ilmb_READSTROBE),
        .IReady(ilmb_READY),
        .IUE(ilmb_UE),
        .IWAIT(ilmb_WAIT),
        .I_AS(ilmb_ADDRSTROBE),
        .Instr(ilmb_READDBUS),
        .Instr_Addr(ilmb_ABUS),
        .Interrupt(1'b0),
        .Interrupt_Address({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .Read_Strobe(dlmb_READSTROBE),
        .Reset(MB_Reset),
        .Write_Strobe(dlmb_WRITESTROBE));
  bd_3914_rst_0_0 rst_0
       (.aux_reset_in(1'b1),
        .bus_struct_reset(LMB_Rst1),
        .dcm_locked(1'b1),
        .ext_reset_in(Reset),
        .mb_debug_sys_rst(1'b0),
        .mb_reset(MB_Reset),
        .peripheral_reset(IO_Rst),
        .slowest_sync_clk(Clk1));
endmodule
