#!/bin/bash

# settings
##########
local_root_folder="$HOME/ISPD22"
round="alpha"
benchmarks="AES_1 AES_2 AES_3 Camellia CAST MISTY PRESENT"
scripts="probing.tcl probing_procs.tcl probing_cells.tcl probing_nets.tcl"
##########

work_folder="$local_root_folder/benchmarks/__release/__$round"
scripts_folder="$local_root_folder/scripts/eval"

#echo "1) Clean and initialize the following folders ..."
#echo "1)  $work_folder"
#echo "1)  $scripts_folder"
#
#	cd $scripts_folder;
#	git pull
#	git checkout .
#
#	cd $work_folder;
#	cd ../
#	rm -rf __$round;
#	git pull
#	git checkout .
#
#	for benchmark in $benchmarks; do
#
#		cd $work_folder/$benchmark
#
#		for script in $scripts; do
#			ln -s $scripts_folder/$script .
#		done
#	done
#
#echo "1) Done"
#echo ""

echo "2) Run baseline evaluations ..."

for benchmark in $benchmarks; do

	echo "2)  Run Innovus scripts for benchmark \"$benchmark\" ..."

	## start frame of code to be run in parallel
	## https://unix.stackexchange.com/a/103921
	(
		cd $work_folder/$benchmark

		innovus -files probing_nets.tcl -log probing_nets
		mv nets_ea.rpt reports/

	## stop actual work stuff
	) &
done
wait

echo "2) Done"
echo ""
