#!/bin/bash

## constant settings; not to be modified
scale=$1
baseline=$2
files="exploit_regions.rpt cells_ea.rpt nets_ea.rpt design_cost.rpt checks_summary.rpt"
rpt=scores.rpt
err_rpt=errors.rpt

## 1) init
rm -f $rpt
error=0

## 1) parameter checks
if [[ $scale == "" ]]; then
	echo "ERROR: cannot compute scores -- 1st parameter, scale, is not provided."
	error=1
fi
## 1) folder check
if ! [[ -d $baseline ]]; then
	echo "ERROR: cannot compute scores -- 2nd parameter, baseline folder \"$baseline\", is not a valid folder."
	error=1
fi
## exit for errors
if [[ $error == 1 ]]; then
	exit
fi

## 1) files check
for file in $files; do

	if ! [[ -e $baseline/$file ]]; then
		echo "ERROR: cannot compute scores -- file \"$baseline/$file\" is missing." | tee -a $err_rpt
		error=1
	fi

	if ! [[ -e $file ]]; then
		echo "ERROR: cannot compute scores -- file \"$file\" is missing." | tee -a $err_rpt
		error=1
	fi
done
## exit for errors
if [[ $error == 1 ]]; then
	exit
fi

## 1) check for any other errors that might have occurred during actual processing
if [[ -e $err_rpt ]]; then
	echo "ERROR: cannot compute scores -- evaluation had some errors" | tee -a $err_rpt
	error=1
fi
## exit for errors
if [[ $error == 1 ]]; then
	exit
fi

## 1) only now, if run calculation can proceed, then init weights
declare -A weights=()
####
#
# Trojan insertion
weights[ti_sts]="0.5"
weights[ti_fts]="0.5"
## placement sites of exploitable regions
weights[ti_sts_total]="0.5"
weights[ti_sts_max]="(1/3)"
weights[ti_sts_avg]="(1/6)"
## routing resources (free tracks) of exploitable regions
weights[ti_fts_total]="0.5"
weights[ti_fts_max]="(1/3)"
weights[ti_fts_avg]="(1/6)"
#
# Frontside probing and fault injection
weights[fsp_fi_ea_c]="0.5"
weights[fsp_fi_ea_n]="0.5"
## exposed area of standard cell assets
weights[fsp_fi_ea_c_total]="0.5"
weights[fsp_fi_ea_c_max]="(1/3)"
weights[fsp_fi_ea_c_avg]="(1/6)"
## exposed area of net assets
weights[fsp_fi_ea_n_total]="0.5"
weights[fsp_fi_ea_n_max]="(1/3)"
weights[fsp_fi_ea_n_avg]="(1/6)"
#
# Design quality
## power
weights[des_p_total]="0.25"
## performance
weights[des_perf]="0.25"
weights[des_perf_setup_TNS]="0.5"
weights[des_perf_setup_WNS]="(1/3)"
weights[des_perf_setup_FEP]="(1/6)"
## area
weights[des_area]="0.25"
## layout checks
weights[des_issues]="0.25"
#
####
echo "Weights:" | tee -a $rpt
for weight in "${!weights[@]}"; do
	value="${weights[$weight]}"
	echo "	$weight:		$value" | tee -a $rpt
done
echo "" | tee -a $rpt

## 1) only now, if run calculation can proceed, then init constraints
declare -A constraints=()
####
# Design quality
## power
constraints[des_p_total]="10"
## performance
constraints[des_perf]="20"
## area
constraints[des_area]="3"
## layout checks
constraints[des_issues]="2"
####
echo "Constraints:" | tee -a $rpt
for constraint in "${!constraints[@]}"; do
	value="${constraints[$constraint]}"
	echo "	$constraint:		$value" | tee -a $rpt
done
echo "" | tee -a $rpt

## 1) also init rounding bit, depending on scale
calc_string_rounding=" + 0."
for (( i=0; i<$scale; i++)); do
	calc_string_rounding+="0"
done
calc_string_rounding+="5"

