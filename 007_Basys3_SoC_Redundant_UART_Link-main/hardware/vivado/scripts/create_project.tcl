set script_dir [file dirname [file normalize [info script]]]
set vivado_dir [file dirname $script_dir]
set build_dir [file join $vivado_dir build]
set source_dir [file join $build_dir source]
set project_dir [file join $build_dir project]

set ip_repos [list \
    [file join $build_dir ip_repo redundant_link_core_source rtl] \
    [file join $build_dir ip_repo sensor_guard_ip_source] \
    [file join $build_dir ip_repo voltage_display_ip_source packaged_ip voltage_display_ip_1.0] \
]

foreach repo $ip_repos {
    if {![file exists [file join $repo component.xml]]} {
        error "Missing IP repository: $repo. Run prepare_vivado_project.py first."
    }
}

set bd_file [file join $source_dir system_bd.bd]
if {![file exists $bd_file]} {
    error "Missing reconstructed Block Design. Run prepare_vivado_project.py first."
}

create_project redundant_link $project_dir -part xc7a35tcpg236-1 -force
set_property board_part digilentinc.com:basys3:part0:1.2 [current_project]
set_property ip_repo_paths $ip_repos [current_project]
update_ip_catalog

add_files -norecurse $bd_file
add_files -fileset constrs_1 -norecurse [file join $vivado_dir constraints basys3_redundant_link.xdc]
validate_bd_design
save_bd_design

generate_target all [get_files system_bd.bd]
make_wrapper -files [get_files system_bd.bd] -top
set wrapper [file join $project_dir redundant_link.gen sources_1 bd system_bd hdl system_bd_wrapper.v]
add_files -norecurse $wrapper
set_property top system_bd_wrapper [current_fileset]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Final Vivado project created at: $project_dir/redundant_link.xpr"
