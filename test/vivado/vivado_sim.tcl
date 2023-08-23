

# STEP#1: define variables
#
#set out_dir $::env(OUTPUT)
#set top_module $::env(TOP)
# set design_src $::env(DESIGN_SRC)
# set simulation_src $::env(SIM_SRC)

#set design_src $::env(DESIGN_SRC)
set config_src "./verilog/sim_config.vh"
set simulation_src "./verilog/UdpIpArpEthCmacTestbenchWrapper.v"

set project_name cmac_test;#$::env(PROJ_NAME)
set cmac_module_name cmac_usplus_0
set device xcvu9p-flga2104-2L-e; # xcvu9p_CIV-flga2577-2-e; #


# STEP#2: create in-memory project and setup sources and ip
#
create_project -part $device $project_name ./$project_name 

add_files -norecurse [glob ./generated/*.v]
add_files -norecurse ./verilog/UdpIpArpEthCmacRxTxSimWrapper.v

add_files -norecurse $config_src
set_property is_global_include true [get_files $config_src]
update_compile_order -fileset sources_1

add_files -fileset sim_1 -norecurse $simulation_src
update_compile_order -fileset sim_1


# STEP#3: create and synthesize ip
#
set ip_xci_file "./${project_name}/${project_name}.srcs/sources_1/ip/${cmac_module_name}/${cmac_module_name}.xci"

create_ip -name cmac_usplus -vendor xilinx.com -library ip -version 3.1 -module_name $cmac_module_name
set_property CONFIG.USER_INTERFACE {AXIS} [ get_ips $cmac_module_name ]


# STEP#4: launch simulation
#
launch_simulation -simset sim_1 -mode behavioral
restart
run all

close_project



