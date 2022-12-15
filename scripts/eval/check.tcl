####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD, in collaboration with Mohammad Eslami and Samuel Pagliarini, TalTech
#
####

####
# general settings
####

set_multi_cpu_usage -local_cpu 24

set_db design_process_node 7
set_db design_tech_node N7

set mmmc_path scripts/mmmc.tcl
set lef_path "ASAP7/asap7_tech_4x_201209.lef ASAP7/asap7sc7p5t_28_L_4x_220121a.lef ASAP7/asap7sc7p5t_28_R_4x_220121a.lef ASAP7/asap7sc7p5t_28_SL_4x_220121a.lef"
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

# delete all kinds of fillers (decaps, tap cells, filler cells)
delete_filler -cells [ get_db -u [ get_db insts -if { .is_physical } ] .base_cell.name ]

####
# design checks
####

# covers routing issues like dangling wires, floating metals, open pins, etc.; check *.conn.rpt
# NOTE false positives for dangling VDD, VSS at M1
# NOTE INTERNAL ONLY: does NOT flag cells not connected or routed at all -- those are caught by LEC, flagged as "Unreachable" points
check_connectivity -error 100000 -warning 100000 -check_wire_loops
mv *.conn.rpt reports/

# covers IO pins; check *.checkPin.rpt
check_pin_assignment
mv *.checkPin.rpt reports/

# covers routing DRCs; check *.geom.rpt
check_drc -limit 100000
mv *.geom.rpt reports/

# covers placement and routing issues
# NOTE false positives for VDD, VSS vias at M4, M5, M6; report file has incomplete info, full details are in check.logv
check_design -type {place route} > reports/check_design.rpt

####
# settings for clock propagation, timing, power, SI
####

# clock propagation
# NOTE no differences in timing values w/ versus w/o these settings, because of 'time_desing -post_route' using the
# clock propagation from SDC files; still kept here just to make sure and be consistent w/ earlier scripts
set_interactive_constraint_modes [all_constraint_modes -active]
reset_propagated_clock [all_clocks]
## NOTE INTERNAL ONLY: probably not needed w/ latency values and clock constraints defined in SDC file
## NOTE INTERNAL ONLY: also errors out for Innovus 21 as follows: ERROR: (TCLCMD-1411): The update_io_latency command cannot be run when a clock is propagated. Check if there is any set_propagated_clock constraint on pin/port.
#update_io_latency -adjust_source_latency -verbose
set_propagated_clock [all_clocks]
# removes clock pessimism
set_db timing_analysis_cppr both

# applicable for (faster) timing analysis, not for subsequent ECO runs or so -- OK for our scope
set_db timing_enable_simultaneous_setup_hold_mode true

# on-chip variations to be considered
set_db timing_analysis_type ocv

# enables SI/noise reporting
set_db si_delay_enable_report true
set_db si_glitch_enable_report true
set_db si_enable_glitch_propagation true

# required for proper power and SI analysis; default activity factor for PIs, 0.2, is not propagated automatically
set_default_switching_activity -sequential_activity 0.2

####
# timing analysis
####

# actual timing eval command
time_design -post_route
## NOTE provides setup, hold, DRV, clock checks all in one; requires simultaneous_setup_hold_mode
report_timing_summary > reports/timing.rpt
	# NOTE INTERNAL ONLY: explicit separate eval not needed
	#report_timing_summary -checks setup >> reports/timing.rpt
	#report_timing_summary -checks hold >> reports/timing.rpt
	#report_timing_summary -checks drv >> reports/timing.rpt

####
# SI/noise reporting
####

#INTERNAL ONLY # NOTE values differ from those obtained in regular flow, as in here less noise and no violations at all are reported
#INTERNAL ONLY # NOTE somewhat more noise, violations are reported for separate timing checks and 'timing_enable_simultaneous_setup_hold_mode false'
#INTERNAL ONLY # TODO try again w/ separate timing checks and timing_enable_simultaneous_setup_hold_mode false, now that set_default_switching_activity is there
#INTERNAL ONLY # NOTE deactivated for now
#INTERNAL ONLY report_noise -threshold 0.2 > reports/noise.rpt
#INTERNAL ONLY # NOTE for some reason, the parameter to be used here is noisy_waveform, not bumpy_waveform
#INTERNAL ONLY report_noise -threshold 0 -noisy_waveform >> reports/noise.rpt

####
# die area
####

set out [open reports/area.rpt w]
puts $out [get_db current_design .bbox.area]
close $out

####
# power
####

report_power > reports/power.rpt

####
# routing track utilization
####

# NOTE INTERNAL ONLY M1 is skipped, even when explicitly setting "-layer 1:10" -- probably because M1 is not made available for routing in lib files
report_route -include_regular_routes -track_utilization > reports/track_utilization.rpt

####
# exploitable regions
####

source scripts/exploitable_regions.tcl

####
# mark done; exit
####

date > DONE.inv_checks
exit
