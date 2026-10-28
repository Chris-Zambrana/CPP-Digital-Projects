set_false_path -through [get_ports "Reset"]
create_waiver -internal -quiet -scoped -user microblaze -tags 12436 -type CDC -id CDC-26 -description "Invalid LUTRAM collision warning" \
  -to [get_pins -quiet "LOCKSTEP_Out_reg\[*\]/R"]
create_waiver -internal -quiet -scoped -user microblaze -tags 12436 -type CDC -id CDC-26 -description "Invalid LUTRAM collision warning" \
  -to [get_pins -quiet "MicroBlaze_Core_I/*Interrupt_DFF/Single_Synchronize.use_sync_reset.sync_reg/D"]

# Waiver for LUT instantiation
create_waiver -internal -quiet -scoped -user microblaze -tags 12436 -type DRC -id PDCN-1569 -description "Valid LUT-6 instantiation" \
  -objects [get_cells -quiet -hierarchical -filter {HLUTNM=~LUT6_2} *LUT*]
