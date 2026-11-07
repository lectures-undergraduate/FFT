`timescale 1ns / 1ps

class fft_driver extends uvm_driver #(fft_frame_item);
    `uvm_component_utils(fft_driver)

    virtual fft_if vif;

    function new(string name = "fft_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fft_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("FFT_DRV", "Could not get virtual interface vif from config_db!")
        end
    endfunction

    task run_phase(uvm_phase phase);
        // Default bus state
        vif.s_axis_config_tvalid <= 1'b0;
        vif.s_axis_config_tdata  <= 16'd0;
        vif.s_axis_data_tvalid   <= 1'b0;
        vif.s_axis_data_tdata    <= 32'd0;
        vif.s_axis_data_tlast    <= 1'b0;
        vif.m_axis_data_tready   <= 1'b1; // Default DMA always ready

        // Wait for reset release
        wait(vif.aresetn === 1'b1);
        @(posedge vif.aclk);

        // Send default configuration
        send_config(1'b1, 10'h3FF);

        // Main driver loop
        forever begin
            seq_item_port.get_next_item(req);
            drive_frame(req);
            seq_item_port.item_done();
        end
    endtask

    task send_config(bit fwd_inv, bit [9:0] scale_sch);
        @(posedge vif.aclk);
        #1ns;
        vif.s_axis_config_tdata  <= {5'd0, scale_sch, fwd_inv};
        vif.s_axis_config_tvalid <= 1'b1;
        @(posedge vif.aclk);
        while (!vif.s_axis_config_tready) @(posedge vif.aclk);
        #1ns;
        vif.s_axis_config_tvalid <= 1'b0;
        repeat(5) @(posedge vif.aclk);
    endtask

    task drive_frame(fft_frame_item item);
        `uvm_info("FFT_DRV", $sformatf("Driving frame type: %s (tone1=%0d, tone2=%0d)", 
                  item.frame_type.name(), item.tone_bin1, item.tone_bin2), UVM_MEDIUM)

        for (int i = 0; i < 1024; i++) begin
            @(posedge vif.aclk);
            #1ns;
            vif.s_axis_data_tvalid <= 1'b1;
            vif.s_axis_data_tdata  <= {item.data_imag[i], item.data_real[i]};
            vif.s_axis_data_tlast  <= (i == 1023);

            // Wait for handshake if core backpressures
            while (!vif.s_axis_data_tready) @(posedge vif.aclk);
        end

        // Do not insert bubble if next frame is immediately available,
        // but if no item, hold valid low.
        @(posedge vif.aclk);
        #1ns;
        vif.s_axis_data_tvalid <= 1'b0;
        vif.s_axis_data_tlast  <= 1'b0;
    endtask

endclass
