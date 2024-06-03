
module XdmaUdpCmacWrapper256#(
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

    localparam XDMA_AXIS_TDATA_WIDTH = 512;
    localparam XDMA_AXIS_TKEEP_WIDTH = 64;
    localparam XDMA_AXIS_TUSER_WIDTH = 1;

    wire xdma_sys_clk, xdma_sys_clk_gt;
    wire xdma_sys_rst_n;

    wire xdma_axi_aclk;
    wire xdma_axi_aresetn;
    wire clk_wiz_locked;

    wire udp_clk, udp_reset;

    wire cmac_init_clk, cmac_sys_reset;

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

    wire xdma_tx_axis_tvalid_piped;
    wire xdma_tx_axis_tready_piped;
    wire xdma_tx_axis_tlast_piped;
    wire [XDMA_AXIS_TDATA_WIDTH - 1 : 0] xdma_tx_axis_tdata_piped;
    wire [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] xdma_tx_axis_tkeep_piped;
    wire [XDMA_AXIS_TUSER_WIDTH - 1 : 0] xdma_tx_axis_tuser_piped;

    wire xdma_rx_axis_tvalid_piped;
    wire xdma_rx_axis_tready_piped;
    wire xdma_rx_axis_tlast_piped;
    wire [XDMA_AXIS_TDATA_WIDTH - 1 : 0] xdma_rx_axis_tdata_piped;
    wire [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] xdma_rx_axis_tkeep_piped;
    wire [XDMA_AXIS_TUSER_WIDTH - 1 : 0] xdma_rx_axis_tuser_piped;
    
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
        .s_aclk   (xdma_axi_aclk   ),
        .m_aclk   (xdma_axi_aclk   ),
        .s_aresetn(xdma_axi_aresetn),

        .injectdbiterr_axis(1'd0),
        .injectsbiterr_axis(1'd0),
        .s_axis_tdest      (1'b0),
        .s_axis_tid        (1'b0),
        .s_axis_tstrb      (32'd0),

        .s_axis_tvalid(xdma_tx_axis_tvalid),
        .s_axis_tready(xdma_tx_axis_tready),
        .s_axis_tdata (xdma_tx_axis_tdata ),
        .s_axis_tkeep (xdma_tx_axis_tkeep ),
        .s_axis_tlast (xdma_tx_axis_tlast ),
        .s_axis_tuser (xdma_tx_axis_tuser ),
        
        .m_axis_tvalid(xdma_tx_axis_tvalid_piped),
        .m_axis_tready(xdma_tx_axis_tready_piped),
        .m_axis_tdata (xdma_tx_axis_tdata_piped ),
        .m_axis_tkeep (xdma_tx_axis_tkeep_piped ),
        .m_axis_tlast (xdma_tx_axis_tlast_piped ),
        .m_axis_tuser (xdma_tx_axis_tuser_piped )
    );

    xpm_fifo_axis #(
        .FIFO_DEPTH(16),
        .TDATA_WIDTH(XDMA_AXIS_TDATA_WIDTH)
    ) xdma_rx_axis_buf (
        .s_aclk   (xdma_axi_aclk   ),
        .m_aclk   (xdma_axi_aclk   ),
        .s_aresetn(xdma_axi_aresetn),

        .injectdbiterr_axis(1'd0 ),
        .injectsbiterr_axis(1'd0 ),
        .s_axis_tdest      (1'b0 ),
        .s_axis_tid        (1'b0 ),
        .s_axis_tstrb      (32'd0),

        .s_axis_tvalid(xdma_rx_axis_tvalid_piped),
        .s_axis_tready(xdma_rx_axis_tready_piped),
        .s_axis_tdata (xdma_rx_axis_tdata_piped ),
        .s_axis_tkeep (xdma_rx_axis_tkeep_piped ),
        .s_axis_tlast (xdma_rx_axis_tlast_piped ),
        .s_axis_tuser (xdma_rx_axis_tuser_piped ),
        
        .m_axis_tvalid(xdma_rx_axis_tvalid),
        .m_axis_tready(xdma_rx_axis_tready),
        .m_axis_tdata (xdma_rx_axis_tdata ),
        .m_axis_tkeep (xdma_rx_axis_tkeep ),
        .m_axis_tlast (xdma_rx_axis_tlast ),
        .m_axis_tuser (xdma_rx_axis_tuser )
    );

    UdpCmacRxTxWrapper#(
        CMAC_GT_LANE_WIDTH,
        XDMA_AXIS_TDATA_WIDTH,
        XDMA_AXIS_TKEEP_WIDTH,
        XDMA_AXIS_TUSER_WIDTH
    ) udp_cmac_inst(

        .xdma_clk  (xdma_axi_aclk   ),
        .xdma_reset(xdma_axi_aresetn),

        .udp_clk   (udp_clk  ),
        .udp_reset (udp_reset),

        .gt_ref_clk_p(qsfp_ref_clk_p    ),
        .gt_ref_clk_n(qsfp_ref_clk_n    ),
        .gt_init_clk (cmac_init_clk     ),
        .gt_sys_reset(cmac_sys_reset    ),

        .xdma_rx_axis_tready(xdma_rx_axis_tready_piped),
        .xdma_rx_axis_tvalid(xdma_rx_axis_tvalid_piped),
        .xdma_rx_axis_tlast (xdma_rx_axis_tlast_piped ),
        .xdma_rx_axis_tdata (xdma_rx_axis_tdata_piped ),
        .xdma_rx_axis_tkeep (xdma_rx_axis_tkeep_piped ),
        .xdma_rx_axis_tuser (xdma_rx_axis_tuser_piped ),

        .xdma_tx_axis_tvalid(xdma_tx_axis_tvalid_piped),
        .xdma_tx_axis_tready(xdma_tx_axis_tready_piped),
        .xdma_tx_axis_tlast (xdma_tx_axis_tlast_piped ),
        .xdma_tx_axis_tdata (xdma_tx_axis_tdata_piped ),
        .xdma_tx_axis_tkeep (xdma_tx_axis_tkeep_piped ),
        .xdma_tx_axis_tuser (xdma_tx_axis_tuser_piped ),

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


module XdmaUdpCmacWrapper512#(
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

    localparam XDMA_AXIS_TDATA_WIDTH = 512;
    localparam XDMA_AXIS_TKEEP_WIDTH = 64;
    localparam XDMA_AXIS_TUSER_WIDTH = 1;

    wire xdma_sys_clk, xdma_sys_clk_gt;
    wire xdma_sys_rst_n;

    wire xdma_axi_aclk;
    wire xdma_axi_aresetn;
    wire clk_wiz_locked;

    wire udp_clk, udp_reset;

    wire cmac_init_clk, cmac_sys_reset;

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

    wire xdma_tx_axis_tvalid_piped;
    wire xdma_tx_axis_tready_piped;
    wire xdma_tx_axis_tlast_piped;
    wire [XDMA_AXIS_TDATA_WIDTH - 1 : 0] xdma_tx_axis_tdata_piped;
    wire [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] xdma_tx_axis_tkeep_piped;
    wire [XDMA_AXIS_TUSER_WIDTH - 1 : 0] xdma_tx_axis_tuser_piped;

    wire xdma_rx_axis_tvalid_piped;
    wire xdma_rx_axis_tready_piped;
    wire xdma_rx_axis_tlast_piped;
    wire [XDMA_AXIS_TDATA_WIDTH - 1 : 0] xdma_rx_axis_tdata_piped;
    wire [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] xdma_rx_axis_tkeep_piped;
    wire [XDMA_AXIS_TUSER_WIDTH - 1 : 0] xdma_rx_axis_tuser_piped;
    
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
        .s_aclk   (xdma_axi_aclk   ),
        .m_aclk   (xdma_axi_aclk   ),
        .s_aresetn(xdma_axi_aresetn),

        .injectdbiterr_axis(1'd0),
        .injectsbiterr_axis(1'd0),
        .s_axis_tdest      (1'b0),
        .s_axis_tid        (1'b0),
        .s_axis_tstrb      (32'd0),

        .s_axis_tvalid(xdma_tx_axis_tvalid),
        .s_axis_tready(xdma_tx_axis_tready),
        .s_axis_tdata (xdma_tx_axis_tdata ),
        .s_axis_tkeep (xdma_tx_axis_tkeep ),
        .s_axis_tlast (xdma_tx_axis_tlast ),
        .s_axis_tuser (xdma_tx_axis_tuser ),
        
        .m_axis_tvalid(xdma_tx_axis_tvalid_piped),
        .m_axis_tready(xdma_tx_axis_tready_piped),
        .m_axis_tdata (xdma_tx_axis_tdata_piped ),
        .m_axis_tkeep (xdma_tx_axis_tkeep_piped ),
        .m_axis_tlast (xdma_tx_axis_tlast_piped ),
        .m_axis_tuser (xdma_tx_axis_tuser_piped )
    );

    xpm_fifo_axis #(
        .FIFO_DEPTH(16),
        .TDATA_WIDTH(XDMA_AXIS_TDATA_WIDTH)
    ) xdma_rx_axis_buf (
        .s_aclk   (xdma_axi_aclk   ),
        .m_aclk   (xdma_axi_aclk   ),
        .s_aresetn(xdma_axi_aresetn),

        .injectdbiterr_axis(1'd0 ),
        .injectsbiterr_axis(1'd0 ),
        .s_axis_tdest      (1'b0 ),
        .s_axis_tid        (1'b0 ),
        .s_axis_tstrb      (32'd0),

        .s_axis_tvalid(xdma_rx_axis_tvalid_piped),
        .s_axis_tready(xdma_rx_axis_tready_piped),
        .s_axis_tdata (xdma_rx_axis_tdata_piped ),
        .s_axis_tkeep (xdma_rx_axis_tkeep_piped ),
        .s_axis_tlast (xdma_rx_axis_tlast_piped ),
        .s_axis_tuser (xdma_rx_axis_tuser_piped ),
        
        .m_axis_tvalid(xdma_rx_axis_tvalid),
        .m_axis_tready(xdma_rx_axis_tready),
        .m_axis_tdata (xdma_rx_axis_tdata ),
        .m_axis_tkeep (xdma_rx_axis_tkeep ),
        .m_axis_tlast (xdma_rx_axis_tlast ),
        .m_axis_tuser (xdma_rx_axis_tuser )
    );

    UdpCmacRxTxWrapper#(
        CMAC_GT_LANE_WIDTH,
        XDMA_AXIS_TDATA_WIDTH,
        XDMA_AXIS_TKEEP_WIDTH,
        XDMA_AXIS_TUSER_WIDTH
    ) udp_cmac_inst(

        .xdma_clk  (xdma_axi_aclk   ),
        .xdma_reset(xdma_axi_aresetn),

        .udp_clk   (xdma_axi_aclk   ),
        .udp_reset (xdma_axi_aresetn),

        .gt_ref_clk_p(qsfp_ref_clk_p    ),
        .gt_ref_clk_n(qsfp_ref_clk_n    ),
        .gt_init_clk (cmac_init_clk     ),
        .gt_sys_reset(cmac_sys_reset    ),

        .xdma_rx_axis_tready(xdma_rx_axis_tready_piped),
        .xdma_rx_axis_tvalid(xdma_rx_axis_tvalid_piped),
        .xdma_rx_axis_tlast (xdma_rx_axis_tlast_piped ),
        .xdma_rx_axis_tdata (xdma_rx_axis_tdata_piped ),
        .xdma_rx_axis_tkeep (xdma_rx_axis_tkeep_piped ),
        .xdma_rx_axis_tuser (xdma_rx_axis_tuser_piped ),

        .xdma_tx_axis_tvalid(xdma_tx_axis_tvalid_piped),
        .xdma_tx_axis_tready(xdma_tx_axis_tready_piped),
        .xdma_tx_axis_tlast (xdma_tx_axis_tlast_piped ),
        .xdma_tx_axis_tdata (xdma_tx_axis_tdata_piped ),
        .xdma_tx_axis_tkeep (xdma_tx_axis_tkeep_piped ),
        .xdma_tx_axis_tuser (xdma_tx_axis_tuser_piped ),

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