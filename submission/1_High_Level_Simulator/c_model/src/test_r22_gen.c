#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

typedef struct { double r, i; } cplx_t;

static inline uint32_t bit_rev(uint32_t x, int bits) {
    uint32_t r = 0;
    for (int i = 0; i < bits; i++) {
        r = (r << 1) | (x & 1);
        x >>= 1;
    }
    return r;
}

// Generalized Radix-2^2 DIF FFT (N must be a power of 4, or power of 2)
// For N=1024, 5 Radix-2^2 pairs
void fft_r22_dif(cplx_t *x, int n) {
    int log2_n = 0;
    while ((1 << log2_n) < n) log2_n++;
    int num_pairs = log2_n / 2;

    for (int p = 0; p < num_pairs; p++) {
        int N_sub = n >> (2 * p);
        int D1 = N_sub / 2;
        int D2 = N_sub / 4;
        int num_blocks = 1 << (2 * p);

        for (int blk = 0; blk < num_blocks; blk++) {
            int base = blk * N_sub;

            // BF2I: Butterfly on D1
            for (int i = 0; i < D1; i++) {
                cplx_t u = x[base + i];
                cplx_t v = x[base + i + D1];
                x[base + i].r = u.r + v.r;
                x[base + i].i = u.i + v.i;
                x[base + i + D1].r = u.r - v.r;
                x[base + i + D1].i = u.i - v.i;
            }

            // BF2II: Butterfly on D2
            // Half 0 (k1=0): no -j
            for (int i = 0; i < D2; i++) {
                cplx_t u = x[base + i];
                cplx_t v = x[base + i + D2];
                x[base + i].r = u.r + v.r;
                x[base + i].i = u.i + v.i;
                x[base + i + D2].r = u.r - v.r;
                x[base + i + D2].i = u.i - v.i;
            }
            // Half 1 (k1=1): multiply v by -j before butterfly!
            for (int i = 0; i < D2; i++) {
                cplx_t u = x[base + D1 + i];
                cplx_t v = x[base + D1 + i + D2];
                cplx_t v_rot = { v.i, -v.r }; // v * (-j)
                x[base + D1 + i].r = u.r + v_rot.r;
                x[base + D1 + i].i = u.i + v_rot.i;
                x[base + D1 + i + D2].r = u.r - v_rot.r;
                x[base + D1 + i + D2].i = u.i - v_rot.i;
            }

            // Twiddle multiplication (only if not last pair)
            if (p < num_pairs - 1) {
                int weights[4] = { 0, 2, 1, 3 };
                for (int b = 0; b < 4; b++) {
                    int w_mult = weights[b];
                    for (int i = 0; i < D2; i++) {
                        int idx = base + b * D2 + i;
                        int tw_k = w_mult * i * (n / N_sub);
                        double angle = -2.0 * M_PI * tw_k / (double)n;
                        cplx_t w = { cos(angle), sin(angle) };
                        cplx_t val = x[idx];
                        x[idx].r = val.r * w.r - val.i * w.i;
                        x[idx].i = val.r * w.i + val.i * w.r;
                    }
                }
            }
        }
    }

    // Bit-reversal reorder
    for (int i = 0; i < n; i++) {
        int rev = (int)bit_rev(i, log2_n);
        if (rev > i) {
            cplx_t tmp = x[i];
            x[i] = x[rev];
            x[rev] = tmp;
        }
    }
}

int main() {
    int n = 1024;
    cplx_t in[1024], out_r22[1024];
    for (int i = 0; i < n; i++) {
        in[i].r = 0.7 * cos(2.0 * M_PI * 57 * i / n) + 0.3 * sin(2.0 * M_PI * 133 * i / n);
        in[i].i = 0.0;
        out_r22[i] = in[i];
    }

    fft_r22_dif(out_r22, n);

    // Let's check peaks
    printf("Peaks in N=1024 R2^2 FFT output:\n");
    for (int i = 0; i < n; i++) {
        double mag = sqrt(out_r22[i].r*out_r22[i].r + out_r22[i].i*out_r22[i].i);
        if (mag > 50.0) {
            printf("  bin %4d: mag=%8.2f\n", i, mag);
        }
    }
    return 0;
}
