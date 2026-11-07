@echo off
setlocal
echo ========================================================
echo  Compiling RTL and UVM Package...
echo ========================================================
call xvlog -sv -L uvm -i rtl/include -i uvm_tb rtl/delay_buffer.v rtl/complex_mult.v rtl/twiddle_rom.v rtl/r22sdf_bf2i.v rtl/r22sdf_bf2ii.v rtl/r22sdf_pair.v rtl/r22sdf_core.v rtl/bit_reverse_buffer.v rtl/axis_skid_buffer.v rtl/axi_fft_top.v uvm_tb/fft_if.sv uvm_tb/fft_pkg.sv uvm_tb/tb_top.sv
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] xvlog failed!
    exit /b %ERRORLEVEL%
)

echo ========================================================
echo  Elaborating UVM Design...
echo ========================================================
call xelab -L uvm -top tb_top -snapshot uvm_top_snap -timescale 1ns/1ps
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] xelab failed!
    exit /b %ERRORLEVEL%
)

echo ========================================================
echo  Running UVM Simulation...
echo ========================================================
call xsim uvm_top_snap -runall
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] xsim failed!
    exit /b %ERRORLEVEL%
)

echo ========================================================
echo  UVM Simulation Completed Successfully!
echo ========================================================
