`timescale 1ns / 1ps

// Ping-Pong Bit-Reversal Buffer for Continuous 100% Throughput
// Reorders Bit-reversed output from R2^2SDF Core into Natural Order (k = 0..1023)
// Generates xk_index (tuser) and frame boundary (tlast) for AXI DMA S2MM.
module bit_reverse_buffer #(
    parameter DATA_WIDTH = 32, // 16-bit Imag + 16-bit Real
    parameter N          = 1024,
    parameter LOG2_N     = 10
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  clk_en,
    
    // Core input (Bit-reversed stream)
    input  wire                  core_valid,
    input  wire [DATA_WIDTH-1:0] core_data,
    
    // Natural Order Stream Output (AXI Compatible)
    output reg                   out_valid,
    output reg  [DATA_WIDTH-1:0] out_data,
    output reg  [LOG2_N-1:0]     out_user,  // xk_index (0..1023)
    output reg                   out_last   // tlast on index 1023
);

    // Bit reversal function
    function [LOG2_N-1:0] bit_rev(input [LOG2_N-1:0] in);
        integer j;
        begin
            for (j = 0; j < LOG2_N; j = j + 1)
                bit_rev[j] = in[LOG2_N - 1 - j];
        end
    endfunction

    // Two memory banks (Ping-Pong BRAM)
    reg [DATA_WIDTH-1:0] ram_bank0 [0:N-1];
    reg [DATA_WIDTH-1:0] ram_bank1 [0:N-1];

    integer mem_init_i;
    initial begin
        for (mem_init_i = 0; mem_init_i < N; mem_init_i = mem_init_i + 1) begin
            ram_bank0[mem_init_i] = {DATA_WIDTH{1'b0}};
            ram_bank1[mem_init_i] = {DATA_WIDTH{1'b0}};
        end
    end

    // Bank toggle and write counter
    reg [LOG2_N-1:0] wr_cnt;
    reg              active_wr_bank;
    reg              first_frame_buffered;

    // Read counter
    reg [LOG2_N-1:0] rd_cnt;
    reg              active_rd_bank;
    reg              rd_en;

    // Write logic
    wire [LOG2_N-1:0] wr_addr = bit_rev(wr_cnt);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_cnt               <= {LOG2_N{1'b0}};
            active_wr_bank       <= 1'b0;
            first_frame_buffered <= 1'b0;
        end else if (clk_en) begin
            if (core_valid) begin
                if (active_wr_bank == 1'b0)
                    ram_bank0[wr_addr] <= core_data;
                else
                    ram_bank1[wr_addr] <= core_data;

                if (wr_cnt == N - 1) begin
                    wr_cnt               <= {LOG2_N{1'b0}};
                    active_wr_bank       <= ~active_wr_bank;
                    first_frame_buffered <= 1'b1;
                end else begin
                    wr_cnt <= wr_cnt + 1'b1;
                end
            end
        end
    end

    // Read logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_cnt         <= {LOG2_N{1'b0}};
            active_rd_bank <= 1'b0;
            rd_en          <= 1'b0;
        end else if (clk_en) begin
            if (core_valid && (wr_cnt == N - 1)) begin
                rd_en          <= 1'b1;
                rd_cnt         <= {LOG2_N{1'b0}};
                active_rd_bank <= active_wr_bank; // Read the bank that just completed writing
            end else if (rd_en) begin
                if (rd_cnt == N - 1) begin
                    rd_cnt <= {LOG2_N{1'b0}};
                    // If no new frame arrived, hold off reading
                    if (!(core_valid && (wr_cnt == N - 1)))
                        rd_en <= 1'b0;
                    else
                        active_rd_bank <= active_wr_bank;
                end else begin
                    rd_cnt <= rd_cnt + 1'b1;
                end
            end
        end
    end

    // Synchronous Read output register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_data  <= {DATA_WIDTH{1'b0}};
            out_user  <= {LOG2_N{1'b0}};
            out_last  <= 1'b0;
        end else if (clk_en) begin
            out_valid <= rd_en;
            if (rd_en) begin
                out_data <= (active_rd_bank == 1'b0) ? ram_bank0[rd_cnt] : ram_bank1[rd_cnt];
                out_user <= rd_cnt;
                out_last <= (rd_cnt == N - 1);
            end else begin
                out_last <= 1'b0;
            end
        end
    end

endmodule
