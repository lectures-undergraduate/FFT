`timescale 1ns / 1ps

class fft_monitor extends uvm_monitor;
    `uvm_component_utils(fft_monitor)

    virtual fft_if vif;

    uvm_analysis_port #(fft_frame_item)     in_frame_port;
    uvm_analysis_port #(fft_out_frame_item) out_frame_port;

    function new(string name = "fft_monitor", uvm_component parent = null);
        super.new(name, parent);
        in_frame_port  = new("in_frame_port", this);
        out_frame_port = new("out_frame_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fft_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("FFT_MON", "Could not get virtual interface vif from config_db!")
        end
    endfunction

    task run_phase(uvm_phase phase);
        fork
            monitor_input();
            monitor_output();
        join
    endtask

    // Monitor input stream
    task monitor_input();
        fft_frame_item in_item;
        int in_cnt = 0;

        forever begin
            @(posedge vif.aclk);
            if (vif.aresetn && vif.s_axis_data_tvalid && vif.s_axis_data_tready) begin
                if (in_cnt == 0) begin
                    in_item = fft_frame_item::type_id::create("mon_in_frame");
                end

                in_item.data_real[in_cnt] = vif.s_axis_data_tdata[15:0];
                in_item.data_imag[in_cnt] = vif.s_axis_data_tdata[31:16];

                if (in_cnt == 1023) begin
                    in_frame_port.write(in_item);
                    in_cnt = 0;
                end else begin
                    in_cnt++;
                end
            end
        end
    endtask

    // Monitor output stream
    task monitor_output();
        fft_out_frame_item out_item;
        int out_cnt = 0;

        forever begin
            @(posedge vif.aclk);
            if (vif.aresetn && vif.m_axis_data_tvalid && vif.m_axis_data_tready) begin
                if (out_cnt == 0) begin
                    out_item = fft_out_frame_item::type_id::create("mon_out_frame");
                end

                out_item.out_real[out_cnt] = vif.m_axis_data_tdata[15:0];
                out_item.out_imag[out_cnt] = vif.m_axis_data_tdata[31:16];
                out_item.out_user[out_cnt] = vif.m_axis_data_tuser;

                // Protocol assertions: Check tuser
                if (vif.m_axis_data_tuser != out_cnt) begin
                    `uvm_error("FFT_MON_PROTO", $sformatf("tuser mismatch! Expected %0d, got %0d", 
                               out_cnt, vif.m_axis_data_tuser))
                end

                // Protocol assertions: Check tlast
                if (out_cnt == 1023) begin
                    if (!vif.m_axis_data_tlast) begin
                        `uvm_error("FFT_MON_PROTO", "m_axis_data_tlast NOT asserted on sample 1023!")
                    end else begin
                        out_item.out_last_at_1023 = 1'b1;
                    end
                    out_frame_port.write(out_item);
                    out_cnt = 0;
                end else begin
                    if (vif.m_axis_data_tlast) begin
                        `uvm_error("FFT_MON_PROTO", $sformatf("Unexpected m_axis_data_tlast asserted at sample %0d!", out_cnt))
                    end
                    out_cnt++;
                end
            end
        end
    endtask

endclass
