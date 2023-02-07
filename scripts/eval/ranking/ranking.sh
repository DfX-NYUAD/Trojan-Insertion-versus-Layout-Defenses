#!/bin/bash

######################
# 0) settings, init
######################

metric_default="OVERALL"
list_files_default=1
team_real_name_default=1
score_related_OVERALL_default=1
daemon_settings="../../gdrive/ISPD23_daemon.settings"
team_settings="team.settings"

# string for non-defined results
ND="-"

# associative array w/ teams and anon IDs
declare -A teams
source $team_settings

echo "Optional parameters:"
echo "1) Metric -- pick one from those available in the scores.rpt files -- default is \"$metric_default\""
echo "2) List related files -- 0: no; 1: yes -- default is $list_files_default"
echo "3) Real team names -- 0: anonymous label; 1: actual names -- default is $team_real_name_default"
echo "4) Score related to \"OVERALL\" -- 0: no, means that best score is selected (for the metric of choice) independently of \"OVERALL\" score; 1: yes, means that best score (for the metric of choice) is extracted for run w/ best \"OVERALL\" score -- default is $score_related_OVERALL_default"
echo "5) List of teams to report for, as one string, e.g., \"_test _production\" -- default is to report for all teams listed in \"$team_settings\""
echo "6) Path for ISPD23_daemon.settings file -- default is \"$daemon_settings\""
echo

# call parameters

if [[ $1 == "-help" || $1 == "-h" || $1 == "--help" ]]; then
	exit 0
elif [[ $1 != "" ]]; then
	metric=$1
else
	metric=$metric_default
fi

if [[ $2 != "" ]]; then
	list_files=$2
else
	list_files=$list_files_default
fi

if [[ $3 != "" ]]; then
	team_real_name=$3
else
	team_real_name=$team_real_name_default
fi

if [[ $4 != "" ]]; then
	score_related_OVERALL=$4
else
	score_related_OVERALL=$score_related_OVERALL_default
fi

if [[ $5 != "" ]]; then
	teams_list="$5"
else
	teams_list=$ND
fi

if [[ $6 != "" ]]; then
	source $6
else
	source $daemon_settings
fi

echo "Parameters:"
echo " Metric: $metric"
echo " List related files: $list_files"
echo " Real team names: $team_real_name"
echo " Score related to OVERALL: $score_related_OVERALL"
echo " List of teams to report for: \"$teams_list\""
echo " Path for ISPD23_daemon.settings file: $daemon_settings"
echo

# cleanup all old log files; cleanup only here, not at the end of the run, so that log would still remain available for more details after running this script
rm /tmp/ISPD23_*_*.log

# init log file; used for keeping track of best runs
log=/tmp/ISPD23_$metric"_"$(date +%s).log

######################
# 1) obtain scores
######################

echo "Extracting scores ..."

declare -A scores_baseline
for benchmark in $benchmarks; do

	## NOTE baseline is baseline; here we don't need to differentiate b/w best score related to OVERALL or not
	scores_baseline[$benchmark]=$(grep -w "$metric" $baselines_root_folder/$benchmark/reports/scores.rpt | tail -n 1 | awk '{print $NF}')
done

