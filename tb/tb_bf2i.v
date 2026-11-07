`timescale 1ns / 1ps

module tb_bf2i;

    reg clk;
    reg rst_n;
    reg clk_en;
    reg scale;
    reg din_valid;
    reg signed [15:0] din_real, din_imag;

    wire dout_valid;
    wire signed [15:0] dout_real, dout_imag;

    r22sdf_bf2i #(
        .DELAY(512)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .clk_en    (clk_en),
        .scale     (scale),
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
    reg [31:0] captured_out [0:1023];

    integer i;
    integer out_cnt = 0;
    integer mismatch = 0;
    reg signed [15:0] u_r, v_r, gold_sum, gold_diff, dut_val;

    always @(posedge clk) begin
        if (dout_valid) begin
            if (out_cnt < 1024) begin
                captured_out[out_cnt] = {dout_imag, dout_real};
            end
            out_cnt = out_cnt + 1;
        end
    end

    initial begin
        $readmemh("input_tone32.hex", test_input);

        rst_n = 0;
        clk_en = 1;
        scale = 1;
        din_valid = 0;
        din_real = 0;
        din_imag = 0;
        #100;
        @(posedge clk);
        rst_n = 1;
        #50;

        $display("[TB BF2I] Streaming 2048 samples continuously (100% throughput)...");
        for (i = 0; i < 2048; i = i + 1) begin
            @(posedge clk);
            #1;
            din_valid = 1;
            din_real  = test_input[i % 1024][15:0];
            din_imag  = test_input[i % 1024][31:16];
        end

        @(posedge clk);
        #1;
        din_valid = 0;

        wait(out_cnt >= 1024);
        #100;

        $display("=========================================================");
        $display("  BF2I Comparison against Hand-calculated Golden");
        $display("=========================================================");

        // Golden for BF2I:
        // For i = 0..511: sum = (in[i] + in[i+512] + 1) >>> 1
        // For i = 512..1023: diff = (in[i-512] - in[i] + 1) >>> 1
        $display("captured_out[509]=%0d, [510]=%0d, [511]=%0d, [512]=%0d, [513]=%0d", 
                 captured_out[509][15:0], captured_out[510][15:0], captured_out[511][15:0], captured_out[512][15:0], captured_out[513][15:0]);
        $display("gold_sum[510]=%0d, gold_sum[511]=%0d, gold_diff[0]=%0d, gold_diff[1]=%0d",
                 (test_input[510][15:0] + test_input[1022][15:0] + 1) >>> 1,
                 (test_input[511][15:0] + test_input[1023][15:0] + 1) >>> 1,
                 (test_input[0][15:0] - test_input[512][15:0] + 1) >>> 1,
                 (test_input[1][15:0] - test_input[513][15:0] + 1) >>> 1);

        for (i = 0; i < 512; i = i + 1) begin
            u_r = $signed(test_input[i][15:0]);
            v_r = $signed(test_input[i + 512][15:0]);
            gold_sum = (u_r + v_r + 1) >>> 1;
            dut_val = captured_out[i][15:0];
            if (dut_val !== gold_sum) begin
                if (mismatch < 5)
                    $display("  [SUM MISMATCH at %0d]: Expected %0d, Got %0d", i, gold_sum, dut_val);
                mismatch = mismatch + 1;
            end
        end

        $display("captured_out[509]=%0d, [510]=%0d, [511]=%0d, [512]=%0d, [513]=%0d", 
                 captured_out[509][15:0], captured_out[510][15:0], captured_out[511][15:0], captured_out[512][15:0], captured_out[513][15:0]);
        $display("gold_sum[510]=%0d, gold_sum[511]=%0d, gold_diff[0]=%0d, gold_diff[1]=%0d",
                 (test_input[510][15:0] + test_input[1022][15:0] + 1) >>> 1,
                 (test_input[511][15:0] + test_input[1023][15:0] + 1) >>> 1,
                 (test_input[0][15:0] - test_input[512][15:0] + 1) >>> 1,
                 (test_input[1][15:0] - test_input[513][15:0] + 1) >>> 1);

        for (i = 0; i < 512; i = i + 1) begin
            u_r = $signed(test_input[i][15:0]);
            v_r = $signed(test_input[i + 512][15:0]);
            gold_diff = (u_r - v_r + 1) >>> 1;
            dut_val = captured_out[512 + i][15:0];
            if (dut_val !== gold_diff) begin
                if (mismatch < 10)
                    $display("  [DIFF MISMATCH at %0d]: Expected %0d, Got %0d", 512 + i, gold_diff, dut_val);
                mismatch = mismatch + 1;
            end
        end

        if (mismatch == 0) begin
            $display("=========================================================");
            $display("  *** BF2I 100%% BIT-ACCURATE MATCH! ***");
            $display("=========================================================");
        end else begin
            $display("[FAIL BF2I] Total mismatches: %0d / 1024", mismatch);
        end

        $finish;
    end

endmodule
