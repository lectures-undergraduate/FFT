# Vivado Synthesis & Static Timing Analysis (STA) Script
# Target Device: AMD Zynq-7000 XC7Z020-1CLG400C (Digilent Zybo Z7-20)
# Top Module: axi_fft_top

set part_name "xc7z020clg400-1"
set top_module "axi_fft_top"
set target_period 6.666 ;# 150 MHz target clock constraint

puts "================================================================="
puts "  Synthesizing $top_module for $part_name"
puts "  Target Clock: $target_period ns ([expr 1000.0 / $target_period] MHz)"
puts "================================================================="

# Read RTL Sources
read_verilog -sv [glob rtl/*.v]

# Create XDC constraint file
set fp [open "constrs_timing.xdc" "w"]
puts $fp "create_clock -period $target_period -name aclk \[get_ports aclk\]"
close $fp
read_xdc constrs_timing.xdc

# Run Synthesis (OOC Mode for standalone IP evaluation)
synth_design -top $top_module -part $part_name -mode out_of_context

# Reports Post-Synthesis
report_utilization -file reports/utilization_synth.rpt
report_timing_summary -file reports/timing_synth.rpt

# Run Implementation
opt_design
place_design
phys_opt_design
route_design

# Reports Post-Implementation
report_utilization -file reports/utilization_impl.rpt -hierarchical
report_timing_summary -file reports/timing_summary.rpt -max_paths 10
report_power -file reports/power.rpt
report_drc -file reports/drc.rpt

# Extract Exact Slack and Fmax
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]

set actual_period [expr $target_period - $wns]
set fmax [expr 1000.0 / $actual_period]

puts "================================================================="
puts "  STA Results Summary:"
puts "  Target Period: $target_period ns"
puts "  Worst Negative Slack (WNS): $wns ns"
puts "  Worst Hold Slack (WHS):     $whs ns"
puts "  Maximum Frequency (Fmax):   $fmax MHz"
puts "================================================================="

set fp [open "reports/sta_summary.txt" "w"]
puts $fp "Target Device: $part_name (Zybo Z7-20)"
puts $fp "Top Module: $top_module"
puts $fp "Clock Period Constraint: $target_period ns"
puts $fp "WNS (Setup Slack): $wns ns"
puts $fp "WHS (Hold Slack):  $whs ns"
puts $fp "Fmax (Max Processing Clock): $fmax MHz"
close $fp

puts "Synthesis and STA Complete!"
exit
