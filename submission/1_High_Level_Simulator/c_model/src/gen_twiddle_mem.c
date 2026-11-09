#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Twiddle ROM generator for hardware synthesis & simulation
// Format: 32-bit hex per line -> [31:16] = Imaginary, [15:0] = Real
// Twiddle factor: W_1024^k = cos(2*pi*k/1024) - j * sin(2*pi*k/1024)
// Real = round(cos * 32767), Imag = round(-sin * 32767)
int main() {
    FILE *f = fopen("data/twiddle_1024.hex", "w");
    if (!f) {
        printf("Error opening file for write\n");
        return 1;
    }

    for (int k = 0; k < 1024; k++) {
        double angle = -2.0 * M_PI * k / 1024.0;
        double c = cos(angle);
        double s = sin(angle);

        int32_t val_r = (int32_t)round(c * 32767.0);
        int32_t val_i = (int32_t)round(s * 32767.0);
        if (val_r > 32767) val_r = 32767;
        if (val_r < -32768) val_r = -32768;
        if (val_i > 32767) val_i = 32767;
        if (val_i < -32768) val_i = -32768;

        uint16_t ur = (uint16_t)val_r;
        uint16_t ui = (uint16_t)val_i;
        uint32_t word = ((uint32_t)ui << 16) | ur;

        fprintf(f, "%08X\n", word);
    }

    fclose(f);
    printf("Successfully generated data/twiddle_1024.hex\n");
    return 0;
}
