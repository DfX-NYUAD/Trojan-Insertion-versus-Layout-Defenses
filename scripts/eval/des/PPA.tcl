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

#####################
# init
#####################

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

# timing, using simultaneous setup, hold analysis
# NOTE applicable for (faster) timing analysis here, but not for subsequent ECO runs later on
set_global timing_enable_simultaneous_setup_hold_mode true
report_timing_summary > reports/timing.rpt

#####################
# write out design files for ECO TI
#####################

## NOTE settings for ECO place and route commands, which are triggered by reclaimArea below
# turn off simultaneous setup, hold analysis; not supported by ECO commands
set_global timing_enable_simultaneous_setup_hold_mode false
# Reset any instance to PLACED status; there cannot be any unplaced instances (as those would also trigger warnings and errors earlier on, namely for checks.tcl), but there may be
# fixed ones marked as such in the submission, and we'd like to 'free up' those, if any.
set_db [get_db insts ] .place_status placed
# limit optimization iterations for detailed routing, as also suggested in Cadence Support; based on own observations, the actual number is larger than what's suggested by Cadence (20)
setNanoRouteMode -drouteEndIteration 30
#
## NOTE Here cannot use 'setPlaceMode -place_detail_preroute_as_obs 3' as that would -- falsely -- push the utilization easily >100% since it's sufficient for the placement to stay
## somewhat out of the M3 PDN stripes, not entirely, to avoid DRC issues. In other words, a valid layout w/o DRC issues may well have >100% util once we check again for these
## preroutes; this constraint should not be used for checking, but only for placement. Now, while reclaimArea does trigger ECO placement here, it is only refinePlace; thus, we don't
## even need that constraint here to maintain DRC-clean layouts.
#setPlaceMode -place_detail_preroute_as_obs 3

## NOTE for regular ECO TI mode: write out design as is
# write out design db
saveDesign design.forTI.reg.enc
# link netlist to that from the sumbission; Trojan logic is to be integrated into this one before ecoDesign is run
ln -sf design.v design.forTI.reg.v
# mark as done so that ECO TI db preparation (via TI_wrapper.sh and TI_init_db.tcl) can go ahead at this point
date > DONE.save.forTI.reg
#
## NOTE while that would be more efficient, these steps/parameters are deprecated for the following reasons.
## NOTE -timingGraph triggers error for ecoDesign: **ERROR: (IMPSYT-6778): can't read "exclude_path_collection": no such variable. Sounds like timing graph is not stored properly.
## Interestingly, restoreDesign works fine with -timingGraph generated db.
## NOTE -rc works fine, but also does not provide much runtime benefit, probably because rc_model.bin is already there as well. Furthermore, it triggers/results in warnings
## `Mismatch between RCDB and Verilog netlist' so it's dropped as well
## NOTE -no_wait and checking only for existence of design files in TI_wrapper.sh could easily lead to race conditions, as in ECO TI already loading the db when it's not
## completely written out yet
#saveDesign design.forTI.reg.enc -timingGraph -rc -no_wait saveDesign.forTI.reg.log

## NOTE for advanced ECO TI mode: reclaim area
# reclaimArea performs decloning, downsizing, and deleting of buffers, all without worsening slacks or DRVs;
# also employs ECO place and route
reclaimArea -maintainHold
# write out design db
saveDesign design.forTI.adv.enc
# also write out revised netlist; Trojan logic is to be integrated into this one before ecoDesign is run
saveNetlist design.forTI.adv.v
# mark as done so that ECO TI db preparation (via TI_wrapper.sh and TI_init_db.tcl) can go ahead at this point
date > DONE.save.forTI.adv

## NOTE for advanced^2 ECO TI mode: reclaim area again, and more aggressively
# NOTE just using 'reclaimArea -maintainHold' multiple times would also be possible, but gains for subsequent runs are very limited.
# (TODO) really needed? maybe too aggressive; maybe better to have different options for ecoDesign etc.
# (TODO) could also do 'reclaimArea -maintainHold' here and some less "aggressive" setting above
# reclaimArea performs decloning, downsizing, and deleting of buffers, all _without_ honoring current hold timing in this setting here (might be possible to fix along w/
# timing-driven ecoPlace later on);
# also employs ECO place and route
reclaimArea 
# write out design db
saveDesign design.forTI.adv2.enc
# also write out revised netlist; Trojan logic is to be integrated into this one before ecoDesign is run
saveNetlist design.forTI.adv2.v
# mark as done so that ECO TI db preparation (via TI_wrapper.sh and TI_init_db.tcl) can go ahead at this point
date > DONE.save.forTI.adv2

#####################
# mark done; exit
#####################

date > DONE.inv_PPA
exit
