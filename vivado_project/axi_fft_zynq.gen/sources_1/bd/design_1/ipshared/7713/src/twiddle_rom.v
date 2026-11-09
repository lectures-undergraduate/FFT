`timescale 1ns / 1ps

// Twiddle Factor ROM for 1024-Point FFT
// Output format: [31:16] = Imaginary, [15:0] = Real (Q1.15)
module twiddle_rom (
    input  wire        clk,
    input  wire        clk_en,
    input  wire        fwd_inv, // 1: Forward FFT, 0: Inverse FFT
    input  wire [9:0]  addr,
    output reg  [31:0] dout
);

    reg [31:0] rom [0:1023];

    integer rom_i;
    initial begin
        for (rom_i = 0; rom_i < 1024; rom_i = rom_i + 1)
            rom[rom_i] = 32'h00007FFF; // Default cos=1, sin=0

        $readmemh("data/twiddle_1024.hex", rom);
        $readmemh("twiddle_1024.hex", rom);
    end

    wire signed [15:0] raw_real = rom[addr][15:0];
    wire signed [15:0] raw_imag = rom[addr][31:16];

    // For IFFT, conjugate the twiddle factor: (cos, -sin) -> (cos, +sin)
    // -(-sin) = sin. In 2's complement: -raw_imag
    wire signed [15:0] eff_imag = fwd_inv ? raw_imag : (-raw_imag);

    always @(posedge clk) begin
        if (clk_en) begin
            dout <= {eff_imag, raw_real};
        end
    end

endmodule
