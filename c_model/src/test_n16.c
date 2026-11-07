#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

typedef struct { double r, i; } cplx_t;

void dft_direct(const cplx_t *in, cplx_t *out, int n) {
    for (int k = 0; k < n; k++) {
        out[k].r = 0; out[k].i = 0;
        for (int t = 0; t < n; t++) {
            double angle = -2.0 * M_PI * k * t / n;
            double cr = cos(angle), ci = sin(angle);
            out[k].r += in[t].r * cr - in[t].i * ci;
            out[k].i += in[t].r * ci + in[t].i * cr;
        }
    }
}

int main() {
    int n = 16;
    cplx_t in[16], dft_out[16];
    for (int i = 0; i < n; i++) {
        in[i].r = cos(2.0 * M_PI * 3 * i / n);
        in[i].i = sin(2.0 * M_PI * 3 * i / n);
    }
    dft_direct(in, dft_out, n);
    printf("DFT done for N=16:\n");
    for (int i = 0; i < n; i++) {
        double mag = sqrt(dft_out[i].r*dft_out[i].r + dft_out[i].i*dft_out[i].i);
        if (mag > 0.1) printf("  k=%d: mag=%.4f (%.4f + j%.4f)\n", i, mag, dft_out[i].r, dft_out[i].i);
    }
    return 0;
}
