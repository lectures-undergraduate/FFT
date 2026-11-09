`timescale 1ns / 1ps

// 1024 / 256 / 64-Point Radix-2^2 SDF FFT Core
// 5 Stage Pairs (10 Stages total) with Runtime Configurable NFFT Bypass
module r22sdf_core (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  clk_en,
    input  wire                  fwd_inv,       // 1: FFT, 0: IFFT
    input  wire [9:0]            scale_sch,     // 10-bit scaling schedule
    input  wire [3:0]            cfg_nfft,      // 10: 1024, 8: 256, 6: 64
    
    // Streaming Input
    input  wire                  din_valid,
    input  wire signed [15:0]    din_real,
    input  wire signed [15:0]    din_imag,
    
    // Streaming Output (Bit-reversed order)
    output wire                  dout_valid,
    output wire signed [15:0]    dout_real,
    output wire signed [15:0]    dout_imag
);

    // Active FFT size decode
    wire is_n1024 = (cfg_nfft == 4'd10 || (cfg_nfft != 4'd8 && cfg_nfft != 4'd6));
    wire is_n256  = (cfg_nfft == 4'd8);
    wire is_n64   = (cfg_nfft == 4'd6);

    // Dynamic Scale Schedule Mapping per Stage Pair
    wire scale_p0_1 = scale_sch[0];
    wire scale_p0_2 = scale_sch[1];

    wire scale_p1_1 = is_n256 ? scale_sch[0] : scale_sch[2];
    wire scale_p1_2 = is_n256 ? scale_sch[1] : scale_sch[3];

    wire scale_p2_1 = is_n64 ? scale_sch[0] : (is_n256 ? scale_sch[2] : scale_sch[4]);
    wire scale_p2_2 = is_n64 ? scale_sch[1] : (is_n256 ? scale_sch[3] : scale_sch[5]);

    wire scale_p3_1 = is_n64 ? scale_sch[2] : (is_n256 ? scale_sch[4] : scale_sch[6]);
    wire scale_p3_2 = is_n64 ? scale_sch[3] : (is_n256 ? scale_sch[5] : scale_sch[7]);

    wire scale_p4_1 = is_n64 ? scale_sch[4] : (is_n256 ? scale_sch[6] : scale_sch[8]);
    wire scale_p4_2 = is_n64 ? scale_sch[5] : (is_n256 ? scale_sch[7] : scale_sch[9]);

    // Stage MUX & Interconnects
    // Pair 0: D1=512, D2=256 (Used only when N=1024)
    wire        p0_in_valid = is_n1024 ? din_valid : 1'b0;
    wire        p0_valid;
    wire [15:0] p0_real, p0_imag;

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
        .scale1    (scale_p0_1),
        .scale2    (scale_p0_2),
        .din_valid (p0_in_valid),
        .din_real  (din_real),
        .din_imag  (din_imag),
        .dout_valid(p0_valid),
        .dout_real (p0_real),
        .dout_imag (p0_imag)
    );

    // Pair 1: D1=128, D2=64 (Used when N=1024 or N=256)
    wire        p1_in_valid = is_n1024 ? p0_valid : (is_n256 ? din_valid : 1'b0);
    wire [15:0] p1_in_real  = is_n1024 ? p0_real  : din_real;
    wire [15:0] p1_in_imag  = is_n1024 ? p0_imag  : din_imag;

    wire        p1_valid;
    wire [15:0] p1_real, p1_imag;

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
        .scale1    (scale_p1_1),
        .scale2    (scale_p1_2),
        .din_valid (p1_in_valid),
        .din_real  (p1_in_real),
        .din_imag  (p1_in_imag),
        .dout_valid(p1_valid),
        .dout_real (p1_real),
        .dout_imag (p1_imag)
    );

    // Pair 2: D1=32, D2=16 (Used for N=1024, 256, 64)
    wire        p2_in_valid = is_n64 ? din_valid : p1_valid;
    wire [15:0] p2_in_real  = is_n64 ? din_real  : p1_real;
    wire [15:0] p2_in_imag  = is_n64 ? din_imag  : p1_imag;

    wire        p2_valid;
    wire [15:0] p2_real, p2_imag;

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
        .scale1    (scale_p2_1),
        .scale2    (scale_p2_2),
        .din_valid (p2_in_valid),
        .din_real  (p2_in_real),
        .din_imag  (p2_in_imag),
        .dout_valid(p2_valid),
        .dout_real (p2_real),
        .dout_imag (p2_imag)
    );

    // Pair 3: D1=8, D2=4
    wire        p3_valid;
    wire [15:0] p3_real, p3_imag;

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
        .scale1    (scale_p3_1),
        .scale2    (scale_p3_2),
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
        .scale1    (scale_p4_1),
        .scale2    (scale_p4_2),
        .din_valid (p3_valid),
        .din_real  (p3_real),
        .din_imag  (p3_imag),
        .dout_valid(dout_valid),
        .dout_real (dout_real),
        .dout_imag (dout_imag)
    );

endmodule
