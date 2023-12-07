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
#
source scripts/TI_settings.tcl
# NOTE mark once the config file is sourced; this signals to TI_wrapper.sh that the config file can be overwritten for the next Trojan
date > DONE.source.TI.$trojan_name.$TI_mode
# NOTE with extended parallel processing of multiple TI modes, we need another layer here to avoid over-writing the config file;
# release the semaphore which is locked by TI_init.sh
rm -f scripts/TI_settings.tcl.semaphore.$trojan_name.$TI_mode

## source other settings
#
source design_name.tcl
source benchmark_name.tcl

## dbg related settings
# NOTE TI_dbg_files is also sourced from scripts/TI_settings.tcl
#
if { $TI_dbg_files == 0 } {
	# NOTE for non-debug mode, report files are placed directly in the work dir, not in reports/ -- this is on purpose, as we don't want to share related reports/details to participants
	set reports_folder "."
} else {
	# NOTE for debug, related report files are placed in reports/ and, thus, also uploaded
	set reports_folder "reports"
}

## (TODO) for manual dbg: restoring session as is
#restoreDesign design.reclaimArea.enc.dat $design_name

#####################
# Trojan insertion
#####################

### (TODO) for manual dbg; goes together with the command just below ecoDesign
#set TI_mode_back $TI_mode
#set TI_mode SET_VIA_TI_HELPER_DBG

## ECO design integration of Trojan
#
# NOTE both 'design_enc_dat' and 'netlist_w_trojan_inserted' already account for/contain 'TI_mode'
ecoDesign $design_enc_dat $design_name $netlist_w_trojan_inserted -keepInstLoc -noEcoPlace -reportFile $reports_folder/$trojan_name.$TI_mode.ecoDesign.rpt

### (TODO) for manual dbg; goes together with the command just above ecoDesign
#set TI_mode $TI_mode_back

## check placement right away, to early-on catch issues like overlaps introduced by ECO design integration, which could become difficult for ecoPlace to fix
# NOTE we are not using 'place_detail_preroute_as_obs' here yet; that would -- falsely -- also flag many of the instances from the original layout (i.e., from the db itself).
#
set rpt $reports_folder/$trojan_name.$TI_mode.ecoDesign.checkPlace.rpt
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

## placement settings; to be set before refinePlace and any other place command
#
# NOTE for the post_contest runs on the same invs version, this setting is not required (and rather even counterproductive on average)
#	# (TODO) for manual dbg, keep or comment out
#	# consider already routed wires as OBS; required to avoid DRCs around PDN stripes
#	# NOTE from now on, we must consider this constraint, to not push/move instances into those stripes regions
#	setPlaceMode -place_detail_preroute_as_obs 3
#
# considers instances added by ECO with higher priority for placement, but still consider others, previously placed ones as well
# NOTE this is actually not relevant for refinePlace, but can already be set here w/o negative side-effects, I think
setPlaceMode -place_detail_eco_priority_insts eco

## if needed, fix placement for early issues arising from ecoDesign
#
if { $refine_list != "" } {

	# NOTE only operates on PLACED instances; only fixes violations, not any other optimization used
	#
	# NOTE by providing only a specific list of instances, namely those having violations other than running into the 'place_detail_preroute_as_obs' OBS (and the vertical-pin
	# track alignment ones filtered out by TI_helper_checkPlace.sh), this is still fine do here -- it basically moves away already placed instances, also honoring the
	# 'place_detail_preroute_as_obs' constraints, to make some room as needed for legalization of the new instances.
	#
	refineplace -inst $refine_list
}

## time the design before timing-driven placement
# NOTE we have to manually time the design here; 'ecoPlace -timing_driven true' won't handle that automatically
# NOTE settings had been set previously, in PPA.tcl, so should be already in db, but just set them again to be sure
#
# OCV
setAnalysisMode -analysisType onChipVariation
# removes clock pessimism
setAnalysisMode -cppr both
# actual timing command
timeDesign -postroute -outDir timingReports.$trojan_name.$TI_mode.preInsertion
# NOTE did not make a difference in the results for trial runs (as in compared when running only for setup view), but should still be done
timeDesign -postroute -hold -outDir timingReports.$trojan_name.$TI_mode.preInsertion

## Control iterations for detailed routing, for both cases: 1) too many violations for large designs, where it's taking too long to fix all,
## 2) give more trials for small designs  where NanoRoute might otherwise give up too soon.
if { $benchmark_name == "aes" } {
	setNanoRouteMode -drouteEndIteration 20
} else {
	setNanoRouteMode -drouteEndIteration 40
}

