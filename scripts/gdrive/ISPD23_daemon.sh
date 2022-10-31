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
teams_root_folder="$local_root_folder/data/$round"
scripts_folder="$local_root_folder/scripts/eval"
#NOTE this currently points to the ISPD22 benchmarks, via sym link
baselines_root_folder="$local_root_folder/benchmarks/__release/__$round"

## benchmarks
##
#TODO to be updated to new alpha benchmarks
#TODO integrate procedure to init related folders on Gdrive for participants folders
benchmarks="AES_1 AES_2 AES_3 Camellia CAST MISTY openMSP430_1 PRESENT SEED TDEA"
## (TODO) use this for testing
#benchmarks="PRESENT"

## emails
##
## NOTE use pipe as separator!
## NOTE at least one email must be given (otherwise grep -Ev used below will exclude all)
emails_excluded_for_notification="ispd23contest.drive@gmail.com"

## innovus
##
innovus_bin="innovus"
# NOTE as above, use pipe as separate and provide at least one term
# NOTE 'IMPOAX' errors are related to OA loading, which is no reason to kill; OA is not used
# NOTE 'IMPEXT' errors are related to LEF/DEF parsing and DRCs, which is no reason to kill.
	#TODO Are there other errors for IMPEXT?
	#TODO kill for DRCs this year, or handle via eval script?
innovus_errors_excluded_for_checking="IMPOAX|IMPEXT"
# NOTE as above, use pipe as separate and provide at least one term
innovus_errors_for_checking="ERROR|StackTrace"

## benchmarks and file handlers
##
## NOTE only to be changed if you know what you're doing
#TODO revise into one script, lef, etc. for ASAP7
benchmarks_10_metal_layers="AES_1 AES_2 AES_3"
benchmarks_6_metal_layers="Camellia CAST CEP MISTY openMSP430_1 openMSP430_2 PRESENT SEED SPARX TDEA"
scripts_regions="exploit_eval.tcl exploit_eval.sh exploit_regions.tcl exploit_regions_metal1--metal6.tcl post_process_exploit_regions.sh"
scripts_probing="probing_CUHK.tcl probing.sh probing_eval summarize_assets.tcl"
scripts_eval="check.tcl lec.do init_eval.tcl design_cost.sh scores.sh check_pins.sh check_pg.sh pg.tcl pg_procedures.tcl"
scripts="$scripts_regions $scripts_probing $scripts_eval"
##################

# 1st, get all Google folders from the google root folder
echo "0) Working on round \"$round\" ..."
echo "0)  Checking Google root folder \"$google_root_folder\" ..."

## query drive for root folder, extract columns 1 and 2 from response
## store into associative array; key is google file/folder ID, value is actual file/folder name
#
declare -A google_team_folders
while read -r a b; do
	google_team_folders[$a]=$b
# (TODO) use this to work on __test folder only
done < <(./gdrive list --no-header -q "parents in '$google_root_folder' and trashed = false and name = '__test'" | awk '{print $1" "$2}')
## (TODO) use this to work on other folders only
#done < <(./gdrive list --no-header -q "parents in '$google_root_folder' and trashed = false and name = 'NTUsplace'" | awk '{print $1" "$2}')
## (TODO) use this for actual runs
#done < <(./gdrive list --no-header -q "parents in '$google_root_folder' and trashed = false" | awk '{print $1" "$2}')

echo "0)   Found ${#google_team_folders[@]} folders, one for each team"

# init arrays for constant folders, helpful for faster gdrive accesses
#
echo "0)   Init all Google folder IDs/references locally ..."

## key syntax: "$team:$benchmark"
declare -A google_benchmark_folders
## key syntax: "$team"
declare -A google_share_emails

## iterate over keys / google IDs
for google_team_folder in "${!google_team_folders[@]}"; do

	team="${google_team_folders[$google_team_folder]}"

	google_round_folder=$(./gdrive list --no-header -q "parents in '$google_team_folder' and trashed = false and name = '$round'" | awk '{print $1}')

	# NOTE the last grep is to filter out non-email entries, 'False' in particular (used by gdrive for global link sharing), which cannot be considered otherwise in the -E expression
	google_share_emails[$team]=$(./gdrive share list $google_round_folder | tail -n +2 | awk '{print $4}' | grep -Ev "$emails_excluded_for_notification" | grep '@')

	for benchmark in $benchmarks; do

		id="$team:$benchmark"

		google_benchmark_folders[$id]=$(./gdrive list --no-header -q "parents in '$google_round_folder' and trashed = false and name = '$benchmark'" | awk '{print $1}')
	done
done

# init corresponding local folders, using the value (actual name)
#
echo "0)   Init corresponding local folders in $teams_root_folder/ ..."

## iterate over values / actual names
for team in "${google_team_folders[@]}"; do

	for benchmark in $benchmarks; do
		mkdir -p $teams_root_folder/$team/$benchmark/downloads
		mkdir -p $teams_root_folder/$team/$benchmark/work
		mkdir -p $teams_root_folder/$team/$benchmark/backup_work
		mkdir -p $teams_root_folder/$team/$benchmark/uploads

		touch $teams_root_folder/$team/$benchmark/downloads/dl_history
	done
done

echo "0)"
echo "0) Done"
echo ""

## continuous loop: file downloads, script runs, file uploads
#
#(TODO) for early errors like file init or so, short-cut and directly upload
while true; do

	echo "1) Check status of ongoing evaluation processing, if any ..."
	echo "1)  Time: $(date)"
	echo "1)  Time stamp: $(date +%s)"
	check_eval
#(TODO) log how many still running, how many done
	echo "1)"
	echo "1) Done"
	echo ""

	echo "2) Upload new results, if any ..."
	echo "2)  Time: $(date)"
	echo "2)  Time stamp: $(date +%s)"
	echo "2)"
	google_uploads
#(TODO) log how many uploads, how many failed
	echo "2) Done"
	echo ""

##NOTE use for deadline mode
#	#https://epoch.vercel.app
#	#2022-03-30 21:00:00 GST (UTC+4)
#	if [[ $(date +%s) < 1648659600 ]]; then

		echo "3) Download new submissions, if any ..."
		echo "3)  Time: $(date)"
		echo "3)  Time stamp: $(date +%s)"
		echo "3)"
		google_downloads
#(TODO) log how many downloaded, how many failed
		echo "3)"
		echo "3) Done"
		echo ""

		echo "4) Start evaluation processing of newly downloaded submission files, if any ..."
		echo "4)  Time: $(date)"
		echo "4)  Time stamp: $(date +%s)"
		echo "4)"
		start_eval
#(TODO) log how many started, how many based checks
		echo "4) Done"
		echo ""

#	else
#		echo "3, 4) Deadline passed -- no more downloads and start of evaluation ..."
#		echo "3, 4)"
#		echo ""
#	fi

	echo "5) Sleep/wait for $check_interval s ..."
	echo "5)  Time: $(date)"
	echo "5)  Time stamp: $(date +%s)"
	echo "5)"
	echo "5) Sleeping ..."
	sleeping $check_interval
	echo "5) Done"
	echo ""
done
