#!/bin/bash

####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD
#
####

## fixed settings; typically not to be modified
#
# NOTE: default values in evaluation backbone: scale=6; baseline=_$round/$benchmark
scale=$1
baseline=$2
files="reports/exploitable_regions.rpt reports/track_utilization.rpt reports/area.rpt reports/power.rpt reports/timing.rpt"
rpt=reports/scores.rpt
rpt_summ=reports/scores.rpt.summary
err_rpt=reports/errors.rpt

## 1) init
rm $rpt 2> /dev/null
error=0

## 1) check for any other errors that might have occurred during actual processing
if [[ -e $err_rpt ]]; then
	echo "ISPD23 -- ERROR: cannot compute scores -- some evaluation step had some errors." | tee -a $err_rpt
	error=1
fi

## 1) parameter checks
if [[ $scale == "" ]]; then
	echo "ISPD23 -- ERROR: cannot compute scores -- 1st parameter, scale, is not provided." | tee -a $err_rpt
	error=1
fi

## 1) folder check
if ! [[ -d $baseline ]]; then
	echo "ISPD23 -- ERROR: cannot compute scores -- 2nd parameter, baseline folder \"$baseline\", is not a valid folder." | tee -a $err_rpt
	error=1
fi

## 1) exit for errors
if [[ $error == 1 ]]; then
	exit 1
fi

## 1) files check
for file in $files; do

	if ! [[ -e $baseline/$file ]]; then
		echo "ISPD23 -- ERROR: cannot compute scores -- file \"$baseline/$file\" is missing." | tee -a $err_rpt
		error=1
	fi

	if ! [[ -e $file ]]; then
		echo "ISPD23 -- ERROR: cannot compute scores -- file \"$file\" is missing." | tee -a $err_rpt
		error=1
	fi
done

## 1) exit for errors
if [[ $error == 1 ]]; then
	exit 1
fi

## 1) only now, if run calculation can proceed, we start with init procedures

### helper for log formating

score_components="sec sec_ti sec_ti_sts sec_ti_sts_sum sec_ti_sts_max sec_ti_sts_med sec_ti_fts sec_ti_fts_sum des des_pwr des_pwr_tot des_prf des_prf_WNS_set des_prf_WNS_hld des_area des_area_die OVERALL"
cmp_max_length="0"

