#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "fft_model.h"

// Precomputed twiddle factor tables for 16-bit Q1.15
// Format: cos in r, -sin in i (for forward FFT)
cplx16_t twiddle_rom_1024[1024];

void generate_twiddles(void) {
    for (int i = 0; i < 1024; i++) {
        double angle = -2.0 * M_PI * i / 1024.0;
        double c = cos(angle);
        double s = sin(angle);
        
        // Scale to Q1.15: 32767 * cos
        int32_t val_r = (int32_t)round(c * 32767.0);
        int32_t val_i = (int32_t)round(s * 32767.0);
        
        if (val_r > 32767) val_r = 32767;
        if (val_r < -32768) val_r = -32768;
        if (val_i > 32767) val_i = 32767;
        if (val_i < -32768) val_i = -32768;
        
        twiddle_rom_1024[i].r = (int16_t)val_r;
        twiddle_rom_1024[i].i = (int16_t)val_i;
    }
}