## 2) parsing
declare -A metrics_baseline=()
declare -A metrics_submission=()
####
#
## placement sites of exploitable regions
  metrics_baseline[ti_sts_total]=$(grep "Total sites across regions:" $baseline/exploit_regions.rpt 2> /dev/null | awk '{print $5}')
  metrics_baseline[ti_sts_max]=$(grep "Max sites across regions:" $baseline/exploit_regions.rpt 2> /dev/null | awk '{print $5}')
  metrics_baseline[ti_sts_avg]=$(grep "Avg sites across regions:" $baseline/exploit_regions.rpt 2> /dev/null | awk '{print $5}')
metrics_submission[ti_sts_total]=$(grep "Total sites across regions:" exploit_regions.rpt 2> /dev/null | awk '{print $5}')
metrics_submission[ti_sts_max]=$(grep "Max sites across regions:" exploit_regions.rpt 2> /dev/null | awk '{print $5}')
metrics_submission[ti_sts_avg]=$(grep "Avg sites across regions:" exploit_regions.rpt 2> /dev/null | awk '{print $5}')
## routing resources (free tracks) of exploitable regions
  metrics_baseline[ti_fts_total]=$(grep "Total free tracks across regions:" $baseline/exploit_regions.rpt 2> /dev/null | awk '{print $6}')
  metrics_baseline[ti_fts_max]=$(grep "Max free tracks across regions:" $baseline/exploit_regions.rpt 2> /dev/null | awk '{print $6}')
  metrics_baseline[ti_fts_avg]=$(grep "Avg free tracks across regions:" $baseline/exploit_regions.rpt 2> /dev/null | awk '{print $6}')
metrics_submission[ti_fts_total]=$(grep "Total free tracks across regions:" exploit_regions.rpt 2> /dev/null | awk '{print $6}')
metrics_submission[ti_fts_max]=$(grep "Max free tracks across regions:" exploit_regions.rpt 2> /dev/null | awk '{print $6}')
metrics_submission[ti_fts_avg]=$(grep "Avg free tracks across regions:" exploit_regions.rpt 2> /dev/null | awk '{print $6}')
## exposed area of standard cell assets
  metrics_baseline[fsp_fi_ea_c_total]=$(grep "Total exposed area across cell assets:" $baseline/cells_ea.rpt 2> /dev/null | awk '{print $7}')
  metrics_baseline[fsp_fi_ea_c_max]=$(grep "Max exposure \[%\] across cell assets:" $baseline/cells_ea.rpt 2> /dev/null | awk '{print $7}')
  metrics_baseline[fsp_fi_ea_c_avg]=$(grep "Avg exposure \[%\] across cell assets:" $baseline/cells_ea.rpt 2> /dev/null | awk '{print $7}')
metrics_submission[fsp_fi_ea_c_total]=$(grep "Total exposed area across cell assets:" cells_ea.rpt 2> /dev/null | awk '{print $7}')
metrics_submission[fsp_fi_ea_c_max]=$(grep "Max exposure \[%\] across cell assets:" cells_ea.rpt 2> /dev/null | awk '{print $7}')
metrics_submission[fsp_fi_ea_c_avg]=$(grep "Avg exposure \[%\] across cell assets:" cells_ea.rpt 2> /dev/null | awk '{print $7}')
## exposed area of net assets
  metrics_baseline[fsp_fi_ea_n_total]=$(grep "Total exposed area across net assets:" $baseline/nets_ea.rpt 2> /dev/null | awk '{print $7}')
  metrics_baseline[fsp_fi_ea_n_max]=$(grep "Max exposure \[%\] across net assets:" $baseline/nets_ea.rpt 2> /dev/null | awk '{print $7}')
  metrics_baseline[fsp_fi_ea_n_avg]=$(grep "Avg exposure \[%\] across net assets:" $baseline/nets_ea.rpt 2> /dev/null | awk '{print $7}')
metrics_submission[fsp_fi_ea_n_total]=$(grep "Total exposed area across net assets:" nets_ea.rpt 2> /dev/null | awk '{print $7}')
metrics_submission[fsp_fi_ea_n_max]=$(grep "Max exposure \[%\] across net assets:" nets_ea.rpt 2> /dev/null | awk '{print $7}')
metrics_submission[fsp_fi_ea_n_avg]=$(grep "Avg exposure \[%\] across net assets:" nets_ea.rpt 2> /dev/null | awk '{print $7}')
## power
  metrics_baseline[des_p_total]=$(grep "Total Power:" $baseline/design_cost.rpt 2> /dev/null | awk '{print $3}')
