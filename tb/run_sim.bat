@echo off
setlocal
echo Compiling RTL and Testbench...
call xvlog -sv -i rtl/include rtl/delay_buffer.v rtl/complex_mult.v rtl/twiddle_rom.v rtl/r22sdf_bf2i.v rtl/r22sdf_bf2ii.v rtl/r22sdf_pair.v rtl/r22sdf_core.v rtl/bit_reverse_buffer.v rtl/axis_skid_buffer.v rtl/axi_fft_top.v tb/tb_axi_fft.v
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] xvlog failed!
    exit /b %ERRORLEVEL%
)

echo Elaborating design...
call xelab -top tb_axi_fft -snapshot tb_axi_fft_snap -timescale 1ns/1ps
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] xelab failed!
    exit /b %ERRORLEVEL%
)

echo Running simulation...
call xsim tb_axi_fft_snap -runall
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] xsim failed!
    exit /b %ERRORLEVEL%
)

echo Simulation finished successfully!
