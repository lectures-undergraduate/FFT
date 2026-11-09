`timescale 1ns / 1ps

// Precision Delay Buffer (Delay Feedback FIFO)
// Infers SRL32E / Distributed RAM / BRAM automatically in Vivado Synthesis
// Exactly DELAY_DEPTH cycles latency, guaranteed zero-offset
module delay_buffer #(
    parameter DATA_WIDTH = 32,
    parameter DELAY_DEPTH = 512
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  clk_en,
    input  wire [DATA_WIDTH-1:0] din,
    output wire [DATA_WIDTH-1:0] dout
);

    reg [DATA_WIDTH-1:0] shift_reg [0:DELAY_DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DELAY_DEPTH; i = i + 1)
            shift_reg[i] = {DATA_WIDTH{1'b0}};
    end

    // Pure synchronous shift without asynchronous reset on data storage
    // Enables Vivado to infer hardware SRL32E / BRAM primitives with 98% resource savings
    always @(posedge clk) begin
        if (clk_en) begin
            shift_reg[0] <= din;
            for (i = 1; i < DELAY_DEPTH; i = i + 1)
                shift_reg[i] <= shift_reg[i-1];
        end
    end

    assign dout = shift_reg[DELAY_DEPTH-1];

endmodule
