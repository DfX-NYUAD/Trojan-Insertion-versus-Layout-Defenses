#!/bin/bash

source ISPD23_daemon_procedures.sh

# settings
##################

## misc key parameters
##
round="alpha"
## wait b/w cycles [s]
check_interval="60"
## max runs allowed to be started in parallel per team
max_parallel_runs="3"
## max uploads allowed to be started in parallel
max_parallel_uploads="10"

## folders
##
google_root_folder="1G1EENqSquzCQbxI1Ij-4vbD8C3yrC_FF"
local_root_folder="$HOME/nyu_projects/ISPD23"
tmp_root_folder="$local_root_folder/data/tmp/"
teams_root_folder="$local_root_folder/data/$round"
scripts_folder="$local_root_folder/scripts/eval"
#NOTE this currently points to the ISPD22 benchmarks, via sym link
baselines_root_folder="$local_root_folder/benchmarks/__release/__$round"

## library
##
#TODO check for multiple files, separated by space
lib_files="NangateOpenCellLibrary.lib"
lef_files="NangateOpenCellLibrary.lef"

## benchmarks
##
#TODO to be updated to new alpha benchmarks
benchmarks="AES_1 AES_2 AES_3 Camellia CAST MISTY openMSP430_1 PRESENT SEED TDEA"
## NOTE use this for testing
#benchmarks="PRESENT"

## emails
##
## NOTE use pipe as separator!
## NOTE at least one email must be given (otherwise grep -Ev used below will exclude all)
emails_excluded_for_notification="ispd23contest.drive@gmail.com"

## Innovus
##
innovus_bin="innovus"
# NOTE as above, use pipe as separate and provide at least one term
# NOTE 'IMPOAX' errors are related to OA loading, which is no reason to kill; OA is not used
# NOTE 'IMPEXT' errors are related to LEF/DEF parsing and DRCs, which is no reason to kill.
# NOTE '@file' lines source the tcl file that is executed, both commands as well as comments; shouldn't be checked since comments can contain keywords like ERROR etc
	#(TODO) Are there other errors for IMPEXT?
	#TODO kill for DRCs this year, or handle via eval script?
innovus_errors_excluded_for_checking="IMPOAX|IMPEXT|@file"
# NOTE as above, use pipe as separate and provide at least one term
innovus_errors_for_checking="ERROR|StackTrace"

## LEC
##
lec_bin="lec_64"
# NOTE as above, use pipe as separate and provide at least one term
lec_errors_for_checking="Error|StackTrace|License check failed!"

## benchmarks and file handlers
##
## NOTE only to be changed if you know what you're doing
#TODO revise into one script, lef, etc. for ASAP7
benchmarks_10_metal_layers="AES_1 AES_2 AES_3"
benchmarks_6_metal_layers="Camellia CAST CEP MISTY openMSP430_1 openMSP430_2 PRESENT SEED SPARX TDEA"
scripts_regions="exploit_eval.tcl exploit_eval.sh exploit_regions.tcl exploit_regions_metal1--metal6.tcl post_process_exploit_regions.sh"
scripts_eval="check.tcl lec.do init_eval.tcl design_cost.sh scores.sh check_pins.sh check_pg.sh pg.tcl pg_procedures.tcl summarize_assets.tcl"
scripts="$scripts_regions $scripts_eval"
##################

# initializing

## main data structures

# key: google IDs; value: team names
declare -A google_team_folders

# syntax for key: "$team:$benchmark"
declare -A google_benchmark_folders

# key: $team
declare -A google_share_emails

echo "ISPD23 -- 0)"
echo "ISPD23 -- 0) Initialize work on round \"$round\" ..."

# NOTE this expects the team folder in the Google root drive and, to begin with, an empty subfolder for the current
# round. The related benchmark sub-subfolders will be initialized by this scrip
initialize

echo "ISPD23 -- 0)"
echo "ISPD23 -- 0) Done"
echo "ISPD23 -- "

## continuous loop: file downloads, script runs, file uploads
#
while true; do

##NOTE use for deadline mode
#	#https://epoch.vercel.app
#	#2022-03-30 21:00:00 GST (UTC+4)
#	if [[ $(date +%s) < 1648659600 ]]; then

		echo "ISPD23 -- 1) Download new submissions, if any ..."
		echo "ISPD23 -- 1)  Time: $(date)"
		echo "ISPD23 -- 1)  Time stamp: $(date +%s)"
		echo "ISPD23 -- 1)"

		google_downloads

		#(TODO) log how many downloaded, how many failed

		echo "ISPD23 -- 1)"
		echo "ISPD23 -- 1) Done"
		echo "ISPD23 -- "


		echo "ISPD23 -- 2) Start evaluation processing of newly downloaded submission files, if any ..."
		echo "ISPD23 -- 2)  Time: $(date)"
		echo "ISPD23 -- 2)  Time stamp: $(date +%s)"
		echo "ISPD23 -- 2)"

		start_eval

		#(TODO) log how many started, how many passed checks, how many running detailed eval

		echo "ISPD23 -- 2) Done"
		echo "ISPD23 -- "

#	else
#		echo "ISPD23 -- 1, 2) Deadline passed -- no more downloads and start of evaluation ..."
#		echo "ISPD23 -- 1, 2)"
#		echo "ISPD23 -- "
#	fi

	echo "ISPD23 -- 3) Check status of ongoing evaluation processing, if any ..."
	echo "ISPD23 -- 3)  Time: $(date)"
	echo "ISPD23 -- 3)  Time stamp: $(date +%s)"

	check_eval

	#(TODO) log how many still running, how many done

	echo "ISPD23 -- 3)"
	echo "ISPD23 -- 3) Done"
	echo "ISPD23 -- "


	echo "ISPD23 -- 4) Upload new results, if any ..."
	echo "ISPD23 -- 4)  Time: $(date)"
	echo "ISPD23 -- 4)  Time stamp: $(date +%s)"
	echo "ISPD23 -- 4)"

	google_uploads

	#(TODO) log how many uploads, how many failed

	echo "ISPD23 -- 4) Done"
	echo "ISPD23 -- "


	echo "ISPD23 -- 5) Sleep/wait for $check_interval s ..."
	echo "ISPD23 -- 5)  Time: $(date)"
	echo "ISPD23 -- 5)  Time stamp: $(date +%s)"
	echo "ISPD23 -- 5)"
	echo "ISPD23 -- 5) Sleeping ..."

	sleeping $check_interval

	echo "ISPD23 -- 5) Done"
	echo "ISPD23 -- "
done
