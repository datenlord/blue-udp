
`timescale 1ps / 1ps

module TestUdpBypassRxTxWrapper();
    localparam GT_LANE_WIDTH = 4;
    localparam XDMA_AXIS_TDATA_WIDTH = 512;
    localparam XDMA_AXIS_TKEEP_WIDTH = 64;
    localparam XDMA_AXIS_TUSER_WIDTH = 1;

    // Clock Period (ps)
    localparam UDP_CLK_HALF_PERIOD     = 2000; // 500MHz
    localparam XDMA_CLK_HALF_PERIOD    = 2000; // 250MHz
    localparam GT_INIT_CLK_HALF_PERIOD = 5000; // 100MHz
    localparam GT_REF_CLK_HALF_PERIOD  = 3200; // 151MHz
    
    localparam GT_SYS_RST_CYCLE        = 100;
    localparam UDP_RST_CYCLE           = 100;
    localparam XDMA_RST_CYCLE          = 100;


    // wire udp_clk;
    // wire udp_reset;

    // wire gt_ref_clk_p;
    // wire gt_ref_clk_n;
    // wire gt_init_clk;
    // wire gt_sys_reset;

    reg udp_clk;
    reg udp_reset;

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

    wire cmac_axis_tready;
    wire cmac_axis_tvalid;
    wire cmac_axis_tlast;
    wire [XDMA_AXIS_TDATA_WIDTH - 1 : 0] cmac_axis_tdata;
    wire [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] cmac_axis_tkeep;
    wire [XDMA_AXIS_TUSER_WIDTH - 1 : 0] cmac_axis_tuser;

    mkRawUdpIpEthBypassRxTxForXdma dut_inst(
        .CLK(udp_clk),
        .RST_N(udp_reset),

        .xdmaAxiStreamTxIn_tvalid (xdma_tx_axis_tvalid),
        .xdmaAxiStreamTxIn_tdata  (xdma_tx_axis_tdata ),
        .xdmaAxiStreamTxIn_tkeep  (xdma_tx_axis_tkeep ),
        .xdmaAxiStreamTxIn_tlast  (xdma_tx_axis_tlast ),
        .xdmaAxiStreamTxIn_tuser  (xdma_tx_axis_tuser ),
        .xdmaAxiStreamTxIn_tready (xdma_tx_axis_tready),
        
        .xdmaAxiStreamRxOut_tvalid(xdma_rx_axis_tvalid),
        .xdmaAxiStreamRxOut_tdata (xdma_rx_axis_tdata ),
        .xdmaAxiStreamRxOut_tkeep (xdma_rx_axis_tkeep ),
        .xdmaAxiStreamRxOut_tlast (xdma_rx_axis_tlast ),
        .xdmaAxiStreamRxOut_tuser (xdma_rx_axis_tuser ),
        .xdmaAxiStreamRxOut_tready(xdma_rx_axis_tready),
        
        .cmacAxiStreamRxIn_tvalid (cmac_axis_tvalid),
        .cmacAxiStreamRxIn_tdata  (cmac_axis_tdata ),
        .cmacAxiStreamRxIn_tkeep  (cmac_axis_tkeep ),
        .cmacAxiStreamRxIn_tlast  (cmac_axis_tlast ),
        .cmacAxiStreamRxIn_tuser  (cmac_axis_tuser ),
        .cmacAxiStreamRxIn_tready (cmac_axis_tready),
        
        .cmacAxiStreamTxOut_tvalid(cmac_axis_tvalid),
        .cmacAxiStreamTxOut_tdata (cmac_axis_tdata ),
        .cmacAxiStreamTxOut_tkeep (cmac_axis_tkeep ),
        .cmacAxiStreamTxOut_tlast (cmac_axis_tlast ),
        .cmacAxiStreamTxOut_tuser (cmac_axis_tuser ),
        .cmacAxiStreamTxOut_tready(cmac_axis_tready)
    );

    mkTestUdpCmacRxTx testbench (
        
        .xdma_rx_axis_tready(xdma_rx_axis_tready),
        .xdma_rx_axis_tvalid(xdma_rx_axis_tvalid),
        .xdma_rx_axis_tdata (xdma_rx_axis_tdata ),
        .xdma_rx_axis_tkeep (xdma_rx_axis_tkeep ),
        .xdma_rx_axis_tlast (xdma_rx_axis_tlast ),
        .xdma_rx_axis_tuser (xdma_rx_axis_tuser ),

        .xdma_tx_axis_tvalid(xdma_tx_axis_tvalid),
        .xdma_tx_axis_tready(xdma_tx_axis_tready),
        .xdma_tx_axis_tlast (xdma_tx_axis_tlast),
        .xdma_tx_axis_tdata (xdma_tx_axis_tdata),
        .xdma_tx_axis_tkeep (xdma_tx_axis_tkeep),
        .xdma_tx_axis_tuser (xdma_tx_axis_tuser),

        .CLK  (udp_clk  ),
        .RST_N(udp_reset)
    );

    initial begin
        udp_clk =0;
        forever #UDP_CLK_HALF_PERIOD udp_clk = ~udp_clk;
    end

    initial begin
        udp_reset = 0;
        #(2 * UDP_CLK_HALF_PERIOD * UDP_RST_CYCLE);
        udp_reset = 1;
    end


endmodule

