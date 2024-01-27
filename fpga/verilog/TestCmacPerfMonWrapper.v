
`timescale 1ps / 1ps

module TestCmacPerfMonWrapper();

    localparam PCIE_GT_LANE_WIDTH = 16;
    localparam CMAC_GT_LANE_WIDTH = 4;
    localparam XDMA_AXIS_TDATA_WIDTH = 512;
    localparam XDMA_AXIS_TKEEP_WIDTH = 64;
    localparam XDMA_AXIS_TUSER_WIDTH = 1;

    localparam TOTAL_CYCLE = 32'd5000;
    localparam PKT_SIZE = 32'd32;
    localparam INTERVAL_NUM = 32'd0;

    wire [CMAC_GT_LANE_WIDTH - 1 : 0] qsfp_txn, qsfp_txp, qsfp_rxn, qsfp_rxp;
    reg qsfp_ref_clk_p, qsfp_ref_clk_n;
    
    reg xdma_axi_aclk;
    reg xdma_axi_aresetn;
    
    wire clk_wiz_locked;
    wire udp_clk, udp_reset;
    wire cmac_init_clk, cmac_sys_reset;

    wire udp_rx_axis_tready;
    wire udp_rx_axis_tvalid;
    wire udp_rx_axis_tlast;
    wire [XDMA_AXIS_TDATA_WIDTH - 1 : 0] udp_rx_axis_tdata;
    wire [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] udp_rx_axis_tkeep;
    wire [XDMA_AXIS_TUSER_WIDTH - 1 : 0] udp_rx_axis_tuser;

    wire udp_tx_axis_tvalid;
    wire udp_tx_axis_tready;
    wire udp_tx_axis_tlast;
    wire [XDMA_AXIS_TDATA_WIDTH - 1 : 0] udp_tx_axis_tdata;
    wire [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] udp_tx_axis_tkeep;
    wire [XDMA_AXIS_TUSER_WIDTH - 1 : 0] udp_tx_axis_tuser;

    wire xdma_rx_axis_tready;
    wire xdma_rx_axis_tvalid;
    wire xdma_rx_axis_tlast;
    wire [XDMA_AXIS_TDATA_WIDTH - 1 : 0] xdma_rx_axis_tdata;
    wire [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] xdma_rx_axis_tkeep;
    wire [XDMA_AXIS_TUSER_WIDTH - 1 : 0] xdma_rx_axis_tuser;

    wire xdma_tx_axis_tvalid;
    wire xdma_tx_axis_tready;
    wire xdma_tx_axis_tlast;
    wire [XDMA_AXIS_TDATA_WIDTH - 1 : 0] xdma_tx_axis_tdata;
    wire [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] xdma_tx_axis_tkeep;
    wire [XDMA_AXIS_TUSER_WIDTH - 1 : 0] xdma_tx_axis_tuser;

    // Perfamance Counter
    wire [15:0] pkt_size_reg;
    wire [31:0] pkt_interval_reg;
    wire [31:0] perf_cycle_count_reg_tx;
    wire [31:0] perf_cycle_count_reg_rx;
    wire [31:0] perf_beat_count_reg_tx;
    wire [31:0] perf_beat_count_reg_rx;
    wire [0:0] perf_cycle_count_full_reg_tx;
    wire [0:0] perf_cycle_count_full_reg_rx;
    wire [0:0] send_pkt_enable_reg;
    wire [0:0] recv_pkt_enable_reg;
    wire [0:0] is_recv_first_pkt_reg;
    wire [31:0] send_pkt_num_count_reg;
    wire [31:0] recv_pkt_num_count_reg;
    wire [31:0] err_pkt_num_count_reg;
    wire [31:0] total_beat_count_reg_tx;
    wire [31:0] total_beat_count_reg_rx;
    
    wire udp_tx_axis_tvalid_piped;
    wire udp_tx_axis_tready_piped;
    wire udp_tx_axis_tlast_piped;
    wire [XDMA_AXIS_TDATA_WIDTH - 1 : 0] udp_tx_axis_tdata_piped;
    wire [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] udp_tx_axis_tkeep_piped;
    wire [XDMA_AXIS_TUSER_WIDTH - 1 : 0] udp_tx_axis_tuser_piped;


    initial begin
        qsfp_ref_clk_p = 1;
        forever #3103 qsfp_ref_clk_p = ~ qsfp_ref_clk_p;
    end
    
    initial begin
        qsfp_ref_clk_n = 0;
        forever #3103 qsfp_ref_clk_n = ~ qsfp_ref_clk_n;
    end

    initial begin
        xdma_axi_aclk = 0;
        forever #2000 xdma_axi_aclk = ~ xdma_axi_aclk;
    end
    
    initial begin
        xdma_axi_aresetn = 0;
        #(100*4000) xdma_axi_aresetn = 1;
    end

    reg is_monitor_config;
    assign xdma_tx_axis_tvalid = !is_monitor_config & xdma_axi_aresetn;
    assign xdma_tx_axis_tdata = {0, TOTAL_CYCLE, INTERVAL_NUM, PKT_SIZE};
    assign xdma_tx_axis_tkeep = 64'hFFFF_FFFF_FFFF_FFFF;
    assign xdma_tx_axis_tlast = 1'b1;
    assign xdma_tx_axis_tuser = 0;
    assign xdma_rx_axis_tready = 1'b1;
    always @(posedge xdma_axi_aclk) begin
        if (!xdma_axi_aresetn) begin
            is_monitor_config <= 1'b0;
        end
        else if (xdma_tx_axis_tvalid & xdma_tx_axis_tready) begin
            is_monitor_config <= 1'b1;
        end

        if (xdma_axi_aresetn) begin
            if ((recv_pkt_num_count_reg != 0)) begin
                if (recv_pkt_num_count_reg == send_pkt_num_count_reg) begin
                    $finish;
                end
            end
        end
    end 

    mkXdmaUdpCmacPerfMonitor perfMonInst(
        .CLK   (xdma_axi_aclk   ),
        .RST_N (xdma_axi_aresetn),
        .xdma_tx_axis_tvalid(xdma_tx_axis_tvalid),
        .xdma_tx_axis_tdata (xdma_tx_axis_tdata ),
        .xdma_tx_axis_tkeep (xdma_tx_axis_tkeep ),
        .xdma_tx_axis_tlast (xdma_tx_axis_tlast ),
        .xdma_tx_axis_tuser (xdma_tx_axis_tuser ),
        .xdma_tx_axis_tready(xdma_tx_axis_tready),

        .xdma_rx_axis_tvalid(xdma_rx_axis_tvalid),
        .xdma_rx_axis_tdata (xdma_rx_axis_tdata ),
        .xdma_rx_axis_tkeep (xdma_rx_axis_tkeep ),
        .xdma_rx_axis_tlast (xdma_rx_axis_tlast ),
        .xdma_rx_axis_tuser (xdma_rx_axis_tuser ),
        .xdma_rx_axis_tready(xdma_rx_axis_tready),

        .udp_rx_axis_tvalid (udp_rx_axis_tvalid),
        .udp_rx_axis_tdata  (udp_rx_axis_tdata ),
        .udp_rx_axis_tkeep  (udp_rx_axis_tkeep ),
        .udp_rx_axis_tlast  (udp_rx_axis_tlast ),
        .udp_rx_axis_tuser  (udp_rx_axis_tuser ),
        .udp_rx_axis_tready (udp_rx_axis_tready),

        .udp_tx_axis_tvalid (udp_tx_axis_tvalid),
        .udp_tx_axis_tdata  (udp_tx_axis_tdata ),
        .udp_tx_axis_tkeep  (udp_tx_axis_tkeep ),
        .udp_tx_axis_tlast  (udp_tx_axis_tlast ),
        .udp_tx_axis_tuser  (udp_tx_axis_tuser ),
        .udp_tx_axis_tready (udp_tx_axis_tready),

        .pktSizeOut             (pkt_size_reg),
        .pktIntervalOut         (pkt_interval_reg),
        .perfCycleCounterTxOut  (perf_cycle_count_reg_tx),
        .perfCycleCounterRxOut  (perf_cycle_count_reg_rx),
        .perfBeatCounterTxOut   (perf_beat_count_reg_tx ),
        .perfBeatCounterRxOut   (perf_beat_count_reg_rx ),
        .totalBeatCounterTxOut  (total_beat_count_reg_tx),
        .totalBeatCounterRxOut  (total_beat_count_reg_rx),
        .perfCycleCountFullTxOut(perf_cycle_count_full_reg_tx),
        .perfCycleCountFullRxOut(perf_cycle_count_full_reg_rx),
        .sendPktEnableOut       (send_pkt_enable_reg),
        .recvPktEnableOut       (recv_pkt_enable_reg),
        .isRecvFirstPktOut      (is_recv_first_pkt_reg),
        .sendPktNumCounterOut   (send_pkt_num_count_reg),
        .recvPktNumCounterOut   (recv_pkt_num_count_reg),
        .errPktNumCounterOut    (err_pkt_num_count_reg)
    );


    ila_0 perf_counter_ila (
        .clk   (xdma_axi_aclk),  // input wire clk
        .probe0(pkt_size_reg),  // input wire [15:0]  probe0  
        .probe1(perf_cycle_count_reg_tx), // input wire [31:0]  probe1 
        .probe2(perf_cycle_count_reg_rx), // input wire [31:0]  probe2 
        .probe3(perf_beat_count_reg_tx ), // input wire [31:0]  probe3 
        .probe4(perf_beat_count_reg_rx ), // input wire [31:0]  probe4 
        .probe5(perf_cycle_count_full_reg_tx), // input wire [0:0]  probe5 
        .probe6(perf_cycle_count_full_reg_rx), // input wire [0:0]  probe6
        .probe7(send_pkt_enable_reg),
        .probe8(recv_pkt_enable_reg),
        .probe9(is_recv_first_pkt_reg),
        .probe10(send_pkt_num_count_reg),
        .probe11(recv_pkt_num_count_reg),
        .probe12(err_pkt_num_count_reg),
        .probe13(total_beat_count_reg_tx),
        .probe14(total_beat_count_reg_rx),
        .probe15(pkt_interval_reg)
    );
    
    clk_wiz_0 clk_wiz_inst (
        // Clock out ports
        .clk_out1 (udp_clk         ),    // output clk_out1
        .clk_out2 (cmac_init_clk   ),    // output clk_out2
        // Status and control signals
        .resetn   (xdma_axi_aresetn),    // input resetn
        .locked   (clk_wiz_locked  ),    // output locked
        // Clock in ports
        .clk_in1  (xdma_axi_aclk   )     // input clk_in1
    );
    
    assign udp_reset = clk_wiz_locked;
    assign cmac_sys_reset = ~ clk_wiz_locked;

    // Extra Buffer for Cross-Die Connections
    xpm_fifo_axis #(
        .FIFO_DEPTH(16),
        .TDATA_WIDTH(XDMA_AXIS_TDATA_WIDTH)
    ) xdma_tx_axis_buf (
        .s_aclk   (xdma_axi_aclk),
        .m_aclk   (xdma_axi_aclk),
        .s_aresetn(xdma_axi_aresetn),

        .injectdbiterr_axis(1'd0),
        .injectsbiterr_axis(1'd0),
        .s_axis_tdest      (1'b0),
        .s_axis_tid        (1'b0),
        .s_axis_tstrb      (32'd0),

        .s_axis_tvalid(udp_tx_axis_tvalid),
        .s_axis_tready(udp_tx_axis_tready),
        .s_axis_tdata (udp_tx_axis_tdata ),
        .s_axis_tkeep (udp_tx_axis_tkeep ),
        .s_axis_tlast (udp_tx_axis_tlast ),
        .s_axis_tuser (udp_tx_axis_tuser ),
        
        .m_axis_tvalid(udp_tx_axis_tvalid_piped),
        .m_axis_tready(udp_tx_axis_tready_piped),
        .m_axis_tdata (udp_tx_axis_tdata_piped ),
        .m_axis_tkeep (udp_tx_axis_tkeep_piped ),
        .m_axis_tlast (udp_tx_axis_tlast_piped ),
        .m_axis_tuser (udp_tx_axis_tuser_piped )
    );

    CmacRxTxWrapper#(
        CMAC_GT_LANE_WIDTH,
        XDMA_AXIS_TDATA_WIDTH,
        XDMA_AXIS_TKEEP_WIDTH,
        XDMA_AXIS_TUSER_WIDTH
    ) cmac_wrapper_inst1(
        .xdma_clk  (xdma_axi_aclk   ),
        .xdma_reset(xdma_axi_aresetn),

        .gt_ref_clk_p(qsfp_ref_clk_p   ),
        .gt_ref_clk_n(qsfp_ref_clk_n   ),
        .gt_init_clk (cmac_init_clk     ),
        .gt_sys_reset(cmac_sys_reset    ),

        .xdma_rx_axis_tready(1'b0),
        .xdma_rx_axis_tvalid(),
        .xdma_rx_axis_tlast (),
        .xdma_rx_axis_tdata (),
        .xdma_rx_axis_tkeep (),
        .xdma_rx_axis_tuser (),

        .xdma_tx_axis_tvalid(udp_tx_axis_tvalid_piped),
        .xdma_tx_axis_tready(udp_tx_axis_tready_piped),
        .xdma_tx_axis_tlast (udp_tx_axis_tlast_piped ),
        .xdma_tx_axis_tdata (udp_tx_axis_tdata_piped ),
        .xdma_tx_axis_tkeep (udp_tx_axis_tkeep_piped ),
        .xdma_tx_axis_tuser (udp_tx_axis_tuser_piped ),

        // CMAC GT
        .gt_rxn_in (qsfp_txn ),
        .gt_rxp_in (qsfp_txp ),
        .gt_txn_out(qsfp_rxn ),
        .gt_txp_out(qsfp_rxp )
    );

    CmacRxTxWrapper#(
        CMAC_GT_LANE_WIDTH,
        XDMA_AXIS_TDATA_WIDTH,
        XDMA_AXIS_TKEEP_WIDTH,
        XDMA_AXIS_TUSER_WIDTH
    ) cmac_wrapper_inst2(

        .xdma_clk  (xdma_axi_aclk   ),
        .xdma_reset(xdma_axi_aresetn),

        .gt_ref_clk_p(qsfp_ref_clk_p   ),
        .gt_ref_clk_n(qsfp_ref_clk_n   ),
        .gt_init_clk (cmac_init_clk     ),
        .gt_sys_reset(cmac_sys_reset    ),

        .xdma_rx_axis_tready(udp_rx_axis_tready),
        .xdma_rx_axis_tvalid(udp_rx_axis_tvalid),
        .xdma_rx_axis_tlast (udp_rx_axis_tlast ),
        .xdma_rx_axis_tdata (udp_rx_axis_tdata ),
        .xdma_rx_axis_tkeep (udp_rx_axis_tkeep ),
        .xdma_rx_axis_tuser (udp_rx_axis_tuser ),

        .xdma_tx_axis_tvalid(1'b0),
        .xdma_tx_axis_tready( ),
        .xdma_tx_axis_tlast (0),
        .xdma_tx_axis_tdata (0),
        .xdma_tx_axis_tkeep (0),
        .xdma_tx_axis_tuser (0),

        // CMAC GT
        .gt_rxn_in (qsfp_rxn ),
        .gt_rxp_in (qsfp_rxp ),
        .gt_txn_out(qsfp_txn ),
        .gt_txp_out(qsfp_txp )
    );
    
endmodule