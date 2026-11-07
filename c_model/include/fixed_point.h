#ifndef FIXED_POINT_H
#define FIXED_POINT_H

#include <stdint.h>
#include <stdbool.h>
#include <math.h>

#define FFT_N           1024
#define LOG2_N          10
#define DATA_WIDTH      16
#define TWIDDLE_WIDTH   16

// 16-bit complex number representation
typedef struct {
    int16_t r;
    int16_t i;
} cplx16_t;

// 32-bit complex number representation (for intermediate accumulation)
typedef struct {
    int32_t r;
    int32_t i;
} cplx32_t;

// Double precision complex for golden model
typedef struct {
    double r;
    double i;
} cplx_double_t;

// Rounding with saturation (Convergent / Round-to-nearest)
static inline int16_t round_shift_sat16(int32_t val, int shift) {
    if (shift == 0) {
        if (val > 32767) return 32767;
        if (val < -32768) return -32768;
        return (int16_t)val;
    }
    // Round to nearest (add 1 << (shift - 1))
    int32_t round_const = 1 << (shift - 1);
    int32_t rounded = (val + round_const) >> shift;
    if (rounded > 32767) rounded = 32767;
    if (rounded < -32768) rounded = -32768;
    return (int16_t)rounded;
}

// Fixed-point complex multiplication with 16-bit twiddle factor
// (Ar + jAi) * (Wr + jWi) = (Ar*Wr - Ai*Wi) + j(Ar*Wi + Ai*Wr)
// Output scaled back to 16-bit (Q1.15 * Q1.15 -> Q2.30 -> shift 15 -> Q1.15)
static inline cplx16_t cplx_mult16(cplx16_t a, cplx16_t w) {
    int32_t real_prod1 = (int32_t)a.r * (int32_t)w.r;
    int32_t real_prod2 = (int32_t)a.i * (int32_t)w.i;
    int32_t imag_prod1 = (int32_t)a.r * (int32_t)w.i;
    int32_t imag_prod2 = (int32_t)a.i * (int32_t)w.r;

    int32_t real_accum = real_prod1 - real_prod2;
    int32_t imag_accum = imag_prod1 + imag_prod2;

    cplx16_t out;
    out.r = round_shift_sat16(real_accum, 15);
    out.i = round_shift_sat16(imag_accum, 15);
    return out;
}

#endif // FIXED_POINT_H
