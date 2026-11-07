#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

int main() {
    FILE *f_rtl = fopen("rtl_output.hex", "r");
    FILE *f_gld = fopen("golden_tone32.hex", "r");
    if (!f_rtl || !f_gld) {
        printf("Error opening hex files\n");
        return 1;
    }

    uint32_t rtl_raw[1024], gld_raw[1024];
    for (int i = 0; i < 1024; i++) {
        fscanf(f_rtl, "%x", &rtl_raw[i]);
        fscanf(f_gld, "%x", &gld_raw[i]);
    }
    fclose(f_rtl);
    fclose(f_gld);

    printf("Top 10 Peaks in RTL Output:\n");
    double mags[1024];
    int idxs[1024];
    for (int i = 0; i < 1024; i++) {
        int16_t r = (int16_t)(rtl_raw[i] & 0xFFFF);
        int16_t im = (int16_t)((rtl_raw[i] >> 16) & 0xFFFF);
        mags[i] = sqrt((double)r * r + (double)im * im);
        idxs[i] = i;
    }

    // Sort by magnitude
    for (int i = 0; i < 1024; i++) {
        for (int j = i + 1; j < 1024; j++) {
            if (mags[j] > mags[i]) {
                double tm = mags[i]; mags[i] = mags[j]; mags[j] = tm;
                int ti = idxs[i]; idxs[i] = idxs[j]; idxs[j] = ti;
            }
        }
    }

    for (int k = 0; k < 10; k++) {
        int id = idxs[k];
        int16_t r = (int16_t)(rtl_raw[id] & 0xFFFF);
        int16_t im = (int16_t)((rtl_raw[id] >> 16) & 0xFFFF);
        printf("  Rank %2d: Bin %4d -> Mag = %7.1f (Real=%6d, Imag=%6d)\n", 
               k + 1, id, mags[k], r, im);
    }

    return 0;
}
