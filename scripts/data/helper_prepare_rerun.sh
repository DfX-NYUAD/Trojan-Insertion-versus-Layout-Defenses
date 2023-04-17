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

		des_=${des##*/}
#		echo $des_

		for run in $des/backup_work/*; do

			if [[ $run == *".zip" || $run != *"downloads"* ]]; then
				continue
			fi

			if ! [[ -e $run/reports/errors.rpt ]]; then
				continue
			fi

			echo $run

# NOTE custom code for MAR re-runs

file=$run/reports/errors.rpt

if [[ $(grep DRC $file | wc -l) != 0 ]]; then

	if [[ $(grep MAR ${file%*errors.rpt}*geom.rpt | wc -l) != 0 ]]; then

		total_vios=$(grep "Total Violations :" ${file%*errors.rpt}*.geom.rpt | awk '{print $(NF-1)}')
		MAR_vios=$(grep MAR ${file%*errors.rpt}*geom.rpt | wc -l)

		if [[ $total_vios != $MAR_vios ]]; then
			continue
		fi
	else
		continue
	fi
else
	continue
fi

echo $run
echo "Total violations: $total_vios"
echo "MAR violations: $MAR_vios"

read -p 'Re-run this? : ' con

if [[ $con == "y" || $con == "Y" ]]; then
			run_=${run##*/}

			dst_=$dst/$des_/downloads/$run_

#			echo $run_
#			echo $dst_

			mkdir -p $dst_

			unzip -j $run".zip" \*/\*.{def,v} -d $dst_
			find $dst_ -type l -delete
			rm $dst_/design.*{reg,adv,adv2}*.{def,v}
fi
		done
	done
done
