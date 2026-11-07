`timescale 1ns / 1ps

// 1024-Point Radix-2^2 SDF FFT Core
// 5 Stage Pairs (10 Stages total)
module r22sdf_core (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  clk_en,
    input  wire                  fwd_inv,       // 1: FFT, 0: IFFT
    input  wire [9:0]            scale_sch,     // 10-bit scaling schedule
    
    // Streaming Input
    input  wire                  din_valid,
    input  wire signed [15:0]    din_real,
    input  wire signed [15:0]    din_imag,
    
    // Streaming Output (Bit-reversed order)
    output wire                  dout_valid,
    output wire signed [15:0]    dout_real,
    output wire signed [15:0]    dout_imag
);

    // Intermediate wires between pairs
    wire        p0_valid;
    wire [15:0] p0_real, p0_imag;

    wire        p1_valid;
    wire [15:0] p1_real, p1_imag;

    wire        p2_valid;
    wire [15:0] p2_real, p2_imag;

    wire        p3_valid;
    wire [15:0] p3_real, p3_imag;

    // Pair 0: D1=512, D2=256
    r22sdf_pair #(
        .D1     (512),
        .D2     (256),
        .HAS_ROT(1),
        .TOTAL_N(1024)
    ) u_pair0 (
        .clk       (clk),
        .rst_n     (rst_n),
        .clk_en    (clk_en),
        .fwd_inv   (fwd_inv),
        .scale1    (scale_sch[0]),
        .scale2    (scale_sch[1]),
        .din_valid (din_valid),
        .din_real  (din_real),
        .din_imag  (din_imag),
        .dout_valid(p0_valid),
        .dout_real (p0_real),
        .dout_imag (p0_imag)
    );

    // Pair 1: D1=128, D2=64
    r22sdf_pair #(
        .D1     (128),
        .D2     (64),
        .HAS_ROT(1),
        .TOTAL_N(1024)
    ) u_pair1 (
        .clk       (clk),
        .rst_n     (rst_n),
        .clk_en    (clk_en),
        .fwd_inv   (fwd_inv),
        .scale1    (scale_sch[2]),
        .scale2    (scale_sch[3]),
        .din_valid (p0_valid),
        .din_real  (p0_real),
        .din_imag  (p0_imag),
        .dout_valid(p1_valid),
        .dout_real (p1_real),
        .dout_imag (p1_imag)
    );

    // Pair 2: D1=32, D2=16
    r22sdf_pair #(
        .D1     (32),
        .D2     (16),
        .HAS_ROT(1),
        .TOTAL_N(1024)
    ) u_pair2 (
        .clk       (clk),
        .rst_n     (rst_n),
        .clk_en    (clk_en),
        .fwd_inv   (fwd_inv),
        .scale1    (scale_sch[4]),
        .scale2    (scale_sch[5]),
        .din_valid (p1_valid),
        .din_real  (p1_real),
        .din_imag  (p1_imag),
        .dout_valid(p2_valid),
        .dout_real (p2_real),
        .dout_imag (p2_imag)
    );

    // Pair 3: D1=8, D2=4
    r22sdf_pair #(
        .D1     (8),
        .D2     (4),
        .HAS_ROT(1),
        .TOTAL_N(1024)
    ) u_pair3 (
        .clk       (clk),
        .rst_n     (rst_n),
        .clk_en    (clk_en),
        .fwd_inv   (fwd_inv),
        .scale1    (scale_sch[6]),
        .scale2    (scale_sch[7]),
        .din_valid (p2_valid),
        .din_real  (p2_real),
        .din_imag  (p2_imag),
        .dout_valid(p3_valid),
        .dout_real (p3_real),
        .dout_imag (p3_imag)
    );

    // Pair 4: D1=2, D2=1 (No non-trivial twiddle rotation)
    r22sdf_pair #(
        .D1     (2),
        .D2     (1),
        .HAS_ROT(0),
        .TOTAL_N(1024)
    ) u_pair4 (
        .clk       (clk),
        .rst_n     (rst_n),
        .clk_en    (clk_en),
        .fwd_inv   (fwd_inv),
        .scale1    (scale_sch[8]),
        .scale2    (scale_sch[9]),
        .din_valid (p3_valid),
        .din_real  (p3_real),
        .din_imag  (p3_imag),
        .dout_valid(dout_valid),
        .dout_real (dout_real),
        .dout_imag (dout_imag)
    );

endmodule
