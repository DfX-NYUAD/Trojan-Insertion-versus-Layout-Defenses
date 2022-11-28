####
# settings
####

set_multi_cpu_usage -local_cpu 16
set_db design_process_node 7
set_db design_tech_node N7

set mmmc_path mmmc.tcl
set lef_path "asap7_tech_4x_201209.lef asap7sc7p5t_28_L_4x_220121a.lef asap7sc7p5t_28_R_4x_220121a.lef asap7sc7p5t_28_SL_4x_220121a.lef"
set def_path design.def
set netlist_path design.v

####
# init
####

read_mmmc $mmmc_path
read_physical -lefs $lef_path
read_netlist $netlist_path
read_def $def_path -preserve_shape

init_design

####
# checks w/ rpt files auto-generated
####

# NOTE covers routing issues like dangling wires, floating metals, open pins, etc.; check *.conn.rpt for "IMPVFC", "Net"
# NOTE does NOT flag cells not connected or routed at all -- those are caught by LEC, flagged as "Unreachable" points
check_connectivity

# NOTE covers IO pins; check *.checkPin.rpt for "ERROR" as well as for "Illegal*", "Unplaced"
check_pin_assignment

# NOTE covers DRC for routing; check *.geom.rpt for "Total Violations"
check_drc
## NOTE standard limit of 1,000 violations is good enough to flag invalid layouts
#check_drc -limit 99999

####
# checks w/o rpt files auto-generated
####

# NOTE covers placement and routing issues
check_design -type route > check_route.rpt

# NOTE checks routing track details
## NOTE errors out; probably not needed anyway as long as other checks here and later on check_DRC is done
#check_tracks > check_tracks.rpt

####
# clock propagation
#
# NOTE not needed when sdc files are properly set up
####

#set_interactive_constraint_modes [all_constraint_modes -active]
#reset_propagated_clock [all_clocks]
#update_io_latency -adjust_source_latency -verbose
#set_propagated_clock [all_clocks]

####
# timing
####

set_db timing_analysis_type ocv
set_db timing_analysis_cppr both
time_design -post_route

####
# basic eval
####

set fl [open area.rpt w]
puts $fl [get_db current_design .bbox.area]
close $fl

report_power > power.rpt

report_timing_summary > timing.rpt
## NOTE already comprised in above, along w/ clock checks
#report_timing_summary -checks setup >> timing.rpt
#report_timing_summary -checks drv >> timing.rpt
## NOTE only hold has to be evaluated separately explicitly
report_timing_summary -checks hold >> timing.rpt

####
# mark done; exit
####

date > DONE.check
exit
