`timescale 1ns / 1ps

interface fft_if (
    input logic aclk,
    input logic aresetn
);

    parameter N = 1024;
    parameter LOG2_N = 10;

    // Config Channel (Slave)
    logic [15:0] s_axis_config_tdata;
    logic        s_axis_config_tvalid;
    logic        s_axis_config_tready;

    // Data Input Channel (Slave)
    logic [31:0] s_axis_data_tdata;
    logic        s_axis_data_tvalid;
    logic        s_axis_data_tready;
    logic        s_axis_data_tlast;

    // Data Output Channel (Master)
    logic [31:0] m_axis_data_tdata;
    logic [15:0] m_axis_data_tuser;
    logic        m_axis_data_tvalid;
    logic        m_axis_data_tready;
    logic        m_axis_data_tlast;

    // Status Channel (Master)
    logic [7:0]  m_axis_status_tdata;
    logic        m_axis_status_tvalid;

    // Event Flags
    logic        event_frame_started;
    logic        event_tlast_unexpected;
    logic        event_tlast_missing;
    logic        event_data_in_channel_halt;

    // Driver Clocking Block
    clocking drv_cb @(posedge aclk);
        default input #1step output #1ns;
        output s_axis_config_tdata, s_axis_config_tvalid;
        input  s_axis_config_tready;
        output s_axis_data_tdata, s_axis_data_tvalid, s_axis_data_tlast;
        input  s_axis_data_tready;
        output m_axis_data_tready;
    endclocking

    // Monitor Clocking Block
    clocking mon_cb @(posedge aclk);
        default input #1step;
        input s_axis_config_tdata, s_axis_config_tvalid, s_axis_config_tready;
        input s_axis_data_tdata, s_axis_data_tvalid, s_axis_data_tready, s_axis_data_tlast;
        input m_axis_data_tdata, m_axis_data_tuser, m_axis_data_tvalid, m_axis_data_tready, m_axis_data_tlast;
        input m_axis_status_tdata, m_axis_status_tvalid;
        input event_frame_started, event_tlast_unexpected, event_tlast_missing, event_data_in_channel_halt;
    endclocking

    modport DRV (clocking drv_cb, input aclk, input aresetn);
    modport MON (clocking mon_cb, input aclk, input aresetn);

endinterface
