`timescale 1ns / 1ps

`uvm_analysis_imp_decl(_in)
`uvm_analysis_imp_decl(_out)

class fft_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fft_scoreboard)

    uvm_analysis_imp_in  #(fft_frame_item,     fft_scoreboard) in_imp;
    uvm_analysis_imp_out #(fft_out_frame_item, fft_scoreboard) out_imp;

    fft_frame_item     in_queue[$];
    int                frame_count = 0;
    int                pass_count  = 0;
    int                fail_count  = 0;

    function new(string name = "fft_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        in_imp  = new("in_imp", this);
        out_imp = new("out_imp", this);
    endfunction

    function void write_in(fft_frame_item item);
        fft_frame_item item_clone;
        $cast(item_clone, item.clone());
        in_queue.push_back(item_clone);
    endfunction

    // Cooley-Tukey Reference FFT in SystemVerilog
    function void compute_ref_fft(
        input  bit signed [15:0] in_r[1024],
        input  bit signed [15:0] in_i[1024],
        output real              ref_mag[1024],
        output int               peak_bin
    );
        real pi = 3.14159265358979323846;
        real sum_r, sum_i, angle;
        real max_mag = -1.0;
        peak_bin = 0;

        for (int k = 0; k < 1024; k++) begin
            sum_r = 0.0;
            sum_i = 0.0;
            for (int n = 0; n < 1024; n++) begin
                angle = -2.0 * pi * real'(k) * real'(n) / 1024.0;
                sum_r += real'(in_r[n]) * $cos(angle) - real'(in_i[n]) * $sin(angle);
                sum_i += real'(in_r[n]) * $sin(angle) + real'(in_i[n]) * $cos(angle);
            end
            // Scaled by 1/1024 (schedule 0x3FF)
            sum_r /= 1024.0;
            sum_i /= 1024.0;
            ref_mag[k] = $sqrt(sum_r * sum_r + sum_i * sum_i);
            if (ref_mag[k] > max_mag) begin
                max_mag = ref_mag[k];
                peak_bin = k;
            end
        end
    endfunction

    function void write_out(fft_out_frame_item out_item);
        fft_frame_item in_item;
        real ref_mag[1024];
        int  gold_peak_bin;
        real dut_mag[1024];
        real dut_max_mag = -1.0;
        int  dut_peak_bin = 0;
        real signal_pwr = 0.0;
        real noise_pwr = 0.0;
        real sqnr_db;
        int  max_diff_r = 0;
        int  max_diff_i = 0;
        int  bin_mismatches = 0;
        bit  peak_matched;

        if (in_queue.size() == 0) begin
            `uvm_error("FFT_SCB", "Received output frame with no corresponding input frame in queue!")
            return;
        end

        in_item = in_queue.pop_front();
        frame_count++;

        // Compute reference spectrum
        compute_ref_fft(in_item.data_real, in_item.data_imag, ref_mag, gold_peak_bin);

        // Find DUT peak bin and calculate SQNR
        for (int k = 0; k < 1024; k++) begin
            real dr = real'(out_item.out_real[k]);
            real di = real'(out_item.out_imag[k]);
            dut_mag[k] = $sqrt(dr * dr + di * di);

            if (dut_mag[k] > dut_max_mag) begin
                dut_max_mag = dut_mag[k];
                dut_peak_bin = k;
            end

            signal_pwr += ref_mag[k] * ref_mag[k];
            noise_pwr  += (dut_mag[k] - ref_mag[k]) * (dut_mag[k] - ref_mag[k]);
        end

        if (noise_pwr > 1.0e-12)
            sqnr_db = 10.0 * ($ln(signal_pwr / noise_pwr) / $ln(10.0));
        else
            sqnr_db = 99.99;

        // Verify Peak Bin (real signals have symmetric peaks at k and 1024-k)
        peak_matched = (dut_peak_bin == gold_peak_bin) || 
                       (dut_peak_bin == ((1024 - gold_peak_bin) % 1024));

        if (!peak_matched) begin
            `uvm_error("FFT_SCB_PEAK", $sformatf("Peak bin mismatch! Golden=%0d (or %0d), DUT=%0d", 
                       gold_peak_bin, (1024 - gold_peak_bin) % 1024, dut_peak_bin))
            fail_count++;
        end else begin
            pass_count++;
            `uvm_info("FFT_SCB_PASS", $sformatf("Frame %0d Verified: Type=%s, PeakBin=%0d (Golden=%0d), SQNR=%0.2fdB, TLAST=%s",
                      frame_count, in_item.frame_type.name(), dut_peak_bin, gold_peak_bin, sqnr_db,
                      out_item.out_last_at_1023 ? "PASS" : "FAIL"), UVM_LOW)
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("FFT_SCB_SUMMARY", "=========================================================", UVM_LOW)
        `uvm_info("FFT_SCB_SUMMARY", "             UVM SCOREBOARD FINAL REPORT                 ", UVM_LOW)
        `uvm_info("FFT_SCB_SUMMARY", "=========================================================", UVM_LOW)
        `uvm_info("FFT_SCB_SUMMARY", $sformatf("  Total Frames Verified: %0d", frame_count), UVM_LOW)
        `uvm_info("FFT_SCB_SUMMARY", $sformatf("  Passed Frames:         %0d", pass_count), UVM_LOW)
        `uvm_info("FFT_SCB_SUMMARY", $sformatf("  Failed Frames:         %0d", fail_count), UVM_LOW)
        `uvm_info("FFT_SCB_SUMMARY", "=========================================================", UVM_LOW)

        if (fail_count == 0 && frame_count > 0) begin
            `uvm_info("FFT_SCB_SUMMARY", "  *** ALL UVM TESTS PASSED SUCCESSFULLY! ***", UVM_LOW)
        end else begin
            `uvm_error("FFT_SCB_SUMMARY", "  *** UVM VERIFICATION FAILED! ***")
        end
    endfunction

endclass
