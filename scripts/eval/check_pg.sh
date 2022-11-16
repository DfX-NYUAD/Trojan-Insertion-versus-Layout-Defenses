#!/bin/bash

## settings
#
# strings
err_prefix="ERROR: For PG check"
# runtime
baseline=$1
# files
rpt_out="pg_metals_eval.rpt"
err_rpt="errors.rpt"
DEF_sub="design.def"
DEF_orig="_design_original.def"
rpt_sub="pg_metals.rpt"
rpt_orig="$baseline/pg_metals.rpt"
# math
scale="6"
threshold="0.1"
coverage_upper_min_value="5.0"

## 1) folder check
if ! [[ -d $baseline ]]; then
	echo "$err_prefix -- baseline folder \"$baseline\" is not a valid folder." | tee -a $err_rpt
	exit
fi
## 1) files check
error=0
if ! [[ -e $rpt_orig ]]; then
	echo "$err_prefix -- report \"$rpt_orig\" is missing." | tee -a $err_rpt
	error=1
fi
if ! [[ -e $rpt_sub ]]; then
	echo "$err_prefix -- report \"$rpt_sub\" is missing." | tee -a $err_rpt
	error=1
fi
if [[ $error == 1 ]]; then
	exit
fi

# cleanup
rm $rpt_out 2> /dev/null

# parse DEF files for dimensions using regex
#
echo "Parse DEF files for dimensions ..."

## DEF example
#DIEAREA ( 0 0 ) ( 134140 128240 ) ;
die_sub_x=$(grep -w 'DIEAREA' $DEF_sub | awk '{print $7}')
die_sub_y=$(grep -w 'DIEAREA' $DEF_sub | awk '{print $8}')
die_orig_x=$(grep -w 'DIEAREA' $DEF_orig | awk '{print $7}')
die_orig_y=$(grep -w 'DIEAREA' $DEF_orig | awk '{print $8}')

## awk for printing leading zero, which is omitted by bc
die_ratio=$(bc -l <<< "scale=$scale; (($die_sub_x * $die_sub_y) / ($die_orig_x * $die_orig_y))" | awk '{printf "%f", $0}')
echo "Ratio area for submission DEF / original DEF: $die_ratio" | tee -a $rpt_out

# parse report for summary of PG metals
#
echo "Parse report for PG metals ..."

## two examples below:
#NET : VDD LAYER : metal1
#WL PAIR : COUNT
#0.24 0.17 : 4 
#0.17 0.58 : 4 
#0.17 0.895 : 34 
#0.17 0.495 : 4 
#0.17 58.71 : 21 
#NET : VDD LAYER : metal2
#WL PAIR : COUNT
#0.17 0.295 : 4 
regex_start="^NET : (\S+) LAYER : (\S+)"
regex_line="([0-9]+[.]*[0-9]+) ([0-9]+[.]*[0-9]+) [:] ([0-9]+)"

## NOTE backslashes in string are properly escaped by readarray
readarray -t lines_sub < $rpt_sub
readarray -t lines_orig < $rpt_orig

### eval submission report

# NOTE here be dragons: any other net names wouldn't work below. Code here as well as in pg_procedures.tcl would ideally be generalized.
declare -A VDD_sub
declare -A VSS_sub

# init for all layers; important to catch cases where sub versus orig have different layer assignments of PG metals
for i in {1..10}; do
	VDD_sub["metal$i"]="0.0"
	VSS_sub["metal$i"]="0.0"
done

