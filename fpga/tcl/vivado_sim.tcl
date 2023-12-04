
# STEP#1: define variables
#

set part $::env(PART)
set dir_vlog $::env(DIR_VLOG)
set dir_vlog_gen $::env(DIR_VLOG_GEN)
set dir_ip_tcl $::env(DIR_IP_TCL)
set dir_ip_gen $::env(DIR_IP_GEN)
set gen_ip_tcl $::env(GEN_IP_TCL)

set sim_top $::env(SIM_TOP)
set project_name $::env(PROJ_NAME)
set config_file $::env(CONFIG_FILE)
set ip_tcl $::env(DIR_IP_TCL)
set read_mem_file $::env(READ_MEM_FILE)


if {[file exists $dir_ip_gen]} {
    puts "Previous Generated and Synthesized IPs Are Used"
} else {
    source $gen_ip_tcl
}

# STEP#2: create in-memory project and setup source files
#
create_project -part $part $project_name $project_name

add_files -norecurse [glob $dir_vlog/*.v]
add_files -norecurse [glob $dir_vlog_gen/*.v]
if { $read_mem_file } {
    add_files -norecurse [glob $dir_vlog_gen/*.mem]
}

add_files -norecurse $config_file
set_property is_global_include true [get_files $config_file]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property top $sim_top [get_filesets sim_1]


# STEP#3: read ip
#
read_ip [glob $dir_ip_gen/**/*.xci]

# STEP#4: launch simulation
#
launch_simulation -simset sim_1 -mode behavioral
restart
run all

#close_project



