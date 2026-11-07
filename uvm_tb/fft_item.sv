`timescale 1ns / 1ps

class fft_config_item extends uvm_sequence_item;
    rand bit       fwd_inv;     // 1: Forward FFT, 0: IFFT
    rand bit [9:0] scale_sch;   // Scaling schedule for 10 stages

    constraint c_default {
        fwd_inv   == 1'b1;
        scale_sch == 10'h3FF;
    }

    `uvm_object_utils_begin(fft_config_item)
        `uvm_field_int(fwd_inv,   UVM_ALL_ON)
        `uvm_field_int(scale_sch, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fft_config_item");
        super.new(name);
        fwd_inv   = 1'b1;
        scale_sch = 10'h3FF;
    endfunction
endclass

typedef enum { TONE, DUAL_TONE, IMPULSE, RANDOM_NOISE } frame_type_e;

class fft_frame_item extends uvm_sequence_item;
    rand frame_type_e frame_type;
    rand int tone_bin1;
    rand int tone_bin2;
    rand bit signed [15:0] data_real[1024];
    rand bit signed [15:0] data_imag[1024];

    constraint c_bins {
        tone_bin1 inside {[1:511]};
        tone_bin2 inside {[1:511]};
        tone_bin1 != tone_bin2;
    }

    `uvm_object_utils_begin(fft_frame_item)
        `uvm_field_enum(frame_type_e, frame_type, UVM_ALL_ON)
        `uvm_field_int(tone_bin1, UVM_ALL_ON)
        `uvm_field_int(tone_bin2, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fft_frame_item");
        super.new(name);
        frame_type = TONE;
        tone_bin1  = 32;
        tone_bin2  = 64;
    endfunction

    function void generate_waveform();
        real pi = 3.14159265358979323846;
        real phase, val;
        case (frame_type)
            TONE: begin
                for (int i = 0; i < 1024; i++) begin
                    phase = 2.0 * pi * real'(tone_bin1) * real'(i) / 1024.0;
                    val = 0.8 * $cos(phase) * 32767.0;
                    data_real[i] = shortint'(val);
                    data_imag[i] = 16'd0;
                end
            end
            DUAL_TONE: begin
                for (int i = 0; i < 1024; i++) begin
                    real p1 = 2.0 * pi * real'(tone_bin1) * real'(i) / 1024.0;
                    real p2 = 2.0 * pi * real'(tone_bin2) * real'(i) / 1024.0;
                    val = (0.4 * $cos(p1) + 0.4 * $cos(p2)) * 32767.0;
                    data_real[i] = shortint'(val);
                    data_imag[i] = 16'd0;
                end
            end
            IMPULSE: begin
                for (int i = 0; i < 1024; i++) begin
                    data_real[i] = (i == 0) ? 16'sh7FFF : 16'sh0000;
                    data_imag[i] = 16'sh0000;
                end
            end
            RANDOM_NOISE: begin
                for (int i = 0; i < 1024; i++) begin
                    data_real[i] = shortint'($urandom_range(0, 16383) - 8192);
                    data_imag[i] = shortint'($urandom_range(0, 16383) - 8192);
                end
            end
        endcase
    endfunction

    function void do_copy(uvm_object rhs);
        fft_frame_item rhs_;
        if (!$cast(rhs_, rhs)) return;
        super.do_copy(rhs);
        this.frame_type = rhs_.frame_type;
        this.tone_bin1  = rhs_.tone_bin1;
        this.tone_bin2  = rhs_.tone_bin2;
        this.data_real  = rhs_.data_real;
        this.data_imag  = rhs_.data_imag;
    endfunction

    function void post_randomize();
        generate_waveform();
    endfunction
endclass

class fft_out_frame_item extends uvm_sequence_item;
    bit signed [15:0] out_real[1024];
    bit signed [15:0] out_imag[1024];
    bit [15:0]        out_user[1024];
    bit               out_last_at_1023;

    `uvm_object_utils_begin(fft_out_frame_item)
        `uvm_field_int(out_last_at_1023, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fft_out_frame_item");
        super.new(name);
        out_last_at_1023 = 1'b0;
    endfunction
endclass