metrics_submission[des_p_total]=$(grep "Total Power:" design_cost.rpt 2> /dev/null | awk '{print $3}')
## performance
  metrics_baseline[des_perf_setup_TNS]=$(grep "TNS for setup:" $baseline/design_cost.rpt 2> /dev/null | awk '{print $4}')
  metrics_baseline[des_perf_setup_WNS]=$(grep "WNS for setup:" $baseline/design_cost.rpt 2> /dev/null | awk '{print $4}')
  metrics_baseline[des_perf_setup_FEP]=$(grep "Failing endpoints for setup:" $baseline/design_cost.rpt 2> /dev/null | awk '{print $5}')
metrics_submission[des_perf_setup_TNS]=$(grep "TNS for setup:" design_cost.rpt 2> /dev/null | awk '{print $4}')
metrics_submission[des_perf_setup_WNS]=$(grep "WNS for setup:" design_cost.rpt 2> /dev/null | awk '{print $4}')
metrics_submission[des_perf_setup_FEP]=$(grep "Failing endpoints for setup:" design_cost.rpt 2> /dev/null | awk '{print $5}')
## area
  metrics_baseline[des_area]=$(grep "Die area:" $baseline/design_cost.rpt 2> /dev/null | awk '{print $3}')
metrics_submission[des_area]=$(grep "Die area:" design_cost.rpt 2> /dev/null | awk '{print $3}')
## layout checks
calc_string=""
calc_string+="$(grep "Basic routing issues:" $baseline/checks_summary.rpt 2> /dev/null | awk '{print $4}')"
calc_string+=" + $(grep "Module pin issues:" $baseline/checks_summary.rpt 2> /dev/null | awk '{print $4}')"
calc_string+=" + $(grep "Unplaced components issues:" $baseline/checks_summary.rpt 2> /dev/null | awk '{print $4}')"
calc_string+=" + $(grep "Placement and/or routing issues:" $baseline/checks_summary.rpt 2> /dev/null | awk '{print $5}')"
calc_string+=" + $(grep "DRC issues:" $baseline/checks_summary.rpt 2> /dev/null | awk '{print $3}')"
calc_string+=" + $(grep "Unreachable points issues:" $baseline/checks_summary.rpt 2> /dev/null | awk '{print $4}')"
calc_string+=" + $(grep "Undriven pins issues:" $baseline/checks_summary.rpt 2> /dev/null | awk '{print $4}')"
calc_string+=" + $(grep "Open output ports issues:" $baseline/checks_summary.rpt 2> /dev/null | awk '{print $5}')"
calc_string+=" + $(grep "Net output floating issues:" $baseline/checks_summary.rpt 2> /dev/null | awk '{print $5}')"
  metrics_baseline[des_issues]=$(bc -l <<< "$calc_string")
calc_string=""
calc_string+="$(grep "Basic routing issues:" checks_summary.rpt 2> /dev/null | awk '{print $4}')"
calc_string+=" + $(grep "Module pin issues:" checks_summary.rpt 2> /dev/null | awk '{print $4}')"
calc_string+=" + $(grep "Unplaced components issues:" checks_summary.rpt 2> /dev/null | awk '{print $4}')"
calc_string+=" + $(grep "Placement and/or routing issues:" checks_summary.rpt 2> /dev/null | awk '{print $5}')"
calc_string+=" + $(grep "DRC issues:" checks_summary.rpt 2> /dev/null | awk '{print $3}')"
calc_string+=" + $(grep "Unreachable points issues:" checks_summary.rpt 2> /dev/null | awk '{print $4}')"
calc_string+=" + $(grep "Undriven pins issues:" checks_summary.rpt 2> /dev/null | awk '{print $4}')"
calc_string+=" + $(grep "Open output ports issues:" checks_summary.rpt 2> /dev/null | awk '{print $5}')"
calc_string+=" + $(grep "Net output floating issues:" checks_summary.rpt 2> /dev/null | awk '{print $5}')"
metrics_submission[des_issues]=$(bc -l <<< "$calc_string")
#
####
echo "Baseline metrics:" | tee -a $rpt
for metric in "${!metrics_baseline[@]}"; do
	value="${metrics_baseline[$metric]}"
	echo "	$metric:		$value" | tee -a $rpt
