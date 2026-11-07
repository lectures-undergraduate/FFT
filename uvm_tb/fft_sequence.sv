`timescale 1ns / 1ps

class fft_base_seq extends uvm_sequence #(fft_frame_item);
    `uvm_object_utils(fft_base_seq)

    function new(string name = "fft_base_seq");
        super.new(name);
    endfunction
endclass

class fft_regression_seq extends fft_base_seq;
    `uvm_object_utils(fft_regression_seq)

    function new(string name = "fft_regression_seq");
        super.new(name);
    endfunction

    task body();
        fft_frame_item req;

        // 1. Frame 1: Single Tone at Bin 32
        req = fft_frame_item::type_id::create("frame_tone32");
        start_item(req);
        if (!req.randomize() with { frame_type == TONE; tone_bin1 == 32; }) begin
            `uvm_fatal("FFT_SEQ", "Randomization failed for frame_tone32!")
        end
        finish_item(req);

        // 2. Frame 2: Single Tone at Bin 120 (Continuous back-to-back streaming)
        req = fft_frame_item::type_id::create("frame_tone120");
        start_item(req);
        if (!req.randomize() with { frame_type == TONE; tone_bin1 == 120; }) begin
            `uvm_fatal("FFT_SEQ", "Randomization failed for frame_tone120!")
        end
        finish_item(req);

        // 3. Frame 3: Single Tone at Bin 250
        req = fft_frame_item::type_id::create("frame_tone250");
        start_item(req);
        if (!req.randomize() with { frame_type == TONE; tone_bin1 == 250; }) begin
            `uvm_fatal("FFT_SEQ", "Randomization failed for frame_tone250!")
        end
        finish_item(req);

        // 4. Frame 4 & 5: Flush frames to completely drain the SDF pipeline and Ping-Pong BRAM
        for (int f = 0; f < 2; f++) begin
            req = fft_frame_item::type_id::create($sformatf("flush_frame_%0d", f));
            start_item(req);
            if (!req.randomize() with { frame_type == TONE; tone_bin1 == 32; }) begin
                `uvm_fatal("FFT_SEQ", "Randomization failed for flush frame!")
            end
            finish_item(req);
        end
    endtask

endclass
