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

# NOTE covers routing issues like dangling wires, floating metals, open pins, etc.; check *.conn.rpt for "IMPVFC", "Net"
# NOTE check regular and special nets, false positives for dangling VDD, VSS at M1 (already seen for ISPD22) are filtered out from the report using TODO script called below
## TODO see exploitable_regions.tcl for syntax for call of external tools
# NOTE does NOT flag cells not connected or routed at all -- those are caught by LEC, flagged as "Unreachable" points
check_connectivity -error 100000 -warning 100000 -check_wire_loops
mv *.conn.rpt reports/

# NOTE covers IO pins; check *.checkPin.rpt for "ERROR" as well as for "Illegal*", "Unplaced"
check_pin_assignment
mv *.checkPin.rpt reports/

# NOTE covers DRC for routing; check *.geom.rpt for "Total Violations"
check_drc -limit 100000
mv *.geom.rpt reports/

# NOTE covers placement and routing issues
check_design -type {place route} > reports/check_design.rpt

####
# settings for clock propagation, timing, power, SI
####

# clock propagation
# NOTE no differences in timing w/ versus w/o these propagation settings, because of time_desing -post_route using the
# clock propagation from SDC files ; still kept here just to make sure and be consistent w/ earlier scripts
set_interactive_constraint_modes [all_constraint_modes -active]
reset_propagated_clock [all_clocks]
## NOTE probably not needed w/ latency values and clock constraints defined in SDC file
## NOTE also errors out for Innovus 21 as follows:
### ERROR: (TCLCMD-1411): The update_io_latency command cannot be run when a clock is propagated. Check if there is any set_propagated_clock constraint on pin/port.
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
	# NOTE explicit separate eval not needed
	#report_timing_summary -checks setup >> reports/timing.rpt
	#report_timing_summary -checks hold >> reports/timing.rpt
	#report_timing_summary -checks drv >> reports/timing.rpt

####
# SI/noise reporting
####

## NOTE values differ from those obtained in regular flow, as in here less noise and no violations at all are reported
## NOTE somewhat more noise, violations are reported for separate timing checks and 'timing_enable_simultaneous_setup_hold_mode false'
## TODO try again w/ separate timing checks and timing_enable_simultaneous_setup_hold_mode false, now that
## set_default_switching_activity is there
## NOTE deactivated for now
#report_noise -threshold 0.2 > reports/noise.rpt
## NOTE for some reason, the parameter to be used here is noisy_waveform, not bumpy_waveform
#report_noise -threshold 0 -noisy_waveform >> reports/noise.rpt

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

# NOTE M1 is skipped, even when explicitly setting "-layer 1:10" -- probably because M1 is not made available for routing in lib files
report_route -include_regular_routes -track_utilization > reports/track_utilization.rpt

####
# exploitable regions
####

source scripts/exploitable_regions.tcl

####
# mark done; exit
####

date > DONE.design_checks
exit
