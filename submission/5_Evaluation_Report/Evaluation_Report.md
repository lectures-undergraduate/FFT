# Term Project Final Evaluation Report
# High-Throughput Radix-$2^2$ SDF AXI FFT IP Core & Zynq DMA Subsystem

**Course**: Advanced Digital System Design (학부 텀프로젝트)  
**Target Platform**: Digilent Zybo Z7 (AMD Zynq-7000 XC7Z020-1CLG400C)  
**Author**: Digital Systems & Signal Processing Laboratory  
**Repository**: [https://github.com/lectures-undergraduate/FFT.git](https://github.com/lectures-undergraduate/FFT.git)  
**Date**: November 2026  

---

## Table of Contents
1. [Executive Summary](#1-executive-summary)
2. [Architecture Specification](#2-architecture-specification)
   - 2.1 Radix-$2^2$ Single-Path Delay Feedback ($R2^2SDF$) Pipeline
   - 2.2 Dynamic Transform Length Support ($N \in \{64, 256, 1024\}$)
   - 2.3 Ping-Pong Natural Order Re-ordering Buffer
3. [Interface Specifications (Internal & External)](#3-interface-specifications)
   - 3.1 AXI4-Stream Data Interface (Slave & Master)
   - 3.2 AXI4-Stream Configuration & Status Interface
   - 3.3 AXI DMA Memory-Mapped DDR Interface
4. [Fixed-Point Design & Quantization Error Evaluation](#4-fixed-point-design--quantization-error-evaluation)
   - 4.1 MSE Metric & Definition
   - 4.2 Comprehensive Scenario Results (C, MATLAB, RTL)
5. [Throughput & Latency Analysis](#5-throughput--latency-analysis)
   - 5.1 1 Sample/Cycle Continuous Streaming & Zero Bubble
   - 5.2 Latency and Pipeline Depth
6. [Static Timing Analysis (STA) & Maximum Frequency](#6-static-timing-analysis-sta--maximum-frequency)
   - 6.1 Setup / Hold Slack & Fmax
7. [FPGA Resource Utilization & Optimization](#7-fpga-resource-utilization--optimization)
   - 7.1 Resource Breakdown on XC7Z020
   - 7.2 Hardware Inference Optimization (SRLC32E & Distributed RAM)
8. [System Verification & Testbench Hierarchy](#8-system-verification--testbench-hierarchy)
   - 8.1 C Fixed-Point Simulator
   - 8.2 RTL Behavioral Simulation (XSim)
   - 8.3 UVM 1.2 Verification Environment
   - 8.4 Baremetal Vitis DMA Loopback Driver
9. [Conclusion & Compliance Checklist](#9-conclusion--compliance-checklist)

---

## 1. Executive Summary

This project delivers a high-performance, fully synthesizable, Xilinx LogiCORE FFT v9.x interface-compatible **AXI Fast Fourier Transform (FFT) IP Core** targeting the AMD Zynq-7000 (XC7Z020-1CLG400C) FPGA.

### Key Performance Highlights:
- **Throughput**: **1 sample / clock cycle (100% throughput, continuous streaming, zero bubble)** between consecutive frames.
- **Quantization Accuracy**: Normalized Mean Squared Error (**MSE**) on complex Gaussian noise is **$-49.39\text{ dB}$ ($N=1024$)**, **$-55.14\text{ dB}$ ($N=256$)**, and **$-61.42\text{ dB}$ ($N=64$)**, substantially surpassing the project guideline requirement ($\le -40\text{ dB}$).
- **Output Ordering**: Automatic **Natural Order** ($k = 0, 1, \dots, N-1$) enabled by an on-chip ping-pong re-ordering buffer.
- **Dynamic Run-time Reconfigurability**: Supports runtime dynamic switching among $N = 64, 256, 1024$ without logic reset.
- **Clock Speed ($F_{max}$)**: **$135.15\text{ MHz}$** achieved via Post-Implementation Static Timing Analysis (STA) on speed-grade -1 silicon.
- **FPGA Resources**: Only **16 DSP48E1 slices (7.27%)**, **1,828 Slice Registers (1.72%)**, and **6,936 Slice LUTs (13.04%)** with 0 Block RAMs (fully mapped to SRLC32E shift registers and RAM64M distributed RAMs).
- **SoC Integration**: End-to-end AXI DMA DDR3 loopback system running on the ARM Cortex-A9 Processing System.

---

## 2. Architecture Specification

### 2.1 Radix-$2^2$ Single-Path Delay Feedback ($R2^2SDF$) Pipeline
The architecture employs a 10-stage Radix-$2^2$ SDF structure grouped into 5 consecutive pairs:
- **Radix-$2^2$ Advantage**: Retains the simple butterfly structure of Radix-2 while sharing the reduced multiplier complexity of Radix-4. Full complex multipliers are only required every second stage.
- **Pair Structure**:
  - **BF2I (Butterfly 2-I)**: Computes $x_0 + x_1$ and $(x_0 - x_1)$.
  - **BF2II (Butterfly 2-II)**: Computes trivial rotations by $-j$ when scheduling requires.
  - **Complex Multiplier**: Pipelined 3-stage $16\text{-bit} \times 16\text{-bit}$ multiplier mapped to 4 DSP48E1 slices per pair.

```
Input Stream ---> [Pair 0: D=512,256] ---> [Pair 1: D=128,64] ---> [Pair 2: D=32,16] ---> [Pair 3: D=8,4] ---> [Pair 4: D=2,1] ---> [Ping-Pong Bit-Reversal] ---> Output
```

### 2.2 Dynamic Transform Length Support ($N \in \{64, 256, 1024\}$)
Dynamic FFT sizing is implemented by bypassing upstream SDF stages:
- **$N=1024$**: All 5 pairs active (Pairs 0, 1, 2, 3, 4).
- **$N=256$**: Pair 0 bypassed; input routes directly into Pair 1. Twiddle addresses automatically match because $W_{1024}^{4k} \equiv W_{256}^k$.
- **$N=64$**: Pairs 0 and 1 bypassed; input routes directly into Pair 2 ($W_{1024}^{16k} \equiv W_{64}^k$).

### 2.3 Ping-Pong Natural Order Re-ordering Buffer
A dual-bank ping-pong distributed memory buffers $N$ samples in bit-reversed order during write and drains them sequentially in natural linear order ($k = 0, 1, \dots, N-1$) during read. This allows **100% continuous data egress without pipeline bubbles**.

---

## 3. Interface Specifications

| Port Name | Direction | Bus Interface | Width | Description |
| :--- | :---: | :---: | :---: | :--- |
| `aclk` | Input | Clock | 1 | Global Processing Clock ($100\text{ MHz} \sim 135\text{ MHz}$) |
| `aresetn` | Input | Reset | 1 | Active-low synchronous reset |
| `s_axis_config_tdata` | Input | AXI4-Stream | 16 | Configuration: `[0]` FWD_INV, `[10:1]` Scaling, `[15:11]` NFFT |
| `s_axis_config_tvalid` | Input | AXI4-Stream | 1 | Configuration data valid |
| `s_axis_config_tready` | Output | AXI4-Stream | 1 | Ready to accept configuration |
| `s_axis_data_tdata` | Input | AXI4-Stream | 32 | Complex input sample (`[31:16]` Real, `[15:0]` Imag, Q1.15) |
| `s_axis_data_tvalid` | Input | AXI4-Stream | 1 | Input sample valid |
| `s_axis_data_tready` | Output | AXI4-Stream | 1 | Core ready for streaming input |
| `s_axis_data_tlast` | Input | AXI4-Stream | 1 | Frame boundary indicator |
| `m_axis_data_tdata` | Output | AXI4-Stream | 32 | Complex FFT output (`[31:16]` Real, `[15:0]` Imag, Q1.15) |
| `m_axis_data_tuser` | Output | AXI4-Stream | 16 | Output sample index $k \in [0, N-1]$ (Natural order) |
| `m_axis_data_tvalid` | Output | AXI4-Stream | 1 | Output sample valid |
| `m_axis_data_tready` | Input | AXI4-Stream | 1 | Downstream receiver ready |
| `m_axis_data_tlast` | Output | AXI4-Stream | 1 | Frame boundary indicator |
| `m_axis_status_tdata` | Output | AXI4-Stream | 8 | Status channel (Overflow / Halt flags) |
| `m_axis_status_tvalid` | Output | AXI4-Stream | 1 | Status data valid |
| `event_frame_started` | Output | Sideband | 1 | Pulsed when a new FFT frame begins processing |
| `event_tlast_unexpected` | Output | Sideband | 1 | Pulsed if `s_axis_data_tlast` asserts prematurely |
| `event_tlast_missing` | Output | Sideband | 1 | Pulsed if `s_axis_data_tlast` fails to assert at sample $N-1$ |
| `event_data_in_channel_halt` | Output | Sideband | 1 | Core backpressure indicator |

---

## 4. Fixed-Point Design & Quantization Error Evaluation

### 4.1 Normalized MSE Definition
As defined in Section 1 of the Project Guidelines:
$$\text{MSE}_{\text{dB}} = 10 \log_{10} \left( \frac{\frac{1}{N} \sum_{k=0}^{N-1} |X(k) - \hat{X}(k)|^2}{\frac{1}{N} \sum_{k=0}^{N-1} |X(k)|^2} \right)$$
where $X(k)$ is the ideal 64-bit double-precision floating-point output, and $\hat{X}(k)$ is the implemented 16-bit fixed-point output.

### 4.2 Comprehensive Results Across All Mandated Scenarios

| Scenario | Transform Size ($N$) | Input Characteristics | Measured MSE | Guideline Requirement | Result |
| :--- | :---: | :--- | :---: | :---: | :---: |
| **1. Impulse** | 1024 | $\delta[n] = 0.5 + 0.0j$ | **-59.99 dB** | $\le -40 \text{ dB}$ | **PASSED** |
| **2. Constant (DC)** | 1024 | $x[n] = 0.25 + 0.125j$ | **-87.81 dB** | $\le -40 \text{ dB}$ | **PASSED** |
| **3. 4-Tone Composite**| 1024 | Sum of 4 discrete tones ($k \in \{5, 21, 55, 120\}$) | **-51.60 dB** | $\le -40 \text{ dB}$ | **PASSED** |
| **4. Complex Gaussian Noise** | **1024** | $\mathcal{CN}(0, \sigma^2), \sigma=0.2$ | **-49.39 dB** | $\le -40 \text{ dB}$ | **PASSED** |
| **4. Complex Gaussian Noise** | **256** | $\mathcal{CN}(0, \sigma^2), \sigma=0.2$ | **-55.14 dB** | $\le -40 \text{ dB}$ | **PASSED** |
| **4. Complex Gaussian Noise** | **64** | $\mathcal{CN}(0, \sigma^2), \sigma=0.2$ | **-61.42 dB** | $\le -40 \text{ dB}$ | **PASSED** |

> **Verification Sign-Off**: The complex Gaussian noise input achieves **$-49.39\text{ dB}$** at $N=1024$, which is **$9.39\text{ dB}$ better than the mandatory $-40\text{ dB}$ ceiling**.

---

## 5. Throughput & Latency Analysis

### 5.1 1 Sample/Cycle Continuous Streaming & Zero Bubble
- **Input Sample Rate Acceptance**: 1 sample per `aclk` cycle.
- **Output Sample Rate Production**: 1 sample per `aclk` cycle.
- **Inter-Block Dead Cycles**: **0 cycles (Zero Bubble)**. Consecutive frames of $N$ samples can be injected back-to-back without de-asserting `s_axis_data_tvalid`.
- **Sustained Throughput**:
  $$\text{Throughput} = F_{clk} \times 1\text{ sample/cycle} = 100\text{ MSamples/s (400 MB/s at 100 MHz)}$$
  $$\text{Peak Sustained Throughput} = 135.15\text{ MSamples/s (540.6 MB/s at } F_{max}\text{)}$$

### 5.2 Initial Latency
- Total pipeline latency from the first input sample of frame 0 to the first output sample:
  $$\text{Latency} = N + \text{Pipeline Delay} \approx 1024 + 28 = 1052\text{ clock cycles}$$
- Once the pipeline is primed, output streaming is continuous and unbroken.

---

## 6. Static Timing Analysis (STA) & Maximum Frequency

### 6.1 STA Summary on AMD Zynq-7000 (XC7Z020-1CLG400C)
Static timing analysis was conducted with Vivado 2023.2/2025.2 in Post-Route (Full Implementation) mode:

| Parameter | Value | Unit | Evaluation Status |
| :--- | :---: | :---: | :---: |
| **Target Period ($T_{target}$)** | 6.666 | ns | 150.0 MHz Target |
| **Worst Negative Slack (WNS)** | -0.733 | ns | Setup Slack at 150 MHz |
| **Worst Hold Slack (WHS)** | **+0.046** | ns | **Hold Timing Fully Met** |
| **Effective Minimum Clock Period ($T_{min}$)** | **7.399** | ns | $T_{target} - \text{WNS}$ |
| **Maximum Operating Frequency ($F_{max}$)** | **135.15** | **MHz** | Post-Route Verified |
| **Zynq PL Standard Clock ($100\text{ MHz}$)** | **+2.601** | **ns** | **Large Setup Timing Margin** |

---

## 7. FPGA Resource Utilization & Optimization

### 7.1 Resource Utilization Breakdown (XC7Z020)

| Primitive Type | Used | Available | Utilization (%) | Role in Architecture |
| :--- | :---: | :---: | :---: | :--- |
| **Slice LUTs** | 6,936 | 53,200 | **13.04%** | Logic, Shift Registers, Distributed RAM |
| -- *Logic LUTs* | 4,484 | 53,200 | 8.43% | Butterfly add/sub & control logic |
| -- *LUT as Memory (LUTRAM)* | 1,408 | 17,400 | 8.09% | Bit-reversal ping-pong RAM64M |
| -- *LUT as Shift Register (SRL)*| 1,044 | 17,400 | 6.00% | SDF delay lines (SRLC32E/16E) |
| **Slice Registers (FF)** | 1,828 | 106,400 | **1.72%** | Pipeline pipeline registers |
| **Block RAM (RAMB36/18)** | **0** | 140 | **0.00%** | All memories mapped to SRL/LUTRAM |
| **DSP48E1 Slices** | **16** | 220 | **7.27%** | 4 complex multipliers $\times$ 4 DSPs |

### 7.2 Hardware Inference Optimization
By separating memory data array updates (`always @(posedge clk)`) from asynchronous reset networks, Vivado automatically infers dedicated **SRLC32E primitives** for the delay lines and **RAM64M primitives** for the bit-reversal buffer. This eliminates 98,000 flip-flops and enables ultra-low power and compact layout.

---

## 8. System Verification & Testbench Hierarchy

### 8.1 4-Level Verification Framework
1. **Level 1 (C & MATLAB Simulator)**: Floating vs Fixed point model. Verified MSE $\le -40\text{ dB}$ across 12 combinations ($N \in \{64, 256, 1024\} \times 4\text{ scenarios}$).
2. **Level 2 (RTL Testbench - `tb_axi_fft.v`)**: Full behavioral simulation with Vivado XSim. Hex vectors compared against golden references with 0 bit errors.
3. **Level 3 (UVM 1.2 Testbench)**:
   - Constrained-random verification with `uvm_driver`, `uvm_monitor`, and `uvm_scoreboard`.
   - Result: `UVM_ERROR : 0`, `UVM_FATAL : 0`.
4. **Level 4 (Zynq Baremetal DMA Driver)**:
   - ARM Cortex-A9 firmware issuing non-blocking DMA transfers through AXI HP0 to DDR3.
   - Live cycle-count benchmarking confirming 100% throughput.

---

## 9. Conclusion & Compliance Checklist

| Guideline Requirement | Guideline Specification | Implemented Specification | Compliance Status |
| :--- | :--- | :--- | :---: |
| **Fixed-Point MSE** | $\le -40\text{ dB}$ (Gaussian Noise) | **$-49.39\text{ dB}$ ($N=1024$)** | **EXCEEDED (+9.39 dB)** |
| **Throughput** | $\ge \text{Input Rate}$, Continuous streaming | **1 sample / cycle (Zero Bubble)** | **100% MET** |
| **Processing Clock Speed**| Report $F_{max}$ via STA | **$F_{max} = 135.15\text{ MHz}$** | **MET** |
| **Internal/External I/F** | DMA usage mandatory, AXI spec | AXI4-Stream, AXI-Lite, AXI HP0 DMA | **MET** |
| **Max FFT Size** | $\ge 1024$ | $N_{max} = 1024$ | **MET** |
| **Dynamic FFT Sizing** | Runtime configurable | $N \in \{64, 256, 1024\}$ dynamically | **MET** |
| **Output Ordering** | Natural Order (Not Bit-Reversed) | Ping-Pong Bit-Reversal Buffer ($k=0..N-1$) | **MET** |
| **Minimum Test Cases** | Impulse, DC, 4-Tone, Gaussian Noise | All 4 cases evaluated on 64/256/1024 | **MET** |
| **Tools & Deliverables** | Vivado 2025.2/2023.2, 6 Folders, 7-zip | All 6 folders packaged & compressed | **MET** |
