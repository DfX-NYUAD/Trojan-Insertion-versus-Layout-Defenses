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
# dynamic config file; generated through the TI_init.sh helper script
source "scripts/TI_settings.tcl"
# NOTE mark once the config file is sourced; this signals to the TI_wrapper.sh helper script that the next config file can be written out
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
setNanoRouteMode -drouteEndIteration 20
ecoRoute

#####################
# post-insertion checks; only those required for scoring
# TODO consider other design checks again here?
#####################
#
verify_drc -limit 100000 -report reports/$design_name.geom.TI_$trojan_name.rpt

# simultaneous setup, hold analysis
# NOTE applicable for (faster) timing analysis, but not for subsequent ECO runs or so -- OK for our scope here, after actual ECO commands
set_global timing_enable_simultaneous_setup_hold_mode true
report_timing_summary > reports/timing.TI_$trojan_name.rpt

#####################
# write out TI-infected design
#####################
#
## netlist, DEF
#set defOutLefVia 1
#set defOutLefNDR 1
#defOut -netlist -routing -allLayers design.TI_$trojan_name.def
#saveNetlist design.TI_$trojan_name.v

## GDS
#setStreamOutMode -reset                                                                                                                                                                                                                                                                             
#
##TODO
## TODO also update daemon, to upload GDS files
## streamOut ./sha256_v${VERSION}.gds.gz \
## -mapFile {../gds/gds2.map} \
## -libName DesignLib \
## -uniquifyCellNames \
## -outputMacros \
## -stripes 1 \
## -mode ALL \
## -units 4000 \
## -reportFile ../report/top/gds_stream_out_final.rpt \
## -merge { ../gds/asap7sc7p5t_28_L_220121a_scaled4x.gds  ../gds/asap7sc7p5t_28_SL_220121a_scaled4x.gds }
### -merge { ../gds/asap7sc7p5t_28_L_220121a_scaled4x.gds  ../gds/asap7sc7p5t_28_R_220121a_scaled4x.gds
#../gds/asap7sc7p5t_28_SL_220121a_scaled4x.gds  ../gds/asap7sc7p5t_28_SRAM_220121a_scaled4x.gds}


####
# mark done; exit
####
#
date > DONE.TI_$trojan_name
exit
