`timescale 1ps / 1ps

module UdpIpArpEthCmacRxTxWrapper#(
    parameter GT_LANE_WIDTH = 4,
    parameter XDMA_AXIS_TDATA_WIDTH = 512,
    parameter XDMA_AXIS_TKEEP_WIDTH = 64,
    parameter XDMA_AXIS_TUSER_WIDTH = 1
)(

    input udp_clk,
    input udp_reset,

    input gt1_ref_clk_p,
    input gt1_ref_clk_n,
    input gt1_init_clk,
    input gt1_sys_reset,

    input gt2_ref_clk_p,
    input gt2_ref_clk_n,
    input gt2_init_clk,
    input gt2_sys_reset,

    input xdma_rx_axis_tready,
    output xdma_rx_axis_tvalid,
    output xdma_rx_axis_tlast,
    output [XDMA_AXIS_TDATA_WIDTH - 1 : 0] xdma_rx_axis_tdata,
    output [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] xdma_rx_axis_tkeep,
    output [XDMA_AXIS_TUSER_WIDTH - 1 : 0] xdma_rx_axis_tuser,

    input xdma_tx_axis_tvalid,
    output xdma_tx_axis_tready,
    input xdma_tx_axis_tlast,
    input [XDMA_AXIS_TDATA_WIDTH - 1 : 0] xdma_tx_axis_tdata,
    input [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] xdma_tx_axis_tkeep,
    input [XDMA_AXIS_TUSER_WIDTH - 1 : 0]xdma_tx_axis_tuser,

    // Serdes
    input [GT_LANE_WIDTH - 1 : 0] gt1_rxn_in,
    input [GT_LANE_WIDTH - 1 : 0] gt1_rxp_in,
    output [GT_LANE_WIDTH - 1 : 0] gt1_txn_out,
    output [GT_LANE_WIDTH - 1 : 0] gt1_txp_out,
        
    input [GT_LANE_WIDTH - 1 : 0] gt2_rxn_in,
    input [GT_LANE_WIDTH - 1 : 0] gt2_rxp_in,
    output [GT_LANE_WIDTH - 1 : 0] gt2_txn_out,
    output [GT_LANE_WIDTH - 1 : 0] gt2_txp_out
);
    localparam CMAC_AXIS_TDATA_WIDTH = 512;
    localparam CMAC_AXIS_TKEEP_WIDTH = 64;
    localparam CMAC_AXIS_TUSER_WIDTH = 1;

    wire [(GT_LANE_WIDTH * 3)-1 :0]    gt_loopback_in;
    //// For other GT loopback options please change the value appropriately
    //// For example, for Near End PMA loopback for 4 Lanes update the gt_loopback_in = {4{3'b010}};
    //// For more information and settings on loopback, refer GT Transceivers user guide
    assign gt_loopback_in  = {GT_LANE_WIDTH{3'b000}};

    wire            gtwiz_reset_tx_datapath;
    wire            gtwiz_reset_rx_datapath;
    assign gtwiz_reset_tx_datapath    = 1'b0;
    assign gtwiz_reset_rx_datapath    = 1'b0;


    // GT1 Signals
    wire            gt1_txusrclk2;
    wire            gt1_usr_tx_reset;
    wire            gt1_usr_rx_reset;

    wire            gt1_rx_axis_tvalid;
    wire            gt1_rx_axis_tlast;
    wire [CMAC_AXIS_TDATA_WIDTH - 1 : 0] gt1_rx_axis_tdata;
    wire [CMAC_AXIS_TKEEP_WIDTH - 1 : 0] gt1_rx_axis_tkeep;
    wire [CMAC_AXIS_TUSER_WIDTH - 1 : 0] gt1_rx_axis_tuser;

    wire            gt1_stat_rx_aligned;
    wire [8:0]      gt1_stat_rx_pause_req;
    wire            gt1_ctl_rx_enable;
    wire            gt1_ctl_rx_force_resync;
    wire            gt1_ctl_rx_test_pattern;
    wire            gt1_ctl_rx_check_etype_gcp;
    wire            gt1_ctl_rx_check_etype_gpp;
    wire            gt1_ctl_rx_check_etype_pcp;
    wire            gt1_ctl_rx_check_etype_ppp;
    wire            gt1_ctl_rx_check_mcast_gcp;
    wire            gt1_ctl_rx_check_mcast_gpp;
    wire            gt1_ctl_rx_check_mcast_pcp;
    wire            gt1_ctl_rx_check_mcast_ppp;
    wire            gt1_ctl_rx_check_opcode_gcp;
    wire            gt1_ctl_rx_check_opcode_gpp;
    wire            gt1_ctl_rx_check_opcode_pcp;
    wire            gt1_ctl_rx_check_opcode_ppp;
    wire            gt1_ctl_rx_check_sa_gcp;
    wire            gt1_ctl_rx_check_sa_gpp;
    wire            gt1_ctl_rx_check_sa_pcp;
    wire            gt1_ctl_rx_check_sa_ppp;
    wire            gt1_ctl_rx_check_ucast_gcp;
    wire            gt1_ctl_rx_check_ucast_gpp;
    wire            gt1_ctl_rx_check_ucast_pcp;
    wire            gt1_ctl_rx_check_ucast_ppp;
    wire            gt1_ctl_rx_enable_gcp;
    wire            gt1_ctl_rx_enable_gpp;
    wire            gt1_ctl_rx_enable_pcp;
    wire            gt1_ctl_rx_enable_ppp;
    wire [8:0]      gt1_ctl_rx_pause_ack;
    wire [8:0]      gt1_ctl_rx_pause_enable;


    wire            gt1_tx_axis_tready;
    wire            gt1_tx_axis_tvalid;
    wire            gt1_tx_axis_tlast;
    wire [CMAC_AXIS_TDATA_WIDTH - 1 : 0] gt1_tx_axis_tdata;
    wire [CMAC_AXIS_TKEEP_WIDTH - 1 : 0] gt1_tx_axis_tkeep;
    wire [CMAC_AXIS_TUSER_WIDTH - 1 : 0] gt1_tx_axis_tuser;

    wire            gt1_tx_ovfout;
    wire            gt1_tx_unfout;
    wire            gt1_ctl_tx_enable;
    wire            gt1_ctl_tx_test_pattern;
    wire            gt1_ctl_tx_send_idle;
    wire            gt1_ctl_tx_send_rfi;
    wire            gt1_ctl_tx_send_lfi;
    wire [8:0]      gt1_ctl_tx_pause_enable;
    wire [15:0]     gt1_ctl_tx_pause_quanta0;
    wire [15:0]     gt1_ctl_tx_pause_quanta1;
    wire [15:0]     gt1_ctl_tx_pause_quanta2;
    wire [15:0]     gt1_ctl_tx_pause_quanta3;
    wire [15:0]     gt1_ctl_tx_pause_quanta4;
    wire [15:0]     gt1_ctl_tx_pause_quanta5;
    wire [15:0]     gt1_ctl_tx_pause_quanta6;
    wire [15:0]     gt1_ctl_tx_pause_quanta7;
    wire [15:0]     gt1_ctl_tx_pause_quanta8;
    wire [15:0]     gt1_ctl_tx_pause_refresh_timer0;
    wire [15:0]     gt1_ctl_tx_pause_refresh_timer1;
    wire [15:0]     gt1_ctl_tx_pause_refresh_timer2;
    wire [15:0]     gt1_ctl_tx_pause_refresh_timer3;
    wire [15:0]     gt1_ctl_tx_pause_refresh_timer4;
    wire [15:0]     gt1_ctl_tx_pause_refresh_timer5;
    wire [15:0]     gt1_ctl_tx_pause_refresh_timer6;
    wire [15:0]     gt1_ctl_tx_pause_refresh_timer7;
    wire [15:0]     gt1_ctl_tx_pause_refresh_timer8;
    wire [8:0]      gt1_ctl_tx_pause_req;
    wire            gt1_ctl_tx_resend_pause;


    cmac_usplus_0 cmac_inst1(
        .gt_rxp_in                            (gt1_rxp_in),
        .gt_rxn_in                            (gt1_rxn_in),
        .gt_txp_out                           (gt1_txp_out),
        .gt_txn_out                           (gt1_txn_out),
        .gt_loopback_in                       (gt_loopback_in),
        
        .gtwiz_reset_tx_datapath              (gtwiz_reset_tx_datapath),
        .gtwiz_reset_rx_datapath              (gtwiz_reset_rx_datapath),
        .sys_reset                            (gt1_sys_reset),
        .gt_ref_clk_p                         (gt1_ref_clk_p),
        .gt_ref_clk_n                         (gt1_ref_clk_n),
        .init_clk                             (gt1_init_clk),

        .gt_txusrclk2                         (gt1_txusrclk2),
        .usr_rx_reset                         (gt1_usr_rx_reset),
        .usr_tx_reset                         (gt1_usr_tx_reset),

        // RX
        .rx_axis_tvalid                       (gt1_rx_axis_tvalid),
        .rx_axis_tdata                        (gt1_rx_axis_tdata),
        .rx_axis_tkeep                        (gt1_rx_axis_tkeep),
        .rx_axis_tlast                        (gt1_rx_axis_tlast),
        .rx_axis_tuser                        (gt1_rx_axis_tuser),
        
        .stat_rx_aligned                      (gt1_stat_rx_aligned),
        .stat_rx_pause_req                    (gt1_stat_rx_pause_req),
        .ctl_rx_enable                        (gt1_ctl_rx_enable),
        .ctl_rx_force_resync                  (gt1_ctl_rx_force_resync),
        .ctl_rx_test_pattern                  (gt1_ctl_rx_test_pattern),
        .ctl_rx_check_etype_gcp               (gt1_ctl_rx_check_etype_gcp),
        .ctl_rx_check_etype_gpp               (gt1_ctl_rx_check_etype_gpp),
        .ctl_rx_check_etype_pcp               (gt1_ctl_rx_check_etype_pcp),
        .ctl_rx_check_etype_ppp               (gt1_ctl_rx_check_etype_ppp),
        .ctl_rx_check_mcast_gcp               (gt1_ctl_rx_check_mcast_gcp),
        .ctl_rx_check_mcast_gpp               (gt1_ctl_rx_check_mcast_gpp),
        .ctl_rx_check_mcast_pcp               (gt1_ctl_rx_check_mcast_pcp),
        .ctl_rx_check_mcast_ppp               (gt1_ctl_rx_check_mcast_ppp),
        .ctl_rx_check_opcode_gcp              (gt1_ctl_rx_check_opcode_gcp),
        .ctl_rx_check_opcode_gpp              (gt1_ctl_rx_check_opcode_gpp),
        .ctl_rx_check_opcode_pcp              (gt1_ctl_rx_check_opcode_pcp),
        .ctl_rx_check_opcode_ppp              (gt1_ctl_rx_check_opcode_ppp),
        .ctl_rx_check_sa_gcp                  (gt1_ctl_rx_check_sa_gcp),
        .ctl_rx_check_sa_gpp                  (gt1_ctl_rx_check_sa_gpp),
        .ctl_rx_check_sa_pcp                  (gt1_ctl_rx_check_sa_pcp),
        .ctl_rx_check_sa_ppp                  (gt1_ctl_rx_check_sa_ppp),
        .ctl_rx_check_ucast_gcp               (gt1_ctl_rx_check_ucast_gcp),
        .ctl_rx_check_ucast_gpp               (gt1_ctl_rx_check_ucast_gpp),
        .ctl_rx_check_ucast_pcp               (gt1_ctl_rx_check_ucast_pcp),
        .ctl_rx_check_ucast_ppp               (gt1_ctl_rx_check_ucast_ppp),
        .ctl_rx_enable_gcp                    (gt1_ctl_rx_enable_gcp),
        .ctl_rx_enable_gpp                    (gt1_ctl_rx_enable_gpp),
        .ctl_rx_enable_pcp                    (gt1_ctl_rx_enable_pcp),
        .ctl_rx_enable_ppp                    (gt1_ctl_rx_enable_ppp),
        .ctl_rx_pause_ack                     (gt1_ctl_rx_pause_ack),
        .ctl_rx_pause_enable                  (gt1_ctl_rx_pause_enable),
    

        // TX
        .tx_axis_tready                       (gt1_tx_axis_tready),
        .tx_axis_tvalid                       (gt1_tx_axis_tvalid),
        .tx_axis_tdata                        (gt1_tx_axis_tdata),
        .tx_axis_tkeep                        (gt1_tx_axis_tkeep),
        .tx_axis_tlast                        (gt1_tx_axis_tlast),
        .tx_axis_tuser                        (gt1_tx_axis_tuser),
        
        .tx_ovfout                            (gt1_tx_ovfout),
        .tx_unfout                            (gt1_tx_unfout),
        .ctl_tx_enable                        (gt1_ctl_tx_enable),
        .ctl_tx_test_pattern                  (gt1_ctl_tx_test_pattern),
        .ctl_tx_send_idle                     (gt1_ctl_tx_send_idle),
        .ctl_tx_send_rfi                      (gt1_ctl_tx_send_rfi),
        .ctl_tx_send_lfi                      (gt1_ctl_tx_send_lfi),
        .ctl_tx_pause_enable                  (gt1_ctl_tx_pause_enable),
        .ctl_tx_pause_req                     (gt1_ctl_tx_pause_req),
        .ctl_tx_pause_quanta0                 (gt1_ctl_tx_pause_quanta0),
        .ctl_tx_pause_quanta1                 (gt1_ctl_tx_pause_quanta1),
        .ctl_tx_pause_quanta2                 (gt1_ctl_tx_pause_quanta2),
        .ctl_tx_pause_quanta3                 (gt1_ctl_tx_pause_quanta3),
        .ctl_tx_pause_quanta4                 (gt1_ctl_tx_pause_quanta4),
        .ctl_tx_pause_quanta5                 (gt1_ctl_tx_pause_quanta5),
        .ctl_tx_pause_quanta6                 (gt1_ctl_tx_pause_quanta6),
        .ctl_tx_pause_quanta7                 (gt1_ctl_tx_pause_quanta7),
        .ctl_tx_pause_quanta8                 (gt1_ctl_tx_pause_quanta8),
        
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
        .tx_preamblein                        (0),
        .core_rx_reset                        (1'b0),
        .core_tx_reset                        (1'b0),
        .rx_clk                               (gt1_txusrclk2),
        .core_drp_reset                       (1'b0),
        .drp_clk                              (1'b0),
        .drp_addr                             (10'b0),
        .drp_di                               (16'b0),
        .drp_en                               (1'b0),
        .drp_do                               (),
        .drp_rdy                              (),
        .drp_we                               (1'b0)
    );
    
    mkXdmaUdpIpArpEthCmacRxTx udp_inst1 (
        .cmac_rxtx_clk(gt1_txusrclk2   ),
		.cmac_rx_reset(gt1_usr_rx_reset),
		.cmac_tx_reset(gt1_usr_tx_reset),
		.udp_clk      (udp_clk),
		.udp_reset    (udp_reset),

		.tx_axis_tvalid(gt1_tx_axis_tvalid),
		.tx_axis_tdata (gt1_tx_axis_tdata ),
		.tx_axis_tkeep (gt1_tx_axis_tkeep ),
		.tx_axis_tlast (gt1_tx_axis_tlast ),
	    .tx_axis_tuser (gt1_tx_axis_tuser ),
		.tx_axis_tready(gt1_tx_axis_tready),

		.tx_stat_ovfout(gt1_tx_ovfout),
		.tx_stat_unfout(gt1_tx_unfout),
		.tx_stat_rx_aligned(gt1_stat_rx_aligned),

		.tx_ctl_enable      (gt1_ctl_tx_enable      ),
		.tx_ctl_test_pattern(gt1_ctl_tx_test_pattern),
		.tx_ctl_send_idle   (gt1_ctl_tx_send_idle   ),
		.tx_ctl_send_lfi    (gt1_ctl_tx_send_lfi    ),
		.tx_ctl_send_rfi    (gt1_ctl_tx_send_rfi    ),
		.tx_ctl_reset       (),

		.tx_ctl_pause_enable (gt1_ctl_tx_pause_enable ),
		.tx_ctl_pause_req    (gt1_ctl_tx_pause_req    ),
		.tx_ctl_pause_quanta0(gt1_ctl_tx_pause_quanta0),
		.tx_ctl_pause_quanta1(gt1_ctl_tx_pause_quanta1),
		.tx_ctl_pause_quanta2(gt1_ctl_tx_pause_quanta2),
		.tx_ctl_pause_quanta3(gt1_ctl_tx_pause_quanta3),
		.tx_ctl_pause_quanta4(gt1_ctl_tx_pause_quanta4),
        .tx_ctl_pause_quanta5(gt1_ctl_tx_pause_quanta5),
        .tx_ctl_pause_quanta6(gt1_ctl_tx_pause_quanta6),
		.tx_ctl_pause_quanta7(gt1_ctl_tx_pause_quanta7),
		.tx_ctl_pause_quanta8(gt1_ctl_tx_pause_quanta8),

		.rx_axis_tvalid (gt1_rx_axis_tvalid),
		.rx_axis_tdata  (gt1_rx_axis_tdata ),
		.rx_axis_tkeep  (gt1_rx_axis_tkeep ),
		.rx_axis_tlast  (gt1_rx_axis_tlast ),
	    .rx_axis_tuser  (gt1_rx_axis_tuser ),
		.rx_axis_tready (),

		.rx_stat_aligned    (gt1_stat_rx_aligned    ),
		.rx_stat_pause_req  (gt1_stat_rx_pause_req  ),
		.rx_ctl_enable      (gt1_ctl_rx_enable      ),
		.rx_ctl_force_resync(gt1_ctl_rx_force_resync),
		.rx_ctl_test_pattern(gt1_ctl_rx_test_pattern),
		.rx_ctl_reset       (),
		.rx_ctl_pause_enable(gt1_ctl_rx_pause_enable),
		.rx_ctl_pause_ack   (gt1_ctl_rx_pause_ack),

		.rx_ctl_enable_gcp      (gt1_ctl_rx_enable_gcp),
		.rx_ctl_check_mcast_gcp (gt1_ctl_rx_check_mcast_gcp),
		.rx_ctl_check_ucast_gcp (gt1_ctl_rx_check_ucast_gcp),
		.rx_ctl_check_sa_gcp    (gt1_ctl_rx_check_sa_gcp),
		.rx_ctl_check_etype_gcp (gt1_ctl_rx_check_etype_gcp),
		.rx_ctl_check_opcode_gcp(gt1_ctl_rx_check_opcode_gcp),
		
		.rx_ctl_enable_pcp      (gt1_ctl_rx_enable_pcp),
		.rx_ctl_check_mcast_pcp (gt1_ctl_rx_check_mcast_pcp),
		.rx_ctl_check_ucast_pcp (gt1_ctl_rx_check_ucast_pcp),
		.rx_ctl_check_sa_pcp    (gt1_ctl_rx_check_sa_pcp),
		.rx_ctl_check_etype_pcp (gt1_ctl_rx_check_etype_pcp),
		.rx_ctl_check_opcode_pcp(gt1_ctl_rx_check_opcode_pcp),
		
		.rx_ctl_enable_gpp      (gt1_ctl_rx_enable_gpp),
		.rx_ctl_check_mcast_gpp (gt1_ctl_rx_check_mcast_gpp),
		.rx_ctl_check_ucast_gpp (gt1_ctl_rx_check_ucast_gpp),
		.rx_ctl_check_sa_gpp    (gt1_ctl_rx_check_sa_gpp),
		.rx_ctl_check_etype_gpp (gt1_ctl_rx_check_etype_gpp),
		.rx_ctl_check_opcode_gpp(gt1_ctl_rx_check_opcode_gpp),
		
		.rx_ctl_enable_ppp      (gt1_ctl_rx_enable_ppp),
		.rx_ctl_check_mcast_ppp (gt1_ctl_rx_check_mcast_ppp),
		.rx_ctl_check_ucast_ppp (gt1_ctl_rx_check_ucast_ppp),
		.rx_ctl_check_sa_ppp    (gt1_ctl_rx_check_sa_ppp),
		.rx_ctl_check_etype_ppp (gt1_ctl_rx_check_etype_ppp),
		.rx_ctl_check_opcode_ppp(gt1_ctl_rx_check_opcode_ppp),

	    .xdma_rx_axis_tvalid(),
		.xdma_rx_axis_tdata (),
		.xdma_rx_axis_tkeep (),
		.xdma_rx_axis_tlast (),
		.xdma_rx_axis_tuser (),
		.xdma_rx_axis_tready(1'b0),

		.xdma_tx_axis_tvalid(xdma_tx_axis_tvalid),
		.xdma_tx_axis_tdata (xdma_tx_axis_tdata ),
		.xdma_tx_axis_tkeep (xdma_tx_axis_tkeep ),
		.xdma_tx_axis_tlast (xdma_tx_axis_tlast ),
		.xdma_tx_axis_tuser (xdma_tx_axis_tuser ),
		.xdma_tx_axis_tready(xdma_tx_axis_tready)
    );

    // GT2 Signals
    wire            gt2_txusrclk2;
    wire            gt2_usr_tx_reset;
    wire            gt2_usr_rx_reset;

    wire            gt2_rx_axis_tvalid;
    wire [511:0]    gt2_rx_axis_tdata;
    wire            gt2_rx_axis_tlast;
    wire [63:0]     gt2_rx_axis_tkeep;
    wire            gt2_rx_axis_tuser;

    wire            gt2_stat_rx_aligned;
    wire [8:0]      gt2_stat_rx_pause_req;
    wire            gt2_ctl_rx_enable;
    wire            gt2_ctl_rx_force_resync;
    wire            gt2_ctl_rx_test_pattern;
    wire            gt2_ctl_rx_check_etype_gcp;
    wire            gt2_ctl_rx_check_etype_gpp;
    wire            gt2_ctl_rx_check_etype_pcp;
    wire            gt2_ctl_rx_check_etype_ppp;
    wire            gt2_ctl_rx_check_mcast_gcp;
    wire            gt2_ctl_rx_check_mcast_gpp;
    wire            gt2_ctl_rx_check_mcast_pcp;
    wire            gt2_ctl_rx_check_mcast_ppp;
    wire            gt2_ctl_rx_check_opcode_gcp;
    wire            gt2_ctl_rx_check_opcode_gpp;
    wire            gt2_ctl_rx_check_opcode_pcp;
    wire            gt2_ctl_rx_check_opcode_ppp;
    wire            gt2_ctl_rx_check_sa_gcp;
    wire            gt2_ctl_rx_check_sa_gpp;
    wire            gt2_ctl_rx_check_sa_pcp;
    wire            gt2_ctl_rx_check_sa_ppp;
    wire            gt2_ctl_rx_check_ucast_gcp;
    wire            gt2_ctl_rx_check_ucast_gpp;
    wire            gt2_ctl_rx_check_ucast_pcp;
    wire            gt2_ctl_rx_check_ucast_ppp;
    wire            gt2_ctl_rx_enable_gcp;
    wire            gt2_ctl_rx_enable_gpp;
    wire            gt2_ctl_rx_enable_pcp;
    wire            gt2_ctl_rx_enable_ppp;
    wire [8:0]      gt2_ctl_rx_pause_ack;
    wire [8:0]      gt2_ctl_rx_pause_enable;


    wire            gt2_tx_axis_tready;
    wire            gt2_tx_axis_tvalid;
    wire [511:0]    gt2_tx_axis_tdata;
    wire            gt2_tx_axis_tlast;
    wire [63:0]     gt2_tx_axis_tkeep;
    wire            gt2_tx_axis_tuser;

    wire            gt2_tx_ovfout;
    wire            gt2_tx_unfout;
    wire            gt2_ctl_tx_enable;
    wire            gt2_ctl_tx_test_pattern;
    wire            gt2_ctl_tx_send_idle;
    wire            gt2_ctl_tx_send_rfi;
    wire            gt2_ctl_tx_send_lfi;
    wire [8:0]      gt2_ctl_tx_pause_enable;
    wire [15:0]     gt2_ctl_tx_pause_quanta0;
    wire [15:0]     gt2_ctl_tx_pause_quanta1;
    wire [15:0]     gt2_ctl_tx_pause_quanta2;
    wire [15:0]     gt2_ctl_tx_pause_quanta3;
    wire [15:0]     gt2_ctl_tx_pause_quanta4;
    wire [15:0]     gt2_ctl_tx_pause_quanta5;
    wire [15:0]     gt2_ctl_tx_pause_quanta6;
    wire [15:0]     gt2_ctl_tx_pause_quanta7;
    wire [15:0]     gt2_ctl_tx_pause_quanta8;
    wire [15:0]     gt2_ctl_tx_pause_refresh_timer0;
    wire [15:0]     gt2_ctl_tx_pause_refresh_timer1;
    wire [15:0]     gt2_ctl_tx_pause_refresh_timer2;
    wire [15:0]     gt2_ctl_tx_pause_refresh_timer3;
    wire [15:0]     gt2_ctl_tx_pause_refresh_timer4;
    wire [15:0]     gt2_ctl_tx_pause_refresh_timer5;
    wire [15:0]     gt2_ctl_tx_pause_refresh_timer6;
    wire [15:0]     gt2_ctl_tx_pause_refresh_timer7;
    wire [15:0]     gt2_ctl_tx_pause_refresh_timer8;
    wire [8:0]      gt2_ctl_tx_pause_req;
    wire            gt2_ctl_tx_resend_pause;


    cmac_usplus_0 cmac_inst2(
        .gt_rxp_in                            (gt2_rxp_in),
        .gt_rxn_in                            (gt2_rxn_in),
        .gt_txp_out                           (gt2_txp_out),
        .gt_txn_out                           (gt2_txn_out),
        .gt_loopback_in                       (gt_loopback_in),
        
        .gtwiz_reset_tx_datapath              (gtwiz_reset_tx_datapath),
        .gtwiz_reset_rx_datapath              (gtwiz_reset_rx_datapath),
        .sys_reset                            (gt2_sys_reset),
        .gt_ref_clk_p                         (gt2_ref_clk_p),
        .gt_ref_clk_n                         (gt2_ref_clk_n),
        .init_clk                             (gt2_init_clk),

        .gt_txusrclk2                         (gt2_txusrclk2),
        .usr_rx_reset                         (gt2_usr_rx_reset),
        .usr_tx_reset                         (gt2_usr_tx_reset),

        // RX
        .rx_axis_tvalid                       (gt2_rx_axis_tvalid),
        .rx_axis_tdata                        (gt2_rx_axis_tdata),
        .rx_axis_tkeep                        (gt2_rx_axis_tkeep),
        .rx_axis_tlast                        (gt2_rx_axis_tlast),
        .rx_axis_tuser                        (gt2_rx_axis_tuser),
        
        .stat_rx_aligned                      (gt2_stat_rx_aligned),
        .stat_rx_pause_req                    (gt2_stat_rx_pause_req),
        .ctl_rx_enable                        (gt2_ctl_rx_enable),
        .ctl_rx_force_resync                  (gt2_ctl_rx_force_resync),
        .ctl_rx_test_pattern                  (gt2_ctl_rx_test_pattern),
        .ctl_rx_check_etype_gcp               (gt2_ctl_rx_check_etype_gcp),
        .ctl_rx_check_etype_gpp               (gt2_ctl_rx_check_etype_gpp),
        .ctl_rx_check_etype_pcp               (gt2_ctl_rx_check_etype_pcp),
        .ctl_rx_check_etype_ppp               (gt2_ctl_rx_check_etype_ppp),
        .ctl_rx_check_mcast_gcp               (gt2_ctl_rx_check_mcast_gcp),
        .ctl_rx_check_mcast_gpp               (gt2_ctl_rx_check_mcast_gpp),
        .ctl_rx_check_mcast_pcp               (gt2_ctl_rx_check_mcast_pcp),
        .ctl_rx_check_mcast_ppp               (gt2_ctl_rx_check_mcast_ppp),
        .ctl_rx_check_opcode_gcp              (gt2_ctl_rx_check_opcode_gcp),
        .ctl_rx_check_opcode_gpp              (gt2_ctl_rx_check_opcode_gpp),
        .ctl_rx_check_opcode_pcp              (gt2_ctl_rx_check_opcode_pcp),
        .ctl_rx_check_opcode_ppp              (gt2_ctl_rx_check_opcode_ppp),
        .ctl_rx_check_sa_gcp                  (gt2_ctl_rx_check_sa_gcp),
        .ctl_rx_check_sa_gpp                  (gt2_ctl_rx_check_sa_gpp),
        .ctl_rx_check_sa_pcp                  (gt2_ctl_rx_check_sa_pcp),
        .ctl_rx_check_sa_ppp                  (gt2_ctl_rx_check_sa_ppp),
        .ctl_rx_check_ucast_gcp               (gt2_ctl_rx_check_ucast_gcp),
        .ctl_rx_check_ucast_gpp               (gt2_ctl_rx_check_ucast_gpp),
        .ctl_rx_check_ucast_pcp               (gt2_ctl_rx_check_ucast_pcp),
        .ctl_rx_check_ucast_ppp               (gt2_ctl_rx_check_ucast_ppp),
        .ctl_rx_enable_gcp                    (gt2_ctl_rx_enable_gcp),
        .ctl_rx_enable_gpp                    (gt2_ctl_rx_enable_gpp),
        .ctl_rx_enable_pcp                    (gt2_ctl_rx_enable_pcp),
        .ctl_rx_enable_ppp                    (gt2_ctl_rx_enable_ppp),
        .ctl_rx_pause_ack                     (gt2_ctl_rx_pause_ack),
        .ctl_rx_pause_enable                  (gt2_ctl_rx_pause_enable),
    

        // TX
        .tx_axis_tready                       (gt2_tx_axis_tready),
        .tx_axis_tvalid                       (gt2_tx_axis_tvalid),
        .tx_axis_tdata                        (gt2_tx_axis_tdata),
        .tx_axis_tkeep                        (gt2_tx_axis_tkeep),
        .tx_axis_tlast                        (gt2_tx_axis_tlast),
        .tx_axis_tuser                        (gt2_tx_axis_tuser),
        
        .tx_ovfout                            (gt2_tx_ovfout),
        .tx_unfout                            (gt2_tx_unfout),
        .ctl_tx_enable                        (gt2_ctl_tx_enable),
        .ctl_tx_test_pattern                  (gt2_ctl_tx_test_pattern),
        .ctl_tx_send_idle                     (gt2_ctl_tx_send_idle),
        .ctl_tx_send_rfi                      (gt2_ctl_tx_send_rfi),
        .ctl_tx_send_lfi                      (gt2_ctl_tx_send_lfi),
        .ctl_tx_pause_enable                  (gt2_ctl_tx_pause_enable),
        .ctl_tx_pause_req                     (gt2_ctl_tx_pause_req),
        .ctl_tx_pause_quanta0                 (gt2_ctl_tx_pause_quanta0),
        .ctl_tx_pause_quanta1                 (gt2_ctl_tx_pause_quanta1),
        .ctl_tx_pause_quanta2                 (gt2_ctl_tx_pause_quanta2),
        .ctl_tx_pause_quanta3                 (gt2_ctl_tx_pause_quanta3),
        .ctl_tx_pause_quanta4                 (gt2_ctl_tx_pause_quanta4),
        .ctl_tx_pause_quanta5                 (gt2_ctl_tx_pause_quanta5),
        .ctl_tx_pause_quanta6                 (gt2_ctl_tx_pause_quanta6),
        .ctl_tx_pause_quanta7                 (gt2_ctl_tx_pause_quanta7),
        .ctl_tx_pause_quanta8                 (gt2_ctl_tx_pause_quanta8),
        
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
        .tx_preamblein                        (0),
        .core_rx_reset                        (1'b0),
        .core_tx_reset                        (1'b0),
        .rx_clk                               (gt2_txusrclk2),
        .core_drp_reset                       (1'b0),
        .drp_clk                              (1'b0),
        .drp_addr                             (10'b0),
        .drp_di                               (16'b0),
        .drp_en                               (1'b0),
        .drp_do                               (),
        .drp_rdy                              (),
        .drp_we                               (1'b0)
    );
    
    mkXdmaUdpIpArpEthCmacRxTx udp_inst2 (
        .cmac_rxtx_clk(gt2_txusrclk2   ),
		.cmac_rx_reset(gt2_usr_rx_reset),
		.cmac_tx_reset(gt2_usr_tx_reset),
		.udp_clk      (udp_clk),
		.udp_reset    (udp_reset),

		.tx_axis_tvalid(gt2_tx_axis_tvalid),
		.tx_axis_tdata (gt2_tx_axis_tdata ),
		.tx_axis_tkeep (gt2_tx_axis_tkeep ),
		.tx_axis_tlast (gt2_tx_axis_tlast ),
	    .tx_axis_tuser (gt2_tx_axis_tuser ),
		.tx_axis_tready(gt2_tx_axis_tready),

		.tx_stat_ovfout(gt2_tx_ovfout),
		.tx_stat_unfout(gt2_tx_unfout),
		.tx_stat_rx_aligned(gt2_stat_rx_aligned),

		.tx_ctl_enable      (gt2_ctl_tx_enable      ),
		.tx_ctl_test_pattern(gt2_ctl_tx_test_pattern),
		.tx_ctl_send_idle   (gt2_ctl_tx_send_idle   ),
		.tx_ctl_send_lfi    (gt2_ctl_tx_send_lfi    ),
		.tx_ctl_send_rfi    (gt2_ctl_tx_send_rfi    ),
		.tx_ctl_reset       (),

		.tx_ctl_pause_enable (gt2_ctl_tx_pause_enable ),
		.tx_ctl_pause_req    (gt2_ctl_tx_pause_req    ),
		.tx_ctl_pause_quanta0(gt2_ctl_tx_pause_quanta0),
		.tx_ctl_pause_quanta1(gt2_ctl_tx_pause_quanta1),
		.tx_ctl_pause_quanta2(gt2_ctl_tx_pause_quanta2),
		.tx_ctl_pause_quanta3(gt2_ctl_tx_pause_quanta3),
		.tx_ctl_pause_quanta4(gt2_ctl_tx_pause_quanta4),
        .tx_ctl_pause_quanta5(gt2_ctl_tx_pause_quanta5),
        .tx_ctl_pause_quanta6(gt2_ctl_tx_pause_quanta6),
		.tx_ctl_pause_quanta7(gt2_ctl_tx_pause_quanta7),
		.tx_ctl_pause_quanta8(gt2_ctl_tx_pause_quanta8),

		.rx_axis_tvalid (gt2_rx_axis_tvalid),
		.rx_axis_tdata  (gt2_rx_axis_tdata ),
		.rx_axis_tkeep  (gt2_rx_axis_tkeep ),
		.rx_axis_tlast  (gt2_rx_axis_tlast ),
	    .rx_axis_tuser  (gt2_rx_axis_tuser ),
		.rx_axis_tready (),

		.rx_stat_aligned    (gt2_stat_rx_aligned    ),
		.rx_stat_pause_req  (gt2_stat_rx_pause_req  ),
		.rx_ctl_enable      (gt2_ctl_rx_enable      ),
		.rx_ctl_force_resync(gt2_ctl_rx_force_resync),
		.rx_ctl_test_pattern(gt2_ctl_rx_test_pattern),
		.rx_ctl_reset       (),
		.rx_ctl_pause_enable(gt2_ctl_rx_pause_enable),
		.rx_ctl_pause_ack   (gt2_ctl_rx_pause_ack),

		.rx_ctl_enable_gcp      (gt2_ctl_rx_enable_gcp),
		.rx_ctl_check_mcast_gcp (gt2_ctl_rx_check_mcast_gcp),
		.rx_ctl_check_ucast_gcp (gt2_ctl_rx_check_ucast_gcp),
		.rx_ctl_check_sa_gcp    (gt2_ctl_rx_check_sa_gcp),
		.rx_ctl_check_etype_gcp (gt2_ctl_rx_check_etype_gcp),
		.rx_ctl_check_opcode_gcp(gt2_ctl_rx_check_opcode_gcp),
		
		.rx_ctl_enable_pcp      (gt2_ctl_rx_enable_pcp),
		.rx_ctl_check_mcast_pcp (gt2_ctl_rx_check_mcast_pcp),
		.rx_ctl_check_ucast_pcp (gt2_ctl_rx_check_ucast_pcp),
		.rx_ctl_check_sa_pcp    (gt2_ctl_rx_check_sa_pcp),
		.rx_ctl_check_etype_pcp (gt2_ctl_rx_etype_pcp),
		.rx_ctl_check_opcode_pcp(gt2_ctl_rx_check_opcode_pcp),
		.rx_ctl_enable_gpp      (gt2_ctl_rx_enable_gpp),
		.rx_ctl_check_mcast_gpp (gt2_ctl_rx_check_mcast_gpp),
		.rx_ctl_check_ucast_gpp (gt2_ctl_rx_check_ucast_gpp),
		.rx_ctl_check_sa_gpp    (gt2_ctl_rx_check_sa_gpp),
		.rx_ctl_check_etype_gpp (gt2_ctl_rx_check_etype_gpp),
		.rx_ctl_check_opcode_gpp(gt2_ctl_rx_check_opcode_gpp),
		.rx_ctl_enable_ppp      (gt2_ctl_rx_enable_ppp),
		.rx_ctl_check_mcast_ppp (gt2_ctl_rx_check_mcast_ppp),
		.rx_ctl_check_ucast_ppp (gt2_ctl_rx_check_ucast_ppp),
		.rx_ctl_check_sa_ppp    (gt2_ctl_rx_check_sa_ppp),
		.rx_ctl_check_etype_ppp (gt2_ctl_rx_check_etype_ppp),
		.rx_ctl_check_opcode_ppp(gt2_ctl_rx_check_opcode_ppp),

	    .xdma_rx_axis_tvalid(xdma_rx_axis_tvalid),
		.xdma_rx_axis_tdata (xdma_rx_axis_tdata ),
		.xdma_rx_axis_tkeep (xdma_rx_axis_tkeep ),
		.xdma_rx_axis_tlast (xdma_rx_axis_tlast ),
		.xdma_rx_axis_tuser (xdma_rx_axis_tuser ),
		.xdma_rx_axis_tready(xdma_rx_axis_tready),

		.xdma_tx_axis_tvalid(1'b0),
		.xdma_tx_axis_tdata (0 ),
		.xdma_tx_axis_tkeep (0 ),
		.xdma_tx_axis_tlast (0 ),
		.xdma_tx_axis_tuser (0 ),
		.xdma_tx_axis_tready()
    );

endmodule