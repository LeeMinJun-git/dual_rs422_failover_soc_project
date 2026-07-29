# Vivado 2024.2 batch/GUI Tcl script.
#
# Batch:
#   vivado -mode batch -source <path>/package_voltage_display_ip.tcl
#
# Vivado GUI Tcl Console:
#   source <path>/package_voltage_display_ip.tcl
#
# The script may be launched from any working directory. No Vivado project
# may be open when it starts.

set script_dir [file normalize [file dirname [info script]]]
set root_dir   [file normalize [file join $script_dir ".."]]
set rtl_dir    [file join $root_dir "rtl"]
set sim_dir    [file join $root_dir "sim"]
set build_dir  [file join $root_dir "vivado_build"]
set report_dir [file join $root_dir "reports"]
set ip_dir     [file join $root_dir "packaged_ip" "voltage_display_ip_1.0"]

set part_name  "xc7a35tcpg236-1"
set clock_hz   100000000
set clock_ns   10.000
set max_timing_paths 1000000

set rtl_files [list \
    [file join $rtl_dir "voltage_display_convert.v"] \
    [file join $rtl_dir "voltage_display_bcd.v"] \
    [file join $rtl_dir "voltage_display_scan.v"] \
    [file join $rtl_dir "voltage_display_ip.v"]]
set tb_file  [file join $sim_dir "tb_voltage_display_ip.v"]
set ooc_xdc  [file join $script_dir "voltage_display_ip_ooc.xdc"]

proc require_file {path} {
    if {![file isfile $path]} {
        error "Required file not found: $path"
    }
}

proc get_or_add_bus_interface {name core} {
    set bus_if [ipx::get_bus_interfaces $name -of_objects $core]
    if {[llength $bus_if] == 0} {
        # Some Vivado releases return an object-type token rather than the
        # newly created object. Add it, then query the core again.
        ipx::add_bus_interface $name $core
        set bus_if [ipx::get_bus_interfaces $name -of_objects $core]
    }
    if {[llength $bus_if] != 1} {
        error "Expected exactly one bus interface named '$name'."
    }
    return [lindex $bus_if 0]
}

proc get_or_add_port_map {logical_name bus_if} {
    set port_map [ipx::get_port_maps $logical_name -of_objects $bus_if]
    if {[llength $port_map] == 0} {
        # Re-query after creation for Vivado-version-independent behavior.
        ipx::add_port_map $logical_name $bus_if
        set port_map [ipx::get_port_maps $logical_name -of_objects $bus_if]
    }
    if {[llength $port_map] != 1} {
        error "Expected exactly one port map named '$logical_name'."
    }
    return [lindex $port_map 0]
}

proc get_or_add_bus_parameter {name bus_if} {
    set bus_param [ipx::get_bus_parameters $name -of_objects $bus_if]
    if {[llength $bus_param] == 0} {
        # Vivado 2024.2 can return the literal token "bus_parameter" from
        # ipx::add_bus_parameter. Do not use that return value as an object.
        ipx::add_bus_parameter $name $bus_if
        set bus_param [ipx::get_bus_parameters $name -of_objects $bus_if]
    }
    if {[llength $bus_param] != 1} {
        error "Expected exactly one bus parameter named '$name'."
    }
    return [lindex $bus_param 0]
}

proc close_vivado_context {} {
    catch {close_vcd}
    catch {close_sim}
    if {[llength [get_projects -quiet]] != 0} {
        catch {close_project}
    }
}

proc sum_negative_slack {paths} {
    set total 0.0
    foreach timing_path $paths {
        set slack [get_property SLACK $timing_path]
        if {$slack < 0.0} {
            set total [expr {$total + $slack}]
        }
    }
    return $total
}

if {[llength [get_projects -quiet]] != 0} {
    error "A Vivado project is already open. Save and close it, then run this script again."
}

