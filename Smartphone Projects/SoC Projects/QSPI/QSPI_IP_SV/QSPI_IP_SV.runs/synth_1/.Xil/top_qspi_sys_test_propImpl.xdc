set_property SRC_FILE_INFO {cfile:c:/Users/chris/ECE_Projects/QSPI_IP/QSPI_IP_SV/QSPI_IP_SV.gen/sources_1/ip/cpu/bd_0/ip/ip_0/bd_3914_microblaze_I_0.xdc rfile:../../../QSPI_IP_SV.gen/sources_1/ip/cpu/bd_0/ip/ip_0/bd_3914_microblaze_I_0.xdc id:1 order:EARLY scoped_inst:cpu_unit/inst/microblaze_I/U0} [current_design]
set_property SRC_FILE_INFO {cfile:C:/Users/chris/ECE_Projects/QSPI_IP/QSPI_IP_SV/QSPI_IP_SV.srcs/constrs_1/imports/Downloads/Nexys-A7-100T-QSPI.xdc rfile:../../../QSPI_IP_SV.srcs/constrs_1/imports/Downloads/Nexys-A7-100T-QSPI.xdc id:2} [current_design]
current_instance cpu_unit/inst/microblaze_I/U0
set_property src_info {type:SCOPED_XDC file:1 line:2 export:INPUT save:INPUT read:READ} [current_design]
create_waiver -internal -quiet -scoped -user microblaze -tags 12436 -type CDC -id CDC-26 -description "Invalid LUTRAM collision warning" -to [get_pins -quiet "LOCKSTEP_Out_reg\[*\]/R"]
set_property src_info {type:SCOPED_XDC file:1 line:4 export:INPUT save:INPUT read:READ} [current_design]
create_waiver -internal -quiet -scoped -user microblaze -tags 12436 -type CDC -id CDC-26 -description "Invalid LUTRAM collision warning" -to [get_pins -quiet "MicroBlaze_Core_I/*Interrupt_DFF/Single_Synchronize.use_sync_reset.sync_reg/D"]
set_property src_info {type:SCOPED_XDC file:1 line:8 export:INPUT save:INPUT read:READ} [current_design]
create_waiver -internal -quiet -scoped -user microblaze -tags 12436 -type DRC -id PDCN-1569 -description "Valid LUT-6 instantiation" -objects [get_cells -quiet -hierarchical -filter {HLUTNM=~LUT6_2} *LUT*]
current_instance
set_property src_info {type:XDC file:2 line:8 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }]; #IO_L12P_T1_MRCC_35 Sch=clk100mhz
set_property src_info {type:XDC file:2 line:75 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { reset_n }]; #IO_L3P_T0_DQS_AD1P_15 Sch=cpu_resetn
set_property src_info {type:XDC file:2 line:186 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { tx }]; #IO_L7P_T1_AD6P_35 Sch=uart_txd_in
set_property src_info {type:XDC file:2 line:187 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports { rx }]; #IO_L11N_T1_SRCC_35 Sch=uart_rxd_out
set_property src_info {type:XDC file:2 line:210 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports { qspi_io[0] }]; #IO_L1P_T0_D00_MOSI_14 Sch=qspi_dq[0]
set_property src_info {type:XDC file:2 line:211 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN K18   IOSTANDARD LVCMOS33 } [get_ports { qspi_io[1] }]; #IO_L1N_T0_D01_DIN_14 Sch=qspi_dq[1]
set_property src_info {type:XDC file:2 line:212 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports { qspi_io[2] }]; #IO_L2P_T0_D02_14 Sch=qspi_dq[2]
set_property src_info {type:XDC file:2 line:213 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { qspi_io[3] }]; #IO_L2N_T0_D03_14 Sch=qspi_dq[3]
set_property src_info {type:XDC file:2 line:214 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN L13   IOSTANDARD LVCMOS33 } [get_ports { qspi_cs[0] }]; #IO_L6P_T0_FCS_B_14 Sch=qspi_csn
