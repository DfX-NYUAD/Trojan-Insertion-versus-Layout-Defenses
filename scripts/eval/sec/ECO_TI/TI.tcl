####
#
# Script for ISPD'23 contest. Mohammad Eslami and Samuel Pagliarini, TalTech, in collaboration with Johann Knechtel, NYUAD
#
# Script to perform ECO TI.
#
####

#####################
# general settings
#####################

setMultiCpuUsage -localCpu 8 -keepLicense true

#####################
# init
#####################

## source dynamic config file; generated through the TI_init.sh helper script
source scripts/TI_settings.tcl
# NOTE mark once the config file is sourced; this signals to the TI_wrapper.sh helper script that the next config file can be written out
date > DONE.source.TI.$trojan_name

## dbg related settings
# NOTE TI_dbg_files is also sourced from scripts/TI_settings.tcl
if { $TI_dbg_files == 0 } {
	# NOTE for non-debug mode, report files are placed directly in the work dir, not in reports/ -- this is on purpose, as we don't want to share related reports/details to participants
	set reports_folder "./"
} else {
	# NOTE for debug, related report files are placed in reports/ and, thus, also uploaded
	set reports_folder "reports/"
}

## (TODO) for manual dbg: restoring session as is
#restoreDesign design.reclaimArea.enc.dat $design_name

#####################
# Trojan insertion
#####################

## (TODO) for manual dbg
set TI_mode_back $TI_mode
set TI_mode "reg"

## ECO design integration of Trojan
ecoDesign design.forTI.$TI_mode.enc.dat $design_name $trojan_netlist -keepInstLoc -noEcoPlace -reportFile $reports_folder/$trojan_name.ecoDesign.$TI_mode.rpt

## (TODO) for manual dbg
set TI_mode $TI_mode_back

## check placement right away, to catch early-on issues like overlaps introduced by ECO design integration
# NOTE we are not using 'place_detail_preroute_as_obs' here yet; that would -- falsely -- also flag many of the instances from the original layout coming from before ecoDesign.
set rpt $reports_folder/$trojan_name.ecoDesign.$TI_mode.checkPlace.rpt
checkPlace
violationBrowserReport -report $rpt 
# extract violating instances using a bash helper script
scripts/TI_helper_checkPlace.sh $rpt
set fp [open $rpt.parsed r]
# NOTE explicitly build up string list, as needed by refinePlace
set refine_list {}
while { [gets $fp line] >= 0 } {
	append refine_list "$line "
}
close $fp
# NOTE deprecated; list handling will quote any instances w/ '[' and ']' in their name using {}, which is not compatible with the string list expected by refinePlace
##set refine_list [split [read $fp] '\n']
## NOTE simpler version for reading files, but also deprecated here
#set refine_list [read $fp]
#close $fp

## placement settings; to be set before refinePlace and any other place command
# consider already routed wires as OBS; required to avoid DRCs around PDN stripes
# NOTE from now on, we must consider this constraint, to not push/move instances into that problematic region
setPlaceMode -place_detail_preroute_as_obs 3
# considers instances added by ECO with higher priority for placement/moving around, but still consider other, previously placed ones as well
setPlaceMode -place_detail_eco_priority_insts eco

## if needed, fix placement for early issues arising from ecoDesign
if { $refine_list != "" } {
	# refine placement, as in only fixing any violations and only operates on PLACED instances
# TODO if this really works only on PLACED instances, it should not be used before ecoPlace --> double check which instances are worked on; also double-check again w/ Mohammad
# about the intentions of that refinePlace
	refineplace -inst $refine_list
}
# NOTE deprecated; list handling will quote any instances w/ '[' and ']' in their name using {}, which is not compatible with the string list expected by refinePlace
## refine initial placement, but only if needed
#if {[llength $refine_list] != 0} {
#
#	# trim last entry which is empty, arising from split '\n'
#	set refine_list [lrange $refine_list 0 end-1]     
#	
#	# refine placement, as in only fixing any violations and only operates on PLACED instances
#	refineplace -inst "$refine_list"
#}

