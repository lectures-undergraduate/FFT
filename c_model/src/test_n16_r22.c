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

// Exact R2^2 derivation for N=16
void r22_n16(const cplx_t *x, cplx_t *X) {
    // Stage 1 (BF2I): D1 = 8
    cplx_t b1[16];
    for (int i = 0; i < 8; i++) {
        // k1 = 0
        b1[i].r = x[i].r + x[i + 8].r;
        b1[i].i = x[i].i + x[i + 8].i;
        // k1 = 1
        b1[i + 8].r = x[i].r - x[i + 8].r;
        b1[i + 8].i = x[i].i - x[i + 8].i;
    }

    // Stage 2 (BF2II): D2 = 4
    cplx_t b2[16];
    // For k1 = 0 (i = 0..3):
    for (int i = 0; i < 4; i++) {
        // k2 = 0
        b2[i].r = b1[i].r + b1[i + 4].r;
        b2[i].i = b1[i].i + b1[i + 4].i;
        // k2 = 1
        b2[i + 4].r = b1[i].r - b1[i + 4].r;
        b2[i + 4].i = b1[i].i - b1[i + 4].i;
    }
    // For k1 = 1 (i = 8..11):
    // Note: b1[i+4] is multiplied by -j before butterfly!
    // b1[i+4] * (-j) = (b1.i, -b1.r)
    for (int i = 0; i < 4; i++) {
        cplx_t u = b1[i + 8];
        cplx_t v = b1[i + 12];
        cplx_t v_rot = { v.i, -v.r }; // v * (-j)

        // k2 = 0
        b2[i + 8].r = u.r + v_rot.r;
        b2[i + 8].i = u.i + v_rot.i;
        // k2 = 1
        b2[i + 12].r = u.r - v_rot.r;
        b2[i + 12].i = u.i - v_rot.i;
    }

    // Twiddle factor after Pair 0:
    // W_16^{n3 * (2*k2 + k1)}
    // b2 is indexed as:
    // 0..3:   k1=0, k2=0 -> (2*k2 + k1) = 0
    // 4..7:   k1=0, k2=1 -> (2*k2 + k1) = 2
    // 8..11:  k1=1, k2=0 -> (2*k2 + k1) = 1
    // 12..15: k1=1, k2=1 -> (2*k2 + k1) = 3
    int mult_factor[4] = { 0, 2, 1, 3 };
    cplx_t z[16];
    for (int grp = 0; grp < 4; grp++) {
        int m = mult_factor[grp];
        for (int n3 = 0; n3 < 4; n3++) {
            int idx = grp * 4 + n3;
            double angle = -2.0 * M_PI * (m * n3) / 16.0;
            cplx_t w = { cos(angle), sin(angle) };
            cplx_t val = b2[idx];
            z[idx].r = val.r * w.r - val.i * w.i;
            z[idx].i = val.r * w.i + val.i * w.r;
        }
    }

    // Now Pair 1 (D1=2, D2=1) on each 4-point block!
    for (int grp = 0; grp < 4; grp++) {
        int base = grp * 4;
        // BF2I on 4-point block (D1=2)
        cplx_t s1[4];
        for (int i = 0; i < 2; i++) {
            s1[i].r = z[base + i].r + z[base + i + 2].r;
            s1[i].i = z[base + i].i + z[base + i + 2].i;
            s1[i + 2].r = z[base + i].r - z[base + i + 2].r;
            s1[i + 2].i = z[base + i].i - z[base + i + 2].i;
        }

        // BF2II on 4-point block (D2=1)
        cplx_t s2[4];
        // k1_sub = 0 (i=0)
        s2[0].r = s1[0].r + s1[1].r;
        s2[0].i = s1[0].i + s1[1].i;
        s2[1].r = s1[0].r - s1[1].r;
        s2[1].i = s1[0].i - s1[1].i;

        // k1_sub = 1 (i=2)
        cplx_t u = s1[2];
        cplx_t v = s1[3];
        cplx_t v_rot = { v.i, -v.r };
        s2[2].r = u.r + v_rot.r;
        s2[2].i = u.i + v_rot.i;
        s2[3].r = u.r - v_rot.r;
        s2[3].i = u.i - v_rot.i;

        for (int i = 0; i < 4; i++) {
            X[base + i] = s2[i];
        }
    }
}

int main() {
    int n = 16;
    cplx_t in[16], dft_out[16], r22_out[16];
    for (int i = 0; i < n; i++) {
        in[i].r = cos(2.0 * M_PI * 3 * i / n);
        in[i].i = sin(2.0 * M_PI * 3 * i / n);
    }
    dft_direct(in, dft_out, n);
    r22_n16(in, r22_out);

    // Let's inspect where the output bins of r22_out are
    printf("Comparing R22 output with DFT:\n");
    for (int i = 0; i < n; i++) {
        double dft_mag = sqrt(dft_out[i].r*dft_out[i].r + dft_out[i].i*dft_out[i].i);
        double r22_mag = sqrt(r22_out[i].r*r22_out[i].r + r22_out[i].i*r22_out[i].i);
        printf("idx %2d: DFT_mag=%6.2f, R22_mag=%6.2f\n", i, dft_mag, r22_mag);
    }
    return 0;
}