# process all lines in rpt
curr_net=""
curr_layer=""
for ((i=0; i<${#lines_sub[@]}; i++)); do

	line=${lines_sub[$i]}

	if [[ "$line" =~ $regex_start ]]; then
#		declare -p BASH_REMATCH

		curr_net=${BASH_REMATCH[1]}
		curr_layer=${BASH_REMATCH[2]}
	fi

	if [[ "$line" =~ $regex_line ]]; then
#		declare -p BASH_REMATCH

		if [[ $curr_net == "VDD" ]]; then

			VDD_sub[$curr_layer]=$(bc -l <<< "scale=$scale; ${VDD_sub[$curr_layer]} + (${BASH_REMATCH[1]} * ${BASH_REMATCH[2]} * ${BASH_REMATCH[3]})" | awk '{printf "%f", $0}')
#			echo ${VDD_sub[$curr_layer]}

		elif [[ $curr_net == "VSS" ]]; then

			VSS_sub[$curr_layer]=$(bc -l <<< "scale=$scale; ${VSS_sub[$curr_layer]} + (${BASH_REMATCH[1]} * ${BASH_REMATCH[2]} * ${BASH_REMATCH[3]})" | awk '{printf "%f", $0}')
#			echo ${VSS_sub[$curr_layer]}
		else
			echo "$err_prefix -- unknown net \"$curr_net\" was found in report \"$rpt_sub\"." | tee -a $err_rpt
			exit
		fi
	fi
done
#declare -p VDD_sub
#declare -p VSS_sub

### eval original report

# NOTE here be dragons: any other net names wouldn't work below. Code here as well as in pg_procedures.tcl would ideally be generalized.
declare -A VDD_orig
declare -A VSS_orig

# init for all layers; important to catch cases where sub versus orig have different layer assignments of PG metals
for i in {1..10}; do
	VDD_orig["metal$i"]="0.0"
	VSS_orig["metal$i"]="0.0"
done

# process all lines in rpt
curr_net=""
curr_layer=""
for ((i=0; i<${#lines_orig[@]}; i++)); do

	line=${lines_orig[$i]}

	if [[ "$line" =~ $regex_start ]]; then
#		declare -p BASH_REMATCH

		curr_net=${BASH_REMATCH[1]}
		curr_layer=${BASH_REMATCH[2]}
	fi

	if [[ "$line" =~ $regex_line ]]; then
#		declare -p BASH_REMATCH

		if [[ $curr_net == "VDD" ]]; then

			VDD_orig[$curr_layer]=$(bc -l <<< "scale=$scale; ${VDD_orig[$curr_layer]} + (${BASH_REMATCH[1]} * ${BASH_REMATCH[2]} * ${BASH_REMATCH[3]})" | awk '{printf "%f", $0}')
#			echo ${VDD_orig[$curr_layer]}

		elif [[ $curr_net == "VSS" ]]; then

			VSS_orig[$curr_layer]=$(bc -l <<< "scale=$scale; ${VSS_orig[$curr_layer]} + (${BASH_REMATCH[1]} * ${BASH_REMATCH[2]} * ${BASH_REMATCH[3]})" | awk '{printf "%f", $0}')
#			echo ${VSS_orig[$curr_layer]}
		else
			echo "$err_prefix -- unknown net \"$curr_net\" was found in report \"$rpt_orig\"." | tee -a $err_rpt
			exit
		fi
	fi
done
#declare -p VDD_orig
#declare -p VSS_orig

# cross-check PG metals
#
echo "Cross-check PG metals ..."

for i in {1..10}; do

	curr_layer="metal$i"

	VDD_coverage_lower=$(bc -l <<< "scale=$scale; ($die_ratio * ${VDD_orig[$curr_layer]}) * (1.0 - $threshold)" | awk '{printf "%f", $0}')
	VDD_coverage_upper=$(bc -l <<< "scale=$scale; ($die_ratio * ${VDD_orig[$curr_layer]}) * (1.0 + $threshold)" | awk '{printf "%f", $0}')

	if (( $(echo "$VDD_coverage_upper == 0.0" | bc -l) )); then
		VDD_coverage_upper=$(bc -l <<< "scale=$scale; $coverage_upper_min_value" | awk '{printf "%f", $0}')
	fi

	echo " Allowed range for area covered by VDD metals in layer \"$curr_layer\": $VDD_coverage_lower--$VDD_coverage_upper" | tee -a $rpt_out

	if (( $(echo "$VDD_coverage_lower <= ${VDD_sub[$curr_layer]}" | bc -l) && $(echo "$VDD_coverage_upper >= ${VDD_sub[$curr_layer]}" | bc -l) )); then
		echo "  PASS" | tee -a $rpt_out
	else
		echo "  FAIL -- actual area covered: ${VDD_sub[$curr_layer]}" | tee -a $rpt_out
	fi

	VSS_coverage_lower=$(bc -l <<< "scale=$scale; ($die_ratio * ${VSS_orig[$curr_layer]}) * (1.0 - $threshold)" | awk '{printf "%f", $0}')
	VSS_coverage_upper=$(bc -l <<< "scale=$scale; ($die_ratio * ${VSS_orig[$curr_layer]}) * (1.0 + $threshold)" | awk '{printf "%f", $0}')

	if (( $(echo "$VSS_coverage_upper == 0.0" | bc -l) )); then
		VSS_coverage_upper=$(bc -l <<< "scale=$scale; $coverage_upper_min_value" | awk '{printf "%f", $0}')
	fi

	echo " Allowed range for area covered by VSS metals in layer \"$curr_layer\": $VSS_coverage_lower--$VSS_coverage_upper" | tee -a $rpt_out

	if (( $(echo "$VSS_coverage_lower <= ${VSS_sub[$curr_layer]}" | bc -l) && $(echo "$VSS_coverage_upper >= ${VSS_sub[$curr_layer]}" | bc -l) )); then
		echo "  PASS" | tee -a $rpt_out
	else
		echo "  FAIL -- actual area covered: ${VSS_sub[$curr_layer]}" | tee -a $rpt_out
	fi
done
