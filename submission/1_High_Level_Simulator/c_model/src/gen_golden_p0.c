#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "fft_model.h"

extern cplx16_t twiddle_rom_1024[1024];

int main() {
    generate_twiddles();
    int n = 1024;
    cplx16_t in[1024], p0_out[1024];
    for (int i = 0; i < n; i++) {
        double val = 0.8 * cos(2.0 * M_PI * 32 * i / n);
        in[i].r = (int16_t)round(val * 32767.0);
        in[i].i = 0;
        p0_out[i] = in[i];
    }

    // Pair 0 only: D1=512, D2=256
    // BF2I
    for (int i = 0; i < 512; i++) {
        cplx16_t u = p0_out[i];
        cplx16_t v = p0_out[i + 512];
        p0_out[i].r = round_shift_sat16((int32_t)u.r + v.r, 1);
        p0_out[i].i = round_shift_sat16((int32_t)u.i + v.i, 1);
        p0_out[i + 512].r = round_shift_sat16((int32_t)u.r - v.r, 1);
        p0_out[i + 512].i = round_shift_sat16((int32_t)u.i - v.i, 1);
    }

    // BF2II
    // Half 0 (0..511): no -j
    for (int i = 0; i < 256; i++) {
        cplx16_t u = p0_out[i];
        cplx16_t v = p0_out[i + 256];
        p0_out[i].r = round_shift_sat16((int32_t)u.r + v.r, 1);
        p0_out[i].i = round_shift_sat16((int32_t)u.i + v.i, 1);
        p0_out[i + 256].r = round_shift_sat16((int32_t)u.r - v.r, 1);
        p0_out[i + 256].i = round_shift_sat16((int32_t)u.i - v.i, 1);
    }
    // Half 1 (512..1023): v * (-j) before butterfly
    for (int i = 0; i < 256; i++) {
        cplx16_t u = p0_out[512 + i];
        cplx16_t v = p0_out[768 + i];
        cplx16_t v_rot = { v.i, -v.r };
        p0_out[512 + i].r = round_shift_sat16((int32_t)u.r + v_rot.r, 1);
        p0_out[512 + i].i = round_shift_sat16((int32_t)u.i + v_rot.i, 1);
        p0_out[768 + i].r = round_shift_sat16((int32_t)u.r - v_rot.r, 1);
        p0_out[768 + i].i = round_shift_sat16((int32_t)u.i - v_rot.i, 1);
    }

    // Twiddle after Pair 0:
    int weights[4] = { 0, 2, 1, 3 };
    for (int b = 0; b < 4; b++) {
        int w_mult = weights[b];
        for (int i = 0; i < 256; i++) {
            int idx = b * 256 + i;
            int tw_k = (w_mult * i) % 1024;
            if (tw_k != 0) {
                p0_out[idx] = cplx_mult16(p0_out[idx], twiddle_rom_1024[tw_k]);
            }
        }
    }

    FILE *f = fopen("data/golden_pair0.hex", "w");
    for (int i = 0; i < 1024; i++) {
        uint32_t w = ((uint32_t)(uint16_t)p0_out[i].i << 16) | (uint16_t)p0_out[i].r;
        fprintf(f, "%08X\n", w);
    }
    fclose(f);
    printf("Generated data/golden_pair0.hex successfully.\n");
    return 0;
}
