`timescale 1ns / 1ps

module tb_top;

    import uvm_pkg::*;
    import fft_pkg::*;
    `include "uvm_macros.svh"

    logic aclk;
    logic aresetn;

    // Clock Generation (100 MHz, 10ns period)
    initial begin
        aclk = 1'b0;
        forever #5 aclk = ~aclk;
    end

    // Reset Generation
    initial begin
        aresetn = 1'b0;
        #100;
        @(posedge aclk);
        aresetn = 1'b1;
    end

    // Interface Instance
    fft_if vif (
        .aclk   (aclk),
        .aresetn(aresetn)
    );

    // DUT Instance: Xilinx LogiCORE IP Compatible AXI FFT Top
    axi_fft_top #(
        .N     (1024),
        .LOG2_N(10)
    ) dut (
        .aclk                      (vif.aclk),
        .aresetn                   (vif.aresetn),
        .s_axis_config_tdata       (vif.s_axis_config_tdata),
        .s_axis_config_tvalid      (vif.s_axis_config_tvalid),
        .s_axis_config_tready      (vif.s_axis_config_tready),
        .s_axis_data_tdata         (vif.s_axis_data_tdata),
        .s_axis_data_tvalid        (vif.s_axis_data_tvalid),
        .s_axis_data_tready        (vif.s_axis_data_tready),
        .s_axis_data_tlast         (vif.s_axis_data_tlast),
        .m_axis_data_tdata         (vif.m_axis_data_tdata),
        .m_axis_data_tuser         (vif.m_axis_data_tuser),
        .m_axis_data_tvalid        (vif.m_axis_data_tvalid),
        .m_axis_data_tready        (vif.m_axis_data_tready),
        .m_axis_data_tlast         (vif.m_axis_data_tlast),
        .m_axis_status_tdata       (vif.m_axis_status_tdata),
        .m_axis_status_tvalid      (vif.m_axis_status_tvalid),
        .event_frame_started       (vif.event_frame_started),
        .event_tlast_unexpected    (vif.event_tlast_unexpected),
        .event_tlast_missing       (vif.event_tlast_missing),
        .event_data_in_channel_halt(vif.event_data_in_channel_halt)
    );

    // UVM Testbench Registration & Startup
    initial begin
        uvm_config_db#(virtual fft_if)::set(null, "*", "vif", vif);
        run_test("fft_base_test");
    end

endmodule
