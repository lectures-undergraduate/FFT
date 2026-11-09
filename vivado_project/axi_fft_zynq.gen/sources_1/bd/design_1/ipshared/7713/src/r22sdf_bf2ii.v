`timescale 1ns / 1ps

// Radix-2^2 SDF Stage: Butterfly II (BF2II)
// Cycle-accurate streaming architecture with -j rotation
module r22sdf_bf2ii #(
    parameter DELAY = 256,
    parameter TOTAL_N = 1024
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  clk_en,
    input  wire                  fwd_inv,    // 1: Forward FFT, 0: Inverse FFT
    input  wire                  scale,      // 1: divide by 2 with rounding
    input  wire                  din_valid,
    input  wire signed [15:0]    din_real,
    input  wire signed [15:0]    din_imag,
    output reg                   dout_valid,
    output reg  signed [15:0]    dout_real,
    output reg  signed [15:0]    dout_imag,
    
    // Twiddle interface for subsequent complex multiplier
    output reg  [9:0]            twiddle_addr,
    output reg                   twiddle_en
);

    localparam TOTAL_PERIOD = 4 * DELAY;
    localparam CNT_BITS = $clog2(TOTAL_PERIOD);

    reg [CNT_BITS-1:0] cnt;
    reg                filled;
    reg [CNT_BITS-1:0] fill_cnt;

    wire [1:0] branch = cnt / DELAY; // 0, 1, 2, 3
    wire state = (branch == 2'd1 || branch == 2'd3); // 0: butterfly, 1: FIFO pop
    wire need_rot = (branch == 2'd2); // Pre-rotate v by -j during k1=1 butterfly!

    // Pre-rotation for butterfly input if need_rot (b=2)
    // FFT:  (r + j*i) * (-j) = i - j*r
    // IFFT: (r + j*i) * (+j) = -i + j*r
    wire signed [15:0] rot_din_real = fwd_inv ? din_imag  : (-din_imag);
    wire signed [15:0] rot_din_imag = fwd_inv ? (-din_real) : din_real;

    wire signed [15:0] eff_din_real = need_rot ? rot_din_real : din_real;
    wire signed [15:0] eff_din_imag = need_rot ? rot_din_imag : din_imag;

    // Delay buffer D2
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
    wire signed [16:0] sum_real  = mem_real + eff_din_real;
    wire signed [16:0] sum_imag  = mem_imag + eff_din_imag;
    wire signed [16:0] diff_real = mem_real - eff_din_real;
    wire signed [16:0] diff_imag = mem_imag - eff_din_imag;

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

    // Buffer input MUX
    always @(*) begin
        if (!filled || state) begin
            buf_in_real = din_real;
            buf_in_imag = din_imag;
        end else begin
            buf_in_real = diff_r_scaled;
            buf_in_imag = diff_i_scaled;
        end
    end

    // Twiddle weight calculation:
    // b=0 -> 0, b=1 -> 2, b=2 -> 1, b=3 -> 3
    reg [1:0] tw_weight;
    always @(*) begin
        case (branch)
            2'd0: tw_weight = 2'd0;
            2'd1: tw_weight = 2'd2;
            2'd2: tw_weight = 2'd1;
            2'd3: tw_weight = 2'd3;
        endcase
    end

    wire [CNT_BITS-1:0] m_idx = cnt % DELAY;
    wire [19:0] raw_tw_k = tw_weight * m_idx * (TOTAL_N / TOTAL_PERIOD);
    wire [9:0]  tw_addr_comb = raw_tw_k % TOTAL_N;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt          <= {CNT_BITS{1'b0}};
            filled       <= 1'b0;
            fill_cnt     <= {CNT_BITS{1'b0}};
            dout_valid   <= 1'b0;
            dout_real    <= 16'd0;
            dout_imag    <= 16'd0;
            twiddle_addr <= 10'd0;
            twiddle_en   <= 1'b0;
        end else if (clk_en) begin
            if (din_valid) begin
                if (!filled) begin
                    if (fill_cnt == DELAY - 1) begin
                        filled     <= 1'b1;
                        cnt        <= {CNT_BITS{1'b0}};
                    end else begin
                        fill_cnt   <= fill_cnt + 1'b1;
                    end
                    dout_valid <= 1'b0;
                end else begin
                    dout_valid <= 1'b1;
                    if (state == 1'b0) begin
                        dout_real <= sum_r_scaled;
                        dout_imag <= sum_i_scaled;
                    end else begin
                        dout_real <= mem_real;
                        dout_imag <= mem_imag;
                    end

                    twiddle_addr <= tw_addr_comb;
                    twiddle_en   <= (tw_addr_comb != 10'd0);

                    if (cnt == TOTAL_PERIOD - 1)
                        cnt <= {CNT_BITS{1'b0}};
                    else
                        cnt <= cnt + 1'b1;
                end
            end else begin
                dout_valid <= 1'b0;
            end
        end
    end

endmodule