## ECO placement; incrementally place yet unplaced instances (i.e., those added by ECO design integration)
#
# NOTE consider timing for all modes; should help to avoid introducing timing violations and/or fix any violations that might have been introduced by 'reclaimArea' w/o maintaining
# hold option for the 'adv2' TI mode

switch $TI_mode {

	# NOTE recall that this mode started with the db holding the submission design as is
	"reg" {
		ecoPlace -fixPlacedInsts true -timing_driven true
	}

	# NOTE recall that this mode started with the db holding the submission design as optimized by running 'reclaimArea -maintainHold' on it
	"adv" {
		# NOTE given the 'place_detail_eco_priority_insts eco' setting, this should not be too aggressive
		# NOTE if density is > 100% after TI, which may well happen once the 'place_detail_preroute_as_obs' constraint is set, 'ecoPlace -fixPlacedInsts false' will error out --> cover via 'adv2' then
		ecoPlace -fixPlacedInsts false -timing_driven true
	}

	# NOTE recall that this mode started with the db holding the submission design as optimized by running 'reclaimArea' on it
	"adv2" {
		# NOTE 'ecoPlace' has to be run first for initial placement of newly added instances; otherwise, 'place_opt_design' will error out.
		# NOTE we must keep 'fixPlacedInsts true' for now; to avoid possibly erroring out due to too high density
		ecoPlace -fixPlacedInsts true -timing_driven true
		place_opt_design -incremental
	}

#	# NOTE No need for default case; TI_mode is sourced from TI_settings.tcl, which is generated by TI_init.sh, which checks already for that parameter. And even if not, as in
#	# some error from manually rewritting TI_settings.tcl etc., that would have thrown off this script most likely already further up, since other files might be misconfigured
#	# then as well.
#	default {
#		puts "ISPD23 -- ERROR: cannot init Trojan insertion -- for the 2nd parameter, TI_mode, an unknown option is provided. Choose one of the following: \"reg\", \"adv\", or \"adv2\""
#		exit
#	}
}

## ECO routing
#
## NOTE deprecated; while this would help for passing through on some submissions that route in M1, it hinders others --> better to disallow M1 routing in general
#setDesignMode -bottomRoutingLayer 1
#
ecoRoute

#####################
# post-insertion checks
#
# NOTE other checks in checks.tcl are skipped here, since 1) accounting for all them during scoring seems difficult and, more importantly, 2) these checks were meant to catch any
# cheating/trivial defenses, so not really needed here.
#####################

verify_drc -limit 100000 -report $reports_folder/$design_name.geom.$trojan_name.$TI_mode.rpt

# simultaneous setup, hold analysis
# NOTE applicable for (faster) timing analysis, but not for subsequent ECO runs or so -- OK for our scope here, after actual ECO commands
set_global timing_enable_simultaneous_setup_hold_mode true
# NOTE irrespective of dbg mode, this report should always be shared and thus stored into reports/
report_timing_summary > reports/timing.$trojan_name.$TI_mode.rpt

#####################
# write out TI-infected design
#####################

# netlist, DEF
# NOTE These files should always be written out; for dbg and/or later inspection. But, sharing of these files with the results uploads or not is managed by the main daemon,
# considering the same TI_dbg_files (which is simply passed through by TI_wrapper.sh, as sourced from the settings file of the main daemon)
set defOutLefVia 1
set defOutLefNDR 1
defOut -netlist -routing -allLayers design.$trojan_name.$TI_mode.def
saveNetlist design.$trojan_name.$TI_mode.v

## GDS
#set_global timing_enable_simultaneous_setup_hold_mode false
#setStreamOutMode -reset
#streamOut $trojan_name.$TI_mode.gds.gz -mapFile {ASAP7/gds2.map} -stripes 1 -libName DesignLib -uniquifyCellNames -outputMacros -mode ALL -units 4000 -reportFile $reports_folder/$trojan_name.$TI_mode.gds.rpt -merge { ASAP7/asap7sc7p5t_28_L_220121a_scaled4x.gds  ASAP7/asap7sc7p5t_28_SL_220121a_scaled4x.gds }

####
# mark done; exit
####

date > DONE.TI.$trojan_name.$TI_mode
exit
