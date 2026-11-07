`timescale 1ns / 1ps

typedef uvm_sequencer #(fft_frame_item) fft_sequencer;

class fft_agent extends uvm_agent;
    `uvm_component_utils(fft_agent)

    fft_driver    driver;
    fft_monitor   monitor;
    fft_sequencer sequencer;

    uvm_analysis_port #(fft_frame_item)     in_frame_port;
    uvm_analysis_port #(fft_out_frame_item) out_frame_port;

    function new(string name = "fft_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = fft_monitor::type_id::create("monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            driver    = fft_driver::type_id::create("driver", this);
            sequencer = fft_sequencer::type_id::create("sequencer", this);
        end
        in_frame_port  = new("in_frame_port", this);
        out_frame_port = new("out_frame_port", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
        monitor.in_frame_port.connect(this.in_frame_port);
        monitor.out_frame_port.connect(this.out_frame_port);
    endfunction

endclass
