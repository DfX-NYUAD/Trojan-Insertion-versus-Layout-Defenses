#!/bin/bash

##################
# settings
##################

if [ $# -lt 1 ]; then
	echo "Parameters required:"
	echo "1) Score -- pick from the following: des_issues OVERALL des_perf des des_area fsp_fi_ea_n ti_sts fsp_fi_ea_c ti_fts fsp_fi ti des_p_total"
	echo "Parameters optional:"
	echo "2) List related rpt files -- 0: no; 1: yes -- default is 1"
	echo "3) Team names -- 0: anonymous label; 1: actual names -- default is 0"
	echo "4) Include blind benchmarks -- 0: no; 1: yes -- default is 0"
	echo "5) Score related to OVERALL -- 0: no, means best score is selected independent of OVERALL score; 1: yes, means best score is extracted for run w/ best OVERALL score -- default is 1"
	exit
fi

round="final"
local_root_folder="$HOME/ISPD22"
teams_root_folder="$local_root_folder/data/$round"
baselines_root_folder="$local_root_folder/benchmarks/__release/__$round"

benchmarks="AES_1 AES_2 AES_3 Camellia CAST MISTY openMSP430_1 PRESENT SEED TDEA"
benchmarks_blind="openMSP430_2 SPARX"

# associative array w/ teams still in final round but the same anon team ID from alpha round
declare -A teams
teams[CUEDA]=A
teams[NTUsplace]=E
teams[Seo]=J
teams[TalTech]=K
teams[TCLAB]=L
teams[UT_pda]=N
teams[XDSecurity]=O
teams[DASYS]=Q

ND="--------"
grep_term="$1:"

if [[ $2 != "" ]]; then
	list_rpts=$2
else
	list_rpts=1
fi

if [[ $3 != "" ]]; then
	team_real_name=$3
else
	team_real_name=0
fi

if [[ $4 != "" ]]; then
	include_blind_benchmarks=$4
else
	include_blind_benchmarks=0
fi

if [[ $5 != "" ]]; then
	score_related_OVERALL=$5
else
	score_related_OVERALL=1
fi

##################

if [[ $include_blind_benchmarks == 1 ]]; then
	benchmarks=$benchmarks" $benchmarks_blind"
fi

rpts=/tmp/$grep_term"_"$(date +%s).rpts

######
# 1) obtain stats
######

echo "Extracting scores ..."

declare -A scores_baseline
for benchmark in $benchmarks; do

	## NOTE baseline is baseline; here we don't need to differentiate b/w best score related to OVERALL or not
	scores_baseline[$benchmark]=$(grep -w "$grep_term" $baselines_root_folder/$benchmark/reports/scores.rpt | tail -n 1 | awk '{print $2}')
done

# iterate over keys
for team in "${!teams[@]}"; do

	# init dedicated arrays for each team

#	echo "Extracting min scores for team $team ..."

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
			if ! [[ -e $backup_work/$run/scores.rpt ]] ; then
				continue
			fi

			## extract scores
			score_OVERALL_curr=$(grep -w "OVERALL" $backup_work/$run/scores.rpt | tail -n 1 | awk '{print $2}')
			score_curr=$(grep -w "$grep_term" $backup_work/$run/scores.rpt | tail -n 1 | awk '{print $2}')

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
				echo $backup_work/$run/scores.rpt >> $rpts
			fi
			## NOTE in this mode, the actual min score should only be initialized when also the OVERALL min score is already initialized
			if [[ $score_related_OVERALL == 1 ]]; then

				if [[ "$score_min" == $ND ]]; then
					if [[ "$score_OVERALL_min" != $ND ]]; then

						eval $array_name[$benchmark]=$score_curr

						# also log the rpt file
						echo $backup_work/$run/scores.rpt >> $rpts

						continue
					fi
				fi

			## NOTE else, the actual score can be initialized anytime
			else 
				if [[ "$score_min" == $ND ]]; then

					eval $array_name[$benchmark]=$score_curr

					# also log the rpt file
					echo $backup_work/$run/scores.rpt >> $rpts

					continue
				fi
			fi

			# update min score
			## NOTE in this mode, the actual min score is dictated by whatever actual score value is there for the OVERALL min score
			if [[ $score_related_OVERALL == 1 ]]; then

				# actual floating point comparison, using bc
				# NOTE in this mode, we want to check for any solution with at least as best OVERALL score, not only better ones (the latter would likely exclude submissions that improve on actual score)
				if (( $(echo "$score_OVERALL_curr <= $score_OVERALL_min" | bc -l) )); then

#					echo $run
#					echo " $score_OVERALL_curr <= $score_OVERALL_min"

					eval $array_name_OVERALL[$benchmark]=$score_OVERALL_curr

					## update actual score for improvements of actual score itself or for overall score (for the latter case we would reset the actual score)
					if (( $(echo "$score_curr < $score_min" | bc -l) || $(echo "$score_OVERALL_curr < $score_OVERALL_min" | bc -l))); then
#						echo "  $score_curr <= $score_min"

						eval $array_name[$benchmark]=$score_curr

						# also log the rpt file
						echo $backup_work/$run/scores.rpt >> $rpts
					fi
				fi

			## NOTE else, the actual min score is updated any time 
			else

				# actual floating point comparison, using bc
				if (( $(echo "$score_curr < $score_min" | bc -l) )); then

					eval $array_name[$benchmark]=$score_curr

					# also log the rpt file
					echo $backup_work/$run/scores.rpt >> $rpts
				fi
			fi

#			echo "Benchmark $benchmark -- score_curr: $score_curr; score_min: $(eval echo \${$array_name[$benchmark]})"
		done
	done

#	echo "Done"
done
echo "Done"
echo

######
# 2) print stats
######

## 1st row: header
echo -n "Team/Benchmark	"
echo -n "Baseline	"
for team in "${!teams[@]}"; do

	# real or anon team name
	if [[ $team_real_name == 1 ]]; then
		echo -n "$team	"
	else
		echo -n "${teams[$team]}	"
	fi
done
# end row
echo

## build up rows, one per benchmark
for benchmark in $benchmarks; do

	# 1st col: benchmark name
	echo -n "$benchmark	"

	# 2nd col: baseline scores
	echo -n "${scores_baseline[$benchmark]}	"

	# remaining cols: team scores
	for team in "${!teams[@]}"; do

		## some characters are not supported for bash var; replace them
		team_=$(echo $team | sed -e 's/-/_/g')
		array_name="scores_$team_"

		scores_string=$(eval echo \${$array_name[$benchmark]})
		echo -n "$scores_string	"
	done
	# end row
	echo
done

if [[ $list_rpts == 1 ]]; then
	echo
	echo "Underlying rpt files/runs:"
	## also print the underlying rpt files
	for benchmark in $benchmarks; do
		for team in "${!teams[@]}"; do
			cat $rpts | grep $benchmark | grep $team | tail -n 1
		done
	done
fi
