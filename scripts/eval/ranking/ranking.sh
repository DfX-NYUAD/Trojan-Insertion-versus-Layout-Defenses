#!/bin/bash

######################
# 0) settings, init
######################

list_rpts_default=1
team_real_name_default=1
score_related_OVERALL_default=1
settings="../../gdrive/ISPD23_daemon.settings"

if [ $# -lt 1 ]; then
	echo "Parameters required:"
	echo "1) Metric -- pick one from those available in the scores.rpt files, e.g., OVERALL"
	echo "Parameters optional:"
	echo "2) List related rpt files -- 0: no; 1: yes -- default is $list_rpts_default"
	echo "3) Team names -- 0: anonymous label; 1: actual names -- default is $team_real_name_default"
	echo "4) Score related to OVERALL -- 0: no, means that best score is selected (for the metric of choice) independently of OVERALL score; 1: yes, means that best score (for the metric of choice) is extracted for run w/ best OVERALL score -- default is $score_related_OVERALL_default"
	echo "5) Path for ISPD23_daemon.settings file -- default is $settings"
	exit
fi

# associative array w/ teams and anon IDs
declare -A teams
teams[_test]=A

# other settings
ND="--------"
metric="$1"

# tmp log file; used for keeping track of best runs
rpts=/tmp/$metric"_"$(date +%s).log

# call parameters 
if [[ $2 != "" ]]; then
	list_rpts=$2
else
	list_rpts=$list_rpts_default
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
	source $5
else
	source $settings
fi

echo "Parameters:"
echo " Metric: $1"
echo " List related rpt files: $list_rpts"
echo " Team names: $team_real_name"
echo " Score related to OVERALL: $score_related_OVERALL"
echo " Path for ISPD23_daemon.settings file: $settings"
echo

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

	# init dedicated arrays for each team

	echo " Extracting best scores (i.e., min value) for team $team ..."

	## some characters are not supported for bash var; replace them
	team_=$(echo $team | sed -e 's/-/_/g')

	## init arrays
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

				# also log the rpt file
				echo $backup_work/$run/reports/scores.rpt >> $rpts
			fi
			## NOTE in this mode, the actual min score should only be initialized when also the OVERALL min score is already initialized
			if [[ $score_related_OVERALL == 1 ]]; then

				if [[ "$score_min" == $ND ]]; then
					if [[ "$score_OVERALL_min" != $ND ]]; then

						eval $array_name[$benchmark]=$score_curr

						# also log the rpt file
						echo $backup_work/$run/reports/scores.rpt >> $rpts

						continue
					fi
				fi

			## NOTE else, the actual score can be initialized anytime
			else 
				if [[ "$score_min" == $ND ]]; then

					eval $array_name[$benchmark]=$score_curr

					# also log the rpt file
					echo $backup_work/$run/reports/scores.rpt >> $rpts

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

						# also log the rpt file
						echo $backup_work/$run/reports/scores.rpt >> $rpts
					fi
				fi

			## NOTE else, the actual min score is updated any time 
			else

				# actual floating point comparison, using bc
				if (( $(echo "$score_curr < $score_min" | bc -l) )); then

					eval $array_name[$benchmark]=$score_curr

					# also log the rpt file
					echo $backup_work/$run/reports/scores.rpt >> $rpts
				fi
			fi

#			# dbg
#			echo "Benchmark $benchmark -- score_curr: $score_curr; score_min: $(eval echo \${$array_name[$benchmark]})"
		done
	done

#	echo "Done"

done
echo "Done"
echo

######################
# 2) print scores
######################

## 1st row: header
out=""
out+="Benchmark "
#out+="Baseline "
for team in "${!teams[@]}"; do

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
# 3) print files
######################

if [[ $list_rpts == 1 ]]; then

	echo
	echo "Underlying report files:"
	echo

	out=""
	out+="Benchmark "
	for team in "${!teams[@]}"; do
	
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

			out+=$(cat $rpts | grep $benchmark | grep $team | tail -n 1)
		done
		# end row
		out+=$'\n'
	done
	
	# print as table
	# NOTE quotes are required here for proper newline handling (https://stackoverflow.com/a/3182519)
	echo "$out" | column -t
fi

# cleanup
rm $rpts
