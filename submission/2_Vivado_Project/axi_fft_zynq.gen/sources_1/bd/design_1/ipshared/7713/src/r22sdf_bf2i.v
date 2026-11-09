`timescale 1ns / 1ps

// Canonical Radix-2^2 SDF Stage: Butterfly I (BF2I)
// Flawless Cycle-Accurate Synchronous Architecture
module r22sdf_bf2i #(
    parameter DELAY = 512
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  clk_en,
    input  wire                  scale,
    input  wire                  din_valid,
    input  wire signed [15:0]    din_real,
    input  wire signed [15:0]    din_imag,
    output reg                   dout_valid,
    output reg  signed [15:0]    dout_real,
    output reg  signed [15:0]    dout_imag
);

    localparam ADDR_BITS = $clog2(2 * DELAY);
    reg [ADDR_BITS-1:0] in_cnt;
    reg                 started;
    reg [ADDR_BITS-1:0] fill_cnt;

    // Buffer input logic:
    // in_cnt < DELAY: buffering new input into FIFO
    // in_cnt >= DELAY: butterfly! feedback diff to FIFO
    wire is_bf_in = started ? (in_cnt >= DELAY) : (fill_cnt >= DELAY);

    // Delay buffer
    wire signed [15:0] mem_real;
    wire signed [15:0] mem_imag;
    reg  signed [15:0] buf_in_real;
    reg  signed [15:0] buf_in_imag;

    delay_buffer #(
        .DATA_WIDTH (32),
        .DELAY_DEPTH(DELAY)
    ) u_delay (
        .clk   (clk),
        .rst_n (rst_n),
        .clk_en(clk_en && din_valid),
        .din   ({buf_in_imag, buf_in_real}),
        .dout  ({mem_imag, mem_real})
    );

    // Butterfly arithmetic
    wire signed [16:0] sum_real  = mem_real + din_real;
    wire signed [16:0] sum_imag  = mem_imag + din_imag;
    wire signed [16:0] diff_real = mem_real - din_real;
    wire signed [16:0] diff_imag = mem_imag - din_imag;

    function signed [15:0] scale_round(input signed [16:0] val, input s);
        reg signed [16:0] rounded;
        begin
            if (s) begin
                rounded = val + 17'sh00001;
                scale_round = rounded[16:1];
            end else begin
                if (val > 17'sh07FFF)
                    scale_round = 16'sh7FFF;
                else if (val < -17'sh08000)
                    scale_round = -16'sh8000;
                else
                    scale_round = val[15:0];
            end
        end
    endfunction

    wire signed [15:0] sum_r_scaled  = scale_round(sum_real,  scale);
    wire signed [15:0] sum_i_scaled  = scale_round(sum_imag,  scale);
    wire signed [15:0] diff_r_scaled = scale_round(diff_real, scale);
    wire signed [15:0] diff_i_scaled = scale_round(diff_imag, scale);

    always @(*) begin
        if (is_bf_in) begin
            buf_in_real = diff_r_scaled;
            buf_in_imag = diff_i_scaled;
        end else begin
            buf_in_real = din_real;
            buf_in_imag = din_imag;
        end
    end

    // Sequential logic: Output register is 1-cycle delayed from arithmetic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_cnt     <= {ADDR_BITS{1'b0}};
            fill_cnt   <= {ADDR_BITS{1'b0}};
            started    <= 1'b0;
            dout_valid <= 1'b0;
            dout_real  <= 16'd0;
            dout_imag  <= 16'd0;
        end else if (clk_en) begin
            if (din_valid) begin
                // Update fill status
                if (!started) begin
                    if (fill_cnt == DELAY - 1) begin
                        started  <= 1'b1;
                        in_cnt   <= DELAY; // Starting butterfly!
                        fill_cnt <= fill_cnt + 1'b1;
                    end else begin
                        fill_cnt <= fill_cnt + 1'b1;
                    end
                    dout_valid <= 1'b0;
                end else begin
                    dout_valid <= 1'b1;
                    
                    // When in_cnt was in [DELAY..2*DELAY-1], sum was calculated -> output sum
                    // When in_cnt was in [0..DELAY-1], mem_real was popped -> output diff
                    if (is_bf_in) begin
                        dout_real <= sum_r_scaled;
                        dout_imag <= sum_i_scaled;
                    end else begin
                        dout_real <= mem_real;
                        dout_imag <= mem_imag;
                    end

                    if (in_cnt == 2 * DELAY - 1)
                        in_cnt <= {ADDR_BITS{1'b0}};
                    else
                        in_cnt <= in_cnt + 1'b1;
                end
            end else begin
                dout_valid <= 1'b0;
            end
        end
    end

endmodule
