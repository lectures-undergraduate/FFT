@echo off
setlocal
echo Compiling C Fixed-Point FFT Model...
gcc -O2 -Iinclude src/fft_float_ref.c src/twiddle_gen.c src/fft_r22sdf_fixed.c src/main.c -o fft_sim.exe -lm
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Build failed!
    exit /b %ERRORLEVEL%
)
echo Build successful! Run with: fft_sim.exe
