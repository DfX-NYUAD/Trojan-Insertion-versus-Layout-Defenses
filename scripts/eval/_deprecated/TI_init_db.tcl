####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD, in collaboration with Mohammad Eslami and Samuel Pagliarini, TalTech
#
# Script to load design files and prepare for ECO TI, by writing out the design db. Derived from PPA.tcl.
#
####

#####################
# general settings
#####################

setMultiCpuUsage -localCpu 8 -keepLicense true

set mmmc_path scripts/mmmc.tcl
set lef_path "ASAP7/asap7_tech_4x_201209.lef ASAP7/asap7sc7p5t_28_L_4x_220121a.lef ASAP7/asap7sc7p5t_28_SL_4x_220121a.lef"

#####################
# init
#####################

# source dynamic config file; generated through the TI_init.sh helper script
# TODO only for TI_mode
source scripts/TI_settings.tcl

## NOTE we cannot mark as done here yet, as that config file is still needed for TI.tcl
## NOTE mark once the config file is sourced; this signals to the TI_wrapper.sh helper script that the next config file can be written out
#date > DONE.source.TI.$trojan_name

# TODO load related files: DEF and netlist w/o Trojan logic, but following TI_mode
# TODO use TI_settings.tcl for passing these file details
set def_path design.def
set netlist_path design.v

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

# NOTE not really needed here, but still done so that it's set in the db and would enable proper power analysis later on, like after ECO TI. (Currently though, we don't do power analysis post-TI.)
# required for proper power analysis; default activity factor for PIs, 0.2, is not propagated automatically
set_default_switching_activity -seq_activity 0.2

## NOTE not needed here; already deleted through PPA.tcl
## delete all kinds of fillers (decaps, tap cells, filler cells)
#deleteFiller -cell [ get_db -u [ get_db insts -if { .is_physical } ] .base_cell.name ]

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

setAnalysisMode -analysisType onChipVariation
# removes clock pessimism
setAnalysisMode -cppr both
## NOTE not needed here; timing graph cannot be restored properly by ecoDesign, so we have to time the design there anyway.
#timeDesign -postroute

######################
## reports
## NOTE not needed here
######################
#
#report_power > reports/power.rpt
#
## simultaneous setup, hold analysis
## NOTE applicable for (faster) timing analysis here, but not for subsequent ECO runs later on
#set_global timing_enable_simultaneous_setup_hold_mode true
#report_timing_summary > reports/timing.rpt
#
##die area
#set out [open reports/area.rpt w]
#puts $out [get_db current_design .bbox.area]
#close $out

#####################
# write out db for ECO TI
#####################

# NOTE not really needed here, as this should be the default and we don't set otherwise in the above code anymore; still done as fail-safe measure.
# turn off simultaneous setup, hold analysis; not supported by ECO commands
set_global timing_enable_simultaneous_setup_hold_mode false

## NOTE these steps/parameters are deprecated, as follows.
## NOTE -timingGraph triggers error for ecoDesign: **ERROR: (IMPSYT-6778): can't read "exclude_path_collection": no such variable. Sounds like timing graph is not stored properly.
## Interestingly, restoreDesign works fine with -timingGraph generated db.
## NOTE -rc works fine, but also does not provide much runtime benefit, probably because rc_model.bin is already there as well. Furthermore, it triggers/results in warnings
## `Mismatch between RCDB and Verilog netlist' so it's dropped as well
## NOTE -no_wait and checking only for existence of design.enc, design.enc.dat in TI_wrapper could easily lead to race conditions, as in ECO TI already loading the db when it's not
## completed yet
#saveDesign design.$trojan_name.enc -timingGraph -rc -no_wait saveDesign.$trojan_name.log

saveDesign design.$trojan_name.enc

#####################
# mark done; exit
#####################

date > DONE.saveDesign.$trojan_name
exit