for cmp in $score_components; do

	if [[ ${#cmp} -gt $cmp_max_length ]]; then
		cmp_max_length=${#cmp}
	fi
done

### weights

declare -A weights=()

### security
#
weights[sec]="0.5"
#
## Trojan insertion
weights[sec_ti]="1.0"
# placement sites of exploitable regions
weights[sec_ti_sts]="0.5"
weights[sec_ti_sts_sum]="0.5"
weights[sec_ti_sts_max]="(1/3)"
weights[sec_ti_sts_med]="(1/6)"
# routing resources (free tracks) of whole layout
weights[sec_ti_fts]="0.5"
weights[sec_ti_fts_sum]="1.0"

### Design quality
#
weights[des]="0.5"
#
## power
weights[des_pwr]="(1/3)"
weights[des_pwr_tot]="1.0"
## performance
weights[des_prf]="(1/3)"
weights[des_prf_WNS_set]="0.5"
weights[des_prf_WNS_hld]="0.5"
## area
weights[des_area]="(1/3)"
weights[des_area_die]="1.0"

echo "Metrics' weights:" | tee -a $rpt
for weight in "${!weights[@]}"; do
	value="${weights[$weight]}"
	weight_=$(printf "%-"$cmp_max_length"s" $weight)
	echo "	$weight_ : $value" | tee -a $rpt
done
echo "" | tee -a $rpt

## init rounding, depending on scale

calc_string_rounding=" + 0."
for (( i=0; i<$scale; i++)); do
	calc_string_rounding+="0"
done
calc_string_rounding+="5"

## 2) parsing

declare -A metrics_baseline=()
declare -A metrics_submission=()

## placement sites of exploitable regions
# NOTE drop the thousands separator ',' as that's not supported by bc
  metrics_baseline[sec_ti_sts_sum]=$(grep "Sum of sites across all regions:" $baseline/reports/exploitable_regions.rpt | awk '{print $NF}' | sed 's/,//g')
  metrics_baseline[sec_ti_sts_max]=$(grep "Max of sites across all regions:" $baseline/reports/exploitable_regions.rpt | awk '{print $NF}' | sed 's/,//g')
  metrics_baseline[sec_ti_sts_med]=$(grep "Median of sites across all regions:" $baseline/reports/exploitable_regions.rpt | awk '{print $NF}' | sed 's/,//g')
metrics_submission[sec_ti_sts_sum]=$(grep "Sum of sites across all regions:" reports/exploitable_regions.rpt | awk '{print $NF}' | sed 's/,//g')
metrics_submission[sec_ti_sts_max]=$(grep "Max of sites across all regions:" reports/exploitable_regions.rpt | awk '{print $NF}' | sed 's/,//g')
metrics_submission[sec_ti_sts_med]=$(grep "Median of sites across all regions:" reports/exploitable_regions.rpt | awk '{print $NF}' | sed 's/,//g')
## routing resources (free tracks) of whole layout
  metrics_baseline[sec_ti_fts_sum]=$(grep "TOTAL" $baseline/reports/track_utilization.rpt | awk '{print $(NF-1)}')
metrics_submission[sec_ti_fts_sum]=$(grep "TOTAL" reports/track_utilization.rpt | awk '{print $(NF-1)}')
## power
  metrics_baseline[des_pwr_tot]=$(grep "Total Power:" $baseline/reports/power.rpt | awk '{print $NF}')
metrics_submission[des_pwr_tot]=$(grep "Total Power:" reports/power.rpt | awk '{print $NF}')
## performance
  metrics_baseline[des_prf_WNS_set]=$(grep "View : ALL" $baseline/reports/timing.rpt | awk 'NR==1' | awk '{print $(NF-2)}')
  metrics_baseline[des_prf_WNS_hld]=$(grep "View : ALL" $baseline/reports/timing.rpt | awk 'NR==2' | awk '{print $(NF-2)}')
metrics_submission[des_prf_WNS_set]=$(grep "View : ALL" reports/timing.rpt | awk 'NR==1' | awk '{print $(NF-2)}')
metrics_submission[des_prf_WNS_hld]=$(grep "View : ALL" reports/timing.rpt | awk 'NR==2' | awk '{print $(NF-2)}')
## area
  metrics_baseline[des_area_die]=$(cat $baseline/reports/area.rpt)
metrics_submission[des_area_die]=$(cat reports/area.rpt)

echo "Baseline numbers (raw, not weighted yet):" | tee -a $rpt
for metric in "${!metrics_baseline[@]}"; do
	value="${metrics_baseline[$metric]}"
	metric_=$(printf "%-"$cmp_max_length"s" $metric)
	echo "	$metric_ : $value" | tee -a $rpt
done
echo "" | tee -a $rpt
echo "Submission numbers (raw, not weighted yet):" | tee -a $rpt
for metric in "${!metrics_submission[@]}"; do
	value="${metrics_submission[$metric]}"
	metric_=$(printf "%-"$cmp_max_length"s" $metric)
	echo "	$metric_ : $value" | tee -a $rpt
done
echo "" | tee -a $rpt

## 3) base score calculation

declare -A base_scores=()

# NOTE metrics where the lower the better, thus calculate score as submission / baseline
#
## placement sites of exploitable regions
base_scores[sec_ti_sts_sum]=$(bc -l <<< "scale=$scale; (${metrics_submission[sec_ti_sts_sum]} / ${metrics_baseline[sec_ti_sts_sum]})")
base_scores[sec_ti_sts_max]=$(bc -l <<< "scale=$scale; (${metrics_submission[sec_ti_sts_max]} / ${metrics_baseline[sec_ti_sts_max]})")
base_scores[sec_ti_sts_med]=$(bc -l <<< "scale=$scale; (${metrics_submission[sec_ti_sts_med]} / ${metrics_baseline[sec_ti_sts_med]})")
## routing resources (free tracks) of whole layout
base_scores[sec_ti_fts_sum]=$(bc -l <<< "scale=$scale; (${metrics_submission[sec_ti_fts_sum]} / ${metrics_baseline[sec_ti_fts_sum]})")
## power
base_scores[des_pwr_tot]=$(bc -l <<< "scale=$scale; (${metrics_submission[des_pwr_tot]} / ${metrics_baseline[des_pwr_tot]})")
## area
base_scores[des_area_die]=$(bc -l <<< "scale=$scale; (${metrics_submission[des_area_die]} / ${metrics_baseline[des_area_die]})")

# NOTE metrics where the higher the better, thus calculate score as baseline / submission 
#
## performance
base_scores[des_prf_WNS_set]=$(bc -l <<< "scale=$scale; (${metrics_baseline[des_prf_WNS_set]} / ${metrics_submission[des_prf_WNS_set]})")
base_scores[des_prf_WNS_hld]=$(bc -l <<< "scale=$scale; (${metrics_baseline[des_prf_WNS_hld]} / ${metrics_submission[des_prf_WNS_hld]})")

echo "Score components (not weighted):" | tee -a $rpt
for metric in "${!base_scores[@]}"; do
	value="${base_scores[$metric]}"
	metric_=$(printf "%-"$cmp_max_length"s" $metric)
	echo "	$metric_ : $value" | tee -a $rpt
done
echo "" | tee -a $rpt

## 3) weighted score calculation

declare -A scores

# NOTE rounding to be done separately for each additive calculation step, but not for simple weighted multiplication
# of single metrics

## placement sites of exploitable regions
calc_string="${weights[sec_ti_sts_sum]}*${base_scores[sec_ti_sts_sum]}"
calc_string+=" + ${weights[sec_ti_sts_max]}*${base_scores[sec_ti_sts_max]}"
calc_string+=" + ${weights[sec_ti_sts_med]}*${base_scores[sec_ti_sts_med]}"
calc_string+=$calc_string_rounding
scores[sec_ti_sts]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "sec_ti_sts: $calc_string"

## routing resources (free tracks) of whole layout
calc_string="${weights[sec_ti_fts_sum]}*${base_scores[sec_ti_fts_sum]}"
scores[sec_ti_fts]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "sec_ti_fts: $calc_string"

## Trojan insertion, combined
calc_string="${weights[sec_ti_sts]}*${scores[sec_ti_sts]}"
calc_string+=" + ${weights[sec_ti_fts]}*${scores[sec_ti_fts]}"
calc_string+=$calc_string_rounding
scores[sec_ti]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "sec_ti: $calc_string"

## security, combined
calc_string="${weights[sec_ti]}*${scores[sec_ti]}"
scores[sec]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "sec: $calc_string"

## power
calc_string="${weights[des_pwr_tot]}*${base_scores[des_pwr_tot]}"
scores[des_pwr]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "des_pwr: $calc_string"

## performance
calc_string="${weights[des_prf_WNS_set]}*${base_scores[des_prf_WNS_set]}"
calc_string+=" + ${weights[des_prf_WNS_hld]}*${base_scores[des_prf_WNS_hld]}"
calc_string+=$calc_string_rounding
scores[des_prf]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "des_prf: $calc_string"

## area
calc_string="${weights[des_area_die]}*${base_scores[des_area_die]}"
scores[des_area]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "des_area: $calc_string"

## design cost, combined
calc_string="${weights[des_pwr]}*${scores[des_pwr]}"
calc_string+=" + ${weights[des_prf]}*${scores[des_prf]}"
calc_string+=" + ${weights[des_area]}*${scores[des_area]}"
calc_string+=$calc_string_rounding
scores[des]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "des: $calc_string"

## overall score: security and design combined
calc_string="${weights[sec]}*${scores[sec]}"
calc_string+=" + ${weights[des]}*${scores[des]}"
calc_string+=$calc_string_rounding
scores[OVERALL]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "OVERALL: $calc_string"

## print scores; perform sanity checks
error=0

echo "Scores (weighted; last digit subject to rounding):" | tee -a $rpt $rpt_summ
for score in "${!scores[@]}"; do

	if [[ "${scores[$score]}" == "" ]]; then
		echo "ISPD23 -- ERROR: computation for score component \"$score\" failed." | tee -a $err_rpt $rpt_summ
		error=1
	fi

	# cut digits going beyond scale, which can result from rounding calculation above
	value=$(echo ${scores[$score]} | awk '{printf "%.'$scale'f", $1}')
	score_=$(printf "%-"$cmp_max_length"s" $score)
	echo "	$score_ : $value" | tee -a $rpt $rpt_summ
done
#echo "" | tee -a $rpt $rpt_summ

## eval sanity checks; move failed report such that it's not accounted for during ranking
# NOTE do not move $rpt_summ as that should be always provided in the email, even when errors occurred
if [[ $error == 1 ]]; then
	mv $rpt $rpt".failed" 
fi
