#!/bin/bash

####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD, in collaboration with Mohammad Eslami and Samuel Pagliarini, TalTech
#
####

out="scripts/TI_settings.tcl"
err_rpt="reports/errors.rpt"

trojan_name=$1

## sanity checks: all parameters provided?
if [[ $trojan_name == "" ]]; then
	echo "ISPD23 -- ERROR: cannot init Trojan insertion -- 1st parameter, trojan_name, is not provided. Examples: camellia_burn_8_32, camellia_fault_16_5, camellia_leak_16_5; note that this parameter is to be provided w/ design prefix." | tee -a $err_rpt
	exit 1
fi

trojan_netlist="TI/"$trojan_name".v"

## sanity checks: all files present?
if ! [[ -e design.enc ]]; then
	echo "ISPD23 -- ERROR: cannot init insertion for Trojan \"$trojan_name\" -- database description file \"design.enc\" is missing in working directory." | tee -a $err_rpt
	error=1
fi
if ! [[ -d design.enc.dat ]]; then
	echo "ISPD23 -- ERROR: cannot init insertion for Trojan \"$trojan_name\" -- database folder \"design.enc.dat\" is missing in working directory." | tee -a $err_rpt
	error=1
fi
if ! [[ -e $trojan_netlist ]]; then
	echo "ISPD23 -- ERROR: cannot init insertion for Trojan \"$trojan_name\" -- Trojan netlist \"$trojan_netlist\" is missing." | tee -a $err_rpt
	error=1
fi
if [[ $error == 1 ]]; then
	exit 1
fi

## backup/move existing TI_settings.tcl file, if any; keep for reference later on for the various Trojans inserted
files=$(ls -t $out* 2> /dev/null | head -n 2 | tail -n 1)
files=${files##*tcl}
files=$((files + 1))
mv $out $out$files 2> /dev/null

## general: extract design name -- which is different from benchmark name
design_name=$(cat design.enc | grep "restoreDesign" | awk '{print $NF}')
if [[ "$design_name" == "" ]]; then
	echo "ISPD23 -- ERROR: cannot init insertion for Trojan \"$trojan_name\" -- failed to retrieve design name from database description file \"design.enc\"." | tee -a $err_rpt
	exit 1
fi

### specific settings, in LUT-style
## TODO clk divider stuff: clk name, instance name for generate_clock command, etc
## TODO inner case statements for leak, burn, fault as needed
## TODO merge cases as useful, using eg aes|camellia)
##
#case $design_name in
#
#	aes_128)
#	;;
#
#	Camellia)
#	;;
#
#	CAST128)
#	;;
#
#	# misty
#	top)
#	;;
#
#	SEED)
#	;;
#
#	sha256)
#	;;
#
#	*)
#	echo "ISPD23 -- ERROR: cannot init insertion for Trojan \"$trojan_name\" -- Unknown/unsupported design name \"$design_name\"." | tee -a $err_rpt
#	;;
#esac

## write out settings file
echo "set design_name \"$design_name\"" > $out
echo "set trojan_name \"$trojan_name\"" >> $out
echo "set trojan_netlist \"$trojan_netlist\"" >> $out
