# Vivado Block Design Creation Script for Zybo Z7 (XC7Z020-1CLG400C)
# Integrates Zynq PS7, AXI DMA, AXI GPIO (Dynamic FFT Config), and custom AXI FFT IP

set proj_name "axi_fft_zynq"
set proj_dir "./vivado_project"
set part_name "xc7z020clg400-1"

file mkdir $proj_dir
create_project -force $proj_name $proj_dir -part $part_name

# Add local IP repository
set_property ip_repo_paths [list [file normalize ./ip_repo]] [current_project]
update_ip_catalog

# Create Block Design
create_bd_design "design_1"

# 1. Instantiate Zynq PS7
set ps7 [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7_0]
set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_EN_CLK0_PORT {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100.0} \
    CONFIG.PCW_EN_RST0_PORT {1} \
    CONFIG.PCW_UART1_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_UART1_UART1_IO {MIO 48 .. 49} \
    CONFIG.PCW_UIPARAM_DDR_PARTNO {MT41K128M16 JT-125} \
    CONFIG.PCW_UIPARAM_DDR_BUS_WIDTH {32 Bit} \
] $ps7

# 2. Instantiate AXI DMA
set dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0]
set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_m_axis_mm2s_tdata_width {32} \
    CONFIG.c_s_axis_s2mm_tdata_width {32} \
    CONFIG.c_mm2s_burst_size {256} \
    CONFIG.c_s2mm_burst_size {256} \
] $dma

# 3. Instantiate AXI GPIO (Dynamic FFT Runtime Configuration)
set gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0]
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {16} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_GPIO2_WIDTH {2} \
    CONFIG.C_ALL_OUTPUTS_2 {1} \
] $gpio

# 4. Instantiate Custom AXI FFT IP
set fft [create_bd_cell -type ip -vlnv kookmin.ac.kr:user:axi_fft:1.0 axi_fft_0]

# 5. Instantiate SmartConnect for High-Performance DDR Access (HP0)
set smc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc]
set_property -dict [list CONFIG.NUM_SI {2} CONFIG.NUM_MI {1}] $smc

# 6. Instantiate AXI Interconnect for GP0 (Control Registers)
set ic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps7_0_axi_periph]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {2}] $ic

# 7. Instantiate Proc Sys Reset
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_100M]

# 8. Instantiate Slice for config_tvalid from GPIO2[0]
set slice_valid [create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 slice_valid]
set_property -dict [list CONFIG.DIN_WIDTH {2} CONFIG.DIN_FROM {0} CONFIG.DIN_TO {0}] $slice_valid

# ================= Clocks & Resets =================
connect_bd_net [get_bd_pins ps7_0/FCLK_CLK0] \
    [get_bd_pins ps7_0/M_AXI_GP0_ACLK] \
    [get_bd_pins ps7_0/S_AXI_HP0_ACLK] \
    [get_bd_pins axi_dma_0/s_axi_lite_aclk] \
    [get_bd_pins axi_dma_0/m_axi_mm2s_aclk] \
    [get_bd_pins axi_dma_0/m_axi_s2mm_aclk] \
    [get_bd_pins axi_fft_0/aclk] \
    [get_bd_pins axi_gpio_0/s_axi_aclk] \
    [get_bd_pins axi_smc/aclk] \
    [get_bd_pins ps7_0_axi_periph/ACLK] \
    [get_bd_pins ps7_0_axi_periph/S00_ACLK] \
    [get_bd_pins ps7_0_axi_periph/M00_ACLK] \
    [get_bd_pins ps7_0_axi_periph/M01_ACLK] \
    [get_bd_pins rst_ps7_0_100M/slowest_sync_clk]

connect_bd_net [get_bd_pins ps7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_0_100M/ext_reset_in]

connect_bd_net [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] \
    [get_bd_pins axi_dma_0/axi_resetn] \
    [get_bd_pins axi_fft_0/aresetn] \
    [get_bd_pins axi_gpio_0/s_axi_aresetn] \
    [get_bd_pins axi_smc/aresetn] \
    [get_bd_pins ps7_0_axi_periph/ARESETN] \
    [get_bd_pins ps7_0_axi_periph/S00_ARESETN] \
    [get_bd_pins ps7_0_axi_periph/M00_ARESETN] \
    [get_bd_pins ps7_0_axi_periph/M01_ARESETN]

