
# STEP#1: define variables
#
set project_name $::env(PROJ_NAME)
set config_src $::env(CONFIG_SRC)
set sim_src $::env(SIM_SRC)

set cmac_module_name cmac_usplus_0
set device xcvu9p-flga2104-2L-e; # xcvu9p_CIV-flga2577-2-e; #


# STEP#2: create in-memory project and setup source files
#
create_project -in_memory -part $device $project_name;#$project_name

add_files -norecurse [glob ./generated/*.v]
add_files -norecurse [glob ./verilog/*.v]

#move_files -fileset sim_1 [get_files $sim_src]
add_files -norecurse $config_src
set_property is_global_include true [get_files $config_src]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1


# STEP#3: create and synthesize ip
#
create_ip -name cmac_usplus -vendor xilinx.com -library ip -version 3.1 -module_name $cmac_module_name
set_property CONFIG.USER_INTERFACE {AXIS} [ get_ips $cmac_module_name ]


# STEP#4: launch simulation
#
launch_simulation -simset sim_1 -mode behavioral
restart
run all

#close_project



