#!/bin/bash

# settings
##########
local_root_folder="$HOME/work/materials/ISPD22"
round="alpha"
benchmarks="AES_1 AES_2 AES_3 Camellia CAST MISTY PRESENT"
#benchmarks="AES_1 AES_2 AES_3"
scripts="post_process_probing_cells.sh post_process_probing_nets.sh"
##########

work_folder="$local_root_folder/benchmarks/__release/__$round"
scripts_folder="$local_root_folder/scripts/eval"

echo "1) Initialize the scripts in following folder ..."
echo "1)  $work_folder"

# NOTE will loose local edits; not good
# NOTE will not restart itself after possibly updated; not useful
#	cd $scripts_folder;
#	git pull
#	git checkout .

	cd $work_folder;
	cd ../
#TODO add as parameter
#	rm -rf __$round;
	git pull
	git checkout .

	for benchmark in $benchmarks; do

		cd $work_folder/$benchmark/reports

		for script in $scripts; do
			ln -sf $scripts_folder/$script .
		done
	done

echo "1) Done"
echo ""

echo "2) Run baseline evaluations ..."

	for benchmark in $benchmarks; do

		echo "2)  Run scripts for benchmark \"$benchmark\" ..."

		## start frame of code to be run in parallel
		## https://unix.stackexchange.com/a/103921
		(
			cd $work_folder/$benchmark/reports

			for script in $scripts; do
				source $script
			done

		## end frame of code to be run in parallel
		) &
	done
	# wait until parallel runs are done
	wait

echo "2) Done"
echo ""
