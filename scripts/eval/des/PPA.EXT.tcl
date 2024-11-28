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

# delete all kinds of fillers (decaps, tap cells, filler cells, metal fills)
deleteFiller -cell [ get_db -u [ get_db insts -if { .is_physical } ] .base_cell.name ]
deleteMetalFill

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
## Control iterations for detailed routing, for both cases: 1) too many violations for large designs, where it's taking too long to fix all,
## 2) give more trials for small designs  where NanoRoute might otherwise give up too soon.
if { $benchmark_name == "aes" } {
	setNanoRouteMode -drouteEndIteration 20
} else {
	setNanoRouteMode -drouteEndIteration 40
}

## regular ECO TI mode: write out design as is
#
# write out design db, including RC data but w/o timing graph (see note above).
saveDesign design.reg.enc -rc
# also write out netlist; Trojan logic is to be integrated into this one before ecoDesign is run
# NOTE here we can just link the submission netlist; TI_init_netlist.tcl will not overwrite this.
ln -sf design.v design.reg.v
# mark as done so that ECO TI db preparation (via TI_wrapper.sh and TI_init_netlist.tcl) can go ahead at this point
date > DONE.save.reg

# link files for easier handling during extended ECO TI
ln -sf design.reg.enc design.1.enc
ln -sf design.reg.enc design.2.enc
ln -sf design.reg.enc design.3.enc
ln -sf design.reg.enc design.4.enc
ln -sf design.reg.enc.dat design.1.enc.dat
ln -sf design.reg.enc.dat design.2.enc.dat
ln -sf design.reg.enc.dat design.3.enc.dat
ln -sf design.reg.enc.dat design.4.enc.dat
ln -sf design.reg.v design.1.v
ln -sf design.reg.v design.2.v
ln -sf design.reg.v design.3.v
ln -sf design.reg.v design.4.v
ln -sf DONE.save.reg DONE.save.1
ln -sf DONE.save.reg DONE.save.2
ln -sf DONE.save.reg DONE.save.3
ln -sf DONE.save.reg DONE.save.4

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

# link files for easier handling during extended ECO TI
ln -sf design.adv.enc design.5.enc
ln -sf design.adv.enc design.6.enc
ln -sf design.adv.enc design.7.enc
ln -sf design.adv.enc design.8.enc
ln -sf design.adv.enc.dat design.5.enc.dat
ln -sf design.adv.enc.dat design.6.enc.dat
ln -sf design.adv.enc.dat design.7.enc.dat
ln -sf design.adv.enc.dat design.8.enc.dat
ln -sf design.adv.v design.5.v
ln -sf design.adv.v design.6.v
ln -sf design.adv.v design.7.v
ln -sf design.adv.v design.8.v
ln -sf DONE.save.adv DONE.save.5
ln -sf DONE.save.adv DONE.save.6
ln -sf DONE.save.adv DONE.save.7
ln -sf DONE.save.adv DONE.save.8

## advanced^2 ECO TI mode: optimize design
# settings for opt design
setOptMode -verbose true
setOptMode -simplifyNetlist true
setOptMode -maxDensity 100
# actual opt design call, postRoute only
optDesign -postRoute -setup -hold
# another run for reclaimArea, as reclaiming during optDesign -postRoute is somewhat limited
reclaimArea -maintainHold
# write out design db, including RC data but w/o timing graph (see note above).
saveDesign design.adv2.enc -rc
# also write out netlist; Trojan logic is to be integrated into this one before ecoDesign is run
saveNetlist design.adv2.v
# mark as done so that ECO TI db preparation (via TI_wrapper.sh and TI_init_netlist.tcl) can go ahead at this point
date > DONE.save.adv2

# link files for easier handling during extended ECO TI
ln -sf design.adv2.enc design.9.enc
ln -sf design.adv2.enc design.10.enc
ln -sf design.adv2.enc design.11.enc
ln -sf design.adv2.enc design.12.enc
ln -sf design.adv2.enc.dat design.9.enc.dat
ln -sf design.adv2.enc.dat design.10.enc.dat
ln -sf design.adv2.enc.dat design.11.enc.dat
ln -sf design.adv2.enc.dat design.12.enc.dat
ln -sf design.adv2.v design.9.v
ln -sf design.adv2.v design.10.v
ln -sf design.adv2.v design.11.v
ln -sf design.adv2.v design.12.v
ln -sf DONE.save.adv2 DONE.save.9
ln -sf DONE.save.adv2 DONE.save.10
ln -sf DONE.save.adv2 DONE.save.11
ln -sf DONE.save.adv2 DONE.save.12

#####################
# mark done; exit
#####################

date > DONE.inv_PPA
exit