## ECO placement; incrementally place yet unplaced instances (i.e., those added by ECO design integration) along with revising others as needed
# NOTE consider timing; should help to avoid introducing timing violations and/or fix any violations that might have been introduced by reclaimArea

# NOTE TI modes are listed from 1--12, with first 4 relating to reg db, etc; within these batches of 4, we use different ECO commands as below; for that, we use simple modulo
# indexing into the full range of 1--12
set TI_mode_ECO [expr $TI_mode % 4]

switch $TI_mode_ECO {

	"1" {
		ecoPlace -fixPlacedInsts true -timing_driven true
	}

	"2" {
		ecoPlace -fixPlacedInsts false -timing_driven true
	}

	"3" {
# NOTE this line is the only difference in modes 3 and 4
		ecoPlace -fixPlacedInsts true -timing_driven true
		ecoRoute
#
		setOptMode -verbose true
		setOptMode -maxDensity 100
		setOptMode -simplifyNetlist false
#
		optDesign -postRoute -setup -hold
	}

	"0" {
# NOTE this line is the only difference in modes 3 and 4
		ecoPlace -fixPlacedInsts false -timing_driven true
#
		ecoRoute
#
		setOptMode -verbose true
		setOptMode -maxDensity 100
		setOptMode -simplifyNetlist false
#
		optDesign -postRoute -setup -hold
	}

	default {
		puts "ISPD23 -- ERROR: cannot init Trojan insertion -- for the 2nd parameter, TI_mode, an unknown option is provided."
		exit
	}
}

## final ECO routing
#
ecoRoute

#####################
# post-insertion checks
#
# NOTE other checks in checks.tcl are skipped here, since 1) accounting for all them during scoring seems difficult and, more importantly, 2) these checks were meant to catch any
# cheating/trivial defenses, so not really needed here.
#####################

## DRC checks
#
set_verify_drc_mode -limit 100000
verify_drc -layer_range {2 10} -report $reports_folder/$design_name.$trojan_name.$TI_mode.geom.layers_2_to_10__all.rpt
# NOTE exclude MAR on M1 as there can be false positives
set_verify_drc_mode -disable_rules min_area
verify_drc -layer_range {1} -report $reports_folder/$design_name.$trojan_name.$TI_mode.geom.layer_1__excl_MAR.rpt

## timing
#
# simultaneous setup, hold analysis
# NOTE applicable for (faster) timing analysis, but not for subsequent ECO runs or so -- OK for our scope here, after actual ECO commands
# NOTE also triggers RC re-extraction, as needed after ECO place and route
set_global timing_enable_simultaneous_setup_hold_mode true
# actual timing command
timeDesign -postroute -outDir timingReports.$trojan_name.$TI_mode.postInsertion
# NOTE irrespective of dbg mode, this report should always be shared and thus stored into reports/
report_timing_summary > reports/timing.$trojan_name.$TI_mode.rpt

#####################
# write out TI-infected design
#####################

## netlist, DEF
# NOTE These files should always be written out; for dbg and/or later inspection. But, sharing of these files with the results uploads or not is managed by the main daemon,
# considering the same TI_dbg_files (which is simply passed through by TI_wrapper.sh, as sourced from the settings file of the main daemon)
#
set defOutLefVia 1
set defOutLefNDR 1
defOut -netlist -routing -allLayers design.$trojan_name.$TI_mode.final.def
# NOTE this differs from the netlist w/ Trojan logic integrated but before the ECO flow, which is "$netlist_w_trojan_inserted" or "design.$trojan_name.$TI_mode.v"
saveNetlist design.$trojan_name.$TI_mode.final.v

# NOTE for post_contest runs, we don't really need the GDS files
#
### GDS
##
#set_global timing_enable_simultaneous_setup_hold_mode false
#setStreamOutMode -reset
#streamOut design.$trojan_name.$TI_mode.gds.gz -mapFile {ASAP7/gds2.map} -stripes 1 -libName DesignLib -uniquifyCellNames -outputMacros -mode ALL -units 4000 -reportFile $reports_folder/design.$trojan_name.$TI_mode.gds.rpt -merge { ASAP7/asap7sc7p5t_28_L_220121a_scaled4x.gds  ASAP7/asap7sc7p5t_28_SL_220121a_scaled4x.gds }

####
# mark done; exit
####

date > DONE.TI.$trojan_name.$TI_mode
exit
