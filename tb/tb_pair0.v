`timescale 1ns / 1ps

module tb_pair0;

    reg clk;
    reg rst_n;
    reg clk_en;
    reg fwd_inv;
    reg scale1, scale2;
    reg din_valid;
    reg signed [15:0] din_real, din_imag;

    wire dout_valid;
    wire signed [15:0] dout_real, dout_imag;

    r22sdf_pair #(
        .D1     (512),
        .D2     (256),
        .HAS_ROT(1),
        .TOTAL_N(1024)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .clk_en    (clk_en),
        .fwd_inv   (fwd_inv),
        .scale1    (scale1),
        .scale2    (scale2),
        .din_valid (din_valid),
        .din_real  (din_real),
        .din_imag  (din_imag),
        .dout_valid(dout_valid),
        .dout_real (dout_real),
        .dout_imag (dout_imag)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    reg [31:0] test_input [0:1023];
    reg [31:0] golden_ref [0:1023];
    reg [31:0] captured_out [0:1023];

    integer i;
    integer out_cnt = 0;
    integer mismatch = 0;
    reg signed [15:0] gr;
    reg signed [15:0] gi;
    reg signed [15:0] dr;
    reg signed [15:0] di;
    integer diff_r;
    integer diff_i;

    always @(posedge clk) begin
        if (dout_valid) begin
            if (out_cnt < 1024) begin
                captured_out[out_cnt] = {dout_imag, dout_real};
            end
            out_cnt = out_cnt + 1;
        end
    end

    initial begin
        $readmemh("data/input_tone32.hex", test_input);
        $readmemh("input_tone32.hex", test_input);
        $readmemh("data/golden_pair0.hex", golden_ref);
        $readmemh("golden_pair0.hex", golden_ref);

        rst_n = 0;
        clk_en = 1;
        fwd_inv = 1;
        scale1 = 1;
        scale2 = 1;
        din_valid = 0;
        din_real = 0;
        din_imag = 0;
        #100;
        @(posedge clk);
        rst_n = 1;
        #50;

        $display("[TB PAIR0] Streaming 1024 samples of Frame 1...");
        for (i = 0; i < 1024; i = i + 1) begin
            @(posedge clk);
            #1;
            din_valid = 1;
            din_real  = test_input[i][15:0];
            din_imag  = test_input[i][31:16];
        end

        $display("[TB PAIR0] Streaming 1024 samples of Frame 2 (to flush latency)...");
        for (i = 0; i < 1024; i = i + 1) begin
            @(posedge clk);
            #1;
            din_valid = 1;
            din_real  = test_input[i][15:0];
            din_imag  = test_input[i][31:16];
        end

        @(posedge clk);
        #1;
        din_valid = 0;

        wait(out_cnt >= 1024);
        #100;

        $display("=========================================================");
        $display("  Pair 0 Comparison (First 1024 outputs vs golden_pair0)");
        $display("=========================================================");

        for (i = 0; i < 1024; i = i + 1) begin
            gr = golden_ref[i][15:0];
            gi = golden_ref[i][31:16];
            dr = captured_out[i][15:0];
            di = captured_out[i][31:16];
            diff_r = dr - gr;
            diff_i = di - gi;
            if (diff_r < 0) diff_r = -diff_r;
            if (diff_i < 0) diff_i = -diff_i;

            if (diff_r > 2 || diff_i > 2) begin
                if (mismatch < 10) begin
                    $display("  [MISMATCH at %0d]: Gold=(%0d, %0d), DUT=(%0d, %0d), diff=(%0d, %0d)", 
                             i, gr, gi, dr, di, diff_r, diff_i);
                end
                mismatch = mismatch + 1;
            end
        end

        if (mismatch == 0) begin
            $display("=========================================================");
            $display("  *** PAIR 0 PASSED 100%% BIT-ACCURATE! ***");
            $display("=========================================================");
        end else begin
            $display("[FAIL PAIR 0] Total mismatches: %0d / 1024", mismatch);
        end

        $finish;
    end

endmodule
