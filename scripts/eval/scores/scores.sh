#!/bin/bash

####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD
#
####

# NOTE FOR PARTICIPANTS: Make sure that you have your submission reports ready. You want to have individual work directories per submission, and all reports for one submission
# should go into a 'reports/' sub-folder. You are flexible though while calling this script, as long as you provide correct paths as parameters. For example,
# 	[USER@HOST results_1245 ]$ $path_unzipped_release/_scripts/scores.sh 6 $path_unzipped_release/_final/aes
# should work fine, where results_12345 would be your current path, e.g., the local copy of the submission's results download, with reports/ as sub-folder, and
# $path_unzipped_release points to the path to the unzipped release bundle.

## fixed settings; typically not to be modified
#
# NOTE: default values in evaluation backend: scale=6; baseline=_$round/$benchmark; run_on_backend=1; dbg_files=$dbg_files
#
scale=$1
baseline=$2
# NOTE FOR PARTICIPANTS: this is by default set to '0' -- do not override this to '1' as that would give you incorrect scores!
run_on_backend=$3
# NOTE FOR PARTICIPANTS: dbg_files has no meaning and no effect for you; it's only relevant for the backend
dbg_files=$4
files="reports/exploitable_regions.rpt reports/track_utilization.rpt reports/area.rpt reports/power.rpt reports/timing.rpt"
rpt=reports/scores.rpt
rpt_back=reports/scores.rpt.back
rpt_log=scores.log
rpt_summ=reports/scores.rpt.summary
err_rpt=reports/errors.rpt

## NOTE deprecated, disabled on purpose; see also https://wp.nyu.edu/ispd23_contest/qa/#scoring QA-5
### 0) check for any other errors that might have occurred during actual processing
#if [[ -e $err_rpt ]]; then
#	echo "ISPD23 -- ERROR: cannot compute scores -- some evaluation step had some errors." | tee -a $err_rpt $rpt_log
#	error=1
#fi

## 0) parameter checks
if [[ $scale == "" ]]; then
	echo "ISPD23 -- ERROR: cannot compute scores -- 1st parameter, scale, is not provided." | tee -a $err_rpt $rpt_log
	error=1
fi
if ! [[ -d $baseline ]]; then
	echo "ISPD23 -- ERROR: cannot compute scores -- 2nd parameter, baseline folder \"$baseline\", is not a valid folder." | tee -a $err_rpt $rpt_log
	error=1
fi
if [[ $run_on_backend == "" ]]; then
	run_on_backend=0
fi
if [[ $dbg_files == "" ]]; then
	dbg_files=0
fi

## 0) basic init
#
mv $rpt $rpt_back 2> /dev/null
#
error=0
#
if [[ $run_on_backend == 0 ]]; then
	path_TI_status_files="reports/"
else
	path_TI_status_files="./"
fi

echo "Settings: " | tee -a $rpt_log
echo " scale=$scale" | tee -a $rpt_log
echo " baseline=$baseline" | tee -a $rpt_log
echo " run_on_backend=$run_on_backend" | tee -a $rpt_log
echo " dbg_files=$dbg_files" | tee -a $rpt_log
echo "" | tee -a $rpt_log

## 0) files check
for file in $files; do

	if ! [[ -e $baseline/$file ]]; then
		echo "ISPD23 -- ERROR: cannot compute scores -- file \"$baseline/$file\" is missing." | tee -a $err_rpt $rpt_log
		error=1
	fi

	if ! [[ -e $file ]]; then
		echo "ISPD23 -- ERROR: cannot compute scores -- file \"$file\" is missing." | tee -a $err_rpt $rpt_log
		error=1
	fi
done

if ! [[ -d TI ]]; then
	echo "ISPD23 -- ERROR: cannot compute scores -- sub-folder folder \"TI\" is missing." | tee -a $err_rpt $rpt_log
	error=1
fi

## 0) error handling
if [[ $error == 1 ]]; then
	exit 1
fi

