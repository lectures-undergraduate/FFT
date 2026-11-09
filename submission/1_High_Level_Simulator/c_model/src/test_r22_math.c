#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "fft_model.h"

// Check exact R2^2 DIF
void test_dif_r22(cplx_double_t *x, int n) {
    int N = n;
    for (int p = 0; p < 5; p++) {
        int N_sub = N >> (2 * p); // 1024, 256, 64, 16, 4
        int D1 = N_sub / 2;
        int D2 = N_sub / 4;

        for (int blk = 0; blk < (1 << (2 * p)); blk++) {
            int base = blk * N_sub;

            // Butterfly I: split into two halves (k1=0, k1=1)
            for (int i = 0; i < D1; i++) {
                cplx_double_t u = x[base + i];
                cplx_double_t v = x[base + i + D1];
                x[base + i].r = u.r + v.r;
                x[base + i].i = u.i + v.i;
                x[base + i + D1].r = u.r - v.r;
                x[base + i + D1].i = u.i - v.i;
            }

            // Butterfly II: split each half into two quarters
            // Half 0 (k1=0): base .. base + D1 - 1
            for (int i = 0; i < D2; i++) {
                cplx_double_t u = x[base + i];
                cplx_double_t v = x[base + i + D2];
                // k2=0
                x[base + i].r = u.r + v.r;
                x[base + i].i = u.i + v.i;
                // k2=1 (k1=0, so no -j)
                x[base + i + D2].r = u.r - v.r;
                x[base + i + D2].i = u.i - v.i;
            }

            // Half 1 (k1=1): base + D1 .. base + N_sub - 1
            for (int i = 0; i < D2; i++) {
                cplx_double_t u = x[base + D1 + i];
                cplx_double_t v = x[base + D1 + i + D2];
                // k2=0
                x[base + D1 + i].r = u.r + v.r;
                x[base + D1 + i].i = u.i + v.i;
                // k2=1 (k1=1, so multiply diff by -j: (r + j*i)*(-j) = i - j*r)
                double dr = u.r - v.r;
                double di = u.i - v.i;
                x[base + D1 + i + D2].r = di;
                x[base + D1 + i + D2].i = -dr;
            }

            // Twiddle multiplication
            // The 4 sub-blocks correspond to (k1, k2):
            // Sub-block 0: base + 0*D2 .. (k1=0, k2=0) -> twiddle weight = 0
            // Sub-block 1: base + 1*D2 .. (k1=0, k2=1) -> twiddle weight = 2*k2 + k1?
            // Let's check: exponent is n3 * (2*k2 + k1)
            // Sub-block 0: k1=0, k2=0 -> weight = 0
            // Sub-block 1: k1=0, k2=1 -> weight = 2
            // Sub-block 2: k1=1, k2=0 -> weight = 1
            // Sub-block 3: k1=1, k2=1 -> weight = 3
            if (p < 4) {
                int weights[4] = { 0, 2, 1, 3 };
                for (int b = 0; b < 4; b++) {
                    int w_mult = weights[b];
                    for (int i = 0; i < D2; i++) {
                        int idx = base + b * D2 + i;
                        int tw_k = w_mult * i * (1024 / N_sub);
                        double angle = -2.0 * M_PI * tw_k / 1024.0;
                        cplx_double_t w = { cos(angle), sin(angle) };
                        cplx_double_t val = x[idx];
                        x[idx].r = val.r * w.r - val.i * w.i;
                        x[idx].i = val.r * w.i + val.i * w.r;
                    }
                }
            }
        }
    }
}

int main() {
    int n = 1024;
    cplx_double_t in[1024], out_fft[1024], out_r22[1024];

    for (int i = 0; i < n; i++) {
        in[i].r = cos(2.0 * M_PI * 32 * i / n);
        in[i].i = 0.0;
        out_r22[i] = in[i];
    }

    fft_float_reference(in, out_fft, n, false);
    test_dif_r22(out_r22, n);

    // In DIF FFT, the output order is bit-reversed!
    for (int i = 0; i < n; i++) {
        int rev = bit_reverse(i, 10);
        if (rev > i) {
            cplx_double_t tmp = out_r22[i];
            out_r22[i] = out_r22[rev];
            out_r22[rev] = tmp;
        }
    }

    double max_diff = 0;
    for (int i = 0; i < n; i++) {
        double dr = out_fft[i].r - out_r22[i].r;
        double di = out_fft[i].i - out_r22[i].i;
        double diff = sqrt(dr*dr + di*di);
        if (diff > max_diff) max_diff = diff;
    }
    printf("Corrected DIF R2^2 reference vs Cooley-Tukey FFT: max_diff = %.3e\n", max_diff);
    return 0;
}
