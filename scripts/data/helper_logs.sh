#!/bin/bash

metric=$1

if [[ $metric == "" ]]; then
	echo "ERROR: provide 'metric' as 1st parameter."
	exit 1
fi

list_files=0
real_team_names=0
score_related_to_OVERALL=1

days_back=28

# March 28th, 00:00 AM UTC
timestamp=1679961600

results_folder="logs/final"
mkdir -p $results_folder

for ((day=1; day<=$days_back; day++)); do

	../../../scripts/eval/scores/ranking.sh $metric $list_files $real_team_names $timestamp $score_related_to_OVERALL | tee $results_folder/$metric"."$timestamp".log"

	((timestamp = timestamp - 86400))
done
