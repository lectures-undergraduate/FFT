`timescale 1ns / 1ps

// Xilinx LogiCORE IP Fast Fourier Transform (v9.x) Compatible AXI Top
// Architecture: Radix-2^2 Single-path Delay Feedback (R2^2SDF)
// Pipelined Streaming I/O, 100% Continuous Throughput
module axi_fft_top #(
    parameter N = 1024,
    parameter LOG2_N = 10
)(
    input  wire                  aclk,
    input  wire                  aresetn,

    // AXI4-Stream Config Channel (Slave)
    input  wire [15:0]           s_axis_config_tdata,
    input  wire                  s_axis_config_tvalid,
    output reg                   s_axis_config_tready,

    // AXI4-Stream Data Input Channel (Slave)
    input  wire [31:0]           s_axis_data_tdata,
    input  wire                  s_axis_data_tvalid,
    output wire                  s_axis_data_tready,
    input  wire                  s_axis_data_tlast,

    // AXI4-Stream Data Output Channel (Master)
    output wire [31:0]           m_axis_data_tdata,
    output wire [15:0]           m_axis_data_tuser,   // xk_index (0..1023)
    output wire                  m_axis_data_tvalid,
    input  wire                  m_axis_data_tready,
    output wire                  m_axis_data_tlast,

    // AXI4-Stream Status Channel (Master)
    output reg  [7:0]            m_axis_status_tdata,
    output reg                   m_axis_status_tvalid,

    // Event Flags (Xilinx FFT IP Compatible)
    output reg                   event_frame_started,
    output reg                   event_tlast_unexpected,
    output reg                   event_tlast_missing,
    output reg                   event_data_in_channel_halt
);

    // Configuration Registers (Default: Forward FFT, full scaling schedule 0x3FF)
    reg        cfg_fwd_inv;
    reg [9:0]  cfg_scale_sch;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            cfg_fwd_inv          <= 1'b1;  // Forward FFT default
            cfg_scale_sch        <= 10'h3FF; // Scale 1/2 at each stage default
            s_axis_config_tready <= 1'b1;
        end else begin
            s_axis_config_tready <= 1'b1;
            if (s_axis_config_tvalid && s_axis_config_tready) begin
                cfg_fwd_inv   <= s_axis_config_tdata[0];
                cfg_scale_sch <= s_axis_config_tdata[10:1];
            end
        end
    end

    // Pipeline Clock Enable / Stall Control
    // The core progresses whenever the output skid buffer is ready to accept or not stalled
    wire out_skid_ready;
    wire pipeline_en = out_skid_ready;

    // Upstream AXI-Stream Input Handshake
    assign s_axis_data_tready = pipeline_en;
    wire in_fire = s_axis_data_tvalid && s_axis_data_tready;

    // Frame sample counter & Event Generation
    reg [LOG2_N-1:0] in_sample_cnt;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            in_sample_cnt              <= {LOG2_N{1'b0}};
            event_frame_started        <= 1'b0;
            event_tlast_unexpected     <= 1'b0;
            event_tlast_missing        <= 1'b0;
            event_data_in_channel_halt <= 1'b0;
            m_axis_status_tvalid       <= 1'b0;
            m_axis_status_tdata        <= 8'd0;
        end else begin
            event_frame_started        <= 1'b0;
            event_tlast_unexpected     <= 1'b0;
            event_tlast_missing        <= 1'b0;
            event_data_in_channel_halt <= s_axis_data_tvalid && !s_axis_data_tready;
            m_axis_status_tvalid       <= 1'b0;

            if (in_fire) begin
                if (in_sample_cnt == 0)
                    event_frame_started <= 1'b1;

                if (in_sample_cnt < (N - 1)) begin
                    if (s_axis_data_tlast)
                        event_tlast_unexpected <= 1'b1;
                    in_sample_cnt <= in_sample_cnt + 1'b1;
                end else begin
                    // 1023th sample
                    if (!s_axis_data_tlast)
                        event_tlast_missing <= 1'b1;
                    in_sample_cnt <= {LOG2_N{1'b0}};
                    m_axis_status_tdata  <= 8'h00; // No overflow
                    m_axis_status_tvalid <= 1'b1;
                end
            end
        end
    end

    // Unpack 32-bit input: [31:16] Imag, [15:0] Real
    wire signed [15:0] din_real = s_axis_data_tdata[15:0];
    wire signed [15:0] din_imag = s_axis_data_tdata[31:16];

    // R2^2SDF Core Instance
    wire        core_valid;
    wire [15:0] core_real;
    wire [15:0] core_imag;

    r22sdf_core u_r22sdf_core (
        .clk       (aclk),
        .rst_n     (aresetn),
        .clk_en    (pipeline_en),
        .fwd_inv   (cfg_fwd_inv),
        .scale_sch (cfg_scale_sch),
        .din_valid (in_fire),
        .din_real  (din_real),
        .din_imag  (din_imag),
        .dout_valid(core_valid),
        .dout_real (core_real),
        .dout_imag (core_imag)
    );

    // Ping-Pong Bit-Reversal Buffer
    wire        rev_valid;
    wire [31:0] rev_data;
    wire [9:0]  rev_user;
    wire        rev_last;

    bit_reverse_buffer #(
        .DATA_WIDTH(32),
        .N         (N),
        .LOG2_N    (LOG2_N)
    ) u_bit_reverse (
        .clk       (aclk),
        .rst_n     (aresetn),
        .clk_en    (pipeline_en),
        .core_valid(core_valid),
        .core_data ({core_imag, core_real}),
        .out_valid (rev_valid),
        .out_data  (rev_data),
        .out_user  (rev_user),
        .out_last  (rev_last)
    );

    // Master Output Skid Buffer (Full throughput & zero bubble handshake)
    wire [15:0] ext_user = {6'd0, rev_user};

    axis_skid_buffer #(
        .DATA_WIDTH(32),
        .USER_WIDTH(16)
    ) u_out_skid (
        .clk    (aclk),
        .rst_n  (aresetn),
        .s_valid(rev_valid),
        .s_ready(out_skid_ready),
        .s_data (rev_data),
        .s_user (ext_user),
        .s_last (rev_last),
        .m_valid(m_axis_data_tvalid),
        .m_ready(m_axis_data_tready),
        .m_data (m_axis_data_tdata),
        .m_user (m_axis_data_tuser),
        .m_last (m_axis_data_tlast)
    );

endmodule
