#ifndef XAXIDMA_FFT_H_
#define XAXIDMA_FFT_H_

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __arm__
#include "xil_types.h"
#include "xil_assert.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xaxidma.h"
#include "xtime_l.h"
#else
// Host simulation stub headers
typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t  u8;
typedef int32_t  s32;
typedef int16_t  s16;
typedef int      XStatus;
#define XST_SUCCESS 0
#define XST_FAILURE 1
#endif

// DDR Buffer Memory Map
#define DDR_BASE_ADDR        0x10000000
#define TX_BUFFER_BASE       (DDR_BASE_ADDR + 0x00100000) // 0x10100000
#define RX_BUFFER_BASE       (DDR_BASE_ADDR + 0x00200000) // 0x10200000
#define GOLDEN_BUFFER_BASE   (DDR_BASE_ADDR + 0x00300000) // 0x10300000

// FFT Configuration
#define MAX_FFT_POINTS       1024
#define BYTES_PER_SAMPLE     4 // 16-bit Imag + 16-bit Real = 32-bit word

// Fixed-point complex type
typedef struct {
    int16_t r;
    int16_t i;
} cplx16_t;

// Test Scenarios Enum
typedef enum {
    SCENARIO_IMPULSE = 0,
    SCENARIO_CONSTANT = 1,
    SCENARIO_4TONE = 2,
    SCENARIO_GAUSSIAN = 3
} fft_scenario_t;

// Function Prototypes
int init_fft_dma_system(void);
int run_fft_dma_transfer(int num_points, uint32_t tx_addr, uint32_t rx_addr);
void prepare_test_vector(fft_scenario_t scenario, int num_points, cplx16_t *tx_buf, cplx16_t *golden_buf);
double evaluate_normalized_mse(const cplx16_t *dut_out, const cplx16_t *golden_out, int num_points);

#endif /* XAXIDMA_FFT_H_ */
