#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "fft_model.h"

uint32_t bit_reverse(uint32_t x, int bits) {
    uint32_t res = 0;
    for (int i = 0; i < bits; i++) {
        res = (res << 1) | (x & 1);
        x >>= 1;
    }
    return res;
}

// Cooley-Tukey Decimation-in-Frequency (DIF) or Decimation-in-Time (DIT)
// Reference double precision FFT
void fft_float_reference(const cplx_double_t *in, cplx_double_t *out, int n, bool inverse) {
    int bits = 0;
    while ((1 << bits) < n) bits++;

    // Initial bit-reversal copy for DIT
    for (int i = 0; i < n; i++) {
        uint32_t rev = bit_reverse(i, bits);
        out[rev] = in[i];
    }

    double sign = inverse ? 1.0 : -1.0;

    for (int len = 2; len <= n; len <<= 1) {
        double angle = sign * 2.0 * M_PI / len;
        cplx_double_t wlen = { cos(angle), sin(angle) };
        for (int i = 0; i < n; i += len) {
            cplx_double_t w = { 1.0, 0.0 };
            for (int j = 0; j < len / 2; j++) {
                cplx_double_t u = out[i + j];
                cplx_double_t v = {
                    out[i + j + len / 2].r * w.r - out[i + j + len / 2].i * w.i,
                    out[i + j + len / 2].r * w.i + out[i + j + len / 2].i * w.r
                };
                out[i + j].r = u.r + v.r;
                out[i + j].i = u.i + v.i;
                out[i + j + len / 2].r = u.r - v.r;
                out[i + j + len / 2].i = u.i - v.i;

                // w = w * wlen
                double next_wr = w.r * wlen.r - w.i * wlen.i;
                double next_wi = w.r * wlen.i + w.i * wlen.r;
                w.r = next_wr;
                w.i = next_wi;
            }
        }
    }

    if (inverse) {
        for (int i = 0; i < n; i++) {
            out[i].r /= n;
            out[i].i /= n;
        }
    }
}
