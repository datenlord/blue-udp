

module XdmaUdpPerfMonRxWrapper#(
    parameter PCIE_GT_LANE_WIDTH = 16
)(
    input pcie_clk_n,
    input pcie_clk_p,
    input pcie_rst_n,

    output [PCIE_GT_LANE_WIDTH - 1 : 0] pci_exp_txn,
    output [PCIE_GT_LANE_WIDTH - 1 : 0] pci_exp_txp,
    input  [PCIE_GT_LANE_WIDTH - 1 : 0] pci_exp_rxn,
    input  [PCIE_GT_LANE_WIDTH - 1 : 0] pci_exp_rxp,

    output user_lnk_up
);
    localparam XDMA_AXIS_TDATA_WIDTH = 512;
    localparam XDMA_AXIS_TKEEP_WIDTH = 64;
    localparam XDMA_AXIS_TUSER_WIDTH = 1;

    wire xdma_sys_clk, xdma_sys_clk_gt;
    wire xdma_sys_rst_n;

    wire xdma_axi_aclk;
    wire xdma_axi_aresetn;
    wire clk_wiz_locked;

    wire udp_clk, udp_reset;

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
    assign xdma_tx_axis_tuser = 1'b0;

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

    // Perfamance Counter
    wire [31:0] pkt_size;
    wire [31:0] pkt_num;
    wire [0 :0] send_pkt_enable; 
    wire [31:0] perf_cycle_counter_tx;
    wire [31:0] total_beat_counter_tx;
    wire [31:0] total_pkt_counter_tx;
    
    wire [0 :0] recv_pkt_enable;
    wire [0 :0] is_recv_first_frame;
    wire [31:0] perf_cycle_counter_rx;
    wire [31:0] total_beat_counter_rx;
    wire [31:0] total_pkt_counter_rx;

    wire cmac_axis_tvalid_loop;
    wire cmac_axis_tready_loop;
    wire cmac_axis_tlast_loop;
    wire [255 : 0] cmac_axis_tdata_loop;
    wire [32  : 0] cmac_axis_tkeep_loop;
    wire [0   : 0] cmac_axis_tuser_loop;

    // PCIe Clock Buffer
    IBUFDS_GTE4 # (.REFCLK_HROW_CK_SEL(2'b00)) refclk_ibuf (.O(xdma_sys_clk_gt), .ODIV2(xdma_sys_clk), .I(pcie_clk_p), .CEB(1'b0), .IB(pcie_clk_n));
    // PCIe Reset Buffer
    IBUF   sys_reset_n_ibuf (.O(xdma_sys_rst_n), .I(pcie_rst_n));
    xdma_0 xdma_inst (
        .sys_clk    (xdma_sys_clk),                  // input wire sys_clk
        .sys_clk_gt (xdma_sys_clk_gt),               // input wire sys_clk_gt
        .sys_rst_n  (xdma_sys_rst_n),                // input wire sys_rst_n
        .user_lnk_up(user_lnk_up),                   // output wire user_lnk_up
        .pci_exp_txp(pci_exp_txp),                   // output wire [15 : 0] pci_exp_txp
        .pci_exp_txn(pci_exp_txn),                   // output wire [15 : 0] pci_exp_txn
        .pci_exp_rxp(pci_exp_rxp),                   // input wire [15 : 0] pci_exp_rxp
        .pci_exp_rxn(pci_exp_rxn),                   // input wire [15 : 0] pci_exp_rxn
        
        .axi_aclk   (xdma_axi_aclk),                 // output wire axi_aclk
        .axi_aresetn(xdma_axi_aresetn),              // output wire axi_aresetn
        .usr_irq_req(0),                             // input wire [0 : 0] usr_irq_req
        .usr_irq_ack(),                              // output wire [0 : 0] usr_irq_ack
        
        .s_axis_c2h_tdata_0 (xdma_rx_axis_tdata),   // input wire [511 : 0] s_axis_c2h_tdata_0
        .s_axis_c2h_tlast_0 (xdma_rx_axis_tlast),   // input wire s_axis_c2h_tlast_0
        .s_axis_c2h_tvalid_0(xdma_rx_axis_tvalid),  // input wire s_axis_c2h_tvalid_0
        .s_axis_c2h_tready_0(xdma_rx_axis_tready),  // output wire s_axis_c2h_tready_0
        .s_axis_c2h_tkeep_0 (xdma_rx_axis_tkeep),   // input wire [63 : 0] s_axis_c2h_tkeep_0

        .m_axis_h2c_tdata_0 (xdma_tx_axis_tdata),   // output wire [511 : 0] m_axis_h2c_tdata_0
        .m_axis_h2c_tlast_0 (xdma_tx_axis_tlast),   // output wire m_axis_h2c_tlast_0
        .m_axis_h2c_tvalid_0(xdma_tx_axis_tvalid),  // output wire m_axis_h2c_tvalid_0
        .m_axis_h2c_tready_0(xdma_tx_axis_tready),  // input wire m_axis_h2c_tready_0
        .m_axis_h2c_tkeep_0 (xdma_tx_axis_tkeep)    // output wire [63 : 0] m_axis_h2c_tkeep_0
    );

    mkXdmaUdpPerfMonitorRx perfMonRxInst(
        .CLK                (xdma_axi_aclk      ),
        .RST_N              (xdma_axi_aresetn   ),

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

        .pktSizeOut           (pkt_size             ),
        .pktNumOut            (pkt_num              ),
        .sendPktEnableOut     (send_pkt_enable      ),
        .perfCycleCounterTxOut(perf_cycle_counter_tx),
        .totalBeatCounterTxOut(total_beat_counter_tx),
        .totalPktCounterTxOut (total_pkt_counter_tx ),
        
        .recvPktEnableOut     (recv_pkt_enable      ),
        .isRecvFirstFrameOut  (is_recv_first_frame  ),
        .perfCycleCounterRxOut(perf_cycle_counter_rx),
        .totalBeatCounterRxOut(total_beat_counter_rx),
        .totalPktCounterRxOut (total_pkt_counter_rx )
    );

    ila_0 perf_counter_ila (
        .clk    (xdma_axi_aclk        ),
        
        .probe0 (pkt_size             ),
        .probe1 (pkt_num              ),
        .probe2 (send_pkt_enable      ),
        .probe3 (perf_cycle_counter_tx),
        .probe4 (total_beat_counter_tx),
        .probe5 (total_pkt_counter_tx ),
        
        .probe6 (recv_pkt_enable      ),
        .probe7 (is_recv_first_frame  ),
        .probe8 (perf_cycle_counter_rx),
        .probe9 (total_beat_counter_rx),
        .probe10(total_pkt_counter_rx )
    );
    
    clk_wiz_0 clk_wiz_inst (
        // Clock out ports
        .clk_out1 (udp_clk         ),    // output clk_out1
        // Status and control signals
        .resetn   (xdma_axi_aresetn),    // input resetn
        .locked   (clk_wiz_locked  ),    // output locked
        // Clock in ports
        .clk_in1  (xdma_axi_aclk   )     // input clk_in1
    );
    
    assign udp_reset = clk_wiz_locked;

    mkXdmaUdpIpArpEthRxTx udp_inst(
        .xdma_clk  (xdma_axi_aclk   ),
        .xdma_reset(xdma_axi_aresetn),
        .udp_clk   (udp_clk         ),
        .udp_reset (udp_reset       ),
        
        .cmac_tx_axis_tvalid(cmac_axis_tvalid_loop),
        .cmac_tx_axis_tdata (cmac_axis_tdata_loop ),
        .cmac_tx_axis_tkeep (cmac_axis_tkeep_loop ),
        .cmac_tx_axis_tlast (cmac_axis_tlast_loop ),
        .cmac_tx_axis_tuser (cmac_axis_tuser_loop ),
        .cmac_tx_axis_tready(cmac_axis_tready_loop),
        
        .cmac_rx_axis_tvalid(cmac_axis_tvalid_loop),
        .cmac_rx_axis_tdata (cmac_axis_tdata_loop ),
        .cmac_rx_axis_tkeep (cmac_axis_tkeep_loop ),
        .cmac_rx_axis_tlast (cmac_axis_tlast_loop ),
        .cmac_rx_axis_tuser (cmac_axis_tuser_loop ),
        .cmac_rx_axis_tready(cmac_axis_tready_loop),
        
        .xdma_rx_axis_tvalid(udp_rx_axis_tvalid   ),
        .xdma_rx_axis_tdata (udp_rx_axis_tdata    ),
        .xdma_rx_axis_tkeep (udp_rx_axis_tkeep    ),
        .xdma_rx_axis_tlast (udp_rx_axis_tlast    ),
        .xdma_rx_axis_tuser (udp_rx_axis_tuser    ),
        .xdma_rx_axis_tready(udp_rx_axis_tready   ),

        .xdma_tx_axis_tvalid(udp_tx_axis_tvalid   ),
        .xdma_tx_axis_tdata (udp_tx_axis_tdata    ),
        .xdma_tx_axis_tkeep (udp_tx_axis_tkeep    ),
        .xdma_tx_axis_tlast (udp_tx_axis_tlast    ),
        .xdma_tx_axis_tuser (udp_tx_axis_tuser    ),
        .xdma_tx_axis_tready(udp_tx_axis_tready   )
    );
endmodule
