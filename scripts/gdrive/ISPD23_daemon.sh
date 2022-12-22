#!/bin/bash

source ISPD23_daemon_procedures.sh

# settings
##################

## misc key parameters
##
round="alpha"
## wait b/w cycles [s]
check_interval="60"
## max runs allowed in parallel per team
max_parallel_runs="6"
## max uploads allowed to be started in parallel; based on experience of load behaviour w/ Google drive
max_parallel_uploads="10"
## margin/tolerance for soft constraints to be classified as errors
issues_margin="10"

## folders
##
google_root_folder="1G1EENqSquzCQbxI1Ij-4vbD8C3yrC_FF"
google_json_file="$HOME/.config/gdrive/USERNAME_v2.json"
local_root_folder="$HOME/nyu_projects/ISPD23"
tmp_root_folder="$local_root_folder/data/tmp/"
teams_root_folder="$local_root_folder/data/$round"
scripts_folder="$local_root_folder/scripts/eval"
baselines_root_folder="$local_root_folder/benchmarks/_release/_$round"

## library files
##
## NOTE no need to specificy separately; all files in $bench/ASAP7 folder are considered automatically
#lib_files="asap7sc7p5t_AO_LVT_TT_nldm_211120.lib asap7sc7p5t_AO_SLVT_TT_nldm_211120.lib asap7sc7p5t_INVBUF_LVT_TT_nldm_220122.lib asap7sc7p5t_INVBUF_SLVT_TT_nldm_220122.lib asap7sc7p5t_OA_LVT_TT_nldm_211120.lib asap7sc7p5t_OA_SLVT_TT_nldm_211120.lib asap7sc7p5t_SEQ_LVT_TT_nldm_220123.lib asap7sc7p5t_SEQ_SLVT_TT_nldm_220123.lib asap7sc7p5t_SIMPLE_LVT_TT_nldm_211120.lib asap7sc7p5t_SIMPLE_SLVT_TT_nldm_211120.lib"
#lef_files="asap7_tech_4x_201209.lef asap7sc7p5t_28_L_4x_220121a.lef asap7sc7p5t_28_R_4x_220121a.lef asap7sc7p5t_28_SL_4x_220121a.lef"
#qrc_file="qrcTechFile_typ03_scaled4xV06"

## benchmarks
##
benchmarks="aes camellia cast misty seed sha256"
## NOTE use this for testing
#benchmarks="aes"
## NOTE will be set automatically via initialize()
benchmarks_string_max_length="0"
teams_string_max_length="0"

## emails
##
## NOTE use pipe as separator!
## NOTE at least one email must be given (otherwise grep -Ev used below will exclude all)
emails_excluded_for_notification="ispd23contest.drive@gmail.com|jk176@nyu.edu"

## Innovus
##
# NOTE as above, use pipe as separate and provide at least one term
innovus_errors_for_checking="ERROR|StackTrace|INTERRUPT"
# NOTE as above, use pipe as separate and provide at least one term
# NOTE 'IMPOAX' errors are related to OA loading, which is no reason to kill; OA is not used
# NOTE 'IMPEXT' errors are related to LEF/DEF parsing and DRCs, which is no reason to kill; should be reported as error though for design checks
# NOTE 'IMPPP' errors are related to the check_design command, which is no reason to kill; should be reported as error though for design checks
# NOTE '@file' lines source the tcl file that is executed, both commands as well as comments; shouldn't be checked
# since comments can contain keywords like ERROR etc -- could be dropped now that CDS_STYLUS_SOURCE_VERBOSE=0 is used
innovus_errors_excluded_for_checking="IMPOAX|IMPEXT|IMPPP|@file"
#
## NOTE use to disable verbose copying of script commands and comments into log file
#export CDS_STYLUS_SOURCE_VERBOSE=0

## LEC
##
# NOTE as above, use pipe as separate and provide at least one term
lec_errors_for_checking="Error|StackTrace|License check failed!"

## benchmarks and file handlers
##
## NOTE only to be changed if you know what you're doing
scripts_sec_first_order="exploitable_regions.bin exploitable_regions.tcl"
scripts_des="check.tcl mmmc.tcl lec.do design_cost.sh scores.sh check_pins.sh check_pg.sh pg.tcl pg_procedures.tcl summarize_assets.tcl"
scripts_des="check.tcl mmmc.tcl lec.do scores.sh"
scripts="$scripts_sec_first_order $scripts_des"
##################

# initializing

## main data structures

# key: Google ID; value: team name
declare -A google_team_folders

# key: internal id; value: Google ID
# syntax for key: team---benchmark
declare -A google_benchmark_folders

# key: team name; value: emails of all accounts having shared access to the team folder
declare -A google_share_emails

# key: internal id; value: queued runs
# syntax for key: team---benchmark
declare -A runs_queued

echo "ISPD23 -- 0)"
echo "ISPD23 -- 0) Initialize work on round \"$round\" ..."

# NOTE this expects the team folder in the Google root drive and, to begin with, an empty subfolder for the current
# round. The related benchmark sub-subfolders will be initialized by this script
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

		echo "ISPD23 -- 1)"
		echo "ISPD23 -- 1) Done"
		echo "ISPD23 -- "


		echo "ISPD23 -- 2) Start evaluation processing of newly downloaded submission files, if any ..."
		echo "ISPD23 -- 2)  Time: $(date)"
		echo "ISPD23 -- 2)  Time stamp: $(date +%s)"
		echo "ISPD23 -- 2)"

		start_eval

		echo "ISPD23 -- 2)"
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

	echo "ISPD23 -- 3)"
	echo "ISPD23 -- 3) Done"
	echo "ISPD23 -- "


	echo "ISPD23 -- 4) Upload new results, if any ..."
	echo "ISPD23 -- 4)  Time: $(date)"
	echo "ISPD23 -- 4)  Time stamp: $(date +%s)"
	echo "ISPD23 -- 4)"

	google_uploads

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
