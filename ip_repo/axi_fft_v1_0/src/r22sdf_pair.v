`timescale 1ns / 1ps

// Radix-2^2 SDF Stage Pair
// Combines BF2I, BF2II, and Twiddle Factor Multiplier
module r22sdf_pair #(
    parameter D1 = 512,
    parameter D2 = 256,
    parameter HAS_ROT = 1,
    parameter TOTAL_N = 1024
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  clk_en,
    input  wire                  fwd_inv,
    input  wire                  scale1,
    input  wire                  scale2,
    input  wire                  din_valid,
    input  wire signed [15:0]    din_real,
    input  wire signed [15:0]    din_imag,
    output wire                  dout_valid,
    output wire signed [15:0]    dout_real,
    output wire signed [15:0]    dout_imag
);

    // BF2I
    wire                  bf1_valid;
    wire signed [15:0]    bf1_real;
    wire signed [15:0]    bf1_imag;

    r22sdf_bf2i #(
        .DELAY(D1)
    ) u_bf2i (
        .clk       (clk),
        .rst_n     (rst_n),
        .clk_en    (clk_en),
        .scale     (scale1),
        .din_valid (din_valid),
        .din_real  (din_real),
        .din_imag  (din_imag),
        .dout_valid(bf1_valid),
        .dout_real (bf1_real),
        .dout_imag (bf1_imag)
    );

    // BF2II
    wire                  bf2_valid;
    wire signed [15:0]    bf2_real;
    wire signed [15:0]    bf2_imag;
    wire [9:0]            tw_addr;
    wire                  tw_en;

    r22sdf_bf2ii #(
        .DELAY  (D2),
        .TOTAL_N(TOTAL_N)
    ) u_bf2ii (
        .clk         (clk),
        .rst_n       (rst_n),
        .clk_en      (clk_en),
        .fwd_inv     (fwd_inv),
        .scale       (scale2),
        .din_valid   (bf1_valid),
        .din_real    (bf1_real),
        .din_imag    (bf1_imag),
        .dout_valid  (bf2_valid),
        .dout_real   (bf2_real),
        .dout_imag   (bf2_imag),
        .twiddle_addr(tw_addr),
        .twiddle_en  (tw_en)
    );

    generate
        if (HAS_ROT) begin : gen_mult
            // Twiddle ROM (1 clock synchronous read latency)
            wire [31:0] tw_data;
            twiddle_rom u_twiddle_rom (
                .clk    (clk),
                .clk_en (clk_en),
                .fwd_inv(fwd_inv),
                .addr   (tw_addr),
                .dout   (tw_data)
            );

            // Align data with ROM read latency (1 cycle)
            reg                  bf2_valid_d1;
            reg signed [15:0]    bf2_real_d1;
            reg signed [15:0]    bf2_imag_d1;

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    bf2_valid_d1 <= 1'b0;
                    bf2_real_d1  <= 16'd0;
                    bf2_imag_d1  <= 16'd0;
                end else if (clk_en) begin
                    bf2_valid_d1 <= bf2_valid;
                    bf2_real_d1  <= bf2_real;
                    bf2_imag_d1  <= bf2_imag;
                end
            end

            // Complex Multiplier (3 clock latency)
            wire signed [15:0] mult_real;
            wire signed [15:0] mult_imag;

            complex_mult u_cmult (
                .clk   (clk),
                .rst_n (rst_n),
                .clk_en(clk_en),
                .ar    (bf2_real_d1),
                .ai    (bf2_imag_d1),
                .wr    (tw_data[15:0]),
                .wi    (tw_data[31:16]),
                .pr    (mult_real),
                .pi    (mult_imag)
            );

            // Valid pipeline alignment (mult latency = 3)
            reg [2:0] val_pipe;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    val_pipe <= 3'b0;
                end else if (clk_en) begin
                    val_pipe <= {val_pipe[1:0], bf2_valid_d1};
                end
            end

            assign dout_valid = val_pipe[2];
            assign dout_real  = mult_real;
            assign dout_imag  = mult_imag;

        end else begin : gen_no_mult
            assign dout_valid = bf2_valid;
            assign dout_real  = bf2_real;
            assign dout_imag  = bf2_imag;
        end
    endgenerate

endmodule
