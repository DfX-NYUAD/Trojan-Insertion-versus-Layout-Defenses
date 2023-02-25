####
#
# Script for ISPD'23 contest. Mohammad Eslami and Samuel Pagliarini, TalTech, in collaboration with Johann Knechtel, NYUAD
#
####

#####################
# general settings
#####################
#
setMultiCpuUsage -localCpu 8 -keepLicense true

#####################
# init
#####################
#
# source dynamic config file; generated through the TI_init.sh helper script
source "scripts/TI_settings.tcl"
# NOTE mark once the config file is sourced; this signals to the TI_wrapper.sh helper script that the next config file can be written out
date > DONE.source.$trojan_name

# dbg related settings
# NOTE TI_dbg is also sourced from scripts/TI_settings.tcl
if { $TI_dbg == 0 } {
	# NOTE for non-debug mode, report files are placed directly in the work dir, not in reports/ -- this is on purpose, as we don't want to share related reports/details to participants
	set reports_folder "./"
} else {
	# NOTE for debug, related report files are placed in reports/ and, thus, also uploaded
	set reports_folder "reports/"
}

## manual dbg: restoring session as is
#restoreDesign design.enc.dat $design_name

#####################
# Trojan insertion
#####################
#
ecoDesign design.enc.dat $design_name $trojan_netlist -keepInstLoc -noEcoPlace -reportFile $reports_folder/$trojan_name.ecoDesign.rpt
setPlaceMode -place_detail_preroute_as_obs 3
ecoPlace -fixPlacedInsts
# NOTE deprecated; while this would help for passing through on some submissions that route in M1, it hinders others --> better to disallow M1 routing in general
#setDesignMode -bottomRoutingLayer 1
setNanoRouteMode -drouteEndIteration 20
ecoRoute

#####################
# post-insertion checks
#
# NOTE other checks in checks.tcl are skipped here, since 1) accounting for all them during scoring seems difficult and, more importantly, 2) these checks were more to try to catch
# any cheating/trivial defenses
#####################
#
verify_drc -limit 100000 -report $reports_folder/$design_name.geom.$trojan_name.rpt

# simultaneous setup, hold analysis
# NOTE applicable for (faster) timing analysis, but not for subsequent ECO runs or so -- OK for our scope here, after actual ECO commands
set_global timing_enable_simultaneous_setup_hold_mode true
# NOTE irrespective of dbg mode, this report should always be shared and thus stored into reports/
report_timing_summary > reports/timing.$trojan_name.rpt

#####################
# write out TI-infected design
#####################
#
# netlist, DEF
if { $TI_dbg == 1 } {
	set defOutLefVia 1
	set defOutLefNDR 1
	defOut -netlist -routing -allLayers design.$trojan_name.def
	saveNetlist design.$trojan_name.v
}

# GDS
set_global timing_enable_simultaneous_setup_hold_mode false
setStreamOutMode -reset
streamOut $trojan_name.gds.gz -mapFile {ASAP7/gds2.map} -stripes 1 -libName DesignLib -uniquifyCellNames -outputMacros -mode ALL -units 4000 -reportFile $reports_folder/$trojan_name.gds.rpt -merge { ASAP7/asap7sc7p5t_28_L_220121a_scaled4x.gds  ASAP7/asap7sc7p5t_28_SL_220121a_scaled4x.gds }

####
# mark done; exit
####
#
date > DONE.TI_$trojan_name
exit