# iterate over keys
for team in "${!teams[@]}"; do

	# list for a) all or b) only for selected teams
	if [[ "$teams_list" != $ND ]]; then
		if [[ "$teams_list" != *"$team"* ]]; then
			continue
		fi
	fi

	echo " Extracting best scores (i.e., min value) for team \"$team\" for metric \"$metric\" ..."

	## some characters are not supported for bash var; replace them
	team_=$(echo $team | sed -e 's/-/_/g')

	# init dedicated arrays for each team
	## NOTE https://unix.stackexchange.com/a/225265
	array_name_OVERALL="scores_OVERALL_$team_"
	declare -A $array_name_OVERALL=\(\)
	array_name="scores_$team_"
	declare -A $array_name=\(\)

	for benchmark in $benchmarks; do

		## init score
		## NOTE extended from https://unix.stackexchange.com/a/225265 for associative array
		eval $array_name_OVERALL[$benchmark]=$ND
		eval $array_name[$benchmark]=$ND

		## check all past runs

		backup_work="$teams_root_folder/$team/$benchmark/backup_work"
		for run in $(ls $backup_work); do

			## only consider folders; ignore other files in main dirs
			if ! [[ -d $backup_work/$run ]] ; then
				continue
			fi

			## skip runs w/o scores
			if ! [[ -e $backup_work/$run/reports/scores.rpt ]] ; then
				continue
			fi

			## also skip runs w/ errors
			if [[ -e $backup_work/$run/reports/errors.rpt ]] ; then
				continue
			fi

			## extract scores
			score_OVERALL_curr=$(grep -w "OVERALL" $backup_work/$run/reports/scores.rpt | tail -n 1 | awk '{print $NF}')
			score_curr=$(grep -w "$metric" $backup_work/$run/reports/scores.rpt | tail -n 1 | awk '{print $NF}')

			## track lowest scores across runs

			# get current min scores
			score_OVERALL_min=$(eval echo \${$array_name_OVERALL[$benchmark]})
			score_min=$(eval echo \${$array_name[$benchmark]})

			# init arrays in case first valid score is this one
			if [[ "$score_OVERALL_min" == $ND ]]; then

				eval $array_name_OVERALL[$benchmark]=$score_OVERALL_curr

				## NOTE update here needed for check below
				score_OVERALL_min=$score_OVERALL_curr

				# also log the rpt file, if not done yet
				string="$backup_work/$run/reports/scores.rpt"
				if [[ $(grep -q $string $log 2> /dev/null; echo $?) != 0 ]]; then
					echo $string >> $log
				fi
			fi
			## NOTE in this mode, the actual min score should only be initialized when also the OVERALL min score is already initialized
			if [[ $score_related_OVERALL == 1 ]]; then

				if [[ "$score_min" == $ND ]]; then
					if [[ "$score_OVERALL_min" != $ND ]]; then

						eval $array_name[$benchmark]=$score_curr

						# also log the rpt file, if not done yet
						string="$backup_work/$run/reports/scores.rpt"
						if [[ $(grep -q $string $log 2> /dev/null; echo $?) != 0 ]]; then
							echo $string >> $log
						fi

						continue
					fi
				fi

			## NOTE else, the actual score can be initialized anytime
			else 
				if [[ "$score_min" == $ND ]]; then

					eval $array_name[$benchmark]=$score_curr

					# also log the rpt file, if not done yet
					string="$backup_work/$run/reports/scores.rpt"
					if [[ $(grep -q $string $log 2> /dev/null; echo $?) != 0 ]]; then
						echo $string >> $log
					fi

					continue
				fi
			fi

			# update min score
			## NOTE in this mode, the actual min score is dictated by whatever actual score value is there for the OVERALL min score
			if [[ $score_related_OVERALL == 1 ]]; then

				# actual floating point comparison, using bc
				# NOTE in this mode, we want to check for any solution with at least as best OVERALL score, not only better ones (the latter would likely exclude submissions that improve on actual score)
				if (( $(echo "$score_OVERALL_curr <= $score_OVERALL_min" | bc -l) )); then

#					# dbg
#					echo $run
#					echo " $score_OVERALL_curr <= $score_OVERALL_min"

					eval $array_name_OVERALL[$benchmark]=$score_OVERALL_curr

					## update actual score for improvements of actual score itself or for overall score (for the latter case we would reset the actual score)
					if (( $(echo "$score_curr < $score_min" | bc -l) || $(echo "$score_OVERALL_curr < $score_OVERALL_min" | bc -l))); then