done
echo "" | tee -a $rpt
echo "Submission metrics:" | tee -a $rpt
for metric in "${!metrics_submission[@]}"; do
	value="${metrics_submission[$metric]}"
	echo "	$metric:		$value" | tee -a $rpt
done
echo "" | tee -a $rpt

declare -A base_scores=()
####
#
## placement sites of exploitable regions
base_scores[ti_sts_total]=$(bc -l <<< "scale=$scale; (${metrics_submission[ti_sts_total]} / ${metrics_baseline[ti_sts_total]})")
base_scores[ti_sts_max]=$(bc -l <<< "scale=$scale; (${metrics_submission[ti_sts_max]} / ${metrics_baseline[ti_sts_max]})")
base_scores[ti_sts_avg]=$(bc -l <<< "scale=$scale; (${metrics_submission[ti_sts_avg]} / ${metrics_baseline[ti_sts_avg]})")
## routing resources (free tracks) of exploitable regions
base_scores[ti_fts_total]=$(bc -l <<< "scale=$scale; (${metrics_submission[ti_fts_total]} / ${metrics_baseline[ti_fts_total]})")
base_scores[ti_fts_max]=$(bc -l <<< "scale=$scale; (${metrics_submission[ti_fts_max]} / ${metrics_baseline[ti_fts_max]})")
base_scores[ti_fts_avg]=$(bc -l <<< "scale=$scale; (${metrics_submission[ti_fts_avg]} / ${metrics_baseline[ti_fts_avg]})")
## exposed area of standard cell assets
base_scores[fsp_fi_ea_c_total]=$(bc -l <<< "scale=$scale; (${metrics_submission[fsp_fi_ea_c_total]} / ${metrics_baseline[fsp_fi_ea_c_total]})")
base_scores[fsp_fi_ea_c_max]=$(bc -l <<< "scale=$scale; (${metrics_submission[fsp_fi_ea_c_max]} / ${metrics_baseline[fsp_fi_ea_c_max]})")
base_scores[fsp_fi_ea_c_avg]=$(bc -l <<< "scale=$scale; (${metrics_submission[fsp_fi_ea_c_avg]} / ${metrics_baseline[fsp_fi_ea_c_avg]})")
## exposed area of net assets
base_scores[fsp_fi_ea_n_total]=$(bc -l <<< "scale=$scale; (${metrics_submission[fsp_fi_ea_n_total]} / ${metrics_baseline[fsp_fi_ea_n_total]})")
base_scores[fsp_fi_ea_n_max]=$(bc -l <<< "scale=$scale; (${metrics_submission[fsp_fi_ea_n_max]} / ${metrics_baseline[fsp_fi_ea_n_max]})")
base_scores[fsp_fi_ea_n_avg]=$(bc -l <<< "scale=$scale; (${metrics_submission[fsp_fi_ea_n_avg]} / ${metrics_baseline[fsp_fi_ea_n_avg]})")
## power
base_scores[des_p_total]=$(bc -l <<< "scale=$scale; (${metrics_submission[des_p_total]} / ${metrics_baseline[des_p_total]})")
## area
base_scores[des_area]=$(bc -l <<< "scale=$scale; (${metrics_submission[des_area]} / ${metrics_baseline[des_area]})")
## performance
#
# TNS
if (( $(echo "${metrics_baseline[des_perf_setup_TNS]} < 0" | bc -l) && $(echo "${metrics_submission[des_perf_setup_TNS]} < 0" | bc -l) )); then

	base_scores[des_perf_setup_TNS]=$(bc -l <<< "scale=$scale; (${metrics_submission[des_perf_setup_TNS]} / ${metrics_baseline[des_perf_setup_TNS]})")

