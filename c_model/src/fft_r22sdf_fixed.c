#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "fft_model.h"

extern cplx16_t twiddle_rom_1024[1024];

// Bit reverse array helper
void bit_reverse_reorder16(cplx16_t *data, int n) {
    int bits = 0;
    while ((1 << bits) < n) bits++;
    for (int i = 0; i < n; i++) {
        int rev = (int)bit_reverse(i, bits);
        if (rev > i) {
            cplx16_t tmp = data[i];
            data[i] = data[rev];
            data[rev] = tmp;
        }
    }
}

// Stage-accurate Fixed-point 16-bit Radix-2^2 SDF C simulator
void fft_r22sdf_fixed_simulate(const cplx16_t *in, cplx16_t *out, int n, uint16_t scale_sch, bool inverse) {
    int log2_n = 0;
    while ((1 << log2_n) < n) log2_n++;
    int num_pairs = log2_n / 2;

    // Working buffer
    cplx16_t *buf = (cplx16_t *)malloc(n * sizeof(cplx16_t));
    memcpy(buf, in, n * sizeof(cplx16_t));

    for (int p = 0; p < num_pairs; p++) {
        int N_sub = n >> (2 * p);
        int D1 = N_sub / 2;
        int D2 = N_sub / 4;
        int num_blocks = 1 << (2 * p);

        int shift1 = (scale_sch >> (2 * p)) & 1;
        int shift2 = (scale_sch >> (2 * p + 1)) & 1;

        for (int blk = 0; blk < num_blocks; blk++) {
            int base = blk * N_sub;

            // BF2I
            for (int i = 0; i < D1; i++) {
                cplx16_t u = buf[base + i];
                cplx16_t v = buf[base + i + D1];

                int32_t sum_r = (int32_t)u.r + (int32_t)v.r;
                int32_t sum_i = (int32_t)u.i + (int32_t)v.i;
                int32_t diff_r = (int32_t)u.r - (int32_t)v.r;
                int32_t diff_i = (int32_t)u.i - (int32_t)v.i;

                buf[base + i].r = round_shift_sat16(sum_r, shift1);
                buf[base + i].i = round_shift_sat16(sum_i, shift1);
                buf[base + i + D1].r = round_shift_sat16(diff_r, shift1);
                buf[base + i + D1].i = round_shift_sat16(diff_i, shift1);
            }

            // BF2II
            // Half 0 (k1=0): no -j
            for (int i = 0; i < D2; i++) {
                cplx16_t u = buf[base + i];
                cplx16_t v = buf[base + i + D2];

                int32_t sum_r = (int32_t)u.r + (int32_t)v.r;
                int32_t sum_i = (int32_t)u.i + (int32_t)v.i;
                int32_t diff_r = (int32_t)u.r - (int32_t)v.r;
                int32_t diff_i = (int32_t)u.i - (int32_t)v.i;

                buf[base + i].r = round_shift_sat16(sum_r, shift2);
                buf[base + i].i = round_shift_sat16(sum_i, shift2);
                buf[base + i + D2].r = round_shift_sat16(diff_r, shift2);
                buf[base + i + D2].i = round_shift_sat16(diff_i, shift2);
            }

            // Half 1 (k1=1): multiply v by -j before butterfly
            // (vr + j*vi) * (-j) = vi - j*vr (for FFT)
            // For IFFT: (vr + j*vi) * (+j) = -vi + j*vr
            for (int i = 0; i < D2; i++) {
                cplx16_t u = buf[base + D1 + i];
                cplx16_t v = buf[base + D1 + i + D2];
                cplx16_t v_rot;
                if (!inverse) {
                    v_rot.r = v.i;
                    v_rot.i = -v.r;
                } else {
                    v_rot.r = -v.i;
                    v_rot.i = v.r;
                }

                int32_t sum_r = (int32_t)u.r + (int32_t)v_rot.r;
                int32_t sum_i = (int32_t)u.i + (int32_t)v_rot.i;
                int32_t diff_r = (int32_t)u.r - (int32_t)v_rot.r;
                int32_t diff_i = (int32_t)u.i - (int32_t)v_rot.i;

                buf[base + D1 + i].r = round_shift_sat16(sum_r, shift2);
                buf[base + D1 + i].i = round_shift_sat16(sum_i, shift2);
                buf[base + D1 + i + D2].r = round_shift_sat16(diff_r, shift2);
                buf[base + D1 + i + D2].i = round_shift_sat16(diff_i, shift2);
            }

            // Twiddle multiplication (if p < 4)
            if (p < num_pairs - 1) {
                int weights[4] = { 0, 2, 1, 3 };
                for (int b = 0; b < 4; b++) {
                    int w_mult = weights[b];
                    for (int i = 0; i < D2; i++) {
                        int idx = base + b * D2 + i;
                        int tw_k = (w_mult * i * 1024) / N_sub;
                        tw_k %= 1024;

                        if (tw_k == 0) {
                            // Multiply by 1 (no-op)
                        } else {
                            cplx16_t w = twiddle_rom_1024[tw_k];
                            if (inverse) {
                                w.i = -w.i;
                            }
                            buf[idx] = cplx_mult16(buf[idx], w);
                        }
                    }
                }
            }
        }
    }

    // Copy to out
    memcpy(out, buf, n * sizeof(cplx16_t));
    free(buf);

    // Bit-reverse reorder to natural output order
    bit_reverse_reorder16(out, n);
}
