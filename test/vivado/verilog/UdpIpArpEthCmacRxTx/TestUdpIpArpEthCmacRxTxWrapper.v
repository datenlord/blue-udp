`timescale 1ps / 1ps

module TestUdpIpArpEthCmacRxTxWrapper();
    localparam GT_LANE_WIDTH = 4;
    localparam UDP_CONFIG_WIDTH = 144;
    localparam UDP_IP_META_WIDTH = 88;
    localparam DATA_STREAM_WIDTH = 290;

    wire udp_clk;
    wire udp_reset;

    wire gt_ref_clk_p;
    wire gt_ref_clk_n;
    wire init_clk;
    wire sys_reset;

	wire [UDP_CONFIG_WIDTH - 1 : 0] udpConfig_put;
	wire EN_udpConfig_put;
	wire RDY_udpConfig_put;

	wire [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataInTx_put;
	wire EN_udpIpMetaDataInTx_put;
	wire RDY_udpIpMetaDataInTx_put;

	wire [DATA_STREAM_WIDTH - 1 : 0] dataStreamInTx_put;
	wire EN_dataStreamInTx_put;
	wire RDY_dataStreamInTx_put;

	wire EN_udpIpMetaDataOutRx_get;
	wire RDY_udpIpMetaDataOutRx_get;
    wire [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataOutRx_get;

	wire EN_dataStreamOutRx_get;
	wire RDY_dataStreamOutRx_get;
    wire [DATA_STREAM_WIDTH - 1 : 0] dataStreamOutRx_get;

    wire [GT_LANE_WIDTH - 1 : 0] gt_n_loop, gt_p_loop;


    mkTestUdpIpArpEthCmacRxTxWithClkRst testbench(

        .EN_udpConfig_get(RDY_udpConfig_put & EN_udpConfig_put),
		.udpConfig_get(udpConfig_put),
		.RDY_udpConfig_get(EN_udpConfig_put),

		.EN_udpIpMetaDataOutTx_get(RDY_udpIpMetaDataInTx_put & EN_udpIpMetaDataInTx_put),
        .udpIpMetaDataOutTx_get(udpIpMetaDataInTx_put),
        .RDY_udpIpMetaDataOutTx_get(EN_udpIpMetaDataInTx_put),

        .EN_dataStreamOutTx_get(RDY_dataStreamInTx_put & EN_dataStreamInTx_put),
        .dataStreamOutTx_get(dataStreamInTx_put),
        .RDY_dataStreamOutTx_get(EN_dataStreamInTx_put),

        .udpIpMetaDataInRx_put(udpIpMetaDataOutRx_get),
        .EN_udpIpMetaDataInRx_put(RDY_udpIpMetaDataOutRx_get & EN_udpIpMetaDataOutRx_get),
        .RDY_udpIpMetaDataInRx_put(EN_udpIpMetaDataOutRx_get),

        .dataStreamInRx_put(dataStreamOutRx_get),
        .EN_dataStreamInRx_put(RDY_dataStreamOutRx_get & EN_dataStreamOutRx_get),
        .RDY_dataStreamInRx_put(EN_dataStreamOutRx_get),


        .gt_ref_clk_p(gt_ref_clk_p),
        .gate_gt_ref_clk_p(),

        .gt_ref_clk_n(gt_ref_clk_n),
        .gate_gt_ref_clk_n(),

        .init_clk(init_clk),
        .gate_init_clk(),

        .udp_clk(udp_clk),
        .gate_udp_clk(),

        .sys_reset(sys_reset),
        .udp_reset(udp_reset)
    );

    UdpIpArpEthCmacRxTxWrapper dut_wrapper(
        .udp_clk(udp_clk),
        .udp_reset(udp_reset),

        .gt_ref_clk_p(gt_ref_clk_p),
        .gt_ref_clk_n(gt_ref_clk_n),
        .init_clk(init_clk),
        .sys_reset(sys_reset),

	    .udpConfig_put(udpConfig_put),
	    .EN_udpConfig_put(EN_udpConfig_put & RDY_udpConfig_put),
	    .RDY_udpConfig_put(RDY_udpConfig_put),

	    .udpIpMetaDataInTx_put(udpIpMetaDataInTx_put),
	    .EN_udpIpMetaDataInTx_put(EN_udpIpMetaDataInTx_put & RDY_udpIpMetaDataInTx_put),
	    .RDY_udpIpMetaDataInTx_put(RDY_udpIpMetaDataInTx_put),

	    .dataStreamInTx_put(dataStreamInTx_put),
	    .EN_dataStreamInTx_put(EN_dataStreamInTx_put & RDY_dataStreamInTx_put),
	    .RDY_dataStreamInTx_put(RDY_dataStreamInTx_put),

	    .EN_udpIpMetaDataOutRx_get(EN_udpIpMetaDataOutRx_get & RDY_udpIpMetaDataOutRx_get),
	    .RDY_udpIpMetaDataOutRx_get(RDY_udpIpMetaDataOutRx_get),
        .udpIpMetaDataOutRx_get(udpIpMetaDataOutRx_get),

	    .EN_dataStreamOutRx_get(EN_dataStreamOutRx_get & RDY_dataStreamOutRx_get),
	    .RDY_dataStreamOutRx_get(RDY_dataStreamOutRx_get),
        .dataStreamOutRx_get(dataStreamOutRx_get),

        .gt_rxn_in (gt_n_loop),
        .gt_rxp_in (gt_p_loop),
        .gt_txn_out(gt_n_loop),
        .gt_txp_out(gt_p_loop)
    );
endmodule
