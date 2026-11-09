# 1. High Level Language Floating/Fixed-Point Simulator

## Overview
This folder contains the complete C-language and MATLAB high-level simulators designed to evaluate, verify, and validate the Radix-$2^2$ Single-Path Delay Feedback ($R2^2SDF$) AXI FFT processor before RTL implementation.

### Standards & Performance Criteria
According to Section 1 of the Term Project Guidelines:
- **Normalized Mean Squared Error (MSE)** must satisfy $\text{MSE} \le -40 \text{ dB}$:
  $$\text{MSE} = 10 \log_{10} \left( \frac{\frac{1}{N} \sum_{k=0}^{N-1} |X(k) - \hat{X}(k)|^2}{\frac{1}{N} \sum_{k=0}^{N-1} |X(k)|^2} \right)$$
- Supported FFT sizes: $N \in \{64, 256, 1024\}$
- Input bit-width: 16-bit signed fixed-point (Q1.15) for both In-phase (I) and Quadrature (Q) components.

---

## Directory Contents
- `c_model/`:
  - `src/main.c`: Main test harness executing all 4 mandatory evaluation scenarios across $N \in \{1024, 256, 64\}$.
  - `src/fft_r22sdf_fixed.c`: Cycle-accurate bit-true fixed-point Radix-$2^2$ SDF simulator with pipelined 1/2 scaling per pair.
  - `src/fft_float_ref.c`: Double-precision Cooley-Tukey floating-point FFT reference.
  - `src/twiddle_gen.c`: Generates 16-bit quantized twiddle factors ($W_{1024}^k$) exported as hex tables.
  - `include/fft_r22sdf.h`: Core data structures and interface prototypes.
  - `Makefile`: Build script for GCC / MinGW.
- `data/`:
  - Test vectors and golden outputs generated for each scenario (`input_*.hex` and `golden_*.hex`).
- `matlab_fft_verify.m`:
  - Standalone MATLAB verification script that benchmarks ideal `fft()` vs fixed-point quantization and outputs the MSE report table.

---

## Evaluation Results Summary (C Simulator)

| FFT Size ($N$) | Test Scenario | Ideal Energy | Error Energy | Normalized MSE | Target Requirement | Status |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1024** | **Scenario 1: Impulse** | $8.00 \times 10^7$ | 80 | **-59.99 dB** | $\le -40 \text{ dB}$ | **PASSED** |
| **1024** | **Scenario 2: Constant (DC)** | $2.75 \times 10^{11}$ | 450 | **-87.81 dB** | $\le -40 \text{ dB}$ | **PASSED** |
| **1024** | **Scenario 3: 4-Tone** | $1.98 \times 10^9$ | 13,760 | **-51.60 dB** | $\le -40 \text{ dB}$ | **PASSED** |
| **1024** | **Scenario 4: Complex Gaussian Noise** | $1.26 \times 10^9$ | 14,357 | **-49.39 dB** | $\le -40 \text{ dB}$ | **PASSED** |
| **256** | **Scenario 4: Complex Gaussian Noise** | $3.15 \times 10^8$ | 967 | **-55.14 dB** | $\le -40 \text{ dB}$ | **PASSED** |
| **64** | **Scenario 4: Complex Gaussian Noise** | $7.88 \times 10^7$ | 56 | **-61.42 dB** | $\le -40 \text{ dB}$ | **PASSED** |

> **Conclusion**: All scenarios significantly exceed the project guideline threshold ($\le -40\text{ dB}$), with Gaussian noise achieving **$-49.39\text{ dB}$** at $N=1024$, **$-55.14\text{ dB}$** at $N=256$, and **$-61.42\text{ dB}$** at $N=64$.

---

## How to Compile & Run
```bash
cd c_model
make clean && make
./fft_sim
```
Or in MATLAB:
```matlab
run('matlab_fft_verify.m');
```
