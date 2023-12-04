
set part $::env(PART)
set dir_ip_tcl $::env(DIR_IP_TCL)
set dir_ip_gen $::env(DIR_IP_GEN)

set_part [get_parts $part]
file mkdir $dir_ip_gen

foreach file [ glob $dir_ip_tcl/*.tcl ] {
    source $file
}

reset_target all [ get_ips * ]
generate_target all [ get_ips * ]

foreach ip [ get_ips * ] {
    synth_ip $ip
}