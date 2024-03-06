

module XdmaUdpCmacPerfTestWrapper#(
    parameter PCIE_GT_LANE_WIDTH = 16,
    parameter CMAC_GT_LANE_WIDTH = 4
)(
    input pcie_clk_n,
    input pcie_clk_p,
    input pcie_rst_n,

    output [PCIE_GT_LANE_WIDTH - 1 : 0] pci_exp_txn,
    output [PCIE_GT_LANE_WIDTH - 1 : 0] pci_exp_txp,
    input  [PCIE_GT_LANE_WIDTH - 1 : 0] pci_exp_rxn,
    input  [PCIE_GT_LANE_WIDTH - 1 : 0] pci_exp_rxp,

    output user_lnk_up,

    input qsfp_ref_clk_p,
    input qsfp_ref_clk_n,

    input  [CMAC_GT_LANE_WIDTH - 1 : 0] qsfp_rxn_in,
    input  [CMAC_GT_LANE_WIDTH - 1 : 0] qsfp_rxp_in,
    output [CMAC_GT_LANE_WIDTH - 1 : 0] qsfp_txn_out,
    output [CMAC_GT_LANE_WIDTH - 1 : 0] qsfp_txp_out,

    input qsfp_fault_in,
    output qsfp_lpmode_out,
    output qsfp_resetl_out,

    // Inidcation LED
    output qsfp_fault_indication,
    output cmac_rx_aligned_indication
);

    localparam XDMA_AXIL_ADDR_WIDTH = 32;
    localparam XDMA_AXIL_STRB_WIDTH = 4;
    localparam XDMA_AXIL_DATA_WIDTH = 32;
    localparam XDMA_AXIL_PROT_WIDTH = 3;
    localparam XDMA_AXIS_BRESP_WIDTH = 2;

    localparam XDMA_DESC_BYP_ADDR_WIDTH = 64;
    localparam XDMA_DESC_BYP_LEN_WIDTH = 28;
    localparam XDMA_DESC_BYP_CTL_WIDTH = 16;
    
    localparam XDMA_AXIS_TDATA_WIDTH = 512;
    localparam XDMA_AXIS_TKEEP_WIDTH = 64;
    localparam XDMA_AXIS_TUSER_WIDTH = 1;

    wire xdma_sys_clk, xdma_sys_clk_gt;
    wire xdma_sys_rst_n;

    wire xdma_axi_aclk;
    wire xdma_axi_aresetn;

    // XDMA AXI4-Lite Bus
    wire xdma_axil_awvalid;
    wire xdma_axil_awready;
    wire [XDMA_AXIL_ADDR_WIDTH - 1 : 0] xdma_axil_awaddr;
    wire [XDMA_AXIL_PROT_WIDTH - 1 : 0] xdma_axil_awprot;

    wire xdma_axil_wvalid;
    wire xdma_axil_wready;
    wire [XDMA_AXIL_DATA_WIDTH - 1 : 0] xdma_axil_wdata;
    wire [XDMA_AXIL_STRB_WIDTH - 1 : 0] xdma_axil_wstrb;

    wire xdma_axil_bvalid;
    wire xdma_axil_bready;
    wire [XDMA_AXIS_BRESP_WIDTH - 1 : 0] xdma_axil_bresp;

    wire xdma_axil_arvalid;
    wire xdma_axil_arready;
    wire [XDMA_AXIL_ADDR_WIDTH - 1 : 0] xdma_axil_araddr;
    wire [XDMA_AXIL_PROT_WIDTH - 1 : 0] xdma_axil_arprot;

    wire xdma_axil_rvalid;
    wire xdma_axil_rready;
    wire [XDMA_AXIL_DATA_WIDTH - 1 : 0] xdma_axil_rdata;
    wire [XDMA_AXIS_BRESP_WIDTH - 1 : 0] xdma_axil_rresp;

    // Descriptor Bypass Interface
    wire xdma_c2h_dsc_byp_ready;
    wire [XDMA_DESC_BYP_ADDR_WIDTH - 1 : 0] xdma_c2h_dsc_byp_src_addr;
    wire [XDMA_DESC_BYP_ADDR_WIDTH - 1 : 0] xdma_c2h_dsc_byp_dst_addr;
    wire [XDMA_DESC_BYP_LEN_WIDTH - 1 : 0] xdma_c2h_dsc_byp_len;
    wire [XDMA_DESC_BYP_CTL_WIDTH - 1 : 0] xdma_c2h_dsc_byp_ctl;
    wire xdma_c2h_dsc_byp_load;
    assign xdma_c2h_dsc_byp_ctl[15:5] = 11'd0;

    wire xdma_h2c_dsc_byp_ready;
    wire [XDMA_DESC_BYP_ADDR_WIDTH - 1 : 0] xdma_h2c_dsc_byp_src_addr;
    wire [XDMA_DESC_BYP_ADDR_WIDTH - 1 : 0] xdma_h2c_dsc_byp_dst_addr;
    wire [XDMA_DESC_BYP_LEN_WIDTH - 1 : 0] xdma_h2c_dsc_byp_len;
    wire [XDMA_DESC_BYP_CTL_WIDTH - 1 : 0] xdma_h2c_dsc_byp_ctl;
    wire xdma_h2c_dsc_byp_load;
    assign xdma_h2c_dsc_byp_ctl[15:5] = 11'd0;

    // XDMA AXI4-Stream Bus
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

    // Monitor Counters
    wire [0: 0] dma_dir;
    wire [0: 0] is_loop_back;
    wire [31:0] pkt_beat_num;
    wire [31:0] pkt_num;
    wire [63:0] xdma_desc_byp_addr;

    wire [0 :0] send_desc_enable;
    wire [31:0] total_desc_counter;
    
    wire [0 :0] send_pkt_enable;
    wire [0 :0] is_send_first_frame;
    wire [31:0] perf_cycle_counter_tx;
    wire [31:0] total_beat_counter_tx;
    wire [31:0] err_beat_counter_tx;
    wire [31:0] total_pkt_counter_tx;

    wire [0 :0] recv_pkt_enable;
    wire [0 :0] is_recv_first_frame;
    wire [31:0] perf_cycle_counter_rx;
    wire [31:0] total_beat_counter_rx;
    wire [31:0] err_beat_counter_rx;
    wire [31:0] total_pkt_counter_rx;

    wire clk_wiz_locked;
    wire udp_clk, udp_reset;
    wire cmac_init_clk, cmac_sys_reset;

    // UDP AXI4-Stream Bus
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
    
    wire udp_tx_axis_tvalid_piped;
    wire udp_tx_axis_tready_piped;
    wire udp_tx_axis_tlast_piped;
    wire [XDMA_AXIS_TDATA_WIDTH - 1 : 0] udp_tx_axis_tdata_piped;
    wire [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] udp_tx_axis_tkeep_piped;
    wire [XDMA_AXIS_TUSER_WIDTH - 1 : 0] udp_tx_axis_tuser_piped;

    wire udp_rx_axis_tvalid_piped;
    wire udp_rx_axis_tready_piped;
    wire udp_rx_axis_tlast_piped;
    wire [XDMA_AXIS_TDATA_WIDTH - 1 : 0] udp_rx_axis_tdata_piped;
    wire [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] udp_rx_axis_tkeep_piped;
    wire [XDMA_AXIS_TUSER_WIDTH - 1 : 0] udp_rx_axis_tuser_piped;

    // PCIe Clock buffer
    IBUFDS_GTE4 # (.REFCLK_HROW_CK_SEL(2'b00)) refclk_ibuf (.O(xdma_sys_clk_gt), .ODIV2(xdma_sys_clk), .I(pcie_clk_p), .CEB(1'b0), .IB(pcie_clk_n));
    // PCIe Reset buffer
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
        
        .axi_aclk   (xdma_axi_aclk   ),                 // output wire axi_aclk
        .axi_aresetn(xdma_axi_aresetn),              // output wire axi_aresetn
        
        .usr_irq_req(0),                        // input wire [0 : 0] usr_irq_req
        .usr_irq_ack(),                        // output wire [0 : 0] usr_irq_ack
        
        .s_axis_c2h_tdata_0 (xdma_rx_axis_tdata ),   // input wire [511 : 0] s_axis_c2h_tdata_0
        .s_axis_c2h_tlast_0 (xdma_rx_axis_tlast ),   // input wire s_axis_c2h_tlast_0
        .s_axis_c2h_tvalid_0(xdma_rx_axis_tvalid),  // input wire s_axis_c2h_tvalid_0
        .s_axis_c2h_tready_0(xdma_rx_axis_tready),  // output wire s_axis_c2h_tready_0
        .s_axis_c2h_tkeep_0 (xdma_rx_axis_tkeep ),   // input wire [63 : 0] s_axis_c2h_tkeep_0

        .m_axis_h2c_tdata_0 (xdma_tx_axis_tdata ),   // output wire [511 : 0] m_axis_h2c_tdata_0
        .m_axis_h2c_tlast_0 (xdma_tx_axis_tlast ),   // output wire m_axis_h2c_tlast_0
        .m_axis_h2c_tvalid_0(xdma_tx_axis_tvalid),  // output wire m_axis_h2c_tvalid_0
        .m_axis_h2c_tready_0(xdma_tx_axis_tready),  // input wire m_axis_h2c_tready_0
        .m_axis_h2c_tkeep_0 (xdma_tx_axis_tkeep ),    // output wire [63 : 0] m_axis_h2c_tkeep_0
        
        .m_axil_awaddr (xdma_axil_awaddr ),                    // output wire [31 : 0] m_axil_awaddr
        .m_axil_awprot (xdma_axil_awprot ),                    // output wire [2 : 0] m_axil_awprot
        .m_axil_awvalid(xdma_axil_awvalid),                  // output wire m_axil_awvalid
        .m_axil_awready(xdma_axil_awready),                  // input wire m_axil_awready
        .m_axil_wdata  (xdma_axil_wdata  ),                      // output wire [31 : 0] m_axil_wdata
        .m_axil_wstrb  (xdma_axil_wstrb  ),                      // output wire [3 : 0] m_axil_wstrb
        .m_axil_wvalid (xdma_axil_wvalid ),                    // output wire m_axil_wvalid
        .m_axil_wready (xdma_axil_wready ),                    // input wire m_axil_wready
        .m_axil_bvalid (xdma_axil_bvalid ),                    // input wire m_axil_bvalid
        .m_axil_bresp  (xdma_axil_bresp  ),                      // input wire [1 : 0] m_axil_bresp
        .m_axil_bready (xdma_axil_bready ),                    // output wire m_axil_bready
        
        .m_axil_araddr (xdma_axil_araddr ),                    // output wire [31 : 0] m_axil_araddr
        .m_axil_arprot (xdma_axil_arprot ),                    // output wire [2 : 0] m_axil_arprot
        .m_axil_arvalid(xdma_axil_arvalid),                  // output wire m_axil_arvalid
        .m_axil_arready(xdma_axil_arready),                  // input wire m_axil_arready
        .m_axil_rdata  (xdma_axil_rdata  ),                      // input wire [31 : 0] m_axil_rdata
        .m_axil_rresp  (xdma_axil_rresp  ),                      // input wire [1 : 0] m_axil_rresp
        .m_axil_rvalid (xdma_axil_rvalid ),                    // input wire m_axil_rvalid
        .m_axil_rready (xdma_axil_rready ),                    // output wire m_axil_rready

        .c2h_dsc_byp_ready_0   (xdma_c2h_dsc_byp_ready   ),        // output wire c2h_dsc_byp_ready_0
        .c2h_dsc_byp_src_addr_0(xdma_c2h_dsc_byp_src_addr),  // input wire [63 : 0] c2h_dsc_byp_src_addr_0
        .c2h_dsc_byp_dst_addr_0(xdma_c2h_dsc_byp_dst_addr),  // input wire [63 : 0] c2h_dsc_byp_dst_addr_0
        .c2h_dsc_byp_len_0     (xdma_c2h_dsc_byp_len     ),            // input wire [27 : 0] c2h_dsc_byp_len_0
        .c2h_dsc_byp_ctl_0     (xdma_c2h_dsc_byp_ctl     ),            // input wire [15 : 0] c2h_dsc_byp_ctl_0
        .c2h_dsc_byp_load_0    (xdma_c2h_dsc_byp_load    ),          // input wire c2h_dsc_byp_load_0
        .h2c_dsc_byp_ready_0   (xdma_h2c_dsc_byp_ready   ),        // output wire h2c_dsc_byp_ready_0
        .h2c_dsc_byp_src_addr_0(xdma_h2c_dsc_byp_src_addr),  // input wire [63 : 0] h2c_dsc_byp_src_addr_0
        .h2c_dsc_byp_dst_addr_0(xdma_h2c_dsc_byp_dst_addr),  // input wire [63 : 0] h2c_dsc_byp_dst_addr_0
        .h2c_dsc_byp_len_0     (xdma_h2c_dsc_byp_len     ),            // input wire [27 : 0] h2c_dsc_byp_len_0
        .h2c_dsc_byp_ctl_0     (xdma_h2c_dsc_byp_ctl     ),            // input wire [15 : 0] h2c_dsc_byp_ctl_0
        .h2c_dsc_byp_load_0    (xdma_h2c_dsc_byp_load    )           // input wire h2c_dsc_byp_load_0
    );

    mkXdmaPerfMonitor perf_mon_inst(
        .clk                (xdma_axi_aclk      ),
        .reset              (xdma_axi_aresetn   ),
        // AXI4-Lite Bus
        .xdma_axil_awvalid  (xdma_axil_awvalid  ),
        .xdma_axil_awready  (xdma_axil_awready  ),
        .xdma_axil_awaddr   (xdma_axil_awaddr   ),
        .xdma_axil_awprot   (xdma_axil_awprot   ),
        .xdma_axil_wvalid   (xdma_axil_wvalid   ),
        .xdma_axil_wready   (xdma_axil_wready   ),
        .xdma_axil_wdata    (xdma_axil_wdata    ),
        .xdma_axil_wstrb    (xdma_axil_wstrb    ),
        .xdma_axil_bvalid   (xdma_axil_bvalid   ),
        .xdma_axil_bready   (xdma_axil_bready   ),
        .xdma_axil_bresp    (xdma_axil_bresp    ),

        .xdma_axil_arvalid  (xdma_axil_arvalid  ),
        .xdma_axil_arready  (xdma_axil_arready  ),
        .xdma_axil_araddr   (xdma_axil_araddr   ),
        .xdma_axil_arprot   (xdma_axil_arprot   ),
        .xdma_axil_rvalid   (xdma_axil_rvalid   ),
        .xdma_axil_rready   (xdma_axil_rready   ),
        .xdma_axil_rdata    (xdma_axil_rdata    ),
        .xdma_axil_rresp    (xdma_axil_rresp    ),

        // Descriptor Bypass Interface
        .xdma_h2c_desc_byp_ready   (xdma_h2c_dsc_byp_ready   ),
        .xdma_h2c_desc_byp_src_addr(xdma_h2c_dsc_byp_src_addr),
        .xdma_h2c_desc_byp_dst_addr(xdma_h2c_dsc_byp_dst_addr),
        .xdma_h2c_desc_byp_len     (xdma_h2c_dsc_byp_len     ),
        .xdma_h2c_desc_byp_ctl     (xdma_h2c_dsc_byp_ctl[4:0]),
        .xdma_h2c_desc_byp_load    (xdma_h2c_dsc_byp_load    ),

        .xdma_c2h_desc_byp_ready   (xdma_c2h_dsc_byp_ready   ),
        .xdma_c2h_desc_byp_src_addr(xdma_c2h_dsc_byp_src_addr),
        .xdma_c2h_desc_byp_dst_addr(xdma_c2h_dsc_byp_dst_addr),
        .xdma_c2h_desc_byp_len     (xdma_c2h_dsc_byp_len     ),
        .xdma_c2h_desc_byp_ctl     (xdma_c2h_dsc_byp_ctl[4:0]),
        .xdma_c2h_desc_byp_load    (xdma_c2h_dsc_byp_load    ),

        // XDMA AXI4-Stream Bus
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

        // UDP AXI4-Stream Bus
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
		
        .dmaDirOut            (dma_dir              ),
        .isLoopbackOut        (is_loop_back         ),
        .pktBeatNumOut        (pkt_beat_num         ),
        .pktNumOut            (pkt_num              ),
        .xdmaDescBypAddrOut   (xdma_desc_byp_addr   ),

        .sendDescEnableOut    (send_desc_enable     ),
        .totalDescCounterOut  (total_desc_counter   ),
        
        .sendPktEnableOut     (send_pkt_enable      ),
        .isSendFirstFrameOut  (is_send_first_frame  ),
        .perfCycleCounterTxOut(perf_cycle_counter_tx),
        .totalBeatCounterTxOut(total_beat_counter_tx),
        .errBeatCounterTxOut  (err_beat_counter_tx  ),
        .totalPktCounterTxOut (total_pkt_counter_tx ),
        
        .recvPktEnableOut     (recv_pkt_enable      ),
        .isRecvFirstFrameOut  (is_recv_first_frame  ),
        .perfCycleCounterRxOut(perf_cycle_counter_rx),
        .totalBeatCounterRxOut(total_beat_counter_rx),
        .errBeatCounterRxOut  (err_beat_counter_rx  ),
        .totalPktCounterRxOut (total_pkt_counter_rx )
    );

    xdma_perf_mon_ila perf_mon_ila_inst (
        .clk    (xdma_axi_aclk        ),

        .probe0 (dma_dir              ),
        .probe1 (is_loop_back         ),
        .probe2 (pkt_beat_num         ),
        .probe3 (pkt_num              ),
        .probe4 (xdma_desc_byp_addr   ),

        .probe5 (send_desc_enable     ),
        .probe6 (total_desc_counter   ),

        .probe7 (send_pkt_enable      ),
        .probe8 (is_send_first_frame  ),
        .probe9 (perf_cycle_counter_tx),
        .probe10 (total_beat_counter_tx),
        .probe11(err_beat_counter_tx  ),
        .probe12(total_pkt_counter_tx ),

        .probe13(recv_pkt_enable      ),
        .probe14(is_recv_first_frame  ),
        .probe15(perf_cycle_counter_rx),
        .probe16(total_beat_counter_rx),
        .probe17(err_beat_counter_rx  ),
        .probe18(total_pkt_counter_rx )
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
    ) udp_tx_axis_buf (
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

    xpm_fifo_axis #(
        .FIFO_DEPTH(16),
        .TDATA_WIDTH(XDMA_AXIS_TDATA_WIDTH)
    ) udp_rx_axis_buf (
        .s_aclk   (xdma_axi_aclk),
        .m_aclk   (xdma_axi_aclk),
        .s_aresetn(xdma_axi_aresetn),

        .injectdbiterr_axis(1'd0 ),
        .injectsbiterr_axis(1'd0 ),
        .s_axis_tdest      (1'b0 ),
        .s_axis_tid        (1'b0 ),
        .s_axis_tstrb      (32'd0),

        .s_axis_tvalid(udp_rx_axis_tvalid_piped),
        .s_axis_tready(udp_rx_axis_tready_piped),
        .s_axis_tdata (udp_rx_axis_tdata_piped ),
        .s_axis_tkeep (udp_rx_axis_tkeep_piped ),
        .s_axis_tlast (udp_rx_axis_tlast_piped ),
        .s_axis_tuser (udp_rx_axis_tuser_piped ),
        
        .m_axis_tvalid(udp_rx_axis_tvalid),
        .m_axis_tready(udp_rx_axis_tready),
        .m_axis_tdata (udp_rx_axis_tdata ),
        .m_axis_tkeep (udp_rx_axis_tkeep ),
        .m_axis_tlast (udp_rx_axis_tlast ),
        .m_axis_tuser (udp_rx_axis_tuser )
    );

    UdpCmacRxTxWrapper#(
        CMAC_GT_LANE_WIDTH,
        XDMA_AXIS_TDATA_WIDTH,
        XDMA_AXIS_TKEEP_WIDTH,
        XDMA_AXIS_TUSER_WIDTH
    ) udp_cmac_inst(
        .xdma_clk    (xdma_axi_aclk   ),
        .xdma_reset  (xdma_axi_aresetn),

        .udp_clk     (udp_clk  ),
        .udp_reset   (udp_reset),

        .gt_ref_clk_p(qsfp_ref_clk_p    ),
        .gt_ref_clk_n(qsfp_ref_clk_n    ),
        .gt_init_clk (cmac_init_clk     ),
        .gt_sys_reset(cmac_sys_reset    ),

        .xdma_rx_axis_tready(udp_rx_axis_tready_piped),
        .xdma_rx_axis_tvalid(udp_rx_axis_tvalid_piped),
        .xdma_rx_axis_tlast (udp_rx_axis_tlast_piped ),
        .xdma_rx_axis_tdata (udp_rx_axis_tdata_piped ),
        .xdma_rx_axis_tkeep (udp_rx_axis_tkeep_piped ),
        .xdma_rx_axis_tuser (udp_rx_axis_tuser_piped ),

        .xdma_tx_axis_tvalid(udp_tx_axis_tvalid_piped),
        .xdma_tx_axis_tready(udp_tx_axis_tready_piped),
        .xdma_tx_axis_tlast (udp_tx_axis_tlast_piped ),
        .xdma_tx_axis_tdata (udp_tx_axis_tdata_piped ),
        .xdma_tx_axis_tkeep (udp_tx_axis_tkeep_piped ),
        .xdma_tx_axis_tuser (udp_tx_axis_tuser_piped ),

        // CMAC GT
        .gt_rxn_in (qsfp_rxn_in ),
        .gt_rxp_in (qsfp_rxp_in ),
        .gt_txn_out(qsfp_txn_out),
        .gt_txp_out(qsfp_txp_out),

        .qsfp_fault_in             (qsfp_fault_in             ),
        .qsfp_lpmode_out           (qsfp_lpmode_out           ),
        .qsfp_resetl_out           (qsfp_resetl_out           ),
        .qsfp_fault_indication     (qsfp_fault_indication     ),
        .cmac_rx_aligned_indication(cmac_rx_aligned_indication)
    );
    
endmodule