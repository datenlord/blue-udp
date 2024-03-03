
#set synth_opts "-directive PerformanceOptimized -resource_sharing off -fsm_extraction one_hot -shreg_min_size 5 -no_lc -keep_equivalent_registers"
set place_opts "-directive ExtraNetDelay_high"
#set route_opts "-directive NoTimingRelaxation"
#set phys_opt_opts "-directive AggressiveExplore"