set script_status [catch {
    foreach source_file [concat $rtl_files [list $tb_file $ooc_xdc]] {
        require_file $source_file
    }

    file mkdir $build_dir
    file mkdir $report_dir
    file mkdir [file dirname $ip_dir]
    if {[file exists $ip_dir]} {
        file delete -force $ip_dir
    }

    # -------------------------------------------------------------------------
    # 1. Behavioral simulation and out-of-context synthesis
    # -------------------------------------------------------------------------
    create_project -force voltage_display_ip_validation \
        [file join $build_dir "validation"] -part $part_name
    set_property target_language Verilog [current_project]
    set_property simulator_language Verilog [current_project]

    add_files -norecurse $rtl_files
    add_files -fileset sim_1 -norecurse $tb_file
    add_files -fileset constrs_1 -norecurse $ooc_xdc
    set_property top voltage_display_ip [current_fileset]
    set_property top tb_voltage_display_ip [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    puts "VOLTAGE_DISPLAY_IP: behavioral simulation started"
    launch_simulation -simset sim_1 -mode behavioral
    open_vcd [file join $report_dir "voltage_display_ip.vcd"]
    log_vcd [get_objects -r /tb_voltage_display_ip/*]
    run all
    close_vcd
    close_sim

    set xsim_log [file join $build_dir "validation" \
        "voltage_display_ip_validation.sim" "sim_1" "behav" "xsim" \
        "simulate.log"]
    require_file $xsim_log
    file copy -force $xsim_log \
        [file join $report_dir "simulation_xsim.log"]

    set xsim_log_file [open $xsim_log r]
    set xsim_log_text [read $xsim_log_file]
    close $xsim_log_file

    if {![regexp -line {^VOLTAGE_DISPLAY_IP TEST PASS\r?$} \
            $xsim_log_text]} {
        error "Behavioral simulation did not report the required PASS line."
    }
    if {[regexp -line {^(ERROR:|VOLTAGE_DISPLAY_IP TEST FAIL)} \
            $xsim_log_text]} {
        error "Behavioral simulation log contains a test error or FAIL line."
    }
    puts "VOLTAGE_DISPLAY_IP: behavioral simulation completed"

    puts "VOLTAGE_DISPLAY_IP: out-of-context synthesis started"
    synth_design -top voltage_display_ip -part $part_name \
        -mode out_of_context

    set clk_port [get_ports -quiet clk]
    if {[llength $clk_port] != 1} {
        error "Expected exactly one top-level clock port named 'clk'."
    }

    # Keep the script self-contained if the XDC does not already create clk.
    if {[llength [get_clocks -quiet -of_objects $clk_port]] == 0} {
        create_clock -name clk -period $clock_ns $clk_port
    }

    # OOC clock-delay/skew estimation requires a representative BUFG location.
    set bufg_sites [get_sites -quiet -filter {SITE_TYPE == BUFGCTRL}]
    if {[llength $bufg_sites] == 0} {
        error "No BUFGCTRL site was found for part $part_name."
    }
    set_property HD.CLK_SRC \
        [get_property NAME [lindex $bufg_sites 0]] $clk_port

    report_utilization \
        -file [file join $report_dir "utilization_ooc.rpt"]
    report_timing_summary -delay_type min_max -report_unconstrained \
        -check_timing_verbose \
        -file [file join $report_dir "timing_summary_ooc.rpt"]
    report_methodology \
        -file [file join $report_dir "methodology_ooc.rpt"]
    report_drc \
        -file [file join $report_dir "drc_ooc.rpt"]
    write_checkpoint -force \
        [file join $report_dir "voltage_display_ip_ooc.dcp"]

    set worst_setup_paths [get_timing_paths -quiet -delay_type max \
        -max_paths 1 -nworst 1]
    set worst_hold_paths [get_timing_paths -quiet -delay_type min \
        -max_paths 1 -nworst 1]
    if {[llength $worst_setup_paths] == 0} {
        error "No setup timing path was found after OOC synthesis."
    }
    if {[llength $worst_hold_paths] == 0} {
        error "No hold timing path was found after OOC synthesis."
    }

    set wns [get_property SLACK [lindex $worst_setup_paths 0]]
    set whs [get_property SLACK [lindex $worst_hold_paths 0]]
    set setup_violations [get_timing_paths -quiet -delay_type max \
        -slack_lesser_than 0.0 -max_paths $max_timing_paths -nworst 1]
    set hold_violations [get_timing_paths -quiet -delay_type min \
        -slack_lesser_than 0.0 -max_paths $max_timing_paths -nworst 1]
    set tns [sum_negative_slack $setup_violations]
    set ths [sum_negative_slack $hold_violations]

    set timing_summary_file \
        [file join $report_dir "timing_metrics_ooc.txt"]
    set timing_summary [open $timing_summary_file w]
    puts $timing_summary "Clock period: [format %.3f $clock_ns] ns"
    puts $timing_summary "Clock frequency: $clock_hz Hz"
    puts $timing_summary "WNS: [format %.3f $wns] ns"
    puts $timing_summary "TNS: [format %.3f $tns] ns"
    puts $timing_summary "WHS: [format %.3f $whs] ns"
    puts $timing_summary "THS: [format %.3f $ths] ns"
    puts $timing_summary \
        "Setup failing endpoints: [llength $setup_violations]"
    puts $timing_summary \
        "Hold failing endpoints: [llength $hold_violations]"
    close $timing_summary

    if {$wns < 0.0 || $tns < 0.0} {
        error [format \
            "100 MHz setup timing failed. WNS=%.3f ns, TNS=%.3f ns" \
            $wns $tns]
    }
    if {$whs < 0.0 || $ths < 0.0} {
        error [format \
            "100 MHz hold timing failed. WHS=%.3f ns, THS=%.3f ns" \
            $whs $ths]
    }

    puts [format \
        "VOLTAGE_DISPLAY_IP: 100 MHz OOC timing passed (WNS=%.3f ns, TNS=%.3f ns, WHS=%.3f ns, THS=%.3f ns)" \
        $wns $tns $whs $ths]
    close_project

    # -------------------------------------------------------------------------
    # 2. Package the RTL as a reusable, non-AXI custom IP
    # -------------------------------------------------------------------------
    create_project -force voltage_display_ip_package \
        [file join $build_dir "package"] -part $part_name
    set_property target_language Verilog [current_project]
    set_property simulator_language Verilog [current_project]

    add_files -norecurse $rtl_files
    add_files -fileset sim_1 -norecurse $tb_file
    set_property top voltage_display_ip [current_fileset]
    set_property top tb_voltage_display_ip [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    ipx::package_project -root_dir $ip_dir \
        -vendor user.org -library user -taxonomy /UserIP \
        -import_files -set_current true

    set core [ipx::current_core]
    set_property name voltage_display_ip $core
    set_property version 1.0 $core
    set_property display_name {Voltage Display IP} $core
    set_property description \
        {Frame-consistent 0.000-3.300 V Basys3 active-low FND display} $core
    set_property vendor_display_name {User} $core

    # Clock interface. Reuse an automatically inferred interface when present.
    set clk_if [get_or_add_bus_interface clk $core]
    set_property interface_mode slave $clk_if
    set_property bus_type_vlnv xilinx.com:signal:clock:1.0 $clk_if
    set_property abstraction_type_vlnv \
        xilinx.com:signal:clock_rtl:1.0 $clk_if

    set clk_map [get_or_add_port_map CLK $clk_if]
    set_property physical_name clk $clk_map

    set clk_assoc [get_or_add_bus_parameter ASSOCIATED_RESET $clk_if]
    set_property value reset_p $clk_assoc

    set clk_freq [get_or_add_bus_parameter FREQ_HZ $clk_if]
    set_property value $clock_hz $clk_freq

    # Active-high reset interface.
    set rst_if [get_or_add_bus_interface reset_p $core]
    set_property interface_mode slave $rst_if
    set_property bus_type_vlnv xilinx.com:signal:reset:1.0 $rst_if
    set_property abstraction_type_vlnv \
        xilinx.com:signal:reset_rtl:1.0 $rst_if

    set rst_map [get_or_add_port_map RST $rst_if]
    set_property physical_name reset_p $rst_map

    set rst_pol [get_or_add_bus_parameter POLARITY $rst_if]
    set_property value ACTIVE_HIGH $rst_pol

    # Expose and document the scan-divider parameter.
    ipx::infer_user_parameters $core
    set scan_param \
        [ipx::get_user_parameters SCAN_TICK_CYCLES -of_objects $core]
    if {[llength $scan_param] != 1} {
        error "Expected exactly one SCAN_TICK_CYCLES user parameter."
    }
    set_property value 100000 $scan_param
    set_property value_format long $scan_param
    set_property display_name {Scan Tick Cycles} $scan_param
    set_property description \
        {Number of input-clock cycles between FND digit scans} $scan_param

    # Keep the testbench out of synthesis while retaining it for simulation.
    set synth_group \
        [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects $core]
    if {[llength $synth_group] != 1} {
        error "Expected exactly one synthesis file group."
    }
    foreach packaged_file [ipx::get_files -of_objects $synth_group] {
        if {[string match "*tb_voltage_display_ip.v" \
                [get_property name $packaged_file]]} {
            ipx::remove_file \
                [get_property name $packaged_file] $synth_group
        }
    }

    set sim_group \
        [ipx::get_file_groups \
            xilinx_anylanguagebehavioralsimulation -of_objects $core]
    if {[llength $sim_group] == 0} {
        set sim_group \
            [ipx::add_file_group \
                xilinx_anylanguagebehavioralsimulation $core]
    }
    if {[llength $sim_group] != 1} {
        error "Expected exactly one behavioral simulation file group."
    }

    # package_project -import_files does not consistently import files from
    # project sim_1 into the IP simulation file group. Copy the self-checking
    # testbench inside the IP and register it explicitly with a relative path,
    # so component.xml never contains an external absolute path.
    set packaged_tb_rel [file join "sim" "tb_voltage_display_ip.v"]
    set packaged_tb_abs [file join $ip_dir $packaged_tb_rel]
    file mkdir [file dirname $packaged_tb_abs]
    file copy -force $tb_file $packaged_tb_abs

    set tb_in_simulation_group 0
    foreach packaged_file [ipx::get_files -of_objects $sim_group] {
        if {[string match "*tb_voltage_display_ip.v" \
                [get_property name $packaged_file]]} {
            set tb_in_simulation_group 1
        }
    }
    if {!$tb_in_simulation_group} {
        ipx::add_file $packaged_tb_rel $sim_group
    }

    set packaged_tb_objects {}
    foreach packaged_file [ipx::get_files -of_objects $sim_group] {
        if {[string match "*tb_voltage_display_ip.v" \
                [get_property name $packaged_file]]} {
            lappend packaged_tb_objects $packaged_file
        }
    }
    if {[llength $packaged_tb_objects] == 1} {
        set_property type verilogSource [lindex $packaged_tb_objects 0]
    }
    set_property model_name tb_voltage_display_ip $sim_group

    set tb_in_simulation_group \
        [expr {[llength $packaged_tb_objects] == 1}]
    if {!$tb_in_simulation_group} {
        error "The self-checking testbench is missing from the simulation file group."
    }

    ipx::update_checksums $core
    ipx::save_core $core
    ipx::check_integrity $core
    ipx::save_core $core

    set expected_vlnv "user.org:user:voltage_display_ip:1.0"
    if {[get_property vlnv $core] ne $expected_vlnv} {
        error "Unexpected packaged-IP VLNV: [get_property vlnv $core]"
    }
    if {[llength [ipx::get_memory_maps -of_objects $core]] != 0} {
        error "The packaged IP unexpectedly contains a memory map."
    }

    set component_xml [file join $ip_dir "component.xml"]
    require_file $component_xml

    # Vivado does not provide a get_messages command. Query the message
    # manager's counters and export the warning text with supported commands.
    # Errors raised by synthesis/simulation subprocesses are also guarded by
    # their run status checks above.
    set error_count \
        [get_msg_config -severity ERROR -count]
    set critical_warning_count \
        [get_msg_config -severity {CRITICAL WARNING} -count]
    set warning_count \
        [get_msg_config -severity WARNING -count]

    set warning_file \
        [file join $report_dir "vivado_warning_messages.txt"]
    write_messages -force -severity WARNING $warning_file

    if {$error_count != 0 || $critical_warning_count != 0} {
        error "Vivado reported $error_count error(s) and $critical_warning_count critical warning(s)."
    }

    set validation_summary_file \
        [file join $report_dir "validation_summary.txt"]
    set validation_summary [open $validation_summary_file w]
    puts $validation_summary "VOLTAGE_DISPLAY_IP VALIDATION PASS"
    puts $validation_summary "Simulation: VOLTAGE_DISPLAY_IP TEST PASS"
    puts $validation_summary "Part: $part_name"
    puts $validation_summary "Clock period: [format %.3f $clock_ns] ns"
    puts $validation_summary "WNS: [format %.3f $wns] ns"
    puts $validation_summary "TNS: [format %.3f $tns] ns"
    puts $validation_summary "WHS: [format %.3f $whs] ns"
    puts $validation_summary "THS: [format %.3f $ths] ns"
    puts $validation_summary "VLNV: [get_property vlnv $core]"
    puts $validation_summary "Errors: $error_count"
    puts $validation_summary \
        "Critical warnings: $critical_warning_count"
    puts $validation_summary "Warnings: $warning_count"
    close $validation_summary

    puts "VOLTAGE_DISPLAY_IP PACKAGE COMPLETE"
    puts "VLNV: [get_property vlnv $core]"
    puts "IP integrity check completed."
    puts "Packaged IP: $ip_dir"
    puts "Reports: $report_dir"

    close_project
} script_error script_options]

if {$script_status != 0} {
    close_vivado_context
    puts stderr "VOLTAGE_DISPLAY_IP PACKAGE FAILED"
    puts stderr $script_error
    return -options $script_options $script_error
}
