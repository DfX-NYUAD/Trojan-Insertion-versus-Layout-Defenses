#!/bin/bash

metric=$1
if [[ $metric == "" ]]; then
	echo "ERROR: provide 'metric' as 1st parameter."
	exit 1
fi

des=$2
if [[ $des == "" ]]; then
	echo "ERROR: provide 'des' as 2nd parameter."
	exit 1
fi

term=$3
if [[ $term == "" ]]; then
	echo "WARNING: 'term' not provided; setting to ''Best scores'' a default."
	term="Best scores"
fi

list_files=0
real_team_names=0
score_related_to_OVERALL=1

days_back=28

# March 28th, 00:00 AM UTC
timestamp=1679961600

results_folder="logs/final"

# header
ack "$term" -A 9 $results_folder/$metric"."$timestamp".log" | head -n 4 | tail -n 1

for ((day=$days_back-1; day>=0; day--)); do

	((timestamp_ = timestamp - (day*86400)))

#	echo $timestamp_

	# selected design
	ack "$term" -A 9 $results_folder/$metric"."$timestamp_".log" | grep $des
done
