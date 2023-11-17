`timescale 1ps / 1ps

module TestUdpIpArpEthCmacRxTxWrapper();
    localparam GT_LANE_WIDTH = 4;
    localparam XDMA_AXIS_TDATA_WIDTH = 512;
    localparam XDMA_AXIS_TKEEP_WIDTH = 64;
    localparam XDMA_AXIS_TUSER_WIDTH = 1;

    // wire udp_clk;
    // wire udp_reset;

    // wire gt_ref_clk_p;
    // wire gt_ref_clk_n;
    // wire gt_init_clk;
    // wire gt_sys_reset;

    reg udp_clk;
    reg udp_reset;
    reg gt_ref_clk_p;
    reg gt_ref_clk_n;
    reg gt_init_clk;
    reg gt_sys_reset;

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

    wire [GT_LANE_WIDTH - 1 : 0] gt1_rx_n, gt1_rx_p, gt1_tx_n, gt1_tx_p;


    UdpIpArpEthCmacRxTxWrapper#(
        GT_LANE_WIDTH, 
        XDMA_AXIS_TDATA_WIDTH,
        XDMA_AXIS_TKEEP_WIDTH,
        XDMA_AXIS_TUSER_WIDTH
    ) udp_cmac_inst1(
        .udp_clk   (  udp_clk),
        .udp_reset (udp_reset),

        .gt_ref_clk_p(gt_ref_clk_p),
        .gt_ref_clk_n(gt_ref_clk_n),
        .gt_init_clk (gt_init_clk    ),
        .gt_sys_reset(gt_sys_reset   ),

        .xdma_rx_axis_tready(1'b0),
        .xdma_rx_axis_tvalid(),
        .xdma_rx_axis_tdata (),
        .xdma_rx_axis_tkeep (),
        .xdma_rx_axis_tlast (),
        .xdma_rx_axis_tuser (),

        .xdma_tx_axis_tvalid(xdma_tx_axis_tvalid),
        .xdma_tx_axis_tready(xdma_tx_axis_tready),
        .xdma_tx_axis_tlast (xdma_tx_axis_tlast),
        .xdma_tx_axis_tdata (xdma_tx_axis_tdata),
        .xdma_tx_axis_tkeep (xdma_tx_axis_tkeep),
        .xdma_tx_axis_tuser (xdma_tx_axis_tuser),

        // Serdes
        .gt_rxn_in (gt1_rx_n),
        .gt_rxp_in (gt1_rx_p),
        .gt_txn_out(gt1_tx_n),
        .gt_txp_out(gt1_tx_p)
    );

    UdpIpArpEthCmacRxTxWrapper#(
        GT_LANE_WIDTH, 
        XDMA_AXIS_TDATA_WIDTH,
        XDMA_AXIS_TKEEP_WIDTH,
        XDMA_AXIS_TUSER_WIDTH
    ) udp_cmac_inst2(
        .udp_clk   (  udp_clk),
        .udp_reset (udp_reset),

        .gt_ref_clk_p(gt_ref_clk_p),
        .gt_ref_clk_n(gt_ref_clk_n),
        .gt_init_clk (gt_init_clk ),
        .gt_sys_reset(gt_sys_reset),

        .xdma_rx_axis_tready(xdma_rx_axis_tready),
        .xdma_rx_axis_tvalid(xdma_rx_axis_tvalid),
        .xdma_rx_axis_tdata (xdma_rx_axis_tdata),
        .xdma_rx_axis_tkeep (xdma_rx_axis_tkeep),
        .xdma_rx_axis_tlast (xdma_rx_axis_tlast),
        .xdma_rx_axis_tuser (xdma_rx_axis_tuser),

        .xdma_tx_axis_tvalid(1'b0),
        .xdma_tx_axis_tready( ),
        .xdma_tx_axis_tlast (0),
        .xdma_tx_axis_tdata (0),
        .xdma_tx_axis_tkeep (0),
        .xdma_tx_axis_tuser (0),

        // Serdes
        .gt_rxn_in (gt1_tx_n),
        .gt_rxp_in (gt1_tx_p),
        .gt_txn_out(gt1_rx_n),
        .gt_txp_out(gt1_rx_p)
    );

    mkTestXdmaUdpIpArpEthRxTx testbench (
        
        .xdma_rx_axis_tready(xdma_rx_axis_tready),
        .xdma_rx_axis_tvalid(xdma_rx_axis_tvalid),
        .xdma_rx_axis_tdata (xdma_rx_axis_tdata),
        .xdma_rx_axis_tkeep (xdma_rx_axis_tkeep),
        .xdma_rx_axis_tlast (xdma_rx_axis_tlast),
        .xdma_rx_axis_tuser (xdma_rx_axis_tuser),

        .xdma_tx_axis_tvalid(xdma_tx_axis_tvalid),
        .xdma_tx_axis_tready(xdma_tx_axis_tready),
        .xdma_tx_axis_tlast (xdma_tx_axis_tlast),
        .xdma_tx_axis_tdata (xdma_tx_axis_tdata),
        .xdma_tx_axis_tkeep (xdma_tx_axis_tkeep),
        .xdma_tx_axis_tuser (xdma_tx_axis_tuser),

        .CLK(udp_clk),
        .RST_N(udp_reset)
    );

    initial
    begin
        gt_ref_clk_p =1;
        forever #3200 gt_ref_clk_p = ~ gt_ref_clk_p;
    end

    initial
    begin
        gt_ref_clk_n =0;
        forever #3200 gt_ref_clk_n = ~ gt_ref_clk_n;
    end

    initial
    begin
        udp_clk =0;
        forever #1000 udp_clk = ~udp_clk;
    end

    initial
    begin
        udp_reset = 0;
        #201000;
        udp_reset = 1;
    end

    initial
    begin
        gt_init_clk = 0;
        forever #5000 gt_init_clk = ~gt_init_clk;
    end

    initial
    begin
        gt_sys_reset = 1;
        #1001000;
        gt_sys_reset = 0;
    end
endmodule