elif (( $(echo "${metrics_baseline[des_perf_setup_TNS]} >= 0" | bc -l) && $(echo "${metrics_submission[des_perf_setup_TNS]} < 0" | bc -l) )); then

	base_scores[des_perf_setup_TNS]="-(${metrics_submission[des_perf_setup_TNS]})"

# else, i.e., metrics_submission[des_perf_setup_TNS] >= 0
else
	base_scores[des_perf_setup_TNS]=0
fi
#
# WNS
if (( $(echo "${metrics_baseline[des_perf_setup_WNS]} < 0" | bc -l) && $(echo "${metrics_submission[des_perf_setup_WNS]} < 0" | bc -l) )); then

	base_scores[des_perf_setup_WNS]=$(bc -l <<< "scale=$scale; (${metrics_submission[des_perf_setup_WNS]} / ${metrics_baseline[des_perf_setup_WNS]})")

elif (( $(echo "${metrics_baseline[des_perf_setup_WNS]} >= 0" | bc -l) && $(echo "${metrics_submission[des_perf_setup_WNS]} < 0" | bc -l) )); then

	base_scores[des_perf_setup_WNS]="-(${metrics_submission[des_perf_setup_WNS]})"

# else, i.e., metrics_submission[des_perf_setup_WNS] >= 0
else
	base_scores[des_perf_setup_WNS]=0
fi
#
# FEP
if [[ ${metrics_baseline[des_perf_setup_FEP]} == 0 ]]; then

	base_scores[des_perf_setup_FEP]=${metrics_submission[des_perf_setup_FEP]}

# else we can divide, normalize over baseline
else
	base_scores[des_perf_setup_FEP]=$(bc -l <<< "scale=$scale; (${metrics_submission[des_perf_setup_FEP]} / ${metrics_baseline[des_perf_setup_FEP]})")
fi
#
## layout checks
if [[ ${metrics_baseline[des_issues]} == 0 ]]; then

	base_scores[des_issues]=${metrics_submission[des_issues]}

# else we can divide, normalize over baseline
else
	base_scores[des_issues]=$(bc -l <<< "scale=$scale; (${metrics_submission[des_issues]} / ${metrics_baseline[des_issues]})")
fi
#
####
echo "Base scores (non-weighted):" | tee -a $rpt
for metric in "${!base_scores[@]}"; do
	value="${base_scores[$metric]}"
	echo "	$metric:		$value" | tee -a $rpt
done
echo "" | tee -a $rpt

