#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdbool.h>
#include "fft_model.h"

extern cplx16_t twiddle_rom_1024[1024];
void bit_reverse_reorder16(cplx16_t *data, int n);

// Box-Muller Gaussian Random Generator
void generate_gaussian_noise(cplx_double_t *f_in, cplx16_t *fix_in, int n, double sigma) {
    for (int i = 0; i < n; i += 2) {
        double u1 = ((double)rand() + 1.0) / ((double)RAND_MAX + 2.0);
        double u2 = ((double)rand() + 1.0) / ((double)RAND_MAX + 2.0);
        double radius = sigma * sqrt(-2.0 * log(u1));
        double theta = 2.0 * M_PI * u2;

        f_in[i].r = radius * cos(theta);
        f_in[i].i = radius * sin(theta);
        fix_in[i].r = (int16_t)round_shift_sat16((int32_t)round(f_in[i].r * 32767.0), 0);
        fix_in[i].i = (int16_t)round_shift_sat16((int32_t)round(f_in[i].i * 32767.0), 0);

        if (i + 1 < n) {
            double u3 = ((double)rand() + 1.0) / ((double)RAND_MAX + 2.0);
            double u4 = ((double)rand() + 1.0) / ((double)RAND_MAX + 2.0);
            double r2 = sigma * sqrt(-2.0 * log(u3));
            double th2 = 2.0 * M_PI * u4;
            f_in[i+1].r = r2 * cos(th2);
            f_in[i+1].i = r2 * sin(th2);
            fix_in[i+1].r = (int16_t)round_shift_sat16((int32_t)round(f_in[i+1].r * 32767.0), 0);
            fix_in[i+1].i = (int16_t)round_shift_sat16((int32_t)round(f_in[i+1].i * 32767.0), 0);
        }
    }
}

int main() {
    printf("=========================================================\n");
    printf("  Gaussian Random Complex Noise Input MSE Verification\n");
    printf("  Term Project Guideline Requirement: Normalized MSE <= -40 dB\n");
    printf("=========================================================\n\n");
    generate_twiddles();
    srand(42);

    int test_sizes[] = {1024, 256, 64};
    for (int s = 0; s < 3; s++) {
        int n = test_sizes[s];
        cplx_double_t *f_in = (cplx_double_t *)malloc(n * sizeof(cplx_double_t));
        cplx_double_t *f_out = (cplx_double_t *)malloc(n * sizeof(cplx_double_t));
        cplx16_t *fix_in = (cplx16_t *)malloc(n * sizeof(cplx16_t));
        cplx16_t *fix_out = (cplx16_t *)malloc(n * sizeof(cplx16_t));

        // Sigma = 0.2 so 3*sigma = 0.6 fits comfortably within [-1, 1]
        generate_gaussian_noise(f_in, fix_in, n, 0.2);

        fft_float_reference(f_in, f_out, n, false);

        int bits = 0;
        while ((1 << bits) < n) bits++;
        int pairs = bits / 2;

        cplx16_t *buf = (cplx16_t *)malloc(n * sizeof(cplx16_t));
        memcpy(buf, fix_in, n * sizeof(cplx16_t));

        for (int p = 0; p < pairs; p++) {
            int N_sub = n >> (2 * p);
            int D1 = N_sub / 2;
            int D2 = N_sub / 4;
            int num_blocks = 1 << (2 * p);

            for (int blk = 0; blk < num_blocks; blk++) {
                int base = blk * N_sub;
                for (int i = 0; i < D1; i++) {
                    cplx16_t u = buf[base + i];
                    cplx16_t v = buf[base + i + D1];
                    buf[base + i].r = round_shift_sat16((int32_t)u.r + v.r, 1);
                    buf[base + i].i = round_shift_sat16((int32_t)u.i + v.i, 1);
                    buf[base + i + D1].r = round_shift_sat16((int32_t)u.r - v.r, 1);
                    buf[base + i + D1].i = round_shift_sat16((int32_t)u.i - v.i, 1);
                }
                for (int i = 0; i < D2; i++) {
                    cplx16_t u = buf[base + i];
                    cplx16_t v = buf[base + i + D2];
                    buf[base + i].r = round_shift_sat16((int32_t)u.r + v.r, 1);
                    buf[base + i].i = round_shift_sat16((int32_t)u.i + v.i, 1);
                    buf[base + i + D2].r = round_shift_sat16((int32_t)u.r - v.r, 1);
                    buf[base + i + D2].i = round_shift_sat16((int32_t)u.i - v.i, 1);
                }
                for (int i = 0; i < D2; i++) {
                    cplx16_t u = buf[base + D1 + i];
                    cplx16_t v = buf[base + D1 + i + D2];
                    cplx16_t v_rot = { v.i, -v.r };
                    buf[base + D1 + i].r = round_shift_sat16((int32_t)u.r + v_rot.r, 1);
                    buf[base + D1 + i].i = round_shift_sat16((int32_t)u.i + v_rot.i, 1);
                    buf[base + D1 + i + D2].r = round_shift_sat16((int32_t)u.r - v_rot.r, 1);
                    buf[base + D1 + i + D2].i = round_shift_sat16((int32_t)u.i - v_rot.i, 1);
                }
                if (p < pairs - 1) {
                    int weights[4] = {0, 2, 1, 3};
                    for (int b = 0; b < 4; b++) {
                        int w_m = weights[b];
                        for (int i = 0; i < D2; i++) {
                            int idx = base + b * D2 + i;
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
        memcpy(fix_out, buf, n * sizeof(cplx16_t));
        free(buf);

        // Guideline Exact Formula:
        // 10 * log10( (1/N * sum |X(k) - X_hat(k)|^2) / (1/N * sum |X(k)|^2) )
        double sum_err_sq = 0.0;
        double sum_sig_sq = 0.0;
        for (int i = 0; i < n; i++) {
            double ref_r = f_out[i].r / (double)n;
            double ref_i = f_out[i].i / (double)n;
            double fix_r = (double)fix_out[i].r / 32768.0;
            double fix_i = (double)fix_out[i].i / 32768.0;

            double diff_r = ref_r - fix_r;
            double diff_i = ref_i - fix_i;

            sum_err_sq += (diff_r * diff_r + diff_i * diff_i);
            sum_sig_sq += (ref_r * ref_r + ref_i * ref_i);
        }

        double num = sum_err_sq / (double)n;
        double den = sum_sig_sq / (double)n;
        double mse_db = 10.0 * log10(num / den);

        printf("[Gaussian Complex Noise N = %4d]\n", n);
        printf("  Numerator   (1/N * sum |X - X_hat|^2) = %.6e\n", num);
        printf("  Denominator (1/N * sum |X|^2)         = %.6e\n", den);
        printf("  Normalized MSE (10*log10(Num/Den))    = %6.2f dB\n", mse_db);
        printf("  Pass / Fail (Target <= -40 dB)        = %s\n\n", (mse_db <= -40.0) ? "PASSED" : "FAILED");

        free(f_in); free(f_out); free(fix_in); free(fix_out);
    }
    return 0;
}
