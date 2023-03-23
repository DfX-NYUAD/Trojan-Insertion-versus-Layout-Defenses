#!/bin/bash

src=$1
dst=$2

if [[ $src == "" ]]; then
	echo "Provide \"src\" as 1st parameter."
	exit 1
fi
if [[ $dst == "" ]]; then
	echo "Provide \"dst\" as 2nd parameter."
	exit 1
fi

for team in $src/*; do

	if [[ $team == "_production" || $team == "_test" ]]; then
		continue
	fi

	team_=${team#*/}
#	echo $team_

	for des in $team/*; do

		des_=${des#*/}
#		echo $des_

		for run in $des/backup_work/*; do

			if [[ $run == *".zip" || $run != *"downloads"* ]]; then
				continue
			fi

			if [[ -e $run/reports/errors.rpt ]]; then
				continue
			fi

			echo $run

			run_=${run##*/}

			dst_=$dst/$des_/downloads/$run_

			mkdir -p $dst_

			unzip -j $run".zip" \*/\*.{def,v} -d $dst_
			find $dst_ -type l -delete
			rm $dst_/design.*{reg,adv,adv2}*.{def,v}
		done
	done
done
