#!/usr/bin/tclsh

# STEP#1: define the output directory area.
#
set out_dir $::env(OUTPUT)
# file delete -force -- $out_dir
file mkdir $out_dir

set top_module $::env(TOP)
set rtl_dir $::env(RTL)
set xdc_dir $::env(XDC)
set synth_only $::env(SYNTHONLY)
set target_clks $::env(CLOCKS)

set MAX_NET_PATH_NUM 1000
# set MAX_LOGIC_LEVEL 40
# set MIN_LOGIC_LEVEL 4

# STEP#2: setup design sources and constraints
#
read_verilog [ glob $rtl_dir/*.v ]
read_xdc [ glob $xdc_dir/*.xdc ]

# STEP#3: run synthesis, write design checkpoint, report timing,
# and utilization estimates
#
set_param general.maxthreads 24
set device [get_parts xcvu9p-flga2104-2L-e]; # xcvu9p_CIV-flga2577-2-e; #
set_part $device
report_property $device -file $out_dir/pre_synth_dev_prop.rpt

synth_design -top $top_module -retiming
write_checkpoint -force $out_dir/post_synth.dcp
# Generated XDC file should be less than 1MB, otherwise too many constraints.
write_xdc -force -exclude_physical $out_dir/post_synth.xdc

# Check 1) slack, 2) requirement, 3) src and dst clocks, 4) datapath delay, 5) logic level, 6) skew and uncertainty.
report_timing_summary -report_unconstrained -warn_on_violation -file $out_dir/post_synth_timing_summary.rpt
report_timing -of_objects [get_timing_paths -setup -to [get_clocks $target_clks] -max_paths $MAX_NET_PATH_NUM -filter { LOGIC_LEVELS >= 4 && LOGIC_LEVELS <= 40 }] -file $out_dir/post_synth_long_paths.rpt
# Check 1) endpoints without clock, 2) combo loop and 3) latch.
check_timing -override_defaults no_clock -file $out_dir/post_synth_check_timing.rpt
report_clock_networks -file $out_dir/post_synth_clock_networks.rpt; # Show unconstrained clocks
report_clock_interaction -delay_type min_max -significant_digits 3 -file $out_dir/post_synth_clock_interaction.rpt; # Pay attention to Clock pair Classification, Inter-CLock Constraints, Path Requirement (WNS)
report_high_fanout_nets -timing -load_type -max_nets $MAX_NET_PATH_NUM -file $out_dir/post_synth_fanout.rpt
report_exceptions -ignored -file $out_dir/post_synth_exceptions.rpt; # -ignored -ignored_objects -write_valid_exceptions -write_merged_exceptions

# 1 LUT + 1 net have delay 0.5ns, if cycle period is Tns, logic level is 2T at most
# report_design_analysis -timing -max_paths $MAX_NET_PATH_NUM -file $out_dir/post_synth_design_timing.rpt
report_design_analysis -setup -max_paths $MAX_NET_PATH_NUM -file $out_dir/post_synth_design_setup_timing.rpt
# report_design_analysis -logic_level_dist_paths $MAX_NET_PATH_NUM -min_level $MIN_LOGIC_LEVEL -max_level $MAX_LOGIC_LEVEL -file $out_dir/post_synth_design_logic_level.rpt
report_design_analysis -logic_level_dist_paths $MAX_NET_PATH_NUM -logic_level_distribution -file $out_dir/post_synth_design_logic_level_dist.rpt

report_datasheet -file $out_dir/post_synth_datasheet.rpt
xilinx::designutils::report_failfast -detailed_reports synth -file $out_dir/post_synth_failfast.rpt

report_drc -file $out_dir/post_synth_drc.rpt
report_drc -ruledeck methodology_checks -file $out_dir/post_synth_drc_methodology.rpt
report_drc -ruledeck timing_checks -file $out_dir/post_synth_drc_timing.rpt

# intra-clock skew < 300ps, inter-clock skew < 500ps

# Check 1) LUT on clock tree (TIMING-14), 2) hold constraints for multicycle path constraints (XDCH-1).
report_methodology -file $out_dir/post_synth_methodology.rpt
report_timing -max $MAX_NET_PATH_NUM -slack_less_than 0 -file $out_dir/post_synth_timing.rpt

report_compile_order -constraints -file $out_dir/post_synth_constraints.rpt; # Verify IP constraints included
report_utilization -file $out_dir/post_synth_util.rpt; # -cells -pblocks
report_cdc -file $out_dir/post_synth_cdc.rpt
report_clocks -file $out_dir/post_synth_clocks.rpt; # Verify clock settings

# Use IS_SEQUENTIAL for -from/-to
# Instantiate XPM_CDC modules
# write_xdc -force -exclude_physical -exclude_timing -constraints INVALID

report_qor_assessment -report_all_suggestions -csv_output_dir $out_dir -file $out_dir/post_synth_qor_assess.rpt
if { $synth_only } {
    puts "synth_only=$synth_only"
    exit
}

# STEP#4: run logic optimization, placement and physical logic optimization,
# write design checkpoint, report utilization and timing estimates
#
opt_design -remap
power_opt_design
place_design
# Optionally run optimization if there are timing violations after placement
if {[get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] < 0} {
    puts "Found setup timing violations => running physical optimization"
    phys_opt_design
}
write_checkpoint -force $out_dir/post_place.dcp
write_xdc -force -exclude_physical $out_dir/post_place.xdc

report_timing_summary -report_unconstrained -warn_on_violation -file $out_dir/post_place_timing_summary.rpt
report_methodology -file $out_dir/post_place_methodology.rpt
report_timing -max $MAX_NET_PATH_NUM -slack_less_than 0 -file $out_dir/post_place_timing.rpt
report_clock_utilization -file $out_dir/post_place_clock_util.rpt
report_utilization -file $out_dir/post_place_util.rpt; # -cells -pblocks -slr

# STEP#5: run the router, write the post-route design checkpoint, report the routing
# status, report timing, power, and DRC, and finally save the Verilog netlist.
#
route_design

proc runPPO { {num_iters 1} {enable_phys_opt 1} } {
    for {set idx 0} {$idx < $num_iters} {incr idx} {
        place_design -post_place_opt; # Better to run after route
        if {$enable_phys_opt != 0} {
            phys_opt_design
        }
        route_design
        if {[get_property SLACK [get_timing_paths ]] >= 0} {
            break; # Stop if timing closure
        }
    }
}

runPPO 4 1; # num_iters=4, enable_phys_opt=1

write_checkpoint -force $out_dir/post_route.dcp
write_xdc -force -exclude_physical $out_dir/post_route.xdc

report_timing_summary -report_unconstrained -warn_on_violation -file $out_dir/post_route_timing_summary.rpt
report_timing -of_objects [get_timing_paths -hold -to [get_clocks $target_clks] -max_paths $MAX_NET_PATH_NUM -filter { LOGIC_LEVELS >= 4 && LOGIC_LEVELS <= 40 }] -file $out_dir/post_route_long_paths.rpt
report_methodology -file $out_dir/post_route_methodology.rpt
report_timing -max $MAX_NET_PATH_NUM -slack_less_than 0 -file $out_dir/post_route_timing.rpt

report_route_status -file $out_dir/post_route_status.rpt
report_drc -file $out_dir/post_route_drc.rpt
report_drc -ruledeck methodology_checks -file $out_dir/post_route_drc_methodology.rpt
report_drc -ruledeck timing_checks -file $out_dir/post_route_drc_timing.rpt
# Check unique control sets < 7.5% of total slices, at most 15%
report_control_sets -verbose -file $out_dir/post_route_control_sets.rpt

report_power -file $out_dir/post_route_power.rpt
report_power_opt -file $out_dir/post_route_power_opt.rpt
report_utilization -file $out_dir/post_route_util.rpt
report_ram_utilization -detail -file $out_dir/post_route_ram_utils.rpt
# Check fanout < 25K
report_high_fanout_nets -file $out_dir/post_route_fanout.rpt

report_design_analysis -hold -max_paths $MAX_NET_PATH_NUM -file $out_dir/post_route_design_hold_timing.rpt
# Check initial estimated router congestion level no more than 5, type (global, long, short) and top cells
report_design_analysis -congestion -file $out_dir/post_route_congestion.rpt
# Check difficult modules (>15K cells) with high Rent Exponent (complex logic cone) >= 0.65 and/or Avg. Fanout >= 4
report_design_analysis -complexity -file $out_dir/post_route_complexity.rpt; # -hierarchical_depth
# If congested, check problematic cells using report_utilization -cells
# If congested, try NetDelay* for UltraScale+, or try SpredLogic* for UltraScale in implementation strategy

xilinx::designutils::report_failfast -detailed_reports impl -file $out_dir/post_route_failfast.rpt
# xilinx::ultrafast::report_io_reg -file $out_dir/post_route_io_reg.rpt
report_io -file $out_dir/post_route_io.rpt
report_pipeline_analysis -file $out_dir/post_route_pipeline.rpt
report_qor_assessment -report_all_suggestions -csv_output_dir $out_dir -file $out_dir/post_route_qor_assess.rpt
report_qor_suggestions -report_all_suggestions -csv_output_dir $out_dir -file $out_dir/post_route_qor_suggest.rpt

write_verilog -force $out_dir/post_impl_netlist.v -mode timesim -sdf_anno true

# STEP#6: generate a bitstream
#
# write_bitstream -force $out_dir/top.bit