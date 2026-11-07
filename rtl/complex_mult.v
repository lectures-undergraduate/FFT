`timescale 1ns / 1ps

// Pipeline Complex Multiplier with Rounding and Saturation
// (Ar + j*Ai) * (Wr + j*Wi) = (Ar*Wr - Ai*Wi) + j*(Ar*Wi + Ai*Wr)
// Output latency: 3 clock cycles
module complex_mult (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        clk_en,
    
    // Inputs (Q1.15)
    input  wire signed [15:0] ar,
    input  wire signed [15:0] ai,
    input  wire signed [15:0] wr,
    input  wire signed [15:0] wi,
    
    // Outputs (Q1.15)
    output reg  signed [15:0] pr,
    output reg  signed [15:0] pi
);

    // Stage 1: Multiplications (Infers DSP48E1 slices)
    reg signed [31:0] p_rr;
    reg signed [31:0] p_ii;
    reg signed [31:0] p_ri;
    reg signed [31:0] p_ir;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p_rr <= 32'd0;
            p_ii <= 32'd0;
            p_ri <= 32'd0;
            p_ir <= 32'd0;
        end else if (clk_en) begin
            p_rr <= ar * wr;
            p_ii <= ai * wi;
            p_ri <= ar * wi;
            p_ir <= ai * wr;
        end
    end

    // Stage 2: Real and Imaginary Accumulations
    reg signed [32:0] sum_real;
    reg signed [32:0] sum_imag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_real <= 33'd0;
            sum_imag <= 33'd0;
        end else if (clk_en) begin
            sum_real <= p_rr - p_ii;
            sum_imag <= p_ri + p_ir;
        end
    end

    // Stage 3: Rounding (+ 0x4000) and Saturation to Q1.15
    // Divide by 2^15 (shift right 15)
    wire signed [32:0] round_real = sum_real + 33'sh00004000;
    wire signed [32:0] round_imag = sum_imag + 33'sh00004000;
    wire signed [17:0] shifted_real = round_real[32:15];
    wire signed [17:0] shifted_imag = round_imag[32:15];

    function signed [15:0] sat16(input signed [17:0] val);
        begin
            if (val > 18'sh07FFF)
                sat16 = 16'sh7FFF;
            else if (val < -18'sh08000)
                sat16 = -16'sh8000;
            else
                sat16 = val[15:0];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pr <= 16'd0;
            pi <= 16'd0;
        end else if (clk_en) begin
            pr <= sat16(shifted_real);
            pi <= sat16(shifted_imag);
        end
    end

endmodule
