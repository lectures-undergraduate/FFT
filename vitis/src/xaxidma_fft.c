#include "xaxidma_fft.h"

#ifdef __arm__
static XAxiDma AxiDmaInstance;
#endif

// Initialize AXI DMA
int init_fft_dma_system(void) {
#ifdef __arm__
    XAxiDma_Config *CfgPtr;
    int Status;

    xil_printf("[VITIS DMA] Initializing AXI DMA engine (Device ID: %d)...\r\n", XPAR_AXIDMA_0_DEVICE_ID);
    CfgPtr = XAxiDma_LookupConfig(XPAR_AXIDMA_0_DEVICE_ID);
    if (!CfgPtr) {
        xil_printf("[ERROR] No config found for %d\r\n", XPAR_AXIDMA_0_DEVICE_ID);
        return XST_FAILURE;
    }

    Status = XAxiDma_CfgInitialize(&AxiDmaInstance, CfgPtr);
    if (Status != XST_SUCCESS) {
        xil_printf("[ERROR] DMA Initialization failed %d\r\n", Status);
        return XST_FAILURE;
    }

    if (XAxiDma_HasSg(&AxiDmaInstance)) {
        xil_printf("[ERROR] Device configured as SG mode, expected Simple Direct mode\r\n");
        return XST_FAILURE;
    }

    // Disable interrupts for simple polling mode
    XAxiDma_IntrDisable(&AxiDmaInstance, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrDisable(&AxiDmaInstance, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

    xil_printf("[VITIS DMA] AXI DMA initialized successfully in Simple Register Mode.\r\n");
#else
    printf("[SIM] Host stub: AXI DMA initialized.\n");
#endif
    return XST_SUCCESS;
}

// Perform DMA Transfer: DDR -> MM2S -> FFT -> S2MM -> DDR
int run_fft_dma_transfer(int num_points, uint32_t tx_addr, uint32_t rx_addr) {
    int byte_len = num_points * BYTES_PER_SAMPLE;
#ifdef __arm__
    int Status;

    // Flush Cache for TX Buffer (DDR -> Device)
    Xil_DCacheFlushRange((UINTPTR)tx_addr, byte_len);

    // Invalidate Cache for RX Buffer (Device -> DDR)
    Xil_DCacheInvalidateRange((UINTPTR)rx_addr, byte_len);

    // 1. Submit S2MM Transfer first so core is ready to receive
    Status = XAxiDma_SimpleTransfer(&AxiDmaInstance, (UINTPTR)rx_addr, byte_len, XAXIDMA_DEVICE_TO_DMA);
    if (Status != XST_SUCCESS) {
        xil_printf("[ERROR] S2MM SimpleTransfer failed %d\r\n", Status);
        return XST_FAILURE;
    }

    // 2. Submit MM2S Transfer
    Status = XAxiDma_SimpleTransfer(&AxiDmaInstance, (UINTPTR)tx_addr, byte_len, XAXIDMA_DMA_TO_DEVICE);
    if (Status != XST_SUCCESS) {
        xil_printf("[ERROR] MM2S SimpleTransfer failed %d\r\n", Status);
        return XST_FAILURE;
    }

    // 3. Poll MM2S completion
    while (XAxiDma_Busy(&AxiDmaInstance, XAXIDMA_DMA_TO_DEVICE)) {
        // Wait
    }

    // 4. Poll S2MM completion
    while (XAxiDma_Busy(&AxiDmaInstance, XAXIDMA_DEVICE_TO_DMA)) {
        // Wait
    }

    // Re-invalidate cache so ARM core reads fresh data from DDR
    Xil_DCacheInvalidateRange((UINTPTR)rx_addr, byte_len);
#else
    // Host simulation stub: copy tx to rx
    memcpy((void *)(uintptr_t)rx_addr, (void *)(uintptr_t)tx_addr, byte_len);
#endif
    return XST_SUCCESS;
}

// Prepare Test Vectors for Guideline Scenarios
void prepare_test_vector(fft_scenario_t scenario, int num_points, cplx16_t *tx_buf, cplx16_t *golden_buf) {
    double pi = 3.14159265358979323846;

    switch (scenario) {
        case SCENARIO_IMPULSE:
            for (int i = 0; i < num_points; i++) {
                tx_buf[i].r = (i == 0) ? 32734 : 0;
                tx_buf[i].i = 0;
            }
            break;

        case SCENARIO_CONSTANT:
            for (int i = 0; i < num_points; i++) {
                tx_buf[i].r = 24575; // 0.75 in Q1.15
                tx_buf[i].i = 0;
            }
            break;

        case SCENARIO_4TONE: {
            int k1 = 12 * num_points / 1024; if (k1 < 1) k1 = 1;
            int k2 = 35 * num_points / 1024; if (k2 <= k1) k2 = k1 + 2;
            int k3 = 88 * num_points / 1024; if (k3 <= k2) k3 = k2 + 4;
            int k4 = 150 * num_points / 1024; if (k4 <= k3) k4 = k3 + 6;
            for (int i = 0; i < num_points; i++) {
                double v = 0.22 * cos(2.0 * pi * k1 * i / num_points) +
                           0.22 * cos(2.0 * pi * k2 * i / num_points) +
                           0.22 * cos(2.0 * pi * k3 * i / num_points) +
                           0.22 * cos(2.0 * pi * k4 * i / num_points);
                tx_buf[i].r = (int16_t)round(v * 32767.0);
                tx_buf[i].i = 0;
            }
            break;
        }

        case SCENARIO_GAUSSIAN: {
            double sigma = 0.2;
            srand(42);
            for (int i = 0; i < num_points; i += 2) {
                double u1 = ((double)rand() + 1.0) / ((double)RAND_MAX + 2.0);
                double u2 = ((double)rand() + 1.0) / ((double)RAND_MAX + 2.0);
                double r = sigma * sqrt(-2.0 * log(u1));
                double th = 2.0 * pi * u2;
                tx_buf[i].r = (int16_t)round(r * cos(th) * 32767.0);
                tx_buf[i].i = (int16_t)round(r * sin(th) * 32767.0);
                if (i + 1 < num_points) {
                    double u3 = ((double)rand() + 1.0) / ((double)RAND_MAX + 2.0);
                    double u4 = ((double)rand() + 1.0) / ((double)RAND_MAX + 2.0);
                    double r2 = sigma * sqrt(-2.0 * log(u3));
                    double th2 = 2.0 * pi * u4;
                    tx_buf[i+1].r = (int16_t)round(r2 * cos(th2) * 32767.0);
                    tx_buf[i+1].i = (int16_t)round(r2 * sin(th2) * 32767.0);
                }
            }
            break;
        }
    }
}

// Compute Normalized MSE (dB)
double evaluate_normalized_mse(const cplx16_t *dut_out, const cplx16_t *golden_out, int num_points) {
    double sum_err = 0.0;
    double sum_sig = 0.0;

    for (int i = 0; i < num_points; i++) {
        double dr = (double)dut_out[i].r / 32768.0;
        double di = (double)dut_out[i].i / 32768.0;
        double gr = (double)golden_out[i].r / 32768.0;
        double gi = (double)golden_out[i].i / 32768.0;

        double er = dr - gr;
        double ei = di - gi;

        sum_err += (er * er + ei * ei);
        sum_sig += (gr * gr + gi * gi);
    }

    if (sum_sig < 1e-15) return -999.0;
    return 10.0 * log10(sum_err / sum_sig);
}