#						# dbg
#						echo "  $score_curr <= $score_min"

						eval $array_name[$benchmark]=$score_curr

						# also log the rpt file, if not done yet
						string="$backup_work/$run/reports/scores.rpt"
						if [[ $(grep -q $string $log 2> /dev/null; echo $?) != 0 ]]; then
							echo $string >> $log
						fi
					fi
				fi

			## NOTE else, the actual min score is updated any time 
			else

				# actual floating point comparison, using bc
				if (( $(echo "$score_curr < $score_min" | bc -l) )); then

					eval $array_name[$benchmark]=$score_curr

					# also log the rpt file, if not done yet
					string="$backup_work/$run/reports/scores.rpt"
					if [[ $(grep -q $string $log 2> /dev/null; echo $?) != 0 ]]; then
						echo $string >> $log
					fi
				fi
			fi

#			# dbg
#			echo "Benchmark $benchmark -- score_curr: $score_curr; score_min: $(eval echo \${$array_name[$benchmark]})"
		done
	done

#	echo "Done"

done
echo "Done"

######################
# 2a) print scores
######################

echo
echo "Submissions: valid/total"
echo "------------------------"
echo

## 1st row: header
out=""
out+="Benchmark "
#out+="Baseline "
for team in "${!teams[@]}"; do

	# list for a) all or b) only for selected teams
	if [[ "$teams_list" != $ND ]]; then
		if [[ "$teams_list" != *"$team"* ]]; then
			continue
		fi
	fi

	# real or anon team name
	if [[ $team_real_name == 1 ]]; then
		out+="$team "
	else
		out+="${teams[$team]} "
	fi
done
# end row
# NOTE see https://stackoverflow.com/a/3182519 for newline handling
out+=$'\n'

