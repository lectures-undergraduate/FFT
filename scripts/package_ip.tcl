# Vivado IP Packager Script for axi_fft_top
# Packages the custom R2^2SDF AXI FFT into ip_repo/axi_fft_v1_0
# Compatible with Xilinx LogiCORE IP FFT v9.x interfaces

set proj_dir "./ip_pack_proj"
create_project -force ip_pack_proj $proj_dir -part xc7z020clg400-1

# Add all RTL files
add_files -norecurse [glob rtl/*.v]
update_compile_order -fileset sources_1

# Create IP repository directory
file mkdir ip_repo/axi_fft_v1_0

# Package project as IP
ipx::package_project -root_dir ip_repo/axi_fft_v1_0 -vendor kookmin.ac.kr -library user -taxonomy /DSP/FFT -import_files -force

set core [ipx::current_core]
set_property name axi_fft $core
set_property display_name "AXI4-Stream FFT (Radix-2^2 SDF)" $core
set_property description "High-Throughput (1 sample/cycle) R2^2SDF AXI FFT IP with Dynamic NFFT (64/256/1024) and Natural Order Output" $core
set_property version "1.0" $core
set_property vendor_display_name "Advanced Digital Systems Lab" $core
set_property company_url "https://github.com/lectures-undergraduate/FFT" $core

# Ensure interfaces are properly inferred
ipx::infer_bus_interface aclk xilinx.com:signal:clock_rtl:1.0 $core
ipx::infer_bus_interface aresetn xilinx.com:signal:reset_rtl:1.0 $core

# Set clock associations
set aclk_intf [ipx::get_bus_interfaces aclk -of_objects $core]
if {$aclk_intf != ""} {
    set param [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects $aclk_intf]
    if {$param != ""} {
        set_property value "s_axis_data:m_axis_data:s_axis_config:m_axis_status" $param
    }
    set rst_param [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects $aclk_intf]
    if {$rst_param != ""} {
        set_property value "aresetn" $rst_param
    }
}

ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::save_core $core

puts "=========================================================="
puts "  IP axi_fft v1.0 successfully packaged into ip_repo/axi_fft_v1_0"
puts "=========================================================="
close_project -delete
exit