declare -A scores
####
#
# Trojan insertion
## placement sites of exploitable regions
calc_string="${weights[ti_sts_total]}*${base_scores[ti_sts_total]}"
calc_string+=" + ${weights[ti_sts_max]}*${base_scores[ti_sts_max]}"
calc_string+=" + ${weights[ti_sts_avg]}*${base_scores[ti_sts_avg]}"
# NOTE add rounding for each calculation step
calc_string+=$calc_string_rounding
scores[ti_sts]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "ti_sts: $calc_string"
## routing resources (free tracks) of exploitable regions
calc_string="${weights[ti_fts_total]}*${base_scores[ti_fts_total]}"
calc_string+=" + ${weights[ti_fts_max]}*${base_scores[ti_fts_max]}"
calc_string+=" + ${weights[ti_fts_avg]}*${base_scores[ti_fts_avg]}"
calc_string+=$calc_string_rounding
scores[ti_fts]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "ti_fts: $calc_string"
## Trojan insertion, combined
calc_string="${weights[ti_sts]}*${scores[ti_sts]}"
calc_string+=" + ${weights[ti_fts]}*${scores[ti_fts]}"
calc_string+=$calc_string_rounding
scores[ti]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "ti: $calc_string"
#
# Frontside probing and fault injection
## exposed area of standard cell assets
calc_string="${weights[fsp_fi_ea_c_total]}*${base_scores[fsp_fi_ea_c_total]}"
calc_string+=" + ${weights[fsp_fi_ea_c_max]}*${base_scores[fsp_fi_ea_c_max]}"
calc_string+=" + ${weights[fsp_fi_ea_c_avg]}*${base_scores[fsp_fi_ea_c_avg]}"
calc_string+=$calc_string_rounding
scores[fsp_fi_ea_c]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "fsp_fi_ea_c: $calc_string"
## exposed area of net assets
calc_string="${weights[fsp_fi_ea_n_total]}*${base_scores[fsp_fi_ea_n_total]}"
calc_string+=" + ${weights[fsp_fi_ea_n_max]}*${base_scores[fsp_fi_ea_n_max]}"
calc_string+=" + ${weights[fsp_fi_ea_n_avg]}*${base_scores[fsp_fi_ea_n_avg]}"
calc_string+=$calc_string_rounding
scores[fsp_fi_ea_n]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "fsp_fi_ea_n: $calc_string"
# Frontside probing and fault injection, combined
calc_string="${weights[fsp_fi_ea_c]}*${scores[fsp_fi_ea_c]}"
calc_string+=" + ${weights[fsp_fi_ea_n]}*${scores[fsp_fi_ea_n]}"
calc_string+=$calc_string_rounding
scores[fsp_fi]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "fsp_fi: $calc_string"
#
# Design quality
## power
# NOTE no score components; will be put directly into combined score
scores[des_p_total]=${base_scores[des_p_total]}
#echo "des_p_total: $calc_string"
## performance
calc_string="${weights[des_perf_setup_TNS]}*${base_scores[des_perf_setup_TNS]}"
calc_string+=" + ${weights[des_perf_setup_WNS]}*${base_scores[des_perf_setup_WNS]}"
calc_string+=" + ${weights[des_perf_setup_FEP]}*${base_scores[des_perf_setup_FEP]}"
calc_string+=$calc_string_rounding
scores[des_perf]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "des_perf: $calc_string"
## area
# NOTE no score components; will be put directly into combined score
scores[des_area]=${base_scores[des_area]}
#echo "des_area: $calc_string"
## layout checks
# NOTE no score components; will be put directly into combined score
scores[des_issues]=${base_scores[des_issues]}
#echo "des_issues: $calc_string"
# Design quality, combined
calc_string="${weights[des_p_total]}*${scores[des_p_total]}"
calc_string+=" + ${weights[des_perf]}*${scores[des_perf]}"
calc_string+=" + ${weights[des_area]}*${scores[des_area]}"
calc_string+=" + ${weights[des_issues]}*${scores[des_issues]}"
calc_string+=$calc_string_rounding
scores[des]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "des: $calc_string"
#
# Overall score
scores[OVERALL]=$(bc -l <<< "scale=$scale; ( 0.5*(${scores[ti]}+${scores[fsp_fi]}) * ${scores[des]} )")

####
# print scores; perform sanity checks
error=0
echo "Scores (weighted):" | tee -a $rpt
for score in "${!scores[@]}"; do

	if [[ "${scores[$score]}" == "" ]]; then
		echo "ERROR: computation for score component \"$score\" failed" | tee -a $err_rpt $rpt
		error=1
	fi

	# cut digits going beyond scale, which result from rounding calculation above
	value=$(echo ${scores[$score]} | awk '{printf "%.'$scale'f", $1}')
	echo "	$score:		$value" | tee -a $rpt
done
echo "" | tee -a $rpt

# eval sanity checks; move report such that it's not accounted for during ranking
if [[ $error == 1 ]]; then
	mv $rpt "failed_calc."$rpt
fi

####
# perform constraints checks
error=0
echo "Constraints checks:" | tee -a $rpt
for constraint in "${!constraints[@]}"; do

	constraint_value=${constraints[$constraint]}

	if (( $(echo "${scores[$constraint]} <= $constraint_value" | bc -l) )); then
		echo "Check for score component \"$constraint\" passed." | tee -a $rpt
	else
		echo "ERROR: Check for score component \"$constraint\" failed." | tee -a $err_rpt $rpt
		error=1
	fi
done
echo "" | tee -a $rpt

# eval constraints checks; move report such that it's not accounted for during ranking
if [[ $error == 1 ]]; then
	mv $rpt "failed_constraint."$rpt
fi
