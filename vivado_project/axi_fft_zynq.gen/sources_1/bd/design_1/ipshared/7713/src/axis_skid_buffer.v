`timescale 1ns / 1ps

// AXI4-Stream Skid Buffer for 100% Throughput and Timing Closure
module axis_skid_buffer #(
    parameter DATA_WIDTH = 32,
    parameter USER_WIDTH = 16
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // Slave Interface (Upstream)
    input  wire                  s_valid,
    output wire                  s_ready,
    input  wire [DATA_WIDTH-1:0] s_data,
    input  wire [USER_WIDTH-1:0] s_user,
    input  wire                  s_last,
    
    // Master Interface (Downstream)
    output reg                   m_valid,
    input  wire                  m_ready,
    output reg  [DATA_WIDTH-1:0] m_data,
    output reg  [USER_WIDTH-1:0] m_user,
    output reg                   m_last
);

    reg [DATA_WIDTH-1:0] buf_data;
    reg [USER_WIDTH-1:0] buf_user;
    reg                  buf_last;
    reg                  buf_valid;

    assign s_ready = !buf_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_valid   <= 1'b0;
            m_data    <= {DATA_WIDTH{1'b0}};
            m_user    <= {USER_WIDTH{1'b0}};
            m_last    <= 1'b0;
            buf_valid <= 1'b0;
            buf_data  <= {DATA_WIDTH{1'b0}};
            buf_user  <= {USER_WIDTH{1'b0}};
            buf_last  <= 1'b0;
        end else begin
            // Downstream handshake completed
            if (m_ready && m_valid) begin
                if (buf_valid) begin
                    m_valid   <= 1'b1;
                    m_data    <= buf_data;
                    m_user    <= buf_user;
                    m_last    <= buf_last;
                    buf_valid <= 1'b0;
                end else if (s_valid) begin
                    m_valid <= 1'b1;
                    m_data  <= s_data;
                    m_user  <= s_user;
                    m_last  <= s_last;
                end else begin
                    m_valid <= 1'b0;
                end
            end else if (!m_valid && s_valid) begin
                m_valid <= 1'b1;
                m_data  <= s_data;
                m_user  <= s_user;
                m_last  <= s_last;
            end else if (!m_ready && s_valid && s_ready) begin
                // Skid into buffer when master is stalled
                buf_valid <= 1'b1;
                buf_data  <= s_data;
                buf_user  <= s_user;
                buf_last  <= s_last;
            end
        end
    end

endmodule