## 1) only now, if all checks pass, we start with init procedures

## init data structures for ECO Trojan insertion (TI)

# key: running ID; value: $TI_mode_ID"_"$TI_mode"__"$trojan
# NOTE associative array is not really needed, but handling of such seems easier than plain indexed array
declare -A TI_mode__trojan
trojan_runs_counter=0

# key: running ID; value $trojan
# NOTE value not really needed; this array is only to keep track of the individual runs, w/o TI modes
declare -A trojans

for file in TI/*.dummy; do

	# drop path
	str=${file##TI/}
	# drop dummy suffix
	str=${str%%.dummy}
	# drop TI_mode_ID
	str=${str#*_}

	# $TI_mode"__"$trojan
	TI_mode__trojan[$trojan_runs_counter]=$str
	((trojan_runs_counter = trojan_runs_counter + 1))

	# $trojan
	trojan=${str#*__}
	# NOTE value not really needed; this array is only to keep track of the individual runs, w/o TI modes
	trojans[$trojan]=1
done
#declare -p TI_mode__trojan

## handling of DRC, timing report files

declare -A trojans_rpt_timing
declare -A trojans_rpt_drc

for str in "${TI_mode__trojan[@]}"; do

	# parsing of $TI_mode"__"$trojan
	trojan=${str#*__}
	TI_mode=${str%__*}
	trojan_TI_dot=$trojan"."$TI_mode
	trojan_TI____=$trojan"_"$TI_mode

	# NOTE FOR PARTICIPANTS -- tl;dr: you can just run the script as is; the code below works around the fact that you're not given the actual DRC reports.
	#
	# We do not share the full DRC reports with you (on purpose, to discourage any benchmark-specific tuning of your defense based on insights from the
	# DRC checks). You may run this script right away without any action, but -- unless your defense does indeed render insertion for this particular Trojan failing at our end, which
	# you can check from errors.rpt -- your related score will be off. To reproduce the correct scores, you need to generate some simple dummy DRC report file at your end. This file
	# must follow the below path selection and it suffices to hold one line as follows:
	# "Total Violations : $DRC_violations"
	# where $DRC_violations is the number of violations, which is listed as sec_ti_eco_drc_vio___$trojan_$TI_mode in the original scores.rpt returned to you.
	# Note that this task could be easily automated; this is already done right below.
	if [[ $run_on_backend == 0 ]]; then

		# NOTE we put this dummy rpt always in the work folder, irrespective of dbg_files; this is because of the ordered conditional check just below.
		dummy_drc_rpt="submission.geom."$trojan_TI_dot".rpt"
		echo -n "Total Violations : " > $dummy_drc_rpt
		grep "sec_ti_eco_drc_vio___$trojan_TI_dot" $rpt_back | awk '{print $NF}' >> $dummy_drc_rpt
	fi

	# NOTE in regular mode, related report file have been placed directly in the work dir, not in reports/ -- this is on purpose, as we don't want to share related
	# details back to participants
	# NOTE order of the two condition matters here; if we do not run on the backend, we have the file in the work dir, but if we do run on the backend, we still need to check dbg_files
	if [[ $run_on_backend == 0 || $dbg_files == 0 ]]; then
		trojans_rpt_drc[$trojan_TI____]="*.geom."$trojan_TI_dot".rpt"
	else
		trojans_rpt_drc[$trojan_TI____]="reports/*.geom."$trojan_TI_dot".rpt"
	fi

	# NOTE timing rpts are always placed in reports/ folder, independent of dbg mode, as they are meant to be shared with participants in any case
	trojans_rpt_timing[$trojan_TI____]="reports/timing."$trojan_TI_dot".rpt"
done

### weights
##
#
declare -A weights=()

### security
#
weights[sec]="0.5"

## Trojan insertion; generic evaluation of resources
weights[sec_ti_gen]="(1/3)"
# placement sites of exploitable regions
weights[sec_ti_gen_sts]="0.5"
weights[sec_ti_gen_sts_sum]="0.5"
weights[sec_ti_gen_sts_max]="(1/3)"
weights[sec_ti_gen_sts_med]="(1/6)"
# routing resources (free tracks) of whole layout
weights[sec_ti_gen_fts]="0.5"
weights[sec_ti_gen_fts_sum]="1.0"

## Trojan insertion; actual ECO insertion
#
weights[sec_ti_eco]="(2/3)"

## NOTE scores table
##
## 1) Lower scores means more difficulty for Trojan insertion, means better defense. The categories are
##    formulated/phrased from the perspective of the attacker.
## 2) All scores will be normalized to the worst case for defenders, i.e., 27.
## 3) Scores for all non-cancelled runs in the different insertion modes are averaged. Note that runs are 
##    only cancelled by the backend if they're not needed: e.g., if regular insertion already passes w/o
##    any violations, both advanced and avanced-advanced insertion are cancelled.
## 4) The gap of 3 score units b/w categories is on purpose. The reasoning is as follows: for attackers
##    (versus defenders), it is more important whether a Trojan has, e.g., no DRC violations at all
##    versus what effort is required to reach (versus hinder) zero DRC violations.
#
# 0 design failures; for advanced-advanced insertion
# 1 design failures; for advanced insertion
# 2 design failures; for regular insertion
#
# 5 DRC violations; for advanced-advanced insertion
# 6 DRC violations; for advanced insertion
# 7 DRC violations; for regular insertion
# 
# 10 setup AND hold violations; for advanced-advanced insertion
# 11 setup AND hold violations; for advanced insertion
# 12 setup AND hold violations; for regular insertion
# 
# 15 setup XOR hold violations; for advanced-advanced insertion
# 16 setup XOR hold violations; for advanced insertion
# 17 setup XOR hold violations; for regular insertion
# 
# 20 DRV, clock check violations; for advanced-advanced insertion
# 21 DRV, clock check violations; for advanced insertion
# 22 DRV, clock check violations; for regular insertion
# 
# 25 no violations; for advanced-advanced insertion
# 26 no violations; for advanced insertion
# 27 no violations; for regular insertion

weights[sec_ti_eco_reg_failed]="(2/27)"
weights[sec_ti_eco_reg_drc_vio]="(7/27)"
weights[sec_ti_eco_reg_set_and_hld_vio]="(12/27)"
weights[sec_ti_eco_reg_set_xor_hld_vio]="(17/27)"
weights[sec_ti_eco_reg_drv_clk_vio]="(22/27)"
# NOTE use 27/27, etc., for easier reading of the report
weights[sec_ti_eco_reg_no_vio]="(27/27)"
#
weights[sec_ti_eco_adv_failed]="(1/27)"
weights[sec_ti_eco_adv_drc_vio]="(6/27)"
weights[sec_ti_eco_adv_set_and_hld_vio]="(11/27)"
weights[sec_ti_eco_adv_set_xor_hld_vio]="(16/27)"
weights[sec_ti_eco_adv_drv_clk_vio]="(21/27)"
weights[sec_ti_eco_adv_no_vio]="(26/27)"
#
weights[sec_ti_eco_adv2_failed]="(0/27)"
weights[sec_ti_eco_adv2_drc_vio]="(5/27)"
weights[sec_ti_eco_adv2_set_and_hld_vio]="(10/27)"
weights[sec_ti_eco_adv2_set_xor_hld_vio]="(15/27)"
weights[sec_ti_eco_adv2_drv_clk_vio]="(20/27)"
weights[sec_ti_eco_adv2_no_vio]="(25/27)"

## weights for actual Trojan runs
# NOTE here we incorporate the scale needed for averaging across all runs to consider, i.e., we exclude all cancelled runs
#
declare -A trojans_non_cancelled_runs

for str in "${TI_mode__trojan[@]}"; do

	# parsing of $TI_mode"__"$trojan
	trojan=${str#*__}
	TI_mode=${str%__*}
	trojan_TI_dot=$trojan"."$TI_mode
#	trojan_TI____=$trojan"_"$TI_mode

	# count non-cancelled runs
	if [[ -e $path_TI_status_files/CANCELLED.TI.$trojan_TI_dot ]]; then

		continue
	else
		if [[ ${trojans_non_cancelled_runs[$trojan]} == "" ]]; then

			trojans_non_cancelled_runs[$trojan]=1
		else
			((trojans_non_cancelled_runs[$trojan] = ${trojans_non_cancelled_runs[$trojan]} + 1))
		fi
	fi

	# NOTE the correct weight calculation is reached only in the last iteration, once all runs are covered
	# NOTE the '___' separator to differentiate from generic weights above
	#
	weights[sec_ti_eco___$trojan]="(1/"${trojans_non_cancelled_runs[$trojan]}")"
done

### Design quality
#
weights[des]="0.5"

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

# NOTE helper to determine max length of array keys. would be nice to outsource into a function, but that works only well for bash version > 4.3 which is not there on the backend.
# So, for now we just copy the code wherever we need to update max_length.
#
max_length="0"
for key in "${!weights[@]}"; do
	if [[ ${#key} -gt $max_length ]]; then
		max_length=${#key}
	fi
done

echo "Metrics' weights:" | tee -a $rpt
for weight in "${!weights[@]}"; do
	value="${weights[$weight]}"
	weight_=$(printf "%-"$max_length"s" $weight)
	echo "	$weight_ : $value" | tee -a $rpt
done
echo "" | tee -a $rpt

## init rounding, depending on scale
#
calc_string_rounding=" + 0."
for (( i=0; i<$scale; i++)); do
	calc_string_rounding+="0"
done
calc_string_rounding+="5"

## 2) parsing

declare -A metrics_baseline=()
declare -A metrics_submission=()

### Trojan insertion; generic evaluation of resources
#

## placement sites of exploitable regions
# NOTE 'sed' is to drop the thousands separator as that's not supported by bc
  metrics_baseline[sec_ti_gen_sts_sum]=$(grep "Sum of sites across all regions:" $baseline/reports/exploitable_regions.rpt | awk '{print $NF}' | sed 's/,//g')
  metrics_baseline[sec_ti_gen_sts_max]=$(grep "Max of sites across all regions:" $baseline/reports/exploitable_regions.rpt | awk '{print $NF}' | sed 's/,//g')
  metrics_baseline[sec_ti_gen_sts_med]=$(grep "Median of sites across all regions:" $baseline/reports/exploitable_regions.rpt | awk '{print $NF}' | sed 's/,//g')
metrics_submission[sec_ti_gen_sts_sum]=$(grep "Sum of sites across all regions:" reports/exploitable_regions.rpt | awk '{print $NF}' | sed 's/,//g')
metrics_submission[sec_ti_gen_sts_max]=$(grep "Max of sites across all regions:" reports/exploitable_regions.rpt | awk '{print $NF}' | sed 's/,//g')
metrics_submission[sec_ti_gen_sts_med]=$(grep "Median of sites across all regions:" reports/exploitable_regions.rpt | awk '{print $NF}' | sed 's/,//g')

## routing resources (free tracks) of whole layout
  metrics_baseline[sec_ti_gen_fts_sum]=$(grep "TOTAL" $baseline/reports/track_utilization.rpt | awk '{print $(NF-1)}')
metrics_submission[sec_ti_gen_fts_sum]=$(grep "TOTAL" reports/track_utilization.rpt | awk '{print $(NF-1)}')

### Trojan insertion; actual ECO insertion
#

## DRC checks
for str in "${TI_mode__trojan[@]}"; do

	# parsing of $TI_mode"__"$trojan
	trojan=${str#*__}
	TI_mode=${str%__*}
	trojan_TI_dot=$trojan"."$TI_mode
	trojan_TI____=$trojan"_"$TI_mode

	id="sec_ti_eco_drc_vio___$trojan_TI____"

	if [[ -e $path_TI_status_files/FAILED.TI.$trojan_TI_dot ]]; then

		metrics_submission[$id]="failed"

	elif [[ -e $path_TI_status_files/CANCELLED.TI.$trojan_TI_dot ]]; then

		metrics_submission[$id]="cancelled"
	else
		metrics_submission[$id]=$(grep "Total Violations :" ${trojans_rpt_drc[$trojan_TI____]} 2> /dev/null | awk '{print $4}')

		# NOTE such line is only present if errors/issues found at all
		if [[ ${metrics_submission[$id]} == "" ]]; then
			metrics_submission[$id]="0"
		fi
	fi
done

## timing checks
# NOTE similar logic/flow as the above
for str in "${TI_mode__trojan[@]}"; do

	# parsing of $TI_mode"__"$trojan
	trojan=${str#*__}
	TI_mode=${str%__*}
	trojan_TI_dot=$trojan"."$TI_mode
	trojan_TI____=$trojan"_"$TI_mode

	id="sec_ti_eco_prf_set_vio___$trojan_TI____"

	if [[ -e $path_TI_status_files/FAILED.TI.$trojan_TI_dot ]]; then

		metrics_submission[$id]="failed"

	elif [[ -e $path_TI_status_files/CANCELLED.TI.$trojan_TI_dot ]]; then

		metrics_submission[$id]="cancelled"
	else
		metrics_submission[$id]=$(grep "View : ALL" ${trojans_rpt_timing[$trojan_TI____]} | awk 'NR==1' | awk '{print $NF}')
	fi

	id="sec_ti_eco_prf_hld_vio___$trojan_TI____"

	if [[ -e $path_TI_status_files/FAILED.TI.$trojan_TI_dot ]]; then

		metrics_submission[$id]="failed"

	elif [[ -e $path_TI_status_files/CANCELLED.TI.$trojan_TI_dot ]]; then

		metrics_submission[$id]="cancelled"
	else
		metrics_submission[$id]=$(grep "View : ALL" ${trojans_rpt_timing[$trojan_TI____]} | awk 'NR==2' | awk '{print $NF}')
	fi
done

## DRV, clock checks
for str in "${TI_mode__trojan[@]}"; do

	# parsing of $TI_mode"__"$trojan
	trojan=${str#*__}
	TI_mode=${str%__*}
	trojan_TI_dot=$trojan"."$TI_mode
	trojan_TI____=$trojan"_"$TI_mode

	id="sec_ti_eco_drv_clk_vio___$trojan_TI____"

	if [[ -e $path_TI_status_files/FAILED.TI.$trojan_TI_dot ]]; then
	
		metrics_submission[$id]="failed"

	elif [[ -e $path_TI_status_files/CANCELLED.TI.$trojan_TI_dot ]]; then

		metrics_submission[$id]="cancelled"
	else
		# NOTE there are multiple lines for these checks, while the number of lines/checks changes also with the design --> just sum up; this is also appropriate in terms
		# of relevance of these two checks and given that we're not considering the actual count of violations for scoring (see further below)
		metrics_submission[$id]=0
		while read line; do

			if [[ "$line" != *"Check : "* ]]; then
				continue
			fi

			curr_line_FEPs=$(echo $line | awk '{print $NF}')
			((metrics_submission[$id] = ${metrics_submission[$id]} + curr_line_FEPs))

		done < ${trojans_rpt_timing[$trojan_TI____]}
	fi
done

### Design quality
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

# NOTE helper to determine max length of array keys. would be nice to outsource into a function, but that works only well for bash version > 4.3 which is not there on the backend.
# So, for now we just copy the code wherever we need to update max_length.
max_length="0"
for key in "${!metrics_baseline[@]}"; do
	if [[ ${#key} -gt $max_length ]]; then
		max_length=${#key}
	fi
done
#
echo "Baseline metrics (raw, not weighted yet):" | tee -a $rpt
for metric in "${!metrics_baseline[@]}"; do
	value="${metrics_baseline[$metric]}"
	metric_=$(printf "%-"$max_length"s" $metric)
	echo "	$metric_ : $value" | tee -a $rpt
done
echo "" | tee -a $rpt

max_length="0"
for key in "${!metrics_submission[@]}"; do
	if [[ ${#key} -gt $max_length ]]; then
		max_length=${#key}
	fi
done
#
echo "Submission metrics (raw, not weighted yet):" | tee -a $rpt
for metric in "${!metrics_submission[@]}"; do
	value="${metrics_submission[$metric]}"
	metric_=$(printf "%-"$max_length"s" $metric)
	echo "	$metric_ : $value" | tee -a $rpt
done
echo "" | tee -a $rpt

## 3) base score calculation

declare -A base_scores=()

# NOTE metrics where the lower the better, thus calculate score as submission / baseline
#
## placement sites of exploitable regions
base_scores[sec_ti_gen_sts_sum]=$(bc -l <<< "scale=$scale; (${metrics_submission[sec_ti_gen_sts_sum]} / ${metrics_baseline[sec_ti_gen_sts_sum]})")
base_scores[sec_ti_gen_sts_max]=$(bc -l <<< "scale=$scale; (${metrics_submission[sec_ti_gen_sts_max]} / ${metrics_baseline[sec_ti_gen_sts_max]})")
base_scores[sec_ti_gen_sts_med]=$(bc -l <<< "scale=$scale; (${metrics_submission[sec_ti_gen_sts_med]} / ${metrics_baseline[sec_ti_gen_sts_med]})")
## routing resources (free tracks) of whole layout
base_scores[sec_ti_gen_fts_sum]=$(bc -l <<< "scale=$scale; (${metrics_submission[sec_ti_gen_fts_sum]} / ${metrics_baseline[sec_ti_gen_fts_sum]})")
## power
base_scores[des_pwr_tot]=$(bc -l <<< "scale=$scale; (${metrics_submission[des_pwr_tot]} / ${metrics_baseline[des_pwr_tot]})")
## area
base_scores[des_area_die]=$(bc -l <<< "scale=$scale; (${metrics_submission[des_area_die]} / ${metrics_baseline[des_area_die]})")

## actual ECO TI: also the lower the better, but calculation does not require/consider baseline values by definition
for str in "${TI_mode__trojan[@]}"; do

	# parsing of $TI_mode"__"$trojan
	trojan=${str#*__}
	TI_mode=${str%__*}
	trojan_TI_dot=$trojan"."$TI_mode
	trojan_TI____=$trojan"_"$TI_mode

	# NOTE for cancelled runs, we don't assign any base score but just skip this case
	if [[ -e $path_TI_status_files/CANCELLED.TI.$trojan_TI_dot ]]; then
		continue
	fi

	# NOTE the scoring does not account for the actual numbers/values of violations, but only whether some violation has occurred or not. This is reasonable as, e.g., for timing, the
	# violations (if any) depend on both the submission as well as the Trojan; it is difficult to separate these parts. Also, we can argue that attackers would only care/hope that
	# violations did not occur. Thus, if violations occur, the related score for the participants will improve.

	## actual score evaluation
	#
	# NOTE order is important here; check from worst to best scenario (for attacker) to assign best-possible score for defender/participants
	
	if [[ -e $path_TI_status_files/FAILED.TI.$trojan_TI_dot ]]; then

		outcome="failed"

	elif [[ ${metrics_submission[sec_ti_eco_drc_vio___$trojan_TI____]} -gt 0 ]]; then

		outcome="drc_vio"

	elif [[ ${metrics_submission[sec_ti_eco_prf_set_vio___$trojan_TI____]} -gt 0 && ${metrics_submission[sec_ti_eco_prf_hld_vio___$trojan_TI____]} -gt 0 ]]; then

		outcome="set_and_hld_vio"

	elif [[ ${metrics_submission[sec_ti_eco_prf_set_vio___$trojan_TI____]} -eq 0 && ${metrics_submission[sec_ti_eco_prf_hld_vio___$trojan_TI____]} -gt 0 ]]; then

		outcome="set_xor_hld_vio"

	elif [[ ${metrics_submission[sec_ti_eco_prf_set_vio___$trojan_TI____]} -gt 0 && ${metrics_submission[sec_ti_eco_prf_hld_vio___$trojan_TI____]} -eq 0 ]]; then

		outcome="set_xor_hld_vio"

	elif [[ ${metrics_submission[sec_ti_eco_drv_clk_vio___$trojan_TI____]} -gt 0 ]]; then

		outcome="drv_clk_vio"

	# NOTE we reach here only once no violations occurred at all
	else
		outcome="no_vio"
	fi

#	# manual dbg
#	echo "$trojan_TI_dot: $outcome"

	## finally, compute the baseline score, which is simply the weight (that is already appropriately normalized over the max value / worst case)
	#
	id_weight="sec_ti_eco_"$TI_mode"_"$outcome
	id_trojan="sec_ti_eco___"$trojan_TI____

	base_scores[$id_trojan]=${weights[$id_weight]}
done

# NOTE metrics where the higher the better, thus calculate score as baseline / submission 
#
## performance
base_scores[des_prf_WNS_set]=$(bc -l <<< "scale=$scale; (${metrics_baseline[des_prf_WNS_set]} / ${metrics_submission[des_prf_WNS_set]})")
base_scores[des_prf_WNS_hld]=$(bc -l <<< "scale=$scale; (${metrics_baseline[des_prf_WNS_hld]} / ${metrics_submission[des_prf_WNS_hld]})")

# NOTE helper to determine max length of array keys. would be nice to outsource into a function, but that works only well for bash version > 4.3 which is not there on the backend.
# So, for now we just copy the code wherever we need to update max_length.
max_length="0"
for key in "${!base_scores[@]}"; do
	if [[ ${#key} -gt $max_length ]]; then
		max_length=${#key}
	fi
done
#
echo "Score components (not weighted):" | tee -a $rpt
for metric in "${!base_scores[@]}"; do
	value="${base_scores[$metric]}"
	metric_=$(printf "%-"$max_length"s" $metric)
	echo "	$metric_ : $value" | tee -a $rpt
done
echo "" | tee -a $rpt

## 3) weighted score calculation

declare -A scores

# NOTE rounding to be done separately for each additive calculation step, but not for simple weighted multiplication
# of single metrics

## Trojan insertion; generic evaluation of resources
# placement sites of exploitable regions
calc_string="${weights[sec_ti_gen_sts_sum]}*${base_scores[sec_ti_gen_sts_sum]}"
calc_string+=" + ${weights[sec_ti_gen_sts_max]}*${base_scores[sec_ti_gen_sts_max]}"
calc_string+=" + ${weights[sec_ti_gen_sts_med]}*${base_scores[sec_ti_gen_sts_med]}"
calc_string+=$calc_string_rounding
scores[sec_ti_gen_sts]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "sec_ti_gen_sts: $calc_string"
#
# routing resources (free tracks) of whole layout
calc_string="${weights[sec_ti_gen_fts_sum]}*${base_scores[sec_ti_gen_fts_sum]}"
scores[sec_ti_gen_fts]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "sec_ti_gen_fts: $calc_string"
#
# Trojan insertion; generic evaluation of resources; combined
calc_string="${weights[sec_ti_gen_sts]}*${scores[sec_ti_gen_sts]}"
calc_string+=" + ${weights[sec_ti_gen_fts]}*${scores[sec_ti_gen_fts]}"
calc_string+=$calc_string_rounding
scores[sec_ti_gen]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "sec_ti_gen: $calc_string"

## Trojan insertion; actual ECO insertion
# NOTE For the combined scoring, each Trojan has the same weight. This is fair, given that, despite the different nature and implementation of the Trojans, the success for Trojan insertion at
# our end depends on many aspects of the participants' submissions; it cannot be easily differentiated b/w the different Trojans and their requirements for successful insertion.
#
for trojan in "${!trojans[@]}"; do
	calc_string="0"

	for str in "${TI_mode__trojan[@]}"; do

		# parsing of $TI_mode"__"$trojan
		trojan_=${str#*__}
		TI_mode=${str%__*}
		trojan_TI_dot=$trojan_"."$TI_mode
		trojan_TI____=$trojan_"_"$TI_mode

		if [[ $trojan_ != $trojan ]]; then
			continue
		fi

		# NOTE for cancelled runs, there is no base score (by definition) so we skip this case
		if [[ -e $path_TI_status_files/CANCELLED.TI.$trojan_TI_dot ]]; then
			continue
		fi

		id="sec_ti_eco___"$trojan
		id_full="sec_ti_eco___"$trojan_TI____

		# NOTE recall that, for each Trojan, their individual weight already accounts for the averaging based on the number of non-cancelled runs
		calc_string+=" + (${weights[$id]}*${base_scores[$id_full]})"
	done

	calc_string+=$calc_string_rounding
	scores[sec_ti_eco__$trojan]=$(bc -l <<< "scale=$scale; ($calc_string)")
	#echo "sec_ti_eco__$trojan: $calc_string"
done
#
## Trojan insertion; actual ECO insertion -- final score: average across all Trojans
calc_string="0"
for trojan in "${!trojans[@]}"; do
	calc_string+=" + (${scores[sec_ti_eco__$trojan]}/${#trojans[@]})"
done
calc_string+=$calc_string_rounding
scores[sec_ti_eco]=$(bc -l <<< "scale=$scale; ($calc_string)")
#echo "sec_ti_eco: $calc_string"

## security, combined
calc_string="${weights[sec_ti_gen]}*${scores[sec_ti_gen]}"
calc_string+=" + ${weights[sec_ti_eco]}*${scores[sec_ti_eco]}"
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

## print scores

# NOTE helper to determine max length of array keys. would be nice to outsource into a function, but that works only well for bash version > 4.3 which is not there on the backend.
# So, for now we just copy the code wherever we need to update max_length.
max_length="0"
for key in "${!scores[@]}"; do
	if [[ ${#key} -gt $max_length ]]; then
		max_length=${#key}
	fi
done
#
# NOTE we also write out these key values to a summary file, $rpt_summ
echo "Scores (weighted; last digit subject to rounding):" | tee -a $rpt $rpt_summ
for score in "${!scores[@]}"; do

	if [[ "${scores[$score]}" == "" ]]; then
		echo "ISPD23 -- ERROR: computation for score component \"$score\" failed." | tee -a $err_rpt $rpt_log
		error=1
	fi

	# cut digits going beyond scale, which can result from rounding calculation above
	value=$(echo ${scores[$score]} | awk '{printf "%.'$scale'f", $1}')
	score_=$(printf "%-"$max_length"s" $score)
	echo "	$score_ : $value" | tee -a $rpt $rpt_summ
done

## also print out warning in case any other error occurred previously, e.g., for design checks or for initialization of some Trojan run.
#
# NOTE this should work for both the backend and local runs; assuming that, for the latter case, the downloaded $err_rpt (if any) did not get removed; if it did get removed, there is
# nothing we can do here
if [[ -e $err_rpt ]]; then

	echo "" | tee -a $rpt $rpt_summ
	echo "SCORES ONLY FOR INFORMATION. THIS SUBMISSION IS INVALID AS SOME DESIGN CHECK FAILED AND/OR SOME ERROR OCCURRED." | tee -a $rpt $rpt_summ
fi

## sanity check; move failed report such that it's not to accounted for during ranking in the backend
if [[ $error == 1 ]]; then

	mv $rpt $rpt".failed" 

	# NOTE do not move $rpt_summ as that should be shared along with the notification email by the backend, even when errors occurred
fi
