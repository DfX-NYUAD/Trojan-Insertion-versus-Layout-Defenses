####
#
# Script for ISPD'23 contest. Mohammad Eslami and Samuel Pagliarini, TalTech, in collaboration with Johann Knechtel, NYUAD
#
# Script to perform PPA evaluation on the submission files (design.def, design.v). Also writes out different sets of design files for ECO TI towards the end.
#
####

#####################
# general settings
#####################

setMultiCpuUsage -localCpu 8 -keepLicense true

set mmmc_path scripts/mmmc.tcl
set lef_path "ASAP7/asap7_tech_4x_201209.lef ASAP7/asap7sc7p5t_28_L_4x_220121a.lef ASAP7/asap7sc7p5t_28_SL_4x_220121a.lef"
set def_path design.def
set netlist_path design.v

## (TODO) for manual dbg
#set def_path design_original.def
#set netlist_path design_original.v

#####################
# init
#####################

source benchmark_name.tcl

set init_mmmc_file $mmmc_path
set init_lef_file $lef_path
set init_verilog $netlist_path

set setup_analysis_views "view_tc"
set hold_analysis_views  "view_tc"
set power_analysis_view  "view_tc"

init_design -setup ${setup_analysis_views} -hold ${hold_analysis_views}

setDesignMode -process 7 -node N7

# preserve shapes/layout as is
defIn $def_path -preserveShape

# required for proper power analysis; default activity factor for PIs, 0.2, is not propagated automatically
set_default_switching_activity -seq_activity 0.2

# delete all kinds of fillers (decaps, tap cells, filler cells)
deleteFiller -cell [ get_db -u [ get_db insts -if { .is_physical } ] .base_cell.name ]

#####################
# clock propagation
#####################

set_interactive_constraint_modes [all_constraint_modes -active]
reset_propagated_clock [all_clocks]
update_io_latency -source -verbose
set_propagated_clock [all_clocks]

#####################
# timing
#####################

# OCV
setAnalysisMode -analysisType onChipVariation
# removes clock pessimism
setAnalysisMode -cppr both
# simultaneous setup, hold analysis
# NOTE applicable for (faster) timing analysis here, but not for subsequent ECO runs later on
set_global timing_enable_simultaneous_setup_hold_mode true
# actual timing command
timeDesign -postroute

#####################
# reports
#####################

# power
report_power > reports/power.rpt

# die area
set out [open reports/area.rpt w]
puts $out [get_db current_design .bbox.area]
close $out

# timing; using simultaneous setup, hold analysis
# NOTE detailed timing reports also include both views
report_timing_summary > reports/timing.rpt

#####################
# write out design files for ECO TI
#####################

## settings for ECO place and route commands, which are triggered by reclaimArea below
#
# turn off simultaneous setup, hold analysis; not supported by ECO commands
# NOTE timing (and RC extraction) are triggered by ECO commands themselves as needed
set_global timing_enable_simultaneous_setup_hold_mode false
#
# Reset any instance to PLACED status; there cannot be any unplaced instances (as those would also trigger warnings and errors earlier on, namely for checks.tcl), but there may be
# fixed ones marked as such in the submission, and we'd like to 'free up' those, if any.
set_db [get_db insts ] .place_status placed
#
## NOTE Here cannot use 'setPlaceMode -place_detail_preroute_as_obs 3' as that would -- falsely -- push the utilization easily >100% since it's sufficient for the placement to stay
## somewhat out of the M3 PDN stripes, not entirely, to avoid DRC issues. In other words, a valid layout w/o DRC issues may well have >100% util once we check again for these
## preroutes; this constraint should not be used for checking, but only for placement. Now, while reclaimArea does trigger ECO placement here, it is only refinePlace; thus, we don't
## even need that constraint here to maintain DRC-clean layouts.
#setPlaceMode -place_detail_preroute_as_obs 3
#
# Control iterations for detailed routing, for both cases: 1) too many violations for large designs, where it's taking too long to fix all,
# 2) give more trials for small designs  where NanoRoute might otherwise give up too soon.
if { $benchmark_name == "aes" } {
	setNanoRouteMode -drouteEndIteration 25
} else {
	setNanoRouteMode -drouteEndIteration 100
}

## NOTE deprecated; while that would be more efficient, these steps/parameters are deprecated for the following reasons.
## NOTE '-timingGraph' triggers error for ecoDesign: **ERROR: (IMPSYT-6778): can't read "exclude_path_collection": no such variable. Sounds like we would need to specify during
## ecoDesign that the paths for the new Trojan logic are not in the stored graph, but am not sure. Note that 'restoreDesign' works fine with '-timingGraph' generated db (but didn't
## check in on related warnings, if any).
## NOTE '-no_wait' and checking only for existence of design files in TI_wrapper.sh could easily lead to race conditions, as in ECO TI already loading the db when it's not
## completely written out yet
#saveDesign design.reg.enc -timingGraph -no_wait saveDesign.reg.log

## regular ECO TI mode: write out design as is
#
# write out design db, including RC data but w/o timing graph (see note above).
saveDesign design.reg.enc -rc
# also write out netlist; Trojan logic is to be integrated into this one before ecoDesign is run
# NOTE here we can just link the submission netlist; TI_init_netlist.tcl will not overwrite this.
ln -sf design.v design.reg.v
# mark as done so that ECO TI db preparation (via TI_wrapper.sh and TI_init_netlist.tcl) can go ahead at this point
date > DONE.save.reg

## advanced ECO TI mode: reclaim area
#
# reclaimArea performs decloning, downsizing, and deleting of buffers, all without worsening slacks or DRVs; also employs ECO place and route
reclaimArea -maintainHold
# write out design db, including RC data but w/o timing graph (see note above).
saveDesign design.adv.enc -rc
# also write out netlist; Trojan logic is to be integrated into this one before ecoDesign is run
saveNetlist design.adv.v
# mark as done so that ECO TI db preparation (via TI_wrapper.sh and TI_init_netlist.tcl) can go ahead at this point
date > DONE.save.adv

## advanced^2 ECO TI mode: reclaim area again, and more aggressively
#
# NOTE skip for aes, as this can take ~7h
if { $benchmark_name == "aes" } {
	date > DONE.inv_PPA
	exit
}
# NOTE just using 'reclaimArea -maintainHold' multiple times would also be possible, but gains for subsequent runs are very limited.
# reclaimArea performs decloning, downsizing, and deleting of buffers, all _without_ honoring current hold timing in this setting here (might be possible to fix along w/
# timing-driven ecoPlace later on); also employs ECO place and route
reclaimArea 
# write out design db, including RC data but w/o timing graph (see note above).
saveDesign design.adv2.enc -rc
# also write out netlist; Trojan logic is to be integrated into this one before ecoDesign is run
saveNetlist design.adv2.v
# mark as done so that ECO TI db preparation (via TI_wrapper.sh and TI_init_netlist.tcl) can go ahead at this point
date > DONE.save.adv2

#####################
# mark done; exit
#####################

date > DONE.inv_PPA
exit
