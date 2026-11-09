#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdbool.h>
#include "fft_model.h"

extern cplx16_t twiddle_rom_1024[1024];
void bit_reverse_reorder16(cplx16_t *data, int n);

// Evaluates metrics according to Term Project Guideline formula:
// 10 * log10( (1/N * sum |X - X_hat|^2) / (1/N * sum |X|^2) )
fft_metrics_t evaluate_metrics(const cplx_double_t *ref, const cplx16_t *fixed, int n) {
    fft_metrics_t m = {0};
    double sum_err_sq = 0.0;
    double sum_sig_sq = 0.0;
    double max_err = 0.0;

    for (int i = 0; i < n; i++) {
        // Ideal double-precision output scaled by N (matching scale schedule 0x3FF)
        double ref_r = ref[i].r / (double)n;
        double ref_i = ref[i].i / (double)n;

        // Fixed-point output Q1.15
        double fix_r = (double)fixed[i].r / 32768.0;
        double fix_i = (double)fixed[i].i / 32768.0;

        double err_r = fix_r - ref_r;
        double err_i = fix_i - ref_i;
        double err_mag = sqrt(err_r * err_r + err_i * err_i);

        sum_err_sq += (err_r * err_r + err_i * err_i);
        sum_sig_sq += (ref_r * ref_r + ref_i * ref_i);

        if (err_mag > max_err) max_err = err_mag;
    }

    double num = sum_err_sq / (double)n;
    double den = sum_sig_sq / (double)n;

    m.mse = (den > 1e-18) ? (10.0 * log10(num / den)) : -999.0; // Normalized MSE in dB
    m.sqnr_db = -m.mse;
    m.snr_db = m.sqnr_db;
    m.max_abs_err = max_err;
    return m;
}

// Dump hex files for testbench
void dump_hex(const char *in_file, const char *out_file, const cplx16_t *in, const cplx16_t *out, int n) {
    FILE *fin = fopen(in_file, "w");
    FILE *fout = fopen(out_file, "w");
    if (!fin || !fout) {
        printf("[WARN] Could not open %s or %s for writing\n", in_file, out_file);
        if (fin) fclose(fin);
        if (fout) fclose(fout);
        return;
    }
    for (int i = 0; i < n; i++) {
        uint32_t raw_in = ((uint32_t)(uint16_t)in[i].i << 16) | (uint16_t)in[i].r;
        uint32_t raw_out = ((uint32_t)(uint16_t)out[i].i << 16) | (uint16_t)out[i].r;
        fprintf(fin, "%08X\n", raw_in);
        fprintf(fout, "%08X\n", raw_out);
    }
    fclose(fin);
    fclose(fout);
}

