
# STEP#1: define variables
#
set project_name $::env(PROJ_NAME)
set config_file $::env(CONFIG_FILE)
set src_dir $::env(SRC_DIR)
set gen_src_dir $::env(GEN_SRC_DIR)
set ip_tcl $::env(IP_TCL)
set read_mem_file $::env(READ_MEM_FILE)

set cmac_module_name cmac_usplus_0
set device xcvu9p-flga2104-2L-e; # xcvu9p_CIV-flga2577-2-e; #


# STEP#2: create in-memory project and setup source files
#
create_project -part $device $project_name $project_name

add_files -norecurse [glob $gen_src_dir/*.v]
add_files -norecurse [glob $src_dir/*.v]
if { $read_mem_file } {
    add_files -norecurse [glob $gen_src_dir/*.mem]
}

#move_files -fileset sim_1 [get_files $sim_src]
add_files -norecurse $config_file
set_property is_global_include true [get_files $config_file]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1


# STEP#3: create and synthesize ip
#
source $ip_tcl


# STEP#4: launch simulation
#
launch_simulation -simset sim_1 -mode behavioral
restart
run all

#close_project



