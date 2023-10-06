`timescale 1ps / 1ps

module PfcUdpIpArpEthCmacRxTxWrapper#(
    parameter GT_LANE_WIDTH = 4,
    parameter UDP_CONFIG_WIDTH = 144,
    parameter UDP_IP_META_WIDTH = 88,
    parameter DATA_STREAM_WIDTH = 290
)(

    input udp_clk,
    input udp_reset,

    input gt_ref_clk_p,
    input gt_ref_clk_n,
    input init_clk,
    input sys_reset,

	input [UDP_CONFIG_WIDTH - 1 : 0] udpConfig_put,
	input EN_udpConfig_put,
	output RDY_udpConfig_put,

    // channel 0
	input [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataInTxVec_0_put,
	input EN_udpIpMetaDataInTxVec_0_put,
	output RDY_udpIpMetaDataInTxVec_0_put,

	input [DATA_STREAM_WIDTH - 1 : 0] dataStreamInTxVec_0_put,
	input EN_dataStreamInTxVec_0_put,
	output RDY_dataStreamInTxVec_0_put,

	input EN_udpIpMetaDataOutRxVec_0_get,
	output RDY_udpIpMetaDataOutRxVec_0_get,
    output [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataOutRxVec_0_get,

	input EN_dataStreamOutRxVec_0_get,
	output RDY_dataStreamOutRxVec_0_get,
    output [DATA_STREAM_WIDTH - 1 : 0] dataStreamOutRxVec_0_get,

    // channel 1
	input [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataInTxVec_1_put,
	input EN_udpIpMetaDataInTxVec_1_put,
	output RDY_udpIpMetaDataInTxVec_1_put,

	input [DATA_STREAM_WIDTH - 1 : 0] dataStreamInTxVec_1_put,
	input EN_dataStreamInTxVec_1_put,
	output RDY_dataStreamInTxVec_1_put,

	input EN_udpIpMetaDataOutRxVec_1_get,
	output RDY_udpIpMetaDataOutRxVec_1_get,
    output [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataOutRxVec_1_get,

	input EN_dataStreamOutRxVec_1_get,
	output RDY_dataStreamOutRxVec_1_get,
    output [DATA_STREAM_WIDTH - 1 : 0] dataStreamOutRxVec_1_get,

    // channel 2
	input [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataInTxVec_2_put,
	input EN_udpIpMetaDataInTxVec_2_put,
	output RDY_udpIpMetaDataInTxVec_2_put,

	input [DATA_STREAM_WIDTH - 1 : 0] dataStreamInTxVec_2_put,
	input EN_dataStreamInTxVec_2_put,
	output RDY_dataStreamInTxVec_2_put,

	input EN_udpIpMetaDataOutRxVec_2_get,
	output RDY_udpIpMetaDataOutRxVec_2_get,
    output [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataOutRxVec_2_get,

	input EN_dataStreamOutRxVec_2_get,
	output RDY_dataStreamOutRxVec_2_get,
    output [DATA_STREAM_WIDTH - 1 : 0] dataStreamOutRxVec_2_get,


    // channel 3
	input [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataInTxVec_3_put,
	input EN_udpIpMetaDataInTxVec_3_put,
	output RDY_udpIpMetaDataInTxVec_3_put,

	input [DATA_STREAM_WIDTH - 1 : 0] dataStreamInTxVec_3_put,
	input EN_dataStreamInTxVec_3_put,
	output RDY_dataStreamInTxVec_3_put,

	input EN_udpIpMetaDataOutRxVec_3_get,
	output RDY_udpIpMetaDataOutRxVec_3_get,
    output [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataOutRxVec_3_get,

	input EN_dataStreamOutRxVec_3_get,
	output RDY_dataStreamOutRxVec_3_get,
    output [DATA_STREAM_WIDTH - 1 : 0] dataStreamOutRxVec_3_get,


    // channel 4
	input [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataInTxVec_4_put,
	input EN_udpIpMetaDataInTxVec_4_put,
	output RDY_udpIpMetaDataInTxVec_4_put,

	input [DATA_STREAM_WIDTH - 1 : 0] dataStreamInTxVec_4_put,
	input EN_dataStreamInTxVec_4_put,
	output RDY_dataStreamInTxVec_4_put,

	input EN_udpIpMetaDataOutRxVec_4_get,
	output RDY_udpIpMetaDataOutRxVec_4_get,
    output [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataOutRxVec_4_get,

	input EN_dataStreamOutRxVec_4_get,
	output RDY_dataStreamOutRxVec_4_get,
    output [DATA_STREAM_WIDTH - 1 : 0] dataStreamOutRxVec_4_get,

    // channel 5
	input [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataInTxVec_5_put,
	input EN_udpIpMetaDataInTxVec_5_put,
	output RDY_udpIpMetaDataInTxVec_5_put,

	input [DATA_STREAM_WIDTH - 1 : 0] dataStreamInTxVec_5_put,
	input EN_dataStreamInTxVec_5_put,
	output RDY_dataStreamInTxVec_5_put,

	input EN_udpIpMetaDataOutRxVec_5_get,
	output RDY_udpIpMetaDataOutRxVec_5_get,
    output [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataOutRxVec_5_get,

	input EN_dataStreamOutRxVec_5_get,
	output RDY_dataStreamOutRxVec_5_get,
    output [DATA_STREAM_WIDTH - 1 : 0] dataStreamOutRxVec_5_get,

    // channel 6
	input [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataInTxVec_6_put,
	input EN_udpIpMetaDataInTxVec_6_put,
	output RDY_udpIpMetaDataInTxVec_6_put,

	input [DATA_STREAM_WIDTH - 1 : 0] dataStreamInTxVec_6_put,
	input EN_dataStreamInTxVec_6_put,
	output RDY_dataStreamInTxVec_6_put,

	input EN_udpIpMetaDataOutRxVec_6_get,
	output RDY_udpIpMetaDataOutRxVec_6_get,
    output [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataOutRxVec_6_get,

	input EN_dataStreamOutRxVec_6_get,
	output RDY_dataStreamOutRxVec_6_get,
    output [DATA_STREAM_WIDTH - 1 : 0] dataStreamOutRxVec_6_get,

    // channel 7
	input [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataInTxVec_7_put,
	input EN_udpIpMetaDataInTxVec_7_put,
	output RDY_udpIpMetaDataInTxVec_7_put,

	input [DATA_STREAM_WIDTH - 1 : 0] dataStreamInTxVec_7_put,
	input EN_dataStreamInTxVec_7_put,
	output RDY_dataStreamInTxVec_7_put,

	input EN_udpIpMetaDataOutRxVec_7_get,
	output RDY_udpIpMetaDataOutRxVec_7_get,
    output [UDP_IP_META_WIDTH - 1 : 0] udpIpMetaDataOutRxVec_7_get,

	input EN_dataStreamOutRxVec_7_get,
	output RDY_dataStreamOutRxVec_7_get,
    output [DATA_STREAM_WIDTH - 1 : 0] dataStreamOutRxVec_7_get,

    // Serdes
    input  [GT_LANE_WIDTH - 1 : 0] gt_rxn_in,
    input  [GT_LANE_WIDTH - 1 : 0] gt_rxp_in,
    output [GT_LANE_WIDTH - 1 : 0] gt_txn_out,
    output [GT_LANE_WIDTH - 1 : 0] gt_txp_out
);

    wire [(GT_LANE_WIDTH * 3)-1 :0]    gt_loopback_in;

    //// For other GT loopback options please change the value appropriately
    //// For example, for Near End PMA loopback for 4 Lanes update the gt_loopback_in = {4{3'b010}};
    //// For more information and settings on loopback, refer GT Transceivers user guide

    assign gt_loopback_in  = {GT_LANE_WIDTH{3'b000}};

    wire            gt_ref_clk_out;
    wire            txusrclk2;
    wire            rxusrclk2;
    wire            usr_tx_reset;
    wire            usr_rx_reset;

    wire            rx_axis_tvalid;
    wire [511:0]    rx_axis_tdata;
    wire            rx_axis_tlast;
    wire [63:0]     rx_axis_tkeep;
    wire            rx_axis_tuser;

    wire            tx_axis_tready;
    wire            tx_axis_tvalid;
    wire [511:0]    tx_axis_tdata;
    wire            tx_axis_tlast;
    wire [63:0]     tx_axis_tkeep;
    wire            tx_axis_tuser;

    wire            tx_ovfout;
    wire            tx_unfout;
    wire [55:0]     tx_preamblein;
    wire [8:0]      stat_tx_pause_valid;
    wire            stat_tx_pause;
    wire            stat_tx_user_pause;
    wire [8:0]      ctl_tx_pause_enable;
    wire [15:0]     ctl_tx_pause_quanta0;
    wire [15:0]     ctl_tx_pause_quanta1;
    wire [15:0]     ctl_tx_pause_quanta2;
    wire [15:0]     ctl_tx_pause_quanta3;
    wire [15:0]     ctl_tx_pause_quanta4;
    wire [15:0]     ctl_tx_pause_quanta5;
    wire [15:0]     ctl_tx_pause_quanta6;
    wire [15:0]     ctl_tx_pause_quanta7;
    wire [15:0]     ctl_tx_pause_quanta8;
    wire [15:0]     ctl_tx_pause_refresh_timer0;
    wire [15:0]     ctl_tx_pause_refresh_timer1;
    wire [15:0]     ctl_tx_pause_refresh_timer2;
    wire [15:0]     ctl_tx_pause_refresh_timer3;
    wire [15:0]     ctl_tx_pause_refresh_timer4;
    wire [15:0]     ctl_tx_pause_refresh_timer5;
    wire [15:0]     ctl_tx_pause_refresh_timer6;
    wire [15:0]     ctl_tx_pause_refresh_timer7;
    wire [15:0]     ctl_tx_pause_refresh_timer8;
    wire [8:0]      ctl_tx_pause_req;
    wire            ctl_tx_resend_pause;
    wire            stat_rx_pause;
    wire [15:0]     stat_rx_pause_quanta0;
    wire [15:0]     stat_rx_pause_quanta1;
    wire [15:0]     stat_rx_pause_quanta2;
    wire [15:0]     stat_rx_pause_quanta3;
    wire [15:0]     stat_rx_pause_quanta4;
    wire [15:0]     stat_rx_pause_quanta5;
    wire [15:0]     stat_rx_pause_quanta6;
    wire [15:0]     stat_rx_pause_quanta7;
    wire [15:0]     stat_rx_pause_quanta8;
    wire [8:0]      stat_rx_pause_req;
    wire [8:0]      stat_rx_pause_valid;
    wire            stat_rx_user_pause;
    wire            ctl_rx_check_etype_gcp;
    wire            ctl_rx_check_etype_gpp;
    wire            ctl_rx_check_etype_pcp;
    wire            ctl_rx_check_etype_ppp;
    wire            ctl_rx_check_mcast_gcp;
    wire            ctl_rx_check_mcast_gpp;
    wire            ctl_rx_check_mcast_pcp;
    wire            ctl_rx_check_mcast_ppp;
    wire            ctl_rx_check_opcode_gcp;
    wire            ctl_rx_check_opcode_gpp;
    wire            ctl_rx_check_opcode_pcp;
    wire            ctl_rx_check_opcode_ppp;
    wire            ctl_rx_check_sa_gcp;
    wire            ctl_rx_check_sa_gpp;
    wire            ctl_rx_check_sa_pcp;
    wire            ctl_rx_check_sa_ppp;
    wire            ctl_rx_check_ucast_gcp;
    wire            ctl_rx_check_ucast_gpp;
    wire            ctl_rx_check_ucast_pcp;
    wire            ctl_rx_check_ucast_ppp;
    wire            ctl_rx_enable_gcp;
    wire            ctl_rx_enable_gpp;
    wire            ctl_rx_enable_pcp;
    wire            ctl_rx_enable_ppp;
    wire [8:0]      ctl_rx_pause_ack;
    wire [8:0]      ctl_rx_pause_enable;
    wire            stat_rx_aligned;
    wire            stat_rx_aligned_err;
    wire [2:0]      stat_rx_bad_code;
    wire [2:0]      stat_rx_bad_fcs;
    wire            stat_rx_bad_preamble;
    wire            stat_rx_bad_sfd;
    wire            stat_rx_bip_err_0;
    wire            stat_rx_bip_err_1;
    wire            stat_rx_bip_err_10;
    wire            stat_rx_bip_err_11;
    wire            stat_rx_bip_err_12;
    wire            stat_rx_bip_err_13;
    wire            stat_rx_bip_err_14;
    wire            stat_rx_bip_err_15;
    wire            stat_rx_bip_err_16;
    wire            stat_rx_bip_err_17;
    wire            stat_rx_bip_err_18;
    wire            stat_rx_bip_err_19;
    wire            stat_rx_bip_err_2;
    wire            stat_rx_bip_err_3;
    wire            stat_rx_bip_err_4;
    wire            stat_rx_bip_err_5;
    wire            stat_rx_bip_err_6;
    wire            stat_rx_bip_err_7;
    wire            stat_rx_bip_err_8;
    wire            stat_rx_bip_err_9;
    wire [19:0]     stat_rx_block_lock;
    wire            stat_rx_broadcast;
    wire [2:0]      stat_rx_fragment;
    wire [1:0]      stat_rx_framing_err_0;
    wire [1:0]      stat_rx_framing_err_1;
    wire [1:0]      stat_rx_framing_err_10;
    wire [1:0]      stat_rx_framing_err_11;
    wire [1:0]      stat_rx_framing_err_12;
    wire [1:0]      stat_rx_framing_err_13;
    wire [1:0]      stat_rx_framing_err_14;
    wire [1:0]      stat_rx_framing_err_15;
    wire [1:0]      stat_rx_framing_err_16;
    wire [1:0]      stat_rx_framing_err_17;
    wire [1:0]      stat_rx_framing_err_18;
    wire [1:0]      stat_rx_framing_err_19;
    wire [1:0]      stat_rx_framing_err_2;
    wire [1:0]      stat_rx_framing_err_3;
    wire [1:0]      stat_rx_framing_err_4;
    wire [1:0]      stat_rx_framing_err_5;
    wire [1:0]      stat_rx_framing_err_6;
    wire [1:0]      stat_rx_framing_err_7;
    wire [1:0]      stat_rx_framing_err_8;
    wire [1:0]      stat_rx_framing_err_9;
    wire            stat_rx_framing_err_valid_0;
    wire            stat_rx_framing_err_valid_1;
    wire            stat_rx_framing_err_valid_10;
    wire            stat_rx_framing_err_valid_11;
    wire            stat_rx_framing_err_valid_12;
    wire            stat_rx_framing_err_valid_13;
    wire            stat_rx_framing_err_valid_14;
    wire            stat_rx_framing_err_valid_15;
    wire            stat_rx_framing_err_valid_16;
    wire            stat_rx_framing_err_valid_17;
    wire            stat_rx_framing_err_valid_18;
    wire            stat_rx_framing_err_valid_19;
    wire            stat_rx_framing_err_valid_2;
    wire            stat_rx_framing_err_valid_3;
    wire            stat_rx_framing_err_valid_4;
    wire            stat_rx_framing_err_valid_5;
    wire            stat_rx_framing_err_valid_6;
    wire            stat_rx_framing_err_valid_7;
    wire            stat_rx_framing_err_valid_8;
    wire            stat_rx_framing_err_valid_9;
    wire            stat_rx_got_signal_os;
    wire            stat_rx_hi_ber;
    wire            stat_rx_inrangeerr;
    wire            stat_rx_internal_local_fault;
    wire            stat_rx_jabber;
    wire            stat_rx_local_fault;
    wire [19:0]     stat_rx_mf_err;
    wire [19:0]     stat_rx_mf_len_err;
    wire [19:0]     stat_rx_mf_repeat_err;
    wire            stat_rx_misaligned;
    wire            stat_rx_multicast;
    wire            stat_rx_oversize;
    wire            stat_rx_packet_1024_1518_bytes;
    wire            stat_rx_packet_128_255_bytes;
    wire            stat_rx_packet_1519_1522_bytes;
    wire            stat_rx_packet_1523_1548_bytes;
    wire            stat_rx_packet_1549_2047_bytes;
    wire            stat_rx_packet_2048_4095_bytes;
    wire            stat_rx_packet_256_511_bytes;
    wire            stat_rx_packet_4096_8191_bytes;
    wire            stat_rx_packet_512_1023_bytes;
    wire            stat_rx_packet_64_bytes;
    wire            stat_rx_packet_65_127_bytes;
    wire            stat_rx_packet_8192_9215_bytes;
    wire            stat_rx_packet_bad_fcs;
    wire            stat_rx_packet_large;
    wire [2:0]      stat_rx_packet_small;
    wire            stat_rx_received_local_fault;
    wire            stat_rx_remote_fault;
    wire            stat_rx_status;
    wire [2:0]      stat_rx_stomped_fcs;
    wire [19:0]     stat_rx_synced;
    wire [19:0]     stat_rx_synced_err;
    wire [2:0]      stat_rx_test_pattern_mismatch;
    wire            stat_rx_toolong;
    wire [6:0]      stat_rx_total_bytes;
    wire [13:0]     stat_rx_total_good_bytes;
    wire            stat_rx_total_good_packets;
    wire [2:0]      stat_rx_total_packets;
    wire            stat_rx_truncated;
    wire [2:0]      stat_rx_undersize;
    wire            stat_rx_unicast;
    wire            stat_rx_vlan;
    wire [19:0]     stat_rx_pcsl_demuxed;
    wire [4:0]      stat_rx_pcsl_number_0;
    wire [4:0]      stat_rx_pcsl_number_1;
    wire [4:0]      stat_rx_pcsl_number_10;
    wire [4:0]      stat_rx_pcsl_number_11;
    wire [4:0]      stat_rx_pcsl_number_12;
    wire [4:0]      stat_rx_pcsl_number_13;
    wire [4:0]      stat_rx_pcsl_number_14;
    wire [4:0]      stat_rx_pcsl_number_15;
    wire [4:0]      stat_rx_pcsl_number_16;
    wire [4:0]      stat_rx_pcsl_number_17;
    wire [4:0]      stat_rx_pcsl_number_18;
    wire [4:0]      stat_rx_pcsl_number_19;
    wire [4:0]      stat_rx_pcsl_number_2;
    wire [4:0]      stat_rx_pcsl_number_3;
    wire [4:0]      stat_rx_pcsl_number_4;
    wire [4:0]      stat_rx_pcsl_number_5;
    wire [4:0]      stat_rx_pcsl_number_6;
    wire [4:0]      stat_rx_pcsl_number_7;
    wire [4:0]      stat_rx_pcsl_number_8;
    wire [4:0]      stat_rx_pcsl_number_9;
    wire            stat_tx_bad_fcs;
    wire            stat_tx_broadcast;
    wire            stat_tx_frame_error;
    wire            stat_tx_local_fault;
    wire            stat_tx_multicast;
    wire            stat_tx_packet_1024_1518_bytes;
    wire            stat_tx_packet_128_255_bytes;
    wire            stat_tx_packet_1519_1522_bytes;
    wire            stat_tx_packet_1523_1548_bytes;
    wire            stat_tx_packet_1549_2047_bytes;
    wire            stat_tx_packet_2048_4095_bytes;
    wire            stat_tx_packet_256_511_bytes;
    wire            stat_tx_packet_4096_8191_bytes;
    wire            stat_tx_packet_512_1023_bytes;
    wire            stat_tx_packet_64_bytes;
    wire            stat_tx_packet_65_127_bytes;
    wire            stat_tx_packet_8192_9215_bytes;
    wire            stat_tx_packet_large;
    wire            stat_tx_packet_small;
    wire [5:0]      stat_tx_total_bytes;
    wire [13:0]     stat_tx_total_good_bytes;
    wire            stat_tx_total_good_packets;
    wire            stat_tx_total_packets;
    wire            stat_tx_unicast;
    wire            stat_tx_vlan;

    wire [7:0]      rx_otn_bip8_0;
    wire [7:0]      rx_otn_bip8_1;
    wire [7:0]      rx_otn_bip8_2;
    wire [7:0]      rx_otn_bip8_3;
    wire [7:0]      rx_otn_bip8_4;
    wire [65:0]     rx_otn_data_0;
    wire [65:0]     rx_otn_data_1;
    wire [65:0]     rx_otn_data_2;
    wire [65:0]     rx_otn_data_3;
    wire [65:0]     rx_otn_data_4;
    wire            rx_otn_ena;
    wire            rx_otn_lane0;
    wire            rx_otn_vlmarker;
    wire [55:0]     rx_preambleout;


    wire            ctl_rx_enable;
    wire            ctl_rx_force_resync;
    wire            ctl_rx_test_pattern;
    wire            ctl_tx_enable;
    wire            ctl_tx_test_pattern;
    wire            ctl_tx_send_idle;
    wire            ctl_tx_send_rfi;
    wire            ctl_tx_send_lfi;
    wire            rx_reset;
    wire            tx_reset;
    wire [GT_LANE_WIDTH - 1 :0]     gt_rxrecclkout;
    wire [GT_LANE_WIDTH - 1 :0]     gt_powergoodout;
    wire            gtwiz_reset_tx_datapath;
    wire            gtwiz_reset_rx_datapath;


    assign gtwiz_reset_tx_datapath    = 1'b0;
    assign gtwiz_reset_rx_datapath    = 1'b0;

    mkPfcUdpIpArpEthCmacRxTxInst udp_inst(
	    .udp_clk(udp_clk),
        .udp_reset(udp_reset),

        .cmac_rxtx_clk(txusrclk2),
        .cmac_rx_reset(usr_rx_reset),
        .cmac_tx_reset(usr_tx_reset),

        .udpConfig_put(udpConfig_put),
        .EN_udpConfig_put(EN_udpConfig_put),
        .RDY_udpConfig_put(RDY_udpConfig_put),

        // Channel 0
        .udpIpMetaDataInTxVec_0_put(udpIpMetaDataInTxVec_0_put),
        .EN_udpIpMetaDataInTxVec_0_put(EN_udpIpMetaDataInTxVec_0_put),
        .RDY_udpIpMetaDataInTxVec_0_put(RDY_udpIpMetaDataInTxVec_0_put),

        .dataStreamInTxVec_0_put(dataStreamInTxVec_0_put),
        .EN_dataStreamInTxVec_0_put(EN_dataStreamInTxVec_0_put),
        .RDY_dataStreamInTxVec_0_put(RDY_dataStreamInTxVec_0_put),

        .EN_udpIpMetaDataOutRxVec_0_get(EN_udpIpMetaDataOutRxVec_0_get),
        .udpIpMetaDataOutRxVec_0_get(udpIpMetaDataOutRxVec_0_get),
        .RDY_udpIpMetaDataOutRxVec_0_get(RDY_udpIpMetaDataOutRxVec_0_get),

        .EN_dataStreamOutRxVec_0_get(EN_dataStreamOutRxVec_0_get),
        .dataStreamOutRxVec_0_get(dataStreamOutRxVec_0_get),
        .RDY_dataStreamOutRxVec_0_get(RDY_dataStreamOutRxVec_0_get),

        // Channel 1
        .udpIpMetaDataInTxVec_1_put(udpIpMetaDataInTxVec_1_put),
        .EN_udpIpMetaDataInTxVec_1_put(EN_udpIpMetaDataInTxVec_1_put),
        .RDY_udpIpMetaDataInTxVec_1_put(RDY_udpIpMetaDataInTxVec_1_put),

        .dataStreamInTxVec_1_put(dataStreamInTxVec_1_put),
        .EN_dataStreamInTxVec_1_put(EN_dataStreamInTxVec_1_put),
        .RDY_dataStreamInTxVec_1_put(RDY_dataStreamInTxVec_1_put),

        .EN_udpIpMetaDataOutRxVec_1_get(EN_udpIpMetaDataOutRxVec_1_get),
        .udpIpMetaDataOutRxVec_1_get(udpIpMetaDataOutRxVec_1_get),
        .RDY_udpIpMetaDataOutRxVec_1_get(RDY_udpIpMetaDataOutRxVec_1_get),

        .EN_dataStreamOutRxVec_1_get(EN_dataStreamOutRxVec_1_get),
        .dataStreamOutRxVec_1_get(dataStreamOutRxVec_1_get),
        .RDY_dataStreamOutRxVec_1_get(RDY_dataStreamOutRxVec_1_get),

        // Channel 2
        .udpIpMetaDataInTxVec_2_put(udpIpMetaDataInTxVec_2_put),
        .EN_udpIpMetaDataInTxVec_2_put(EN_udpIpMetaDataInTxVec_2_put),
        .RDY_udpIpMetaDataInTxVec_2_put(RDY_udpIpMetaDataInTxVec_2_put),

        .dataStreamInTxVec_2_put(dataStreamInTxVec_2_put),
        .EN_dataStreamInTxVec_2_put(EN_dataStreamInTxVec_2_put),
        .RDY_dataStreamInTxVec_2_put(RDY_dataStreamInTxVec_2_put),

        .EN_udpIpMetaDataOutRxVec_2_get(EN_udpIpMetaDataOutRxVec_2_get),
        .udpIpMetaDataOutRxVec_2_get(udpIpMetaDataOutRxVec_2_get),
        .RDY_udpIpMetaDataOutRxVec_2_get(RDY_udpIpMetaDataOutRxVec_2_get),

        .EN_dataStreamOutRxVec_2_get(EN_dataStreamOutRxVec_2_get),
        .dataStreamOutRxVec_2_get(dataStreamOutRxVec_2_get),
        .RDY_dataStreamOutRxVec_2_get(RDY_dataStreamOutRxVec_2_get),

        // Channel 3
        .udpIpMetaDataInTxVec_3_put(udpIpMetaDataInTxVec_3_put),
        .EN_udpIpMetaDataInTxVec_3_put(EN_udpIpMetaDataInTxVec_3_put),
        .RDY_udpIpMetaDataInTxVec_3_put(RDY_udpIpMetaDataInTxVec_3_put),

        .dataStreamInTxVec_3_put(dataStreamInTxVec_3_put),
        .EN_dataStreamInTxVec_3_put(EN_dataStreamInTxVec_3_put),
        .RDY_dataStreamInTxVec_3_put(RDY_dataStreamInTxVec_3_put),

        .EN_udpIpMetaDataOutRxVec_3_get(EN_udpIpMetaDataOutRxVec_3_get),
        .udpIpMetaDataOutRxVec_3_get(udpIpMetaDataOutRxVec_3_get),
        .RDY_udpIpMetaDataOutRxVec_3_get(RDY_udpIpMetaDataOutRxVec_3_get),

        .EN_dataStreamOutRxVec_3_get(EN_dataStreamOutRxVec_3_get),
        .dataStreamOutRxVec_3_get(dataStreamOutRxVec_3_get),
        .RDY_dataStreamOutRxVec_3_get(RDY_dataStreamOutRxVec_3_get),

        // Channel 4
        .udpIpMetaDataInTxVec_4_put(udpIpMetaDataInTxVec_4_put),
        .EN_udpIpMetaDataInTxVec_4_put(EN_udpIpMetaDataInTxVec_4_put),
        .RDY_udpIpMetaDataInTxVec_4_put(RDY_udpIpMetaDataInTxVec_4_put),

        .dataStreamInTxVec_4_put(dataStreamInTxVec_4_put),
        .EN_dataStreamInTxVec_4_put(EN_dataStreamInTxVec_4_put),
        .RDY_dataStreamInTxVec_4_put(RDY_dataStreamInTxVec_4_put),

        .EN_udpIpMetaDataOutRxVec_4_get(EN_udpIpMetaDataOutRxVec_4_get),
        .udpIpMetaDataOutRxVec_4_get(udpIpMetaDataOutRxVec_4_get),
        .RDY_udpIpMetaDataOutRxVec_4_get(RDY_udpIpMetaDataOutRxVec_4_get),

        .EN_dataStreamOutRxVec_4_get(EN_dataStreamOutRxVec_4_get),
        .dataStreamOutRxVec_4_get(dataStreamOutRxVec_4_get),
        .RDY_dataStreamOutRxVec_4_get(RDY_dataStreamOutRxVec_4_get),

        // Channel 5
        .udpIpMetaDataInTxVec_5_put(udpIpMetaDataInTxVec_5_put),
        .EN_udpIpMetaDataInTxVec_5_put(EN_udpIpMetaDataInTxVec_5_put),
        .RDY_udpIpMetaDataInTxVec_5_put(RDY_udpIpMetaDataInTxVec_5_put),

        .dataStreamInTxVec_5_put(dataStreamInTxVec_5_put),
        .EN_dataStreamInTxVec_5_put(EN_dataStreamInTxVec_5_put),
        .RDY_dataStreamInTxVec_5_put(RDY_dataStreamInTxVec_5_put),

        .EN_udpIpMetaDataOutRxVec_5_get(EN_udpIpMetaDataOutRxVec_5_get),
        .udpIpMetaDataOutRxVec_5_get(udpIpMetaDataOutRxVec_5_get),
        .RDY_udpIpMetaDataOutRxVec_5_get(RDY_udpIpMetaDataOutRxVec_5_get),

        .EN_dataStreamOutRxVec_5_get(EN_dataStreamOutRxVec_5_get),
        .dataStreamOutRxVec_5_get(dataStreamOutRxVec_5_get),
        .RDY_dataStreamOutRxVec_5_get(RDY_dataStreamOutRxVec_5_get),

        // Channel 6
        .udpIpMetaDataInTxVec_6_put(udpIpMetaDataInTxVec_6_put),
        .EN_udpIpMetaDataInTxVec_6_put(EN_udpIpMetaDataInTxVec_6_put),
        .RDY_udpIpMetaDataInTxVec_6_put(RDY_udpIpMetaDataInTxVec_6_put),

        .dataStreamInTxVec_6_put(dataStreamInTxVec_6_put),
        .EN_dataStreamInTxVec_6_put(EN_dataStreamInTxVec_6_put),
        .RDY_dataStreamInTxVec_6_put(RDY_dataStreamInTxVec_6_put),

        .EN_udpIpMetaDataOutRxVec_6_get(EN_udpIpMetaDataOutRxVec_6_get),
        .udpIpMetaDataOutRxVec_6_get(udpIpMetaDataOutRxVec_6_get),
        .RDY_udpIpMetaDataOutRxVec_6_get(RDY_udpIpMetaDataOutRxVec_6_get),

        .EN_dataStreamOutRxVec_6_get(EN_dataStreamOutRxVec_6_get),
        .dataStreamOutRxVec_6_get(dataStreamOutRxVec_6_get),
        .RDY_dataStreamOutRxVec_6_get(RDY_dataStreamOutRxVec_6_get),

        // Channel 7
        .udpIpMetaDataInTxVec_7_put(udpIpMetaDataInTxVec_7_put),
        .EN_udpIpMetaDataInTxVec_7_put(EN_udpIpMetaDataInTxVec_7_put),
        .RDY_udpIpMetaDataInTxVec_7_put(RDY_udpIpMetaDataInTxVec_7_put),

        .dataStreamInTxVec_7_put(dataStreamInTxVec_7_put),
        .EN_dataStreamInTxVec_7_put(EN_dataStreamInTxVec_7_put),
        .RDY_dataStreamInTxVec_7_put(RDY_dataStreamInTxVec_7_put),

        .EN_udpIpMetaDataOutRxVec_7_get(EN_udpIpMetaDataOutRxVec_7_get),
        .udpIpMetaDataOutRxVec_7_get(udpIpMetaDataOutRxVec_7_get),
        .RDY_udpIpMetaDataOutRxVec_7_get(RDY_udpIpMetaDataOutRxVec_7_get),

        .EN_dataStreamOutRxVec_7_get(EN_dataStreamOutRxVec_7_get),
        .dataStreamOutRxVec_7_get(dataStreamOutRxVec_7_get),
        .RDY_dataStreamOutRxVec_7_get(RDY_dataStreamOutRxVec_7_get),


	    .tx_axis_tvalid(tx_axis_tvalid),
		.tx_axis_tdata ( tx_axis_tdata),
		.tx_axis_tkeep ( tx_axis_tkeep),
		.tx_axis_tlast ( tx_axis_tlast),
		.tx_axis_tuser ( tx_axis_tuser),
		.tx_axis_tready(tx_axis_tready),

		.tx_ctl_enable      (      ctl_tx_enable),
		.tx_ctl_test_pattern(ctl_tx_test_pattern),
		.tx_ctl_send_idle   (   ctl_tx_send_idle),
		.tx_ctl_send_lfi    (    ctl_tx_send_lfi),
		.tx_ctl_send_rfi    (    ctl_tx_send_rfi),
		.tx_ctl_reset(),

	    .tx_ctl_pause_enable (ctl_tx_pause_enable),
	    .tx_ctl_pause_req    (ctl_tx_pause_req),
	    .tx_ctl_pause_quanta0(ctl_tx_pause_quanta0),
	    .tx_ctl_pause_quanta1(ctl_tx_pause_quanta1),
	    .tx_ctl_pause_quanta2(ctl_tx_pause_quanta2),
	    .tx_ctl_pause_quanta3(ctl_tx_pause_quanta3),
		.tx_ctl_pause_quanta4(ctl_tx_pause_quanta4),
		.tx_ctl_pause_quanta5(ctl_tx_pause_quanta5),
		.tx_ctl_pause_quanta6(ctl_tx_pause_quanta6),
		.tx_ctl_pause_quanta7(ctl_tx_pause_quanta7),
		.tx_ctl_pause_quanta8(ctl_tx_pause_quanta8),

		.tx_stat_ovfout    (tx_ovfout),
		.tx_stat_unfout    (tx_unfout),
		.tx_stat_rx_aligned(stat_rx_aligned),

		.rx_axis_tvalid(rx_axis_tvalid),
		.rx_axis_tdata (rx_axis_tdata),
		.rx_axis_tkeep (rx_axis_tkeep),
		.rx_axis_tlast (rx_axis_tlast),
		.rx_axis_tuser (rx_axis_tuser),
		.rx_axis_tready(),

		.rx_ctl_enable      (ctl_rx_enable),
		.rx_ctl_force_resync(ctl_rx_force_resync),
		.rx_ctl_test_pattern(ctl_rx_test_pattern),
		.rx_ctl_reset(),
		
		.rx_ctl_pause_enable    (ctl_rx_pause_enable),
		.rx_ctl_pause_ack       (ctl_rx_pause_ack),
		
		.rx_ctl_enable_gcp      (ctl_rx_enable_gcp),
		.rx_ctl_check_mcast_gcp (ctl_rx_check_mcast_gcp),
		.rx_ctl_check_ucast_gcp (ctl_rx_check_ucast_gcp),
		.rx_ctl_check_sa_gcp    (ctl_rx_check_sa_gcp),
		.rx_ctl_check_etype_gcp (ctl_rx_check_etype_gcp),
		.rx_ctl_check_opcode_gcp(ctl_rx_check_opcode_gcp),
		
		.rx_ctl_enable_pcp      (ctl_rx_enable_pcp),
		.rx_ctl_check_mcast_pcp (ctl_rx_check_mcast_pcp),
		.rx_ctl_check_ucast_pcp (ctl_rx_check_ucast_pcp),
		.rx_ctl_check_sa_pcp    (ctl_rx_check_sa_pcp),
		.rx_ctl_check_etype_pcp (ctl_rx_etype_pcp),
		.rx_ctl_check_opcode_pcp(ctl_rx_check_opcode_pcp),
		
		.rx_ctl_enable_gpp      (ctl_rx_enable_gpp),
		.rx_ctl_check_mcast_gpp (ctl_rx_check_mcast_gpp),
		.rx_ctl_check_ucast_gpp (ctl_rx_check_ucast_gpp),
		.rx_ctl_check_sa_gpp    (ctl_rx_check_sa_gpp),
		.rx_ctl_check_etype_gpp (ctl_rx_check_etype_gpp),
		.rx_ctl_check_opcode_gpp(ctl_rx_check_opcode_gpp),
		
		.rx_ctl_enable_ppp      (ctl_rx_enable_ppp),
		.rx_ctl_check_mcast_ppp (ctl_rx_check_mcast_ppp),
		.rx_ctl_check_ucast_ppp (ctl_rx_check_ucast_ppp),
		.rx_ctl_check_sa_ppp    (ctl_rx_check_sa_ppp),
		.rx_ctl_check_etype_ppp (ctl_rx_check_etype_ppp),
		.rx_ctl_check_opcode_ppp(ctl_rx_check_opcode_ppp),

		.rx_stat_aligned  (stat_rx_aligned),
		.rx_stat_pause_req(stat_rx_pause_req)
    );

    cmac_usplus_0 cmac_inst(
        .gt_rxp_in                            (gt_rxp_in),
        .gt_rxn_in                            (gt_rxn_in),
        .gt_txp_out                           (gt_txp_out),
        .gt_txn_out                           (gt_txn_out),
        
        .gt_txusrclk2                         (txusrclk2),
        .gt_loopback_in                       (gt_loopback_in),
        .gt_rxrecclkout                       (gt_rxrecclkout),
        .gt_powergoodout                      (gt_powergoodout),
        .gtwiz_reset_tx_datapath              (gtwiz_reset_tx_datapath),
        .gtwiz_reset_rx_datapath              (gtwiz_reset_rx_datapath),
        .sys_reset                            (sys_reset),
        .gt_ref_clk_p                         (gt_ref_clk_p),
        .gt_ref_clk_n                         (gt_ref_clk_n),
        .init_clk                             (init_clk),
        .gt_ref_clk_out                       (gt_ref_clk_out),

        .rx_axis_tvalid                       (rx_axis_tvalid),
        .rx_axis_tdata                        (rx_axis_tdata),
        .rx_axis_tkeep                        (rx_axis_tkeep),
        .rx_axis_tlast                        (rx_axis_tlast),
        .rx_axis_tuser                        (rx_axis_tuser),
        
        .rx_otn_bip8_0                        (rx_otn_bip8_0),
        .rx_otn_bip8_1                        (rx_otn_bip8_1),
        .rx_otn_bip8_2                        (rx_otn_bip8_2),
        .rx_otn_bip8_3                        (rx_otn_bip8_3),
        .rx_otn_bip8_4                        (rx_otn_bip8_4),
        .rx_otn_data_0                        (rx_otn_data_0),
        .rx_otn_data_1                        (rx_otn_data_1),
        .rx_otn_data_2                        (rx_otn_data_2),
        .rx_otn_data_3                        (rx_otn_data_3),
        .rx_otn_data_4                        (rx_otn_data_4),
        .rx_otn_ena                           (rx_otn_ena),
        .rx_otn_lane0                         (rx_otn_lane0),
        .rx_otn_vlmarker                      (rx_otn_vlmarker),
        .rx_preambleout                       (rx_preambleout),
        .usr_rx_reset                         (usr_rx_reset),
        .gt_rxusrclk2                         (rxusrclk2),
        
        .stat_rx_aligned                      (stat_rx_aligned),
        .stat_rx_aligned_err                  (stat_rx_aligned_err),
        .stat_rx_bad_code                     (stat_rx_bad_code),
        .stat_rx_bad_fcs                      (stat_rx_bad_fcs),
        .stat_rx_bad_preamble                 (stat_rx_bad_preamble),
        .stat_rx_bad_sfd                      (stat_rx_bad_sfd),
        .stat_rx_bip_err_0                    (stat_rx_bip_err_0),
        .stat_rx_bip_err_1                    (stat_rx_bip_err_1),
        .stat_rx_bip_err_10                   (stat_rx_bip_err_10),
        .stat_rx_bip_err_11                   (stat_rx_bip_err_11),
        .stat_rx_bip_err_12                   (stat_rx_bip_err_12),
        .stat_rx_bip_err_13                   (stat_rx_bip_err_13),
        .stat_rx_bip_err_14                   (stat_rx_bip_err_14),
        .stat_rx_bip_err_15                   (stat_rx_bip_err_15),
        .stat_rx_bip_err_16                   (stat_rx_bip_err_16),
        .stat_rx_bip_err_17                   (stat_rx_bip_err_17),
        .stat_rx_bip_err_18                   (stat_rx_bip_err_18),
        .stat_rx_bip_err_19                   (stat_rx_bip_err_19),
        .stat_rx_bip_err_2                    (stat_rx_bip_err_2),
        .stat_rx_bip_err_3                    (stat_rx_bip_err_3),
        .stat_rx_bip_err_4                    (stat_rx_bip_err_4),
        .stat_rx_bip_err_5                    (stat_rx_bip_err_5),
        .stat_rx_bip_err_6                    (stat_rx_bip_err_6),
        .stat_rx_bip_err_7                    (stat_rx_bip_err_7),
        .stat_rx_bip_err_8                    (stat_rx_bip_err_8),
        .stat_rx_bip_err_9                    (stat_rx_bip_err_9),
        .stat_rx_block_lock                   (stat_rx_block_lock),
        .stat_rx_broadcast                    (stat_rx_broadcast),
        .stat_rx_fragment                     (stat_rx_fragment),
        .stat_rx_framing_err_0                (stat_rx_framing_err_0),
        .stat_rx_framing_err_1                (stat_rx_framing_err_1),
        .stat_rx_framing_err_10               (stat_rx_framing_err_10),
        .stat_rx_framing_err_11               (stat_rx_framing_err_11),
        .stat_rx_framing_err_12               (stat_rx_framing_err_12),
        .stat_rx_framing_err_13               (stat_rx_framing_err_13),
        .stat_rx_framing_err_14               (stat_rx_framing_err_14),
        .stat_rx_framing_err_15               (stat_rx_framing_err_15),
        .stat_rx_framing_err_16               (stat_rx_framing_err_16),
        .stat_rx_framing_err_17               (stat_rx_framing_err_17),
        .stat_rx_framing_err_18               (stat_rx_framing_err_18),
        .stat_rx_framing_err_19               (stat_rx_framing_err_19),
        .stat_rx_framing_err_2                (stat_rx_framing_err_2),
        .stat_rx_framing_err_3                (stat_rx_framing_err_3),
        .stat_rx_framing_err_4                (stat_rx_framing_err_4),
        .stat_rx_framing_err_5                (stat_rx_framing_err_5),
        .stat_rx_framing_err_6                (stat_rx_framing_err_6),
        .stat_rx_framing_err_7                (stat_rx_framing_err_7),
        .stat_rx_framing_err_8                (stat_rx_framing_err_8),
        .stat_rx_framing_err_9                (stat_rx_framing_err_9),
        .stat_rx_framing_err_valid_0          (stat_rx_framing_err_valid_0),
        .stat_rx_framing_err_valid_1          (stat_rx_framing_err_valid_1),
        .stat_rx_framing_err_valid_10         (stat_rx_framing_err_valid_10),
        .stat_rx_framing_err_valid_11         (stat_rx_framing_err_valid_11),
        .stat_rx_framing_err_valid_12         (stat_rx_framing_err_valid_12),
        .stat_rx_framing_err_valid_13         (stat_rx_framing_err_valid_13),
        .stat_rx_framing_err_valid_14         (stat_rx_framing_err_valid_14),
        .stat_rx_framing_err_valid_15         (stat_rx_framing_err_valid_15),
        .stat_rx_framing_err_valid_16         (stat_rx_framing_err_valid_16),
        .stat_rx_framing_err_valid_17         (stat_rx_framing_err_valid_17),
        .stat_rx_framing_err_valid_18         (stat_rx_framing_err_valid_18),
        .stat_rx_framing_err_valid_19         (stat_rx_framing_err_valid_19),
        .stat_rx_framing_err_valid_2          (stat_rx_framing_err_valid_2),
        .stat_rx_framing_err_valid_3          (stat_rx_framing_err_valid_3),
        .stat_rx_framing_err_valid_4          (stat_rx_framing_err_valid_4),
        .stat_rx_framing_err_valid_5          (stat_rx_framing_err_valid_5),
        .stat_rx_framing_err_valid_6          (stat_rx_framing_err_valid_6),
        .stat_rx_framing_err_valid_7          (stat_rx_framing_err_valid_7),
        .stat_rx_framing_err_valid_8          (stat_rx_framing_err_valid_8),
        .stat_rx_framing_err_valid_9          (stat_rx_framing_err_valid_9),
        .stat_rx_got_signal_os                (stat_rx_got_signal_os),
        .stat_rx_hi_ber                       (stat_rx_hi_ber),
        .stat_rx_inrangeerr                   (stat_rx_inrangeerr),
        .stat_rx_internal_local_fault         (stat_rx_internal_local_fault),
        .stat_rx_jabber                       (stat_rx_jabber),
        .stat_rx_local_fault                  (stat_rx_local_fault),
        .stat_rx_mf_err                       (stat_rx_mf_err),
        .stat_rx_mf_len_err                   (stat_rx_mf_len_err),
        .stat_rx_mf_repeat_err                (stat_rx_mf_repeat_err),
        .stat_rx_misaligned                   (stat_rx_misaligned),
        .stat_rx_multicast                    (stat_rx_multicast),
        .stat_rx_oversize                     (stat_rx_oversize),
        .stat_rx_packet_1024_1518_bytes       (stat_rx_packet_1024_1518_bytes),
        .stat_rx_packet_128_255_bytes         (stat_rx_packet_128_255_bytes),
        .stat_rx_packet_1519_1522_bytes       (stat_rx_packet_1519_1522_bytes),
        .stat_rx_packet_1523_1548_bytes       (stat_rx_packet_1523_1548_bytes),
        .stat_rx_packet_1549_2047_bytes       (stat_rx_packet_1549_2047_bytes),
        .stat_rx_packet_2048_4095_bytes       (stat_rx_packet_2048_4095_bytes),
        .stat_rx_packet_256_511_bytes         (stat_rx_packet_256_511_bytes),
        .stat_rx_packet_4096_8191_bytes       (stat_rx_packet_4096_8191_bytes),
        .stat_rx_packet_512_1023_bytes        (stat_rx_packet_512_1023_bytes),
        .stat_rx_packet_64_bytes              (stat_rx_packet_64_bytes),
        .stat_rx_packet_65_127_bytes          (stat_rx_packet_65_127_bytes),
        .stat_rx_packet_8192_9215_bytes       (stat_rx_packet_8192_9215_bytes),
        .stat_rx_packet_bad_fcs               (stat_rx_packet_bad_fcs),
        .stat_rx_packet_large                 (stat_rx_packet_large),
        .stat_rx_packet_small                 (stat_rx_packet_small),
        .stat_rx_pause                        (stat_rx_pause),
        .stat_rx_pause_quanta0                (stat_rx_pause_quanta0),
        .stat_rx_pause_quanta1                (stat_rx_pause_quanta1),
        .stat_rx_pause_quanta2                (stat_rx_pause_quanta2),
        .stat_rx_pause_quanta3                (stat_rx_pause_quanta3),
        .stat_rx_pause_quanta4                (stat_rx_pause_quanta4),
        .stat_rx_pause_quanta5                (stat_rx_pause_quanta5),
        .stat_rx_pause_quanta6                (stat_rx_pause_quanta6),
        .stat_rx_pause_quanta7                (stat_rx_pause_quanta7),
        .stat_rx_pause_quanta8                (stat_rx_pause_quanta8),
        .stat_rx_pause_req                    (stat_rx_pause_req),
        .stat_rx_pause_valid                  (stat_rx_pause_valid),
        .stat_rx_user_pause                   (stat_rx_user_pause),
        
        .ctl_rx_check_etype_gcp               (ctl_rx_check_etype_gcp),
        .ctl_rx_check_etype_gpp               (ctl_rx_check_etype_gpp),
        .ctl_rx_check_etype_pcp               (ctl_rx_check_etype_pcp),
        .ctl_rx_check_etype_ppp               (ctl_rx_check_etype_ppp),
        .ctl_rx_check_mcast_gcp               (ctl_rx_check_mcast_gcp),
        .ctl_rx_check_mcast_gpp               (ctl_rx_check_mcast_gpp),
        .ctl_rx_check_mcast_pcp               (ctl_rx_check_mcast_pcp),
        .ctl_rx_check_mcast_ppp               (ctl_rx_check_mcast_ppp),
        .ctl_rx_check_opcode_gcp              (ctl_rx_check_opcode_gcp),
        .ctl_rx_check_opcode_gpp              (ctl_rx_check_opcode_gpp),
        .ctl_rx_check_opcode_pcp              (ctl_rx_check_opcode_pcp),
        .ctl_rx_check_opcode_ppp              (ctl_rx_check_opcode_ppp),
        .ctl_rx_check_sa_gcp                  (ctl_rx_check_sa_gcp),
        .ctl_rx_check_sa_gpp                  (ctl_rx_check_sa_gpp),
        .ctl_rx_check_sa_pcp                  (ctl_rx_check_sa_pcp),
        .ctl_rx_check_sa_ppp                  (ctl_rx_check_sa_ppp),
        .ctl_rx_check_ucast_gcp               (ctl_rx_check_ucast_gcp),
        .ctl_rx_check_ucast_gpp               (ctl_rx_check_ucast_gpp),
        .ctl_rx_check_ucast_pcp               (ctl_rx_check_ucast_pcp),
        .ctl_rx_check_ucast_ppp               (ctl_rx_check_ucast_ppp),
        .ctl_rx_enable_gcp                    (ctl_rx_enable_gcp),
        .ctl_rx_enable_gpp                    (ctl_rx_enable_gpp),
        .ctl_rx_enable_pcp                    (ctl_rx_enable_pcp),
        .ctl_rx_enable_ppp                    (ctl_rx_enable_ppp),
        .ctl_rx_pause_ack                     (ctl_rx_pause_ack),
        .ctl_rx_pause_enable                  (ctl_rx_pause_enable),
        
        .ctl_rx_enable                        (ctl_rx_enable),
        .ctl_rx_force_resync                  (ctl_rx_force_resync),
        .ctl_rx_test_pattern                  (ctl_rx_test_pattern),
        
        .core_rx_reset                        (1'b0),
        .rx_clk                               (txusrclk2),
        .stat_rx_received_local_fault         (stat_rx_received_local_fault),
        .stat_rx_remote_fault                 (stat_rx_remote_fault),
        .stat_rx_status                       (stat_rx_status),
        .stat_rx_stomped_fcs                  (stat_rx_stomped_fcs),
        .stat_rx_synced                       (stat_rx_synced),
        .stat_rx_synced_err                   (stat_rx_synced_err),
        .stat_rx_test_pattern_mismatch        (stat_rx_test_pattern_mismatch),
        .stat_rx_toolong                      (stat_rx_toolong),
        .stat_rx_total_bytes                  (stat_rx_total_bytes),
        .stat_rx_total_good_bytes             (stat_rx_total_good_bytes),
        .stat_rx_total_good_packets           (stat_rx_total_good_packets),
        .stat_rx_total_packets                (stat_rx_total_packets),
        .stat_rx_truncated                    (stat_rx_truncated),
        .stat_rx_undersize                    (stat_rx_undersize),
        .stat_rx_unicast                      (stat_rx_unicast),
        .stat_rx_vlan                         (stat_rx_vlan),
        .stat_rx_pcsl_demuxed                 (stat_rx_pcsl_demuxed),
        .stat_rx_pcsl_number_0                (stat_rx_pcsl_number_0),
        .stat_rx_pcsl_number_1                (stat_rx_pcsl_number_1),
        .stat_rx_pcsl_number_10               (stat_rx_pcsl_number_10),
        .stat_rx_pcsl_number_11               (stat_rx_pcsl_number_11),
        .stat_rx_pcsl_number_12               (stat_rx_pcsl_number_12),
        .stat_rx_pcsl_number_13               (stat_rx_pcsl_number_13),
        .stat_rx_pcsl_number_14               (stat_rx_pcsl_number_14),
        .stat_rx_pcsl_number_15               (stat_rx_pcsl_number_15),
        .stat_rx_pcsl_number_16               (stat_rx_pcsl_number_16),
        .stat_rx_pcsl_number_17               (stat_rx_pcsl_number_17),
        .stat_rx_pcsl_number_18               (stat_rx_pcsl_number_18),
        .stat_rx_pcsl_number_19               (stat_rx_pcsl_number_19),
        .stat_rx_pcsl_number_2                (stat_rx_pcsl_number_2),
        .stat_rx_pcsl_number_3                (stat_rx_pcsl_number_3),
        .stat_rx_pcsl_number_4                (stat_rx_pcsl_number_4),
        .stat_rx_pcsl_number_5                (stat_rx_pcsl_number_5),
        .stat_rx_pcsl_number_6                (stat_rx_pcsl_number_6),
        .stat_rx_pcsl_number_7                (stat_rx_pcsl_number_7),
        .stat_rx_pcsl_number_8                (stat_rx_pcsl_number_8),
        .stat_rx_pcsl_number_9                (stat_rx_pcsl_number_9),
        .stat_tx_bad_fcs                      (stat_tx_bad_fcs),
        .stat_tx_broadcast                    (stat_tx_broadcast),
        .stat_tx_frame_error                  (stat_tx_frame_error),
        .stat_tx_local_fault                  (stat_tx_local_fault),
        .stat_tx_multicast                    (stat_tx_multicast),
        .stat_tx_packet_1024_1518_bytes       (stat_tx_packet_1024_1518_bytes),
        .stat_tx_packet_128_255_bytes         (stat_tx_packet_128_255_bytes),
        .stat_tx_packet_1519_1522_bytes       (stat_tx_packet_1519_1522_bytes),
        .stat_tx_packet_1523_1548_bytes       (stat_tx_packet_1523_1548_bytes),
        .stat_tx_packet_1549_2047_bytes       (stat_tx_packet_1549_2047_bytes),
        .stat_tx_packet_2048_4095_bytes       (stat_tx_packet_2048_4095_bytes),
        .stat_tx_packet_256_511_bytes         (stat_tx_packet_256_511_bytes),
        .stat_tx_packet_4096_8191_bytes       (stat_tx_packet_4096_8191_bytes),
        .stat_tx_packet_512_1023_bytes        (stat_tx_packet_512_1023_bytes),
        .stat_tx_packet_64_bytes              (stat_tx_packet_64_bytes),
        .stat_tx_packet_65_127_bytes          (stat_tx_packet_65_127_bytes),
        .stat_tx_packet_8192_9215_bytes       (stat_tx_packet_8192_9215_bytes),
        .stat_tx_packet_large                 (stat_tx_packet_large),
        .stat_tx_packet_small                 (stat_tx_packet_small),
        .stat_tx_total_bytes                  (stat_tx_total_bytes),
        .stat_tx_total_good_bytes             (stat_tx_total_good_bytes),
        .stat_tx_total_good_packets           (stat_tx_total_good_packets),
        .stat_tx_total_packets                (stat_tx_total_packets),
        .stat_tx_unicast                      (stat_tx_unicast),
        .stat_tx_vlan                         (stat_tx_vlan),


        .ctl_tx_enable                        (ctl_tx_enable),
        .ctl_tx_test_pattern                  (ctl_tx_test_pattern),
        .ctl_tx_send_idle                     (ctl_tx_send_idle),
        .ctl_tx_send_rfi                      (ctl_tx_send_rfi),
        .ctl_tx_send_lfi                      (ctl_tx_send_lfi),
        .core_tx_reset                        (1'b0),
        .stat_tx_pause_valid                  (stat_tx_pause_valid),
        .stat_tx_pause                        (stat_tx_pause),
        .stat_tx_user_pause                   (stat_tx_user_pause),
        
        .ctl_tx_pause_enable                  (ctl_tx_pause_enable),
        .ctl_tx_pause_req                     (ctl_tx_pause_req),
        .ctl_tx_pause_quanta0                 (ctl_tx_pause_quanta0),
        .ctl_tx_pause_quanta1                 (ctl_tx_pause_quanta1),
        .ctl_tx_pause_quanta2                 (ctl_tx_pause_quanta2),
        .ctl_tx_pause_quanta3                 (ctl_tx_pause_quanta3),
        .ctl_tx_pause_quanta4                 (ctl_tx_pause_quanta4),
        .ctl_tx_pause_quanta5                 (ctl_tx_pause_quanta5),
        .ctl_tx_pause_quanta6                 (ctl_tx_pause_quanta6),
        .ctl_tx_pause_quanta7                 (ctl_tx_pause_quanta7),
        .ctl_tx_pause_quanta8                 (ctl_tx_pause_quanta8),
        .ctl_tx_pause_refresh_timer0          (0),
        .ctl_tx_pause_refresh_timer1          (0),
        .ctl_tx_pause_refresh_timer2          (0),
        .ctl_tx_pause_refresh_timer3          (0),
        .ctl_tx_pause_refresh_timer4          (0),
        .ctl_tx_pause_refresh_timer5          (0),
        .ctl_tx_pause_refresh_timer6          (0),
        .ctl_tx_pause_refresh_timer7          (0),
        .ctl_tx_pause_refresh_timer8          (0),
        .ctl_tx_resend_pause                  (0),
        
        .tx_axis_tready                       (tx_axis_tready),
        .tx_axis_tvalid                       (tx_axis_tvalid),
        .tx_axis_tdata                        (tx_axis_tdata),
        .tx_axis_tkeep                        (tx_axis_tkeep),
        .tx_axis_tlast                        (tx_axis_tlast),
        .tx_axis_tuser                        (tx_axis_tuser),
        .tx_ovfout                            (tx_ovfout),
        .tx_unfout                            (tx_unfout),
        .tx_preamblein                        (0),
        .usr_tx_reset                         (usr_tx_reset),


        .core_drp_reset                       (1'b0),
        .drp_clk                              (1'b0),
        .drp_addr                             (10'b0),
        .drp_di                               (16'b0),
        .drp_en                               (1'b0),
        .drp_do                               (),
        .drp_rdy                              (),
        .drp_we                               (1'b0)
    );


endmodule