####
# settings
####
set_multi_cpu_usage -local_cpu 8
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
# clock propagation
####
set_interactive_constraint_modes [all_constraint_modes -active]
reset_propagated_clock [all_clocks]
update_io_latency -adjust_source_latency -verbose
set_propagated_clock [all_clocks]

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
report_timing_summary -checks setup > timing.rpt

## NOTE no exit here, as this is supposed to be sourced along with other scripts
