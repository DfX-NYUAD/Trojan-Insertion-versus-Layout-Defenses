#!/bin/bash

####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD, in collaboration with Mohammad Eslami and Samuel Pagliarini, TalTech
#
# Script to write out the TI_settings.tcl config file for different Trojans. Includes various sanity checks.
#
####

out="scripts/TI_settings.tcl"
err_rpt="reports/errors.rpt"
warn_rpt="reports/warnings.rpt"

trojan_name=$1
TI_mode=$2
dbg_files=$3

## sanity checks on parameters
#
# NOTE Importantly, this, and most other issues below, are to be handled as errors for the logs/reports, not only as warnings. This is to flag scores as invalid; any initialization
# issue means the score evaluation was done not properly and should be fixed.
if [[ "$trojan_name" == "" ]]; then

	echo "ISPD23 -- ERROR: cannot init Trojan insertion -- the 1st parameter, trojan_name, is not provided. Example: camellia_burn_8_32_random ; note that this parameter is to be provided w/ design prefix." | tee -a $err_rpt
	error=1
fi
if [[ "$TI_mode" != "reg" && "$TI_mode" != "adv" && "$TI_mode" != "adv2" ]]; then

	echo "ISPD23 -- ERROR: cannot init Trojan insertion -- for the 2nd parameter, TI_mode, an unknown option is provided. Choose one of the following: \"reg\", \"adv\", or \"adv2\"" | tee -a $err_rpt
	error=1
fi
if [[ $dbg_files != "0" && $dbg_files != "1" ]]; then

	dbg_files=0
	# NOTE handling as warning is fine; we just assume the safe default of dbg_files off
	echo "ISPD23 -- WARNING: For init Trojan insertion -- for the 3rd parameter, dbg_files, an unknown option other than '0' and '1' is provided. Setting to dbg_files=\'$dbg_files\' instead by default." | tee -a $warn_rpt
fi
if [[ $error == 1 ]]; then
	exit 1
fi

## init runtime settings based on parameters
#
benchmark=${trojan_name%%_*}
design_v="design."$TI_mode".v"
design_enc="design."$TI_mode".enc"
design_enc_dat="design."$TI_mode".enc.dat"
netlist_for_trojan_insertion=$design_v
netlist_w_trojan_inserted="design."$trojan_name"."$TI_mode".v"

design_name=$(cat $design_enc | grep "restoreDesign" | awk '{print $NF}')

## sanity checks on files
#
if ! [[ -e $design_v ]]; then

	echo "ISPD23 -- ERROR: cannot init insertion for Trojan \"$trojan_name\" -- baseline netlist \"$design_v\" is missing in working directory." | tee -a $err_rpt
	error=1
fi
if ! [[ -e $design_enc ]]; then

	echo "ISPD23 -- ERROR: cannot init insertion for Trojan \"$trojan_name\" -- database description file \"$design_enc\" is missing in working directory." | tee -a $err_rpt
	error=1
fi
# NOTE we do not (and practically also cannot at this point) check the db folder in full for correctness or consistency; just sanity check whether folder exists at all
if ! [[ -d $design_enc_dat ]]; then

	echo "ISPD23 -- ERROR: cannot init insertion for Trojan \"$trojan_name\" -- database folder \"$design_enc_dat\" is missing in working directory." | tee -a $err_rpt
	error=1
fi

## other sanity checks
#
if [[ "$design_name" == "" ]]; then

	echo "ISPD23 -- ERROR: cannot init insertion for Trojan \"$trojan_name\" -- failed to retrieve design name from database description file \"$design_enc\"." | tee -a $err_rpt
	error=1
fi
case $benchmark in
	aes|camellia|cast|misty|seed|sha256)
	;;
	*)
		echo "ISPD23 -- ERROR: cannot init insertion for Trojan \"$trojan_name\" -- Unknown/unsupported benchmark \"$benchmark\"." | tee -a $err_rpt
		error=1
	;;
esac

## exit for any errors
#
if [[ $error == 1 ]]; then
	exit 1
fi

### (TODO) design-specific settings, as needed, in LUT-style
## NOTE multi-cycle path constraints: clk name, instance name for generate_clock command, etc
## NOTE merge cases as useful, using this syntax: aes|camellia)
## NOTE introduce (and merge as appropriate) inner case statements for leak, burn, fault types of Trojans
##
#case $benchmark in
#
#	aes)
#	;;
#
#	camellia)
#	;;
#
#	cast)
#	;;
#
#	misty)
#	;;
#
#	seed)
#	;;
#
#	sha256)
#	;;
#
#	*)
#	echo "ISPD23 -- ERROR: cannot init insertion for Trojan \"$trojan_name\" -- Unknown/unsupported benchmark name \"$benchmark_name\"." | tee -a $err_rpt
#	;;
#esac

## backup/move existing TI_settings.tcl file, if any; keep for reference later on for the various Trojans inserted
#
files=$(ls -t $out* 2> /dev/null | head -n 2 | tail -n 1)
files=${files##*tcl}
files=$((files + 1))
mv $out $out$files 2> /dev/null

## write out settings file
#
echo "set benchmark \"$benchmark\"" > $out
echo "set design_name \"$design_name\"" > $out
echo "set design_enc_dat \"$design_enc_dat\"" > $out
echo "set trojan_name \"$trojan_name\"" >> $out
echo "set netlist_for_trojan_insertion \"$netlist_for_trojan_insertion\"" >> $out
echo "set netlist_w_trojan_inserted \"$netlist_w_trojan_inserted\"" >> $out
echo "set TI_mode \"$TI_mode\"" >> $out
echo "set TI_dbg_files \"$dbg_files\"" >> $out

## insert Trojan into netlist
#
tclsh scripts/TI_init_netlist.tcl

## sanity check on the above
## NOTE only checks for file written or not; does not account for any errors in syntax, functionality of the netlist; this would be captured/covered by 'ecoDesign' later on
if ! [[ -e $netlist_w_trojan_inserted ]]; then

	echo "ISPD23 -- ERROR: cannot init insertion for Trojan \"$trojan_name\" -- Trojan netlist \"$netlist_w_trojan_inserted\" is missing." | tee -a $err_rpt
	exit 1
fi
