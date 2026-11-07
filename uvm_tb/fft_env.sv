`timescale 1ns / 1ps

class fft_env extends uvm_env;
    `uvm_component_utils(fft_env)

    fft_agent      agent;
    fft_scoreboard scoreboard;

    function new(string name = "fft_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = fft_agent::type_id::create("agent", this);
        scoreboard = fft_scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.in_frame_port.connect(scoreboard.in_imp);
        agent.out_frame_port.connect(scoreboard.out_imp);
    endfunction

endclass
