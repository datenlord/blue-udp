`timescale 1ps / 1ps

module TestPfcUdpIpArpEthCmacRxTxWrapper();

    localparam CHANNEL_NUM = 8;
    localparam GT_LANE_WIDTH = 4;
    localparam UDP_CONFIG_WIDTH = 144;
    localparam UDP_IP_META_WIDTH = 88;
    localparam DATA_STREAM_WIDTH = 290;

    reg udp_clk;
    reg udp_reset;

    reg gt_ref_clk_p;
    reg gt_ref_clk_n;
    reg gt_init_clk;
    reg gt_sys_reset;

    wire [UDP_CONFIG_WIDTH - 1 : 0] udpConfig_put;
    wire EN_udpConfig_put;
    wire RDY_udpConfig_put;

    wire [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataTxInVec_put[CHANNEL_NUM - 1 : 0];
    wire EN_udpIpMetaDataTxInVec_put[CHANNEL_NUM - 1 : 0];
    wire RDY_udpIpMetaDataTxInVec_put[CHANNEL_NUM - 1 : 0];

    wire [DATA_STREAM_WIDTH - 1 : 0] dataStreamTxInVec_put[CHANNEL_NUM - 1 : 0];
    wire EN_dataStreamTxInVec_put[CHANNEL_NUM - 1 : 0];
    wire RDY_dataStreamTxInVec_put[CHANNEL_NUM - 1 : 0];

    wire EN_udpIpMetaDataRxOutVec_get[CHANNEL_NUM - 1 : 0];
    wire RDY_udpIpMetaDataRxOutVec_get[CHANNEL_NUM - 1 : 0];
    wire [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataRxOutVec_get[CHANNEL_NUM - 1 : 0];

    wire EN_dataStreamRxOutVec_get[CHANNEL_NUM - 1 : 0];
    wire RDY_dataStreamRxOutVec_get[CHANNEL_NUM - 1 : 0];
    wire [DATA_STREAM_WIDTH - 1 : 0] dataStreamRxOutVec_get[CHANNEL_NUM - 1 : 0];

    wire [GT_LANE_WIDTH - 1 : 0] gt_n_loop, gt_p_loop;


    mkTestPfcUdpIpArpEthCmacRxTx testbench(
        .udp_clk(udp_clk),
        .udp_reset(udp_reset),

        .EN_udpConfig_get(RDY_udpConfig_put & EN_udpConfig_put),
        .udpConfig_get(udpConfig_put),
        .RDY_udpConfig_get(EN_udpConfig_put),

        // channel 0
        .EN_udpIpMetaDataTxOutVec_0_get(RDY_udpIpMetaDataTxInVec_put[0] & EN_udpIpMetaDataTxInVec_put[0]),
        .udpIpMetaDataTxOutVec_0_get(udpIpMetaDataTxInVec_put[0]),
        .RDY_udpIpMetaDataTxOutVec_0_get(EN_udpIpMetaDataTxInVec_put[0]),

        .EN_dataStreamTxOutVec_0_get(RDY_dataStreamTxInVec_put[0] & EN_dataStreamTxInVec_put[0]),
        .dataStreamTxOutVec_0_get(dataStreamTxInVec_put[0]),
        .RDY_dataStreamTxOutVec_0_get(EN_dataStreamTxInVec_put[0]),

        .udpIpMetaDataRxInVec_0_put(udpIpMetaDataRxOutVec_get[0]),
        .EN_udpIpMetaDataRxInVec_0_put(RDY_udpIpMetaDataRxOutVec_get[0] & EN_udpIpMetaDataRxOutVec_get[0]),
        .RDY_udpIpMetaDataRxInVec_0_put(EN_udpIpMetaDataRxOutVec_get[0]),

        .dataStreamRxInVec_0_put(dataStreamRxOutVec_get[0]),
        .EN_dataStreamRxInVec_0_put(RDY_dataStreamRxOutVec_get[0] & EN_dataStreamRxOutVec_get[0]),
        .RDY_dataStreamRxInVec_0_put(EN_dataStreamRxOutVec_get[0]),

        // channel 1
        .EN_udpIpMetaDataTxOutVec_1_get(RDY_udpIpMetaDataTxInVec_put[1] & EN_udpIpMetaDataTxInVec_put[1]),
        .udpIpMetaDataTxOutVec_1_get(udpIpMetaDataTxInVec_put[1]),
        .RDY_udpIpMetaDataTxOutVec_1_get(EN_udpIpMetaDataTxInVec_put[1]),

        .EN_dataStreamTxOutVec_1_get(RDY_dataStreamTxInVec_put[1] & EN_dataStreamTxInVec_put[1]),
        .dataStreamTxOutVec_1_get(dataStreamTxInVec_put[1]),
        .RDY_dataStreamTxOutVec_1_get(EN_dataStreamTxInVec_put[1]),

        .udpIpMetaDataRxInVec_1_put(udpIpMetaDataRxOutVec_get[1]),
        .EN_udpIpMetaDataRxInVec_1_put(RDY_udpIpMetaDataRxOutVec_get[1] & EN_udpIpMetaDataRxOutVec_get[1]),
        .RDY_udpIpMetaDataRxInVec_1_put(EN_udpIpMetaDataRxOutVec_get[1]),

        .dataStreamRxInVec_1_put(dataStreamRxOutVec_get[1]),
        .EN_dataStreamRxInVec_1_put(RDY_dataStreamRxOutVec_get[1] & EN_dataStreamRxOutVec_get[1]),
        .RDY_dataStreamRxInVec_1_put(EN_dataStreamRxOutVec_get[1]),

        // channel 2
        .EN_udpIpMetaDataTxOutVec_2_get(RDY_udpIpMetaDataTxInVec_put[2] & EN_udpIpMetaDataTxInVec_put[2]),
        .udpIpMetaDataTxOutVec_2_get(udpIpMetaDataTxInVec_put[2]),
        .RDY_udpIpMetaDataTxOutVec_2_get(EN_udpIpMetaDataTxInVec_put[2]),

        .EN_dataStreamTxOutVec_2_get(RDY_dataStreamTxInVec_put[2] & EN_dataStreamTxInVec_put[2]),
        .dataStreamTxOutVec_2_get(dataStreamTxInVec_put[2]),
        .RDY_dataStreamTxOutVec_2_get(EN_dataStreamTxInVec_put[2]),

        .udpIpMetaDataRxInVec_2_put(udpIpMetaDataRxOutVec_get[2]),
        .EN_udpIpMetaDataRxInVec_2_put(RDY_udpIpMetaDataRxOutVec_get[2] & EN_udpIpMetaDataRxOutVec_get[2]),
        .RDY_udpIpMetaDataRxInVec_2_put(EN_udpIpMetaDataRxOutVec_get[2]),

        .dataStreamRxInVec_2_put(dataStreamRxOutVec_get[2]),
        .EN_dataStreamRxInVec_2_put(RDY_dataStreamRxOutVec_get[2] & EN_dataStreamRxOutVec_get[2]),
        .RDY_dataStreamRxInVec_2_put(EN_dataStreamRxOutVec_get[2]),

        // channel 3
        .EN_udpIpMetaDataTxOutVec_3_get(RDY_udpIpMetaDataTxInVec_put[3] & EN_udpIpMetaDataTxInVec_put[3]),
        .udpIpMetaDataTxOutVec_3_get(udpIpMetaDataTxInVec_put[3]),
        .RDY_udpIpMetaDataTxOutVec_3_get(EN_udpIpMetaDataTxInVec_put[3]),

        .EN_dataStreamTxOutVec_3_get(RDY_dataStreamTxInVec_put[3] & EN_dataStreamTxInVec_put[3]),
        .dataStreamTxOutVec_3_get(dataStreamTxInVec_put[3]),
        .RDY_dataStreamTxOutVec_3_get(EN_dataStreamTxInVec_put[3]),

        .udpIpMetaDataRxInVec_3_put(udpIpMetaDataRxOutVec_get[3]),
        .EN_udpIpMetaDataRxInVec_3_put(RDY_udpIpMetaDataRxOutVec_get[3] & EN_udpIpMetaDataRxOutVec_get[3]),
        .RDY_udpIpMetaDataRxInVec_3_put(EN_udpIpMetaDataRxOutVec_get[3]),

        .dataStreamRxInVec_3_put(dataStreamRxOutVec_get[3]),
        .EN_dataStreamRxInVec_3_put(RDY_dataStreamRxOutVec_get[3] & EN_dataStreamRxOutVec_get[3]),
        .RDY_dataStreamRxInVec_3_put(EN_dataStreamRxOutVec_get[3]),

        // channel 4
        .EN_udpIpMetaDataTxOutVec_4_get(RDY_udpIpMetaDataTxInVec_put[4] & EN_udpIpMetaDataTxInVec_put[4]),
        .udpIpMetaDataTxOutVec_4_get(udpIpMetaDataTxInVec_put[4]),
        .RDY_udpIpMetaDataTxOutVec_4_get(EN_udpIpMetaDataTxInVec_put[4]),

        .EN_dataStreamTxOutVec_4_get(RDY_dataStreamTxInVec_put[4] & EN_dataStreamTxInVec_put[4]),
        .dataStreamTxOutVec_4_get(dataStreamTxInVec_put[4]),
        .RDY_dataStreamTxOutVec_4_get(EN_dataStreamTxInVec_put[4]),

        .udpIpMetaDataRxInVec_4_put(udpIpMetaDataRxOutVec_get[4]),
        .EN_udpIpMetaDataRxInVec_4_put(RDY_udpIpMetaDataRxOutVec_get[4] & EN_udpIpMetaDataRxOutVec_get[4]),
        .RDY_udpIpMetaDataRxInVec_4_put(EN_udpIpMetaDataRxOutVec_get[4]),

        .dataStreamRxInVec_4_put(dataStreamRxOutVec_get[4]),
        .EN_dataStreamRxInVec_4_put(RDY_dataStreamRxOutVec_get[4] & EN_dataStreamRxOutVec_get[4]),
        .RDY_dataStreamRxInVec_4_put(EN_dataStreamRxOutVec_get[4]),

        // channel 5
        .EN_udpIpMetaDataTxOutVec_5_get(RDY_udpIpMetaDataTxInVec_put[5] & EN_udpIpMetaDataTxInVec_put[5]),
        .udpIpMetaDataTxOutVec_5_get(udpIpMetaDataTxInVec_put[5]),
        .RDY_udpIpMetaDataTxOutVec_5_get(EN_udpIpMetaDataTxInVec_put[5]),

        .EN_dataStreamTxOutVec_5_get(RDY_dataStreamTxInVec_put[5] & EN_dataStreamTxInVec_put[5]),
        .dataStreamTxOutVec_5_get(dataStreamTxInVec_put[5]),
        .RDY_dataStreamTxOutVec_5_get(EN_dataStreamTxInVec_put[5]),

        .udpIpMetaDataRxInVec_5_put(udpIpMetaDataRxOutVec_get[5]),
        .EN_udpIpMetaDataRxInVec_5_put(RDY_udpIpMetaDataRxOutVec_get[5] & EN_udpIpMetaDataRxOutVec_get[5]),
        .RDY_udpIpMetaDataRxInVec_5_put(EN_udpIpMetaDataRxOutVec_get[5]),

        .dataStreamRxInVec_5_put(dataStreamRxOutVec_get[5]),
        .EN_dataStreamRxInVec_5_put(RDY_dataStreamRxOutVec_get[5] & EN_dataStreamRxOutVec_get[5]),
        .RDY_dataStreamRxInVec_5_put(EN_dataStreamRxOutVec_get[5]),

        // channel 6
        .EN_udpIpMetaDataTxOutVec_6_get(RDY_udpIpMetaDataTxInVec_put[6] & EN_udpIpMetaDataTxInVec_put[6]),
        .udpIpMetaDataTxOutVec_6_get(udpIpMetaDataTxInVec_put[6]),
        .RDY_udpIpMetaDataTxOutVec_6_get(EN_udpIpMetaDataTxInVec_put[6]),

        .EN_dataStreamTxOutVec_6_get(RDY_dataStreamTxInVec_put[6] & EN_dataStreamTxInVec_put[6]),
        .dataStreamTxOutVec_6_get(dataStreamTxInVec_put[6]),
        .RDY_dataStreamTxOutVec_6_get(EN_dataStreamTxInVec_put[6]),

        .udpIpMetaDataRxInVec_6_put(udpIpMetaDataRxOutVec_get[6]),
        .EN_udpIpMetaDataRxInVec_6_put(RDY_udpIpMetaDataRxOutVec_get[6] & EN_udpIpMetaDataRxOutVec_get[6]),
        .RDY_udpIpMetaDataRxInVec_6_put(EN_udpIpMetaDataRxOutVec_get[6]),

        .dataStreamRxInVec_6_put(dataStreamRxOutVec_get[6]),
        .EN_dataStreamRxInVec_6_put(RDY_dataStreamRxOutVec_get[6] & EN_dataStreamRxOutVec_get[6]),
        .RDY_dataStreamRxInVec_6_put(EN_dataStreamRxOutVec_get[6]),

        // channel 7
        .EN_udpIpMetaDataTxOutVec_7_get(RDY_udpIpMetaDataTxInVec_put[7] & EN_udpIpMetaDataTxInVec_put[7]),
        .udpIpMetaDataTxOutVec_7_get(udpIpMetaDataTxInVec_put[7]),
        .RDY_udpIpMetaDataTxOutVec_7_get(EN_udpIpMetaDataTxInVec_put[7]),

        .EN_dataStreamTxOutVec_7_get(RDY_dataStreamTxInVec_put[7] & EN_dataStreamTxInVec_put[7]),
        .dataStreamTxOutVec_7_get(dataStreamTxInVec_put[7]),
        .RDY_dataStreamTxOutVec_7_get(EN_dataStreamTxInVec_put[7]),

        .udpIpMetaDataRxInVec_7_put(udpIpMetaDataRxOutVec_get[7]),
        .EN_udpIpMetaDataRxInVec_7_put(RDY_udpIpMetaDataRxOutVec_get[7] & EN_udpIpMetaDataRxOutVec_get[7]),
        .RDY_udpIpMetaDataRxInVec_7_put(EN_udpIpMetaDataRxOutVec_get[7]),

        .dataStreamRxInVec_7_put(dataStreamRxOutVec_get[7]),
        .EN_dataStreamRxInVec_7_put(RDY_dataStreamRxOutVec_get[7] & EN_dataStreamRxOutVec_get[7]),
        .RDY_dataStreamRxInVec_7_put(EN_dataStreamRxOutVec_get[7])
    );

    PfcUdpIpArpEthCmacRxTxWrapper dut_wrapper(
        .udp_clk     (udp_clk     ),
        .udp_reset   (udp_reset   ),

        .gt_ref_clk_p(gt_ref_clk_p),
        .gt_ref_clk_n(gt_ref_clk_n),
        .init_clk    (gt_init_clk    ),
        .sys_reset   (gt_sys_reset   ),

        .udpConfig_put    (udpConfig_put),
        .EN_udpConfig_put (EN_udpConfig_put & RDY_udpConfig_put),
        .RDY_udpConfig_put(RDY_udpConfig_put),


        // channel 0
        .udpIpMetaDataTxInVec_0_put(udpIpMetaDataTxInVec_put[0]),
        .EN_udpIpMetaDataTxInVec_0_put(EN_udpIpMetaDataTxInVec_put[0] & RDY_udpIpMetaDataTxInVec_put[0]),
        .RDY_udpIpMetaDataTxInVec_0_put(RDY_udpIpMetaDataTxInVec_put[0]),

        .dataStreamTxInVec_0_put(dataStreamTxInVec_put[0]),
        .EN_dataStreamTxInVec_0_put(EN_dataStreamTxInVec_put[0] & RDY_dataStreamTxInVec_put[0]),
        .RDY_dataStreamTxInVec_0_put(RDY_dataStreamTxInVec_put[0]),

        .EN_udpIpMetaDataRxOutVec_0_get(EN_udpIpMetaDataRxOutVec_get[0] & RDY_udpIpMetaDataRxOutVec_get[0]),
        .RDY_udpIpMetaDataRxOutVec_0_get(RDY_udpIpMetaDataRxOutVec_get[0]),
        .udpIpMetaDataRxOutVec_0_get(udpIpMetaDataRxOutVec_get[0]),

        .EN_dataStreamRxOutVec_0_get(EN_dataStreamRxOutVec_get[0] & RDY_dataStreamRxOutVec_get[0]),
        .RDY_dataStreamRxOutVec_0_get(RDY_dataStreamRxOutVec_get[0]),
        .dataStreamRxOutVec_0_get(dataStreamRxOutVec_get[0]),

        // channel 1
        .udpIpMetaDataTxInVec_1_put(udpIpMetaDataTxInVec_put[1]),
        .EN_udpIpMetaDataTxInVec_1_put(EN_udpIpMetaDataTxInVec_put[1] & RDY_udpIpMetaDataTxInVec_put[1]),
        .RDY_udpIpMetaDataTxInVec_1_put(RDY_udpIpMetaDataTxInVec_put[1]),

        .dataStreamTxInVec_1_put(dataStreamTxInVec_put[1]),
        .EN_dataStreamTxInVec_1_put(EN_dataStreamTxInVec_put[1] & RDY_dataStreamTxInVec_put[1]),
        .RDY_dataStreamTxInVec_1_put(RDY_dataStreamTxInVec_put[1]),

        .EN_udpIpMetaDataRxOutVec_1_get(EN_udpIpMetaDataRxOutVec_get[1] & RDY_udpIpMetaDataRxOutVec_get[1]),
        .RDY_udpIpMetaDataRxOutVec_1_get(RDY_udpIpMetaDataRxOutVec_get[1]),
        .udpIpMetaDataRxOutVec_1_get(udpIpMetaDataRxOutVec_get[1]),

        .EN_dataStreamRxOutVec_1_get(EN_dataStreamRxOutVec_get[1] & RDY_dataStreamRxOutVec_get[1]),
        .RDY_dataStreamRxOutVec_1_get(RDY_dataStreamRxOutVec_get[1]),
        .dataStreamRxOutVec_1_get(dataStreamRxOutVec_get[1]),

        // channel 2
        .udpIpMetaDataTxInVec_2_put(udpIpMetaDataTxInVec_put[2]),
        .EN_udpIpMetaDataTxInVec_2_put(EN_udpIpMetaDataTxInVec_put[2] & RDY_udpIpMetaDataTxInVec_put[2]),
        .RDY_udpIpMetaDataTxInVec_2_put(RDY_udpIpMetaDataTxInVec_put[2]),

        .dataStreamTxInVec_2_put(dataStreamTxInVec_put[2]),
        .EN_dataStreamTxInVec_2_put(EN_dataStreamTxInVec_put[2] & RDY_dataStreamTxInVec_put[2]),
        .RDY_dataStreamTxInVec_2_put(RDY_dataStreamTxInVec_put[2]),

        .EN_udpIpMetaDataRxOutVec_2_get(EN_udpIpMetaDataRxOutVec_get[2] & RDY_udpIpMetaDataRxOutVec_get[2]),
        .RDY_udpIpMetaDataRxOutVec_2_get(RDY_udpIpMetaDataRxOutVec_get[2]),
        .udpIpMetaDataRxOutVec_2_get(udpIpMetaDataRxOutVec_get[2]),

        .EN_dataStreamRxOutVec_2_get(EN_dataStreamRxOutVec_get[2] & RDY_dataStreamRxOutVec_get[2]),
        .RDY_dataStreamRxOutVec_2_get(RDY_dataStreamRxOutVec_get[2]),
        .dataStreamRxOutVec_2_get(dataStreamRxOutVec_get[2]),

        // channel 3
        .udpIpMetaDataTxInVec_3_put(udpIpMetaDataTxInVec_put[3]),
        .EN_udpIpMetaDataTxInVec_3_put(EN_udpIpMetaDataTxInVec_put[3] & RDY_udpIpMetaDataTxInVec_put[3]),
        .RDY_udpIpMetaDataTxInVec_3_put(RDY_udpIpMetaDataTxInVec_put[3]),

        .dataStreamTxInVec_3_put(dataStreamTxInVec_put[3]),
        .EN_dataStreamTxInVec_3_put(EN_dataStreamTxInVec_put[3] & RDY_dataStreamTxInVec_put[3]),
        .RDY_dataStreamTxInVec_3_put(RDY_dataStreamTxInVec_put[3]),

        .EN_udpIpMetaDataRxOutVec_3_get(EN_udpIpMetaDataRxOutVec_get[3] & RDY_udpIpMetaDataRxOutVec_get[3]),
        .RDY_udpIpMetaDataRxOutVec_3_get(RDY_udpIpMetaDataRxOutVec_get[3]),
        .udpIpMetaDataRxOutVec_3_get(udpIpMetaDataRxOutVec_get[3]),

        .EN_dataStreamRxOutVec_3_get(EN_dataStreamRxOutVec_get[3] & RDY_dataStreamRxOutVec_get[3]),
        .RDY_dataStreamRxOutVec_3_get(RDY_dataStreamRxOutVec_get[3]),
        .dataStreamRxOutVec_3_get(dataStreamRxOutVec_get[3]),

        // channel 4
        .udpIpMetaDataTxInVec_4_put(udpIpMetaDataTxInVec_put[4]),
        .EN_udpIpMetaDataTxInVec_4_put(EN_udpIpMetaDataTxInVec_put[4] & RDY_udpIpMetaDataTxInVec_put[4]),
        .RDY_udpIpMetaDataTxInVec_4_put(RDY_udpIpMetaDataTxInVec_put[4]),

        .dataStreamTxInVec_4_put(dataStreamTxInVec_put[4]),
        .EN_dataStreamTxInVec_4_put(EN_dataStreamTxInVec_put[4] & RDY_dataStreamTxInVec_put[4]),
        .RDY_dataStreamTxInVec_4_put(RDY_dataStreamTxInVec_put[4]),

        .EN_udpIpMetaDataRxOutVec_4_get(EN_udpIpMetaDataRxOutVec_get[4] & RDY_udpIpMetaDataRxOutVec_get[4]),
        .RDY_udpIpMetaDataRxOutVec_4_get(RDY_udpIpMetaDataRxOutVec_get[4]),
        .udpIpMetaDataRxOutVec_4_get(udpIpMetaDataRxOutVec_get[4]),

        .EN_dataStreamRxOutVec_4_get(EN_dataStreamRxOutVec_get[4] & RDY_dataStreamRxOutVec_get[4]),
        .RDY_dataStreamRxOutVec_4_get(RDY_dataStreamRxOutVec_get[4]),
        .dataStreamRxOutVec_4_get(dataStreamRxOutVec_get[4]),

        // channel 5
        .udpIpMetaDataTxInVec_5_put(udpIpMetaDataTxInVec_put[5]),
        .EN_udpIpMetaDataTxInVec_5_put(EN_udpIpMetaDataTxInVec_put[5] & RDY_udpIpMetaDataTxInVec_put[5]),
        .RDY_udpIpMetaDataTxInVec_5_put(RDY_udpIpMetaDataTxInVec_put[5]),

        .dataStreamTxInVec_5_put(dataStreamTxInVec_put[5]),
        .EN_dataStreamTxInVec_5_put(EN_dataStreamTxInVec_put[5] & RDY_dataStreamTxInVec_put[5]),
        .RDY_dataStreamTxInVec_5_put(RDY_dataStreamTxInVec_put[5]),

        .EN_udpIpMetaDataRxOutVec_5_get(EN_udpIpMetaDataRxOutVec_get[5] & RDY_udpIpMetaDataRxOutVec_get[5]),
        .RDY_udpIpMetaDataRxOutVec_5_get(RDY_udpIpMetaDataRxOutVec_get[5]),
        .udpIpMetaDataRxOutVec_5_get(udpIpMetaDataRxOutVec_get[5]),

        .EN_dataStreamRxOutVec_5_get(EN_dataStreamRxOutVec_get[5] & RDY_dataStreamRxOutVec_get[5]),
        .RDY_dataStreamRxOutVec_5_get(RDY_dataStreamRxOutVec_get[5]),
        .dataStreamRxOutVec_5_get(dataStreamRxOutVec_get[5]),

        // channel 6
        .udpIpMetaDataTxInVec_6_put(udpIpMetaDataTxInVec_put[6]),
        .EN_udpIpMetaDataTxInVec_6_put(EN_udpIpMetaDataTxInVec_put[6] & RDY_udpIpMetaDataTxInVec_put[6]),
        .RDY_udpIpMetaDataTxInVec_6_put(RDY_udpIpMetaDataTxInVec_put[6]),

        .dataStreamTxInVec_6_put(dataStreamTxInVec_put[6]),
        .EN_dataStreamTxInVec_6_put(EN_dataStreamTxInVec_put[6] & RDY_dataStreamTxInVec_put[6]),
        .RDY_dataStreamTxInVec_6_put(RDY_dataStreamTxInVec_put[6]),

        .EN_udpIpMetaDataRxOutVec_6_get(EN_udpIpMetaDataRxOutVec_get[6] & RDY_udpIpMetaDataRxOutVec_get[6]),
        .RDY_udpIpMetaDataRxOutVec_6_get(RDY_udpIpMetaDataRxOutVec_get[6]),
        .udpIpMetaDataRxOutVec_6_get(udpIpMetaDataRxOutVec_get[6]),

        .EN_dataStreamRxOutVec_6_get(EN_dataStreamRxOutVec_get[6] & RDY_dataStreamRxOutVec_get[6]),
        .RDY_dataStreamRxOutVec_6_get(RDY_dataStreamRxOutVec_get[6]),
        .dataStreamRxOutVec_6_get(dataStreamRxOutVec_get[6]),

        // channel 7
        .udpIpMetaDataTxInVec_7_put(udpIpMetaDataTxInVec_put[7]),
        .EN_udpIpMetaDataTxInVec_7_put(EN_udpIpMetaDataTxInVec_put[7] & RDY_udpIpMetaDataTxInVec_put[7]),
        .RDY_udpIpMetaDataTxInVec_7_put(RDY_udpIpMetaDataTxInVec_put[7]),

        .dataStreamTxInVec_7_put(dataStreamTxInVec_put[7]),
        .EN_dataStreamTxInVec_7_put(EN_dataStreamTxInVec_put[7] & RDY_dataStreamTxInVec_put[7]),
        .RDY_dataStreamTxInVec_7_put(RDY_dataStreamTxInVec_put[7]),

        .EN_udpIpMetaDataRxOutVec_7_get(EN_udpIpMetaDataRxOutVec_get[7] & RDY_udpIpMetaDataRxOutVec_get[7]),
        .RDY_udpIpMetaDataRxOutVec_7_get(RDY_udpIpMetaDataRxOutVec_get[7]),
        .udpIpMetaDataRxOutVec_7_get(udpIpMetaDataRxOutVec_get[7]),

        .EN_dataStreamRxOutVec_7_get(EN_dataStreamRxOutVec_get[7] & RDY_dataStreamRxOutVec_get[7]),
        .RDY_dataStreamRxOutVec_7_get(RDY_dataStreamRxOutVec_get[7]),
        .dataStreamRxOutVec_7_get(dataStreamRxOutVec_get[7]),

        .gt_rxn_in (gt_n_loop),
        .gt_rxp_in (gt_p_loop),
        .gt_txn_out(gt_n_loop),
        .gt_txp_out(gt_p_loop)
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
