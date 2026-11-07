`timescale 1ns / 1ps

class fft_base_test extends uvm_test;
    `uvm_component_utils(fft_base_test)

    fft_env env;

    function new(string name = "fft_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fft_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        fft_regression_seq seq;
        phase.raise_objection(this);

        `uvm_info("FFT_TEST", "Starting FFT UVM Regression Test...", UVM_LOW)
        seq = fft_regression_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);

        // Wait for pipeline drain & scoreboard comparison completion
        #50000ns;

        `uvm_info("FFT_TEST", "FFT UVM Regression Test completed.", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass
