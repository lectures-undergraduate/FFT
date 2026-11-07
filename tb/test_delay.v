`timescale 1ns / 1ps

module test_delay;
    reg clk, rst_n, clk_en;
    reg [15:0] din;
    wire [15:0] dout;

    delay_buffer #(
        .DATA_WIDTH(16),
        .DELAY_DEPTH(8)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .clk_en(clk_en),
        .din(din),
        .dout(dout)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0; clk_en = 1; din = 0;
        #20; @(posedge clk); rst_n = 1;
        
        @(posedge clk); din = 16'h1111;
        @(posedge clk); din = 16'h2222;
        @(posedge clk); din = 16'h3333;
        @(posedge clk); din = 16'h4444;
        @(posedge clk); din = 16'h5555;
        @(posedge clk); din = 16'h6666;
        #100;
        $finish;
    end

    always @(posedge clk) begin
        $display("time=%0t: din=0x%04x, dout=0x%04x", $time, din, dout);
    end
endmodule
