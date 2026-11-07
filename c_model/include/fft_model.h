#ifndef FFT_MODEL_H
#define FFT_MODEL_H

#include "fixed_point.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Function prototypes
void fft_float_reference(const cplx_double_t *in, cplx_double_t *out, int n, bool inverse);
void fft_r22sdf_fixed_simulate(const cplx16_t *in, cplx16_t *out, int n, uint16_t scale_sch, bool inverse);
void generate_twiddles(void);
uint32_t bit_reverse(uint32_t x, int bits);

// Evaluation
typedef struct {
    double sqnr_db;
    double snr_db;
    double mse;
    double max_abs_err;
    double max_rel_err;
} fft_metrics_t;

fft_metrics_t evaluate_accuracy(const cplx_double_t *ref, const cplx16_t *fixed, int n, double input_scale);

#endif // FFT_MODEL_H
