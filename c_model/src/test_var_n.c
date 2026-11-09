#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdbool.h>
#include "fft_model.h"

extern cplx16_t twiddle_rom_1024[1024];
void bit_reverse_reorder16(cplx16_t *data, int n);

// Test variable N FFT in C
int main() {
    printf("Testing Variable FFT Sizes in C...\n");
    generate_twiddles();

    int test_sizes[] = {1024, 256, 64};
    int num_sizes = 3;

    for (int s = 0; s < num_sizes; s++) {
        int n = test_sizes[s];
        printf("\n=========================================\n");
        printf(" Testing N = %d\n", n);
        printf("=========================================\n");

        cplx_double_t *float_in = (cplx_double_t *)malloc(n * sizeof(cplx_double_t));
        cplx_double_t *float_out = (cplx_double_t *)malloc(n * sizeof(cplx_double_t));
        cplx16_t *fixed_in = (cplx16_t *)malloc(n * sizeof(cplx16_t));
        cplx16_t *fixed_out = (cplx16_t *)malloc(n * sizeof(cplx16_t));

        // Test 1: Tone at bin 8
        int tone = 8;
        for (int i = 0; i < n; i++) {
            double val = 0.8 * cos(2.0 * M_PI * tone * i / n);
            float_in[i].r = val;
            float_in[i].i = 0.0;
            fixed_in[i].r = (int16_t)round(val * 32767.0);
            fixed_in[i].i = 0;
        }

        fft_float_reference(float_in, float_out, n, false);

        // Run fixed-point for size n
        int bits = 0;
        while ((1 << bits) < n) bits++;
        int pairs = bits / 2;
        uint16_t scale_sch = (1 << bits) - 1;

        // Custom simulation for n
        cplx16_t *buf = (cplx16_t *)malloc(n * sizeof(cplx16_t));
        memcpy(buf, fixed_in, n * sizeof(cplx16_t));

        for (int p = 0; p < pairs; p++) {
            int N_sub = n >> (2 * p);
            int D1 = N_sub / 2;
            int D2 = N_sub / 4;
            int num_blocks = 1 << (2 * p);

            for (int blk = 0; blk < num_blocks; blk++) {
                int base = blk * N_sub;
                // BF2I
                for (int i = 0; i < D1; i++) {
                    cplx16_t u = buf[base + i];
                    cplx16_t v = buf[base + i + D1];
                    int32_t sr = (int32_t)u.r + (int32_t)v.r;
                    int32_t si = (int32_t)u.i + (int32_t)v.i;
                    int32_t dr = (int32_t)u.r - (int32_t)v.r;
                    int32_t di = (int32_t)u.i - (int32_t)v.i;
                    buf[base + i].r = round_shift_sat16(sr, 1);
                    buf[base + i].i = round_shift_sat16(si, 1);
                    buf[base + i + D1].r = round_shift_sat16(dr, 1);
                    buf[base + i + D1].i = round_shift_sat16(di, 1);
                }
                // BF2II
                for (int i = 0; i < D2; i++) {
                    cplx16_t u = buf[base + i];
                    cplx16_t v = buf[base + i + D2];
                    int32_t sr = (int32_t)u.r + (int32_t)v.r;
                    int32_t si = (int32_t)u.i + (int32_t)v.i;
                    int32_t dr = (int32_t)u.r - (int32_t)v.r;
                    int32_t di = (int32_t)u.i - (int32_t)v.i;
                    buf[base + i].r = round_shift_sat16(sr, 1);
                    buf[base + i].i = round_shift_sat16(si, 1);
                    buf[base + i + D2].r = round_shift_sat16(dr, 1);
                    buf[base + i + D2].i = round_shift_sat16(di, 1);
                }
                // Half 1
                for (int i = 0; i < D2; i++) {
                    cplx16_t u = buf[base + D1 + i];
                    cplx16_t v = buf[base + D1 + i + D2];
                    cplx16_t v_rot = { v.i, -v.r };
                    int32_t sr = (int32_t)u.r + (int32_t)v_rot.r;
                    int32_t si = (int32_t)u.i + (int32_t)v_rot.i;
                    int32_t dr = (int32_t)u.r - (int32_t)v_rot.r;
                    int32_t di = (int32_t)u.i - (int32_t)v_rot.i;
                    buf[base + D1 + i].r = round_shift_sat16(sr, 1);
                    buf[base + D1 + i].i = round_shift_sat16(si, 1);
                    buf[base + D1 + i + D2].r = round_shift_sat16(dr, 1);
                    buf[base + D1 + i + D2].i = round_shift_sat16(di, 1);
                }
                // Twiddle
                if (p < pairs - 1) {
                    int weights[4] = {0, 2, 1, 3};
                    for (int b = 0; b < 4; b++) {
                        int w_m = weights[b];
                        for (int i = 0; i < D2; i++) {
                            int idx = base + b * D2 + i;
                            // twiddle index in 1024 ROM: (1024 / n) * w_m * i * (n / N_sub) = 1024 / N_sub * w_m * i!
                            int tw_k = (w_m * i * 1024) / N_sub;
                            tw_k %= 1024;
                            if (tw_k != 0) {
                                buf[idx] = cplx_mult16(buf[idx], twiddle_rom_1024[tw_k]);
                            }
                        }
                    }
                }
            }
        }

        bit_reverse_reorder16(buf, n);
        memcpy(fixed_out, buf, n * sizeof(cplx16_t));
        free(buf);

        // Evaluate
        double sig_pwr = 0, noise_pwr = 0;
        for (int i = 0; i < n; i++) {
            double ref_r = float_out[i].r / (double)n;
            double ref_i = float_out[i].i / (double)n;
            double fix_r = (double)fixed_out[i].r / 32768.0;
            double fix_i = (double)fixed_out[i].i / 32768.0;
            double er = fix_r - ref_r;
            double ei = fix_i - ref_i;
            sig_pwr += (ref_r * ref_r + ref_i * ref_i);
            noise_pwr += (er * er + ei * ei);
        }
        double sqnr = 10.0 * log10(sig_pwr / noise_pwr);
        double mse_db = 10.0 * log10(noise_pwr / sig_pwr);
        printf("  N=%d: SQNR = %.2f dB, Normalized MSE = %.2f dB (Target <= -40 dB)\n", 
               n, sqnr, mse_db);

        free(float_in); free(float_out); free(fixed_in); free(fixed_out);
    }
    return 0;
}