# ================= AXI GP0 (Register Control) =================
connect_bd_intf_net [get_bd_intf_pins ps7_0/M_AXI_GP0] [get_bd_intf_pins ps7_0_axi_periph/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins ps7_0_axi_periph/M00_AXI] [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins ps7_0_axi_periph/M01_AXI] [get_bd_intf_pins axi_gpio_0/S_AXI]

# ================= AXI HP0 (High Throughput DMA) =================
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins ps7_0/S_AXI_HP0]

# ================= AXI4-Stream Data Path =================
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins axi_fft_0/s_axis_data]
connect_bd_intf_net [get_bd_intf_pins axi_fft_0/m_axis_data] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

# ================= Dynamic FFT Configuration =================
connect_bd_net [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_pins axi_fft_0/s_axis_config_tdata]
connect_bd_net [get_bd_pins axi_gpio_0/gpio2_io_o] [get_bd_pins slice_valid/Din]
connect_bd_net [get_bd_pins slice_valid/Dout] [get_bd_pins axi_fft_0/s_axis_config_tvalid]

# Connect DDR & FIXED_IO interfaces of PS7 to top-level ports
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable" } [get_bd_cells ps7_0]

# Auto-assign Memory Addresses
assign_bd_address

# Validate and Save Block Design
validate_bd_design
save_bd_design

puts "=========================================================="
puts "  Block Design design_1 successfully created and validated!"
puts "=========================================================="

# Create HDL Wrapper
make_wrapper -files [get_files design_1.bd] -top
set wrapper_files [glob -nocomplain "$proj_dir/${proj_name}.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v"]
if {[llength $wrapper_files] > 0} {
    add_files -norecurse [lindex $wrapper_files 0]
}
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Generate all BD targets
generate_target all [get_files design_1.bd]

# Add Testbench to project
file mkdir Testbench
file copy -force tb/tb_axi_fft.v Testbench/tb_axi_fft.v
add_files -fileset sim_1 -norecurse Testbench/tb_axi_fft.v

# Run Synthesis and Implementation to generate Bitstream and XSA
puts "Starting Bitstream generation..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation Run Status: $impl_status"

# Export Hardware Definition (.xsa)
file mkdir submission/4_Boot_Artifacts
write_hw_platform -fixed -include_bit -force -file ./submission/4_Boot_Artifacts/axi_fft_zynq.xsa

# Copy Bitstream and Debug Probes
if {[file exists $proj_dir/${proj_name}.runs/impl_1/design_1_wrapper.bit]} {
    file copy -force $proj_dir/${proj_name}.runs/impl_1/design_1_wrapper.bit ./submission/4_Boot_Artifacts/axi_fft_zynq.bit
    puts "Bitstream successfully copied to submission/4_Boot_Artifacts/axi_fft_zynq.bit"
}

if {[file exists $proj_dir/${proj_name}.runs/impl_1/design_1_wrapper.ltx]} {
    file copy -force $proj_dir/${proj_name}.runs/impl_1/design_1_wrapper.ltx ./submission/4_Boot_Artifacts/axi_fft_zynq.ltx
} else {
    # Create empty/dummy ltx if no ILA was instantiated
    set fp [open "./submission/4_Boot_Artifacts/axi_fft_zynq.ltx" "w"]
    puts $fp "<!-- No ILA cores present in design -->"
    close $fp
}

# Generate BOOT.bin using bootgen
catch {
    set fp [open "./submission/4_Boot_Artifacts/boot.bif" "w"]
    puts $fp "//arch = zynq; split = false; format = BIN"
    puts $fp "the_ROM_image:"
    puts $fp "{"
    puts $fp "    \[destination_device = pl\] ./submission/4_Boot_Artifacts/axi_fft_zynq.bit"
    puts $fp "}"
    close $fp
    exec bootgen -image ./submission/4_Boot_Artifacts/boot.bif -arch zynq -process_bitstream bin -w on -o ./submission/4_Boot_Artifacts/BOOT.bin
    puts "BOOT.bin successfully created in submission/4_Boot_Artifacts/BOOT.bin"
}

puts "=========================================================="
puts "  Vivado Zynq Block Design and Artifacts Build Finished!"
puts "=========================================================="
exit
