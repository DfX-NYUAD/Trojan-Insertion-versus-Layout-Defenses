####
# settings
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

####
# checks w/ rpt files auto-generated
####

# NOTE covers routing issues like dangling wires, floating metals, open pins, etc.; check *.conn.rpt for "IMPVFC", "Net"
# NOTE only check regular nets, ignore special nets (VDD, VSS); there are false positives for dangling VDD, VSS at M1,
# already seen at ISPD22; VDD, VSS are checked separately anyway
# NOTE any re-declaration of other nets as special nets would allow teams to bypass checks; but, DRC checks are still
# there anyway, so should be fine
# NOTE does NOT flag cells not connected or routed at all -- those are caught by LEC, flagged as "Unreachable" points
check_connectivity -type regular -error 100000 -warning 100000 -check_wire_loops
mv *.conn.rpt reports/

# NOTE covers IO pins; check *.checkPin.rpt for "ERROR" as well as for "Illegal*", "Unplaced"
check_pin_assignment
mv *.checkPin.rpt reports/

# NOTE covers DRC for routing; check *.geom.rpt for "Total Violations"
check_drc -limit 100000
mv *.geom.rpt reports/

####
# checks w/o rpt files auto-generated
####

# NOTE covers placement and routing issues
check_design -type route > reports/check_route.rpt

####
# clock propagation
####

set_interactive_constraint_modes [all_constraint_modes -active]
reset_propagated_clock [all_clocks]
#
## NOTE probably not needed w/ latency values and clock constraints defined in SDC file
## NOTE also errors out for Innovus 21 as follows:
### ERROR: (TCLCMD-1411): The update_io_latency command cannot be run when a clock is propagated. Check if there is any set_propagated_clock constraint on pin/port.
#update_io_latency -adjust_source_latency -verbose
#
set_propagated_clock [all_clocks]

####
# timing
####

## NOTE only applicable for timing analysis, not for subsequent ECO or so -- fits our scope
set_db timing_enable_simultaneous_setup_hold_mode true
# on-chip variations to be considered
set_db timing_analysis_type ocv
# removes clock pessimism
set_db timing_analysis_cppr both
# enables SI/noise reporting
set_db si_delay_enable_report true
set_db si_glitch_enable_report true
set_db si_enable_glitch_propagation true
# actual timing eval command
time_design -post_route

# timing reporting
#
## NOTE provides setup, hold, DRV, clock checks all in one; requires simultaneous_setup_hold_mode
report_timing_summary > reports/timing.rpt
# NOTE explicit separate eval not needed
#report_timing_summary -checks setup >> reports/timing.rpt
#report_timing_summary -checks hold >> reports/timing.rpt
#report_timing_summary -checks drv >> reports/timing.rpt

# SI/noise reporting
#
report_noise -threshold 0.2 > reports/noise.rpt

####
# die area
####

set fl [open reports/area.rpt w]
puts $fl [get_db current_design .bbox.area]
close $fl

####
# power
####

report_power > reports/power.rpt

####
# mark done; exit
####

date > DONE.check
exit
