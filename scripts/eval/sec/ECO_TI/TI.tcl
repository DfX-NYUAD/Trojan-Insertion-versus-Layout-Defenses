####
#
# Script for ISPD'23 contest. Mohammad Eslami and Samuel Pagliarini, TalTech, in collaboration with Johann Knechtel, NYUAD
#
####

#####################
# general settings
#####################
#
setMultiCpuUsage -localCpu 24

#####################
# init
#####################
#
# dynamic config file; generated through TI_init.sh helper script
source "scripts/TI_settings.tcl"
# NOTE mark once the config file is sourced; this signals to TODO helper script that the next config file can be written out
date > DONE.source.TI_$trojan_name

## dbg: restoring session as is
#restoreDesign design.enc.dat $design_name

#####################
# Trojan insertion
#####################
#
ecoDesign design.enc.dat $design_name $trojan_netlist -keepInstLoc -noEcoPlace
setPlaceMode -place_detail_preroute_as_obs 3
ecoPlace -fixPlacedInsts
ecoRoute

#####################
# post-insertion checks
#####################
#
verify_drc -limit 100000 -report reports/$design_name.geom.TI_$trojan_name.rpt

# simultaneous setup, hold analysis
# NOTE applicable for (faster) timing analysis, but not for subsequent ECO runs or so -- OK for our scope here, after actual ECO commands
set_global timing_enable_simultaneous_setup_hold_mode true
report_timing_summary > reports/timing.TI_$trojan_name.rpt

#####################
# write out design
#####################
#
set defOutLefVia 1
set defOutLefNDR 1
defOut -netlist -routing -allLayers design.TI_$trojan_name.def
saveNetlist design.TI_$trojan_name.v

####
# mark done; exit
####
#
date > DONE.TI_$trojan_name
exit