## build up rows, one per benchmark
for benchmark in $benchmarks; do

	# 1st col: benchmark name
	out+="$benchmark "

	# remaining cols: reference, extracted from underyling rpt file
	for team in "${!teams[@]}"; do

		# list for a) all or b) only for selected teams
		if [[ "$teams_list" != $ND ]]; then
			if [[ "$teams_list" != *"$team"* ]]; then
				continue
			fi
		fi

		backup_work="$teams_root_folder/$team/$benchmark/backup_work"
		runs_total=$(ls $backup_work/*.zip 2> /dev/null | wc -l)

		if [[ $(cat $log | grep $benchmark | grep -q $team; echo $?) == 0 ]]; then

			string=$(cat $log | grep $benchmark | grep $team | wc -l)
			out+="$string/$runs_total "
		else
			out+="$ND/$runs_total "
		fi
	done
	# end row
	out+=$'\n'
done

# print as table
# NOTE quotes are required here for proper newline handling (https://stackoverflow.com/a/3182519)
echo "$out" | column -t

######################
# 2b) print scores
######################

echo
echo "Best scores"
echo "-----------"
echo

## 1st row: header
out=""
out+="Benchmark "
#out+="Baseline "
for team in "${!teams[@]}"; do

	# list for a) all or b) only for selected teams
	if [[ "$teams_list" != $ND ]]; then
		if [[ "$teams_list" != *"$team"* ]]; then
			continue
		fi
	fi

	# real or anon team name
	if [[ $team_real_name == 1 ]]; then
		out+="$team "
	else
		out+="${teams[$team]} "
	fi
done
# end row
# NOTE see https://stackoverflow.com/a/3182519 for newline handling
out+=$'\n'

## build up rows, one per benchmark
for benchmark in $benchmarks; do

	# 1st col: benchmark name
	out+="$benchmark "

#	# 2nd col: baseline scores
#	out+="${scores_baseline[$benchmark]} "

	# remaining cols: team scores
	for team in "${!teams[@]}"; do

		# list for a) all or b) only for selected teams
		if [[ "$teams_list" != $ND ]]; then
			if [[ "$teams_list" != *"$team"* ]]; then
				continue
			fi
		fi

		## some characters are not supported for bash var; replace them
		team_=$(echo $team | sed -e 's/-/_/g')
		array_name="scores_$team_"

		scores_string=$(eval echo \${$array_name[$benchmark]})
		out+="$scores_string "
	done
	# end row
	out+=$'\n'
done

# print as table
# NOTE quotes are required here for proper newline handling (https://stackoverflow.com/a/3182519)
echo "$out" | column -t

######################
# 2c) print references
######################

echo
echo "Related references"
echo "------------------"
echo

## 1st row: header
out=""
out+="Benchmark "
for team in "${!teams[@]}"; do

	# list for a) all or b) only for selected teams
	if [[ "$teams_list" != $ND ]]; then
		if [[ "$teams_list" != *"$team"* ]]; then
			continue
		fi
	fi

	# real or anon team name
	if [[ $team_real_name == 1 ]]; then
		out+="$team "
	else
		out+="${teams[$team]} "
	fi
done
# end row
# NOTE see https://stackoverflow.com/a/3182519 for newline handling
out+=$'\n'

## build up rows, one per benchmark
for benchmark in $benchmarks; do

	# 1st col: benchmark name
	out+="$benchmark "

	# remaining cols: reference, extracted from underyling rpt file
	for team in "${!teams[@]}"; do

		# list for a) all or b) only for selected teams
		if [[ "$teams_list" != $ND ]]; then
			if [[ "$teams_list" != *"$team"* ]]; then
				continue
			fi
		fi

		if [[ $(cat $log | grep $benchmark | grep -q $team; echo $?) == 0 ]]; then

			string=$(cat $log | grep $benchmark | grep $team | tail -n 1)
			string=${string%/reports/scores.rpt}
			string=${string##*_}
			out+="$string "
		else
			out+="$ND "
		fi
	done
	# end row
	out+=$'\n'
done

# print as table
# NOTE quotes are required here for proper newline handling (https://stackoverflow.com/a/3182519)
echo "$out" | column -t

######################
# 3) print files
######################

if [[ $list_files == 1 ]]; then

	echo
	echo "Related files"
	echo "-------------"
	echo

	out=""
	out+="Benchmark "
	for team in "${!teams[@]}"; do

		# list for a) all or b) only for selected teams
		if [[ "$teams_list" != $ND ]]; then
			if [[ "$teams_list" != *"$team"* ]]; then
				continue
			fi
		fi
	
		# real or anon team name
		if [[ $team_real_name == 1 ]]; then
			out+="$team "
		else
			out+="${teams[$team]} "
		fi
	done
	# end row
	# NOTE see https://stackoverflow.com/a/3182519 for newline handling
	out+=$'\n'

	## build up rows, one per benchmark
	for benchmark in $benchmarks; do
	
		# 1st col: benchmark name
		out+="$benchmark "
	
		# remaining cols: underyling rpt file
		for team in "${!teams[@]}"; do

			# list for a) all or b) only for selected teams
			if [[ "$teams_list" != $ND ]]; then
				if [[ "$teams_list" != *"$team"* ]]; then
					continue
				fi
			fi

			if [[ $(cat $log | grep $benchmark | grep -q $team; echo $?) == 0 ]]; then
				out+=$(cat $log | grep $benchmark | grep $team | tail -n 1)
				out+=" "
			else
				out+="$ND "
			fi
		done
		# end row
		out+=$'\n'
	
		# 1st col: benchmark name
		out+="$benchmark "
	
		# remaining cols: underyling zip file, extracted from underlying rpt file
		for team in "${!teams[@]}"; do

			# list for a) all or b) only for selected teams
			if [[ "$teams_list" != $ND ]]; then
				if [[ "$teams_list" != *"$team"* ]]; then
					continue
				fi
			fi

			if [[ $(cat $log | grep $benchmark | grep -q $team; echo $?) == 0 ]]; then

				string=$(cat $log | grep $benchmark | grep $team | tail -n 1)
				out+=${string%/reports/scores.rpt}
				out+=".zip"
				out+=" "
			else
				out+="$ND "
			fi
		done
		# end row
		out+=$'\n'
	done
	
	# print as table
	# NOTE quotes are required here for proper newline handling (https://stackoverflow.com/a/3182519)
	echo "$out" | column -t
fi
