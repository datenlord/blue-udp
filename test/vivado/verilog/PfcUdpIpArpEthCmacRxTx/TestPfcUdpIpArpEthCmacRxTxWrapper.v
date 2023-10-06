`timescale 1ps / 1ps

module TestPfcUdpIpArpEthCmacRxTxWrapper();

    localparam CHANNEL_NUM = 8;
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

	wire [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataInTxVec_put[CHANNEL_NUM - 1 : 0];
	wire EN_udpIpMetaDataInTxVec_put[CHANNEL_NUM - 1 : 0];
	wire RDY_udpIpMetaDataInTxVec_put[CHANNEL_NUM - 1 : 0];

	wire [DATA_STREAM_WIDTH - 1 : 0] dataStreamInTxVec_put[CHANNEL_NUM - 1 : 0];
	wire EN_dataStreamInTxVec_put[CHANNEL_NUM - 1 : 0];
	wire RDY_dataStreamInTxVec_put[CHANNEL_NUM - 1 : 0];

	wire EN_udpIpMetaDataOutRxVec_get[CHANNEL_NUM - 1 : 0];
	wire RDY_udpIpMetaDataOutRxVec_get[CHANNEL_NUM - 1 : 0];
    wire [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataOutRxVec_get[CHANNEL_NUM - 1 : 0];

	wire EN_dataStreamOutRxVec_get[CHANNEL_NUM - 1 : 0];
	wire RDY_dataStreamOutRxVec_get[CHANNEL_NUM - 1 : 0];
    wire [DATA_STREAM_WIDTH - 1 : 0] dataStreamOutRxVec_get[CHANNEL_NUM - 1 : 0];

    wire [GT_LANE_WIDTH - 1 : 0] gt_n_loop, gt_p_loop;


    mkTestPfcUdpIpArpEthCmacRxTxWithClkRst testbench(

        .EN_udpConfig_get(RDY_udpConfig_put & EN_udpConfig_put),
		.udpConfig_get(udpConfig_put),
		.RDY_udpConfig_get(EN_udpConfig_put),

        // channel 0
		.EN_udpIpMetaDataOutTxVec_0_get(RDY_udpIpMetaDataInTxVec_put[0] & EN_udpIpMetaDataInTxVec_put[0]),
        .udpIpMetaDataOutTxVec_0_get(udpIpMetaDataInTxVec_put[0]),
        .RDY_udpIpMetaDataOutTxVec_0_get(EN_udpIpMetaDataInTxVec_put[0]),

        .EN_dataStreamOutTxVec_0_get(RDY_dataStreamInTxVec_put[0] & EN_dataStreamInTxVec_put[0]),
        .dataStreamOutTxVec_0_get(dataStreamInTxVec_put[0]),
        .RDY_dataStreamOutTxVec_0_get(EN_dataStreamInTxVec_put[0]),

        .udpIpMetaDataInRxVec_0_put(udpIpMetaDataOutRxVec_get[0]),
        .EN_udpIpMetaDataInRxVec_0_put(RDY_udpIpMetaDataOutRxVec_get[0] & EN_udpIpMetaDataOutRxVec_get[0]),
        .RDY_udpIpMetaDataInRxVec_0_put(EN_udpIpMetaDataOutRxVec_get[0]),

        .dataStreamInRxVec_0_put(dataStreamOutRxVec_get[0]),
        .EN_dataStreamInRxVec_0_put(RDY_dataStreamOutRxVec_get[0] & EN_dataStreamOutRxVec_get[0]),
        .RDY_dataStreamInRxVec_0_put(EN_dataStreamOutRxVec_get[0]),

        // channel 1
		.EN_udpIpMetaDataOutTxVec_1_get(RDY_udpIpMetaDataInTxVec_put[1] & EN_udpIpMetaDataInTxVec_put[1]),
        .udpIpMetaDataOutTxVec_1_get(udpIpMetaDataInTxVec_put[1]),
        .RDY_udpIpMetaDataOutTxVec_1_get(EN_udpIpMetaDataInTxVec_put[1]),

        .EN_dataStreamOutTxVec_1_get(RDY_dataStreamInTxVec_put[1] & EN_dataStreamInTxVec_put[1]),
        .dataStreamOutTxVec_1_get(dataStreamInTxVec_put[1]),
        .RDY_dataStreamOutTxVec_1_get(EN_dataStreamInTxVec_put[1]),

        .udpIpMetaDataInRxVec_1_put(udpIpMetaDataOutRxVec_get[1]),
        .EN_udpIpMetaDataInRxVec_1_put(RDY_udpIpMetaDataOutRxVec_get[1] & EN_udpIpMetaDataOutRxVec_get[1]),
        .RDY_udpIpMetaDataInRxVec_1_put(EN_udpIpMetaDataOutRxVec_get[1]),

        .dataStreamInRxVec_1_put(dataStreamOutRxVec_get[1]),
        .EN_dataStreamInRxVec_1_put(RDY_dataStreamOutRxVec_get[1] & EN_dataStreamOutRxVec_get[1]),
        .RDY_dataStreamInRxVec_1_put(EN_dataStreamOutRxVec_get[1]),

        // channel 2
		.EN_udpIpMetaDataOutTxVec_2_get(RDY_udpIpMetaDataInTxVec_put[2] & EN_udpIpMetaDataInTxVec_put[2]),
        .udpIpMetaDataOutTxVec_2_get(udpIpMetaDataInTxVec_put[2]),
        .RDY_udpIpMetaDataOutTxVec_2_get(EN_udpIpMetaDataInTxVec_put[2]),

        .EN_dataStreamOutTxVec_2_get(RDY_dataStreamInTxVec_put[2] & EN_dataStreamInTxVec_put[2]),
        .dataStreamOutTxVec_2_get(dataStreamInTxVec_put[2]),
        .RDY_dataStreamOutTxVec_2_get(EN_dataStreamInTxVec_put[2]),

        .udpIpMetaDataInRxVec_2_put(udpIpMetaDataOutRxVec_get[2]),
        .EN_udpIpMetaDataInRxVec_2_put(RDY_udpIpMetaDataOutRxVec_get[2] & EN_udpIpMetaDataOutRxVec_get[2]),
        .RDY_udpIpMetaDataInRxVec_2_put(EN_udpIpMetaDataOutRxVec_get[2]),

        .dataStreamInRxVec_2_put(dataStreamOutRxVec_get[2]),
        .EN_dataStreamInRxVec_2_put(RDY_dataStreamOutRxVec_get[2] & EN_dataStreamOutRxVec_get[2]),
        .RDY_dataStreamInRxVec_2_put(EN_dataStreamOutRxVec_get[2]),

        // channel 3
		.EN_udpIpMetaDataOutTxVec_3_get(RDY_udpIpMetaDataInTxVec_put[3] & EN_udpIpMetaDataInTxVec_put[3]),
        .udpIpMetaDataOutTxVec_3_get(udpIpMetaDataInTxVec_put[3]),
        .RDY_udpIpMetaDataOutTxVec_3_get(EN_udpIpMetaDataInTxVec_put[3]),

        .EN_dataStreamOutTxVec_3_get(RDY_dataStreamInTxVec_put[3] & EN_dataStreamInTxVec_put[3]),
        .dataStreamOutTxVec_3_get(dataStreamInTxVec_put[3]),
        .RDY_dataStreamOutTxVec_3_get(EN_dataStreamInTxVec_put[3]),

        .udpIpMetaDataInRxVec_3_put(udpIpMetaDataOutRxVec_get[3]),
        .EN_udpIpMetaDataInRxVec_3_put(RDY_udpIpMetaDataOutRxVec_get[3] & EN_udpIpMetaDataOutRxVec_get[3]),
        .RDY_udpIpMetaDataInRxVec_3_put(EN_udpIpMetaDataOutRxVec_get[3]),

        .dataStreamInRxVec_3_put(dataStreamOutRxVec_get[3]),
        .EN_dataStreamInRxVec_3_put(RDY_dataStreamOutRxVec_get[3] & EN_dataStreamOutRxVec_get[3]),
        .RDY_dataStreamInRxVec_3_put(EN_dataStreamOutRxVec_get[3]),

        // channel 4
		.EN_udpIpMetaDataOutTxVec_4_get(RDY_udpIpMetaDataInTxVec_put[4] & EN_udpIpMetaDataInTxVec_put[4]),
        .udpIpMetaDataOutTxVec_4_get(udpIpMetaDataInTxVec_put[4]),
        .RDY_udpIpMetaDataOutTxVec_4_get(EN_udpIpMetaDataInTxVec_put[4]),

        .EN_dataStreamOutTxVec_4_get(RDY_dataStreamInTxVec_put[4] & EN_dataStreamInTxVec_put[4]),
        .dataStreamOutTxVec_4_get(dataStreamInTxVec_put[4]),
        .RDY_dataStreamOutTxVec_4_get(EN_dataStreamInTxVec_put[4]),

        .udpIpMetaDataInRxVec_4_put(udpIpMetaDataOutRxVec_get[4]),
        .EN_udpIpMetaDataInRxVec_4_put(RDY_udpIpMetaDataOutRxVec_get[4] & EN_udpIpMetaDataOutRxVec_get[4]),
        .RDY_udpIpMetaDataInRxVec_4_put(EN_udpIpMetaDataOutRxVec_get[4]),

        .dataStreamInRxVec_4_put(dataStreamOutRxVec_get[4]),
        .EN_dataStreamInRxVec_4_put(RDY_dataStreamOutRxVec_get[4] & EN_dataStreamOutRxVec_get[4]),
        .RDY_dataStreamInRxVec_4_put(EN_dataStreamOutRxVec_get[4]),

        // channel 5
		.EN_udpIpMetaDataOutTxVec_5_get(RDY_udpIpMetaDataInTxVec_put[5] & EN_udpIpMetaDataInTxVec_put[5]),
        .udpIpMetaDataOutTxVec_5_get(udpIpMetaDataInTxVec_put[5]),
        .RDY_udpIpMetaDataOutTxVec_5_get(EN_udpIpMetaDataInTxVec_put[5]),

        .EN_dataStreamOutTxVec_5_get(RDY_dataStreamInTxVec_put[5] & EN_dataStreamInTxVec_put[5]),
        .dataStreamOutTxVec_5_get(dataStreamInTxVec_put[5]),
        .RDY_dataStreamOutTxVec_5_get(EN_dataStreamInTxVec_put[5]),

        .udpIpMetaDataInRxVec_5_put(udpIpMetaDataOutRxVec_get[5]),
        .EN_udpIpMetaDataInRxVec_5_put(RDY_udpIpMetaDataOutRxVec_get[5] & EN_udpIpMetaDataOutRxVec_get[5]),
        .RDY_udpIpMetaDataInRxVec_5_put(EN_udpIpMetaDataOutRxVec_get[5]),

        .dataStreamInRxVec_5_put(dataStreamOutRxVec_get[5]),
        .EN_dataStreamInRxVec_5_put(RDY_dataStreamOutRxVec_get[5] & EN_dataStreamOutRxVec_get[5]),
        .RDY_dataStreamInRxVec_5_put(EN_dataStreamOutRxVec_get[5]),

        // channel 6
		.EN_udpIpMetaDataOutTxVec_6_get(RDY_udpIpMetaDataInTxVec_put[6] & EN_udpIpMetaDataInTxVec_put[6]),
        .udpIpMetaDataOutTxVec_6_get(udpIpMetaDataInTxVec_put[6]),
        .RDY_udpIpMetaDataOutTxVec_6_get(EN_udpIpMetaDataInTxVec_put[6]),

        .EN_dataStreamOutTxVec_6_get(RDY_dataStreamInTxVec_put[6] & EN_dataStreamInTxVec_put[6]),
        .dataStreamOutTxVec_6_get(dataStreamInTxVec_put[6]),
        .RDY_dataStreamOutTxVec_6_get(EN_dataStreamInTxVec_put[6]),

        .udpIpMetaDataInRxVec_6_put(udpIpMetaDataOutRxVec_get[6]),
        .EN_udpIpMetaDataInRxVec_6_put(RDY_udpIpMetaDataOutRxVec_get[6] & EN_udpIpMetaDataOutRxVec_get[6]),
        .RDY_udpIpMetaDataInRxVec_6_put(EN_udpIpMetaDataOutRxVec_get[6]),

        .dataStreamInRxVec_6_put(dataStreamOutRxVec_get[6]),
        .EN_dataStreamInRxVec_6_put(RDY_dataStreamOutRxVec_get[6] & EN_dataStreamOutRxVec_get[6]),
        .RDY_dataStreamInRxVec_6_put(EN_dataStreamOutRxVec_get[6]),

        // channel 7
		.EN_udpIpMetaDataOutTxVec_7_get(RDY_udpIpMetaDataInTxVec_put[7] & EN_udpIpMetaDataInTxVec_put[7]),
        .udpIpMetaDataOutTxVec_7_get(udpIpMetaDataInTxVec_put[7]),
        .RDY_udpIpMetaDataOutTxVec_7_get(EN_udpIpMetaDataInTxVec_put[7]),

        .EN_dataStreamOutTxVec_7_get(RDY_dataStreamInTxVec_put[7] & EN_dataStreamInTxVec_put[7]),
        .dataStreamOutTxVec_7_get(dataStreamInTxVec_put[7]),
        .RDY_dataStreamOutTxVec_7_get(EN_dataStreamInTxVec_put[7]),

        .udpIpMetaDataInRxVec_7_put(udpIpMetaDataOutRxVec_get[7]),
        .EN_udpIpMetaDataInRxVec_7_put(RDY_udpIpMetaDataOutRxVec_get[7] & EN_udpIpMetaDataOutRxVec_get[7]),
        .RDY_udpIpMetaDataInRxVec_7_put(EN_udpIpMetaDataOutRxVec_get[7]),

        .dataStreamInRxVec_7_put(dataStreamOutRxVec_get[7]),
        .EN_dataStreamInRxVec_7_put(RDY_dataStreamOutRxVec_get[7] & EN_dataStreamOutRxVec_get[7]),
        .RDY_dataStreamInRxVec_7_put(EN_dataStreamOutRxVec_get[7]),


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

    PfcUdpIpArpEthCmacRxTxWrapper dut_wrapper(
        .udp_clk(udp_clk),
        .udp_reset(udp_reset),

        .gt_ref_clk_p(gt_ref_clk_p),
        .gt_ref_clk_n(gt_ref_clk_n),
        .init_clk(init_clk),
        .sys_reset(sys_reset),

	    .udpConfig_put(udpConfig_put),
	    .EN_udpConfig_put(EN_udpConfig_put & RDY_udpConfig_put),
	    .RDY_udpConfig_put(RDY_udpConfig_put),


        // channel 0
	    .udpIpMetaDataInTxVec_0_put(udpIpMetaDataInTxVec_put[0]),
	    .EN_udpIpMetaDataInTxVec_0_put(EN_udpIpMetaDataInTxVec_put[0] & RDY_udpIpMetaDataInTxVec_put[0]),
	    .RDY_udpIpMetaDataInTxVec_0_put(RDY_udpIpMetaDataInTxVec_put[0]),

	    .dataStreamInTxVec_0_put(dataStreamInTxVec_put[0]),
	    .EN_dataStreamInTxVec_0_put(EN_dataStreamInTxVec_put[0] & RDY_dataStreamInTxVec_put[0]),
	    .RDY_dataStreamInTxVec_0_put(RDY_dataStreamInTxVec_put[0]),

	    .EN_udpIpMetaDataOutRxVec_0_get(EN_udpIpMetaDataOutRxVec_get[0] & RDY_udpIpMetaDataOutRxVec_get[0]),
	    .RDY_udpIpMetaDataOutRxVec_0_get(RDY_udpIpMetaDataOutRxVec_get[0]),
        .udpIpMetaDataOutRxVec_0_get(udpIpMetaDataOutRxVec_get[0]),

	    .EN_dataStreamOutRxVec_0_get(EN_dataStreamOutRxVec_get[0] & RDY_dataStreamOutRxVec_get[0]),
	    .RDY_dataStreamOutRxVec_0_get(RDY_dataStreamOutRxVec_get[0]),
        .dataStreamOutRxVec_0_get(dataStreamOutRxVec_get[0]),

        // channel 1
	    .udpIpMetaDataInTxVec_1_put(udpIpMetaDataInTxVec_put[1]),
	    .EN_udpIpMetaDataInTxVec_1_put(EN_udpIpMetaDataInTxVec_put[1] & RDY_udpIpMetaDataInTxVec_put[1]),
	    .RDY_udpIpMetaDataInTxVec_1_put(RDY_udpIpMetaDataInTxVec_put[1]),

	    .dataStreamInTxVec_1_put(dataStreamInTxVec_put[1]),
	    .EN_dataStreamInTxVec_1_put(EN_dataStreamInTxVec_put[1] & RDY_dataStreamInTxVec_put[1]),
	    .RDY_dataStreamInTxVec_1_put(RDY_dataStreamInTxVec_put[1]),

	    .EN_udpIpMetaDataOutRxVec_1_get(EN_udpIpMetaDataOutRxVec_get[1] & RDY_udpIpMetaDataOutRxVec_get[1]),
	    .RDY_udpIpMetaDataOutRxVec_1_get(RDY_udpIpMetaDataOutRxVec_get[1]),
        .udpIpMetaDataOutRxVec_1_get(udpIpMetaDataOutRxVec_get[1]),

	    .EN_dataStreamOutRxVec_1_get(EN_dataStreamOutRxVec_get[1] & RDY_dataStreamOutRxVec_get[1]),
	    .RDY_dataStreamOutRxVec_1_get(RDY_dataStreamOutRxVec_get[1]),
        .dataStreamOutRxVec_1_get(dataStreamOutRxVec_get[1]),

        // channel 2
	    .udpIpMetaDataInTxVec_2_put(udpIpMetaDataInTxVec_put[2]),
	    .EN_udpIpMetaDataInTxVec_2_put(EN_udpIpMetaDataInTxVec_put[2] & RDY_udpIpMetaDataInTxVec_put[2]),
	    .RDY_udpIpMetaDataInTxVec_2_put(RDY_udpIpMetaDataInTxVec_put[2]),

	    .dataStreamInTxVec_2_put(dataStreamInTxVec_put[2]),
	    .EN_dataStreamInTxVec_2_put(EN_dataStreamInTxVec_put[2] & RDY_dataStreamInTxVec_put[2]),
	    .RDY_dataStreamInTxVec_2_put(RDY_dataStreamInTxVec_put[2]),

	    .EN_udpIpMetaDataOutRxVec_2_get(EN_udpIpMetaDataOutRxVec_get[2] & RDY_udpIpMetaDataOutRxVec_get[2]),
	    .RDY_udpIpMetaDataOutRxVec_2_get(RDY_udpIpMetaDataOutRxVec_get[2]),
        .udpIpMetaDataOutRxVec_2_get(udpIpMetaDataOutRxVec_get[2]),

	    .EN_dataStreamOutRxVec_2_get(EN_dataStreamOutRxVec_get[2] & RDY_dataStreamOutRxVec_get[2]),
	    .RDY_dataStreamOutRxVec_2_get(RDY_dataStreamOutRxVec_get[2]),
        .dataStreamOutRxVec_2_get(dataStreamOutRxVec_get[2]),

        // channel 3
	    .udpIpMetaDataInTxVec_3_put(udpIpMetaDataInTxVec_put[3]),
	    .EN_udpIpMetaDataInTxVec_3_put(EN_udpIpMetaDataInTxVec_put[3] & RDY_udpIpMetaDataInTxVec_put[3]),
	    .RDY_udpIpMetaDataInTxVec_3_put(RDY_udpIpMetaDataInTxVec_put[3]),

	    .dataStreamInTxVec_3_put(dataStreamInTxVec_put[3]),
	    .EN_dataStreamInTxVec_3_put(EN_dataStreamInTxVec_put[3] & RDY_dataStreamInTxVec_put[3]),
	    .RDY_dataStreamInTxVec_3_put(RDY_dataStreamInTxVec_put[3]),

	    .EN_udpIpMetaDataOutRxVec_3_get(EN_udpIpMetaDataOutRxVec_get[3] & RDY_udpIpMetaDataOutRxVec_get[3]),
	    .RDY_udpIpMetaDataOutRxVec_3_get(RDY_udpIpMetaDataOutRxVec_get[3]),
        .udpIpMetaDataOutRxVec_3_get(udpIpMetaDataOutRxVec_get[3]),

	    .EN_dataStreamOutRxVec_3_get(EN_dataStreamOutRxVec_get[3] & RDY_dataStreamOutRxVec_get[3]),
	    .RDY_dataStreamOutRxVec_3_get(RDY_dataStreamOutRxVec_get[3]),
        .dataStreamOutRxVec_3_get(dataStreamOutRxVec_get[3]),

        // channel 4
	    .udpIpMetaDataInTxVec_4_put(udpIpMetaDataInTxVec_put[4]),
	    .EN_udpIpMetaDataInTxVec_4_put(EN_udpIpMetaDataInTxVec_put[4] & RDY_udpIpMetaDataInTxVec_put[4]),
	    .RDY_udpIpMetaDataInTxVec_4_put(RDY_udpIpMetaDataInTxVec_put[4]),

	    .dataStreamInTxVec_4_put(dataStreamInTxVec_put[4]),
	    .EN_dataStreamInTxVec_4_put(EN_dataStreamInTxVec_put[4] & RDY_dataStreamInTxVec_put[4]),
	    .RDY_dataStreamInTxVec_4_put(RDY_dataStreamInTxVec_put[4]),

	    .EN_udpIpMetaDataOutRxVec_4_get(EN_udpIpMetaDataOutRxVec_get[4] & RDY_udpIpMetaDataOutRxVec_get[4]),
	    .RDY_udpIpMetaDataOutRxVec_4_get(RDY_udpIpMetaDataOutRxVec_get[4]),
        .udpIpMetaDataOutRxVec_4_get(udpIpMetaDataOutRxVec_get[4]),

	    .EN_dataStreamOutRxVec_4_get(EN_dataStreamOutRxVec_get[4] & RDY_dataStreamOutRxVec_get[4]),
	    .RDY_dataStreamOutRxVec_4_get(RDY_dataStreamOutRxVec_get[4]),
        .dataStreamOutRxVec_4_get(dataStreamOutRxVec_get[4]),

        // channel 5
	    .udpIpMetaDataInTxVec_5_put(udpIpMetaDataInTxVec_put[5]),
	    .EN_udpIpMetaDataInTxVec_5_put(EN_udpIpMetaDataInTxVec_put[5] & RDY_udpIpMetaDataInTxVec_put[5]),
	    .RDY_udpIpMetaDataInTxVec_5_put(RDY_udpIpMetaDataInTxVec_put[5]),

	    .dataStreamInTxVec_5_put(dataStreamInTxVec_put[5]),
	    .EN_dataStreamInTxVec_5_put(EN_dataStreamInTxVec_put[5] & RDY_dataStreamInTxVec_put[5]),
	    .RDY_dataStreamInTxVec_5_put(RDY_dataStreamInTxVec_put[5]),

	    .EN_udpIpMetaDataOutRxVec_5_get(EN_udpIpMetaDataOutRxVec_get[5] & RDY_udpIpMetaDataOutRxVec_get[5]),
	    .RDY_udpIpMetaDataOutRxVec_5_get(RDY_udpIpMetaDataOutRxVec_get[5]),
        .udpIpMetaDataOutRxVec_5_get(udpIpMetaDataOutRxVec_get[5]),

	    .EN_dataStreamOutRxVec_5_get(EN_dataStreamOutRxVec_get[5] & RDY_dataStreamOutRxVec_get[5]),
	    .RDY_dataStreamOutRxVec_5_get(RDY_dataStreamOutRxVec_get[5]),
        .dataStreamOutRxVec_5_get(dataStreamOutRxVec_get[5]),

        // channel 6
	    .udpIpMetaDataInTxVec_6_put(udpIpMetaDataInTxVec_put[6]),
	    .EN_udpIpMetaDataInTxVec_6_put(EN_udpIpMetaDataInTxVec_put[6] & RDY_udpIpMetaDataInTxVec_put[6]),
	    .RDY_udpIpMetaDataInTxVec_6_put(RDY_udpIpMetaDataInTxVec_put[6]),

	    .dataStreamInTxVec_6_put(dataStreamInTxVec_put[6]),
	    .EN_dataStreamInTxVec_6_put(EN_dataStreamInTxVec_put[6] & RDY_dataStreamInTxVec_put[6]),
	    .RDY_dataStreamInTxVec_6_put(RDY_dataStreamInTxVec_put[6]),

	    .EN_udpIpMetaDataOutRxVec_6_get(EN_udpIpMetaDataOutRxVec_get[6] & RDY_udpIpMetaDataOutRxVec_get[6]),
	    .RDY_udpIpMetaDataOutRxVec_6_get(RDY_udpIpMetaDataOutRxVec_get[6]),
        .udpIpMetaDataOutRxVec_6_get(udpIpMetaDataOutRxVec_get[6]),

	    .EN_dataStreamOutRxVec_6_get(EN_dataStreamOutRxVec_get[6] & RDY_dataStreamOutRxVec_get[6]),
	    .RDY_dataStreamOutRxVec_6_get(RDY_dataStreamOutRxVec_get[6]),
        .dataStreamOutRxVec_6_get(dataStreamOutRxVec_get[6]),

        // channel 7
	    .udpIpMetaDataInTxVec_7_put(udpIpMetaDataInTxVec_put[7]),
	    .EN_udpIpMetaDataInTxVec_7_put(EN_udpIpMetaDataInTxVec_put[7] & RDY_udpIpMetaDataInTxVec_put[7]),
	    .RDY_udpIpMetaDataInTxVec_7_put(RDY_udpIpMetaDataInTxVec_put[7]),

	    .dataStreamInTxVec_7_put(dataStreamInTxVec_put[7]),
	    .EN_dataStreamInTxVec_7_put(EN_dataStreamInTxVec_put[7] & RDY_dataStreamInTxVec_put[7]),
	    .RDY_dataStreamInTxVec_7_put(RDY_dataStreamInTxVec_put[7]),

	    .EN_udpIpMetaDataOutRxVec_7_get(EN_udpIpMetaDataOutRxVec_get[7] & RDY_udpIpMetaDataOutRxVec_get[7]),
	    .RDY_udpIpMetaDataOutRxVec_7_get(RDY_udpIpMetaDataOutRxVec_get[7]),
        .udpIpMetaDataOutRxVec_7_get(udpIpMetaDataOutRxVec_get[7]),

	    .EN_dataStreamOutRxVec_7_get(EN_dataStreamOutRxVec_get[7] & RDY_dataStreamOutRxVec_get[7]),
	    .RDY_dataStreamOutRxVec_7_get(RDY_dataStreamOutRxVec_get[7]),
        .dataStreamOutRxVec_7_get(dataStreamOutRxVec_get[7]),

        .gt_rxn_in (gt_n_loop),
        .gt_rxp_in (gt_p_loop),
        .gt_txn_out(gt_n_loop),
        .gt_txp_out(gt_p_loop)
    );
endmodule