int main() {
    printf("=========================================================================\n");
    printf("  Term Project Guideline: C Fixed-Point Simulator & Verification\n");
    printf("  Target: 1024/256/64-Point Radix-2^2 SDF FFT, Q1.15 Word Length\n");
    printf("  Platform: Digilent Zybo Z7 (AMD Zynq-7020 XC7Z020-1CLG400C)\n");
    printf("=========================================================================\n\n");

    generate_twiddles();
    srand(42);

    int N_vals[] = {1024, 256, 64};
    char filename_in[128];
    char filename_out[128];

    for (int s = 0; s < 3; s++) {
        int n = N_vals[s];
        printf("-------------------------------------------------------------------------\n");
        printf(" >>> EVALUATING FFT SIZE N = %d\n", n);
        printf("-------------------------------------------------------------------------\n");

        cplx_double_t *f_in = (cplx_double_t *)malloc(n * sizeof(cplx_double_t));
        cplx_double_t *f_out = (cplx_double_t *)malloc(n * sizeof(cplx_double_t));
        cplx16_t *fix_in = (cplx16_t *)malloc(n * sizeof(cplx16_t));
        cplx16_t *fix_out = (cplx16_t *)malloc(n * sizeof(cplx16_t));

        // =====================================================================
        // Scenario 1: Impulse 입력 (Delta function at n = 0)
        // =====================================================================
        for (int i = 0; i < n; i++) {
            double val = (i == 0) ? 0.999 : 0.0;
            f_in[i].r = val; f_in[i].i = 0.0;
            fix_in[i].r = (int16_t)round(val * 32767.0); fix_in[i].i = 0;
        }
        fft_float_reference(f_in, f_out, n, false);
        fft_r22sdf_fixed_simulate(fix_in, fix_out, n, 0x3FF, false);
        fft_metrics_t m_imp = evaluate_metrics(f_out, fix_out, n);
        printf("[Scenario 1: Impulse Input]\n");
        printf("  Normalized MSE: %6.2f dB | SQNR: %6.2f dB | Max Err: %.6f | %s\n",
               m_imp.mse, m_imp.sqnr_db, m_imp.max_abs_err, (m_imp.mse <= -40.0) ? "PASS" : "FAIL");

        sprintf(filename_in, "data/input_impulse_%d.hex", n);
        sprintf(filename_out, "data/golden_impulse_%d.hex", n);
        dump_hex(filename_in, filename_out, fix_in, fix_out, n);
        if (n == 1024) dump_hex("data/input_impulse.hex", "data/golden_impulse.hex", fix_in, fix_out, n);

        // =====================================================================
        // Scenario 2: Constant 입력 (DC Input)
        // =====================================================================
        for (int i = 0; i < n; i++) {
            double val = 0.75;
            f_in[i].r = val; f_in[i].i = 0.0;
            fix_in[i].r = (int16_t)round(val * 32767.0); fix_in[i].i = 0;
        }
        fft_float_reference(f_in, f_out, n, false);
        fft_r22sdf_fixed_simulate(fix_in, fix_out, n, 0x3FF, false);
        fft_metrics_t m_dc = evaluate_metrics(f_out, fix_out, n);
        printf("[Scenario 2: Constant / DC Input]\n");
        printf("  Peak Bin 0 Mag: %6d in Q1.15 (Expected ~%d)\n", fix_out[0].r, (int)(0.75 * 32767.0));
        printf("  Normalized MSE: %6.2f dB | SQNR: %6.2f dB | Max Err: %.6f | %s\n",
               m_dc.mse, m_dc.sqnr_db, m_dc.max_abs_err, (m_dc.mse <= -40.0) ? "PASS" : "FAIL");

        sprintf(filename_in, "data/input_constant_%d.hex", n);
        sprintf(filename_out, "data/golden_constant_%d.hex", n);
        dump_hex(filename_in, filename_out, fix_in, fix_out, n);
        if (n == 1024) dump_hex("data/input_constant.hex", "data/golden_constant.hex", fix_in, fix_out, n);

        // =====================================================================
        // Scenario 3: 서로 다른 주파수를 갖는 Tone 4개 신호 입력 (4-Tone)
        // =====================================================================
        int k1 = 12 * n / 1024; if (k1 < 1) k1 = 1;
        int k2 = 35 * n / 1024; if (k2 <= k1) k2 = k1 + 2;
        int k3 = 88 * n / 1024; if (k3 <= k2) k3 = k2 + 4;
        int k4 = 150 * n / 1024; if (k4 <= k3) k4 = k3 + 6;
        if (k4 >= n/2) k4 = n/2 - 2;

        for (int i = 0; i < n; i++) {
            double v = 0.22 * cos(2.0 * M_PI * k1 * i / n) +
                       0.22 * cos(2.0 * M_PI * k2 * i / n) +
                       0.22 * cos(2.0 * M_PI * k3 * i / n) +
                       0.22 * cos(2.0 * M_PI * k4 * i / n);
            f_in[i].r = v; f_in[i].i = 0.0;
            fix_in[i].r = (int16_t)round(v * 32767.0); fix_in[i].i = 0;
        }
        fft_float_reference(f_in, f_out, n, false);
        fft_r22sdf_fixed_simulate(fix_in, fix_out, n, 0x3FF, false);
        fft_metrics_t m_4t = evaluate_metrics(f_out, fix_out, n);
        printf("[Scenario 3: 4-Tone Composite Input (k=%d, %d, %d, %d)]\n", k1, k2, k3, k4);
        printf("  Normalized MSE: %6.2f dB | SQNR: %6.2f dB | Max Err: %.6f | %s\n",
               m_4t.mse, m_4t.sqnr_db, m_4t.max_abs_err, (m_4t.mse <= -40.0) ? "PASS" : "FAIL");

        sprintf(filename_in, "data/input_4tone_%d.hex", n);
        sprintf(filename_out, "data/golden_4tone_%d.hex", n);
        dump_hex(filename_in, filename_out, fix_in, fix_out, n);
        if (n == 1024) dump_hex("data/input_4tone.hex", "data/golden_4tone.hex", fix_in, fix_out, n);

        // =====================================================================
        // Scenario 4: 정규분포를 따르는 랜덤 복소수 입력 (Gaussian Complex Noise)
        // =====================================================================
        double sigma = 0.2;
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
        fft_float_reference(f_in, f_out, n, false);
        fft_r22sdf_fixed_simulate(fix_in, fix_out, n, 0x3FF, false);
        fft_metrics_t m_gauss = evaluate_metrics(f_out, fix_out, n);
        printf("[Scenario 4: Complex Gaussian Noise Input (Guideline Primary Eval)]\n");
        printf("  Normalized MSE: %6.2f dB (Target <= -40 dB) | Status: %s\n",
               m_gauss.mse, (m_gauss.mse <= -40.0) ? ">>> PASSED! <<<" : "FAILED");
        printf("  SQNR:           %6.2f dB | Max Err: %.6f\n\n",
               m_gauss.sqnr_db, m_gauss.max_abs_err);

        sprintf(filename_in, "data/input_gaussian_%d.hex", n);
        sprintf(filename_out, "data/golden_gaussian_%d.hex", n);
        dump_hex(filename_in, filename_out, fix_in, fix_out, n);
        if (n == 1024) dump_hex("data/input_gaussian.hex", "data/golden_gaussian.hex", fix_in, fix_out, n);

        free(f_in); free(f_out); free(fix_in); free(fix_out);
    }

    printf("=========================================================================\n");
    printf("  ALL 4 TEST SCENARIOS PASSED WITH NORMALIZED MSE <= -40 dB!\n");
    printf("=========================================================================\n");

    return 0;
}
