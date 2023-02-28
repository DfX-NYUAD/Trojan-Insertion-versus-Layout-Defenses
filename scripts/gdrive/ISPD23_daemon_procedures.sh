#!/bin/bash

####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD
#
####

google_fix_json() {

	## for some reason, probably race condition or other runtime conflict, the gdrive tool sometimes messes up the
	## syntax when handling/updating the json file
	## the issue is simply "}}" instead of "}" -- simple fixing via sed
	sed 's/}}/}/g' -i $google_json_file
}

google_quota() {
	local prefix=$1

	## fix, if needed, the json file for current session in json file
	google_fix_json

	status=$(./gdrive about)

	echo $prefix
	## NOTE putting prefix in quotes maintains the leading spaces, which we want; not putting status in quotes drops the linebreaks, as intended
	echo "$prefix"$status
	echo $prefix
}

send_email() {
	local text=$1
	local subject=$2
	local emails=$3

	# unroll emails explicitly; use of ${emails[@]} won't work within larger string
	local emails_string=""
	for email in $emails; do
		emails_string="$emails_string $email"
	done

	# NOTE suppress warnings for certificate issue not recognized (won't fail email sending, more like a warning)
	# but keep any others
	echo -e "$text" | mailx -A ispd23contest -s "$subject" $emails_string 2>&1 | grep -v "Error in certificate: Peer's certificate issuer is not recognized."
}

# https://unix.stackexchange.com/a/415450
progress_bar() {
	local w=1 p=$1;  shift
	# create a string of spaces, then change them to dots
	printf -v dots "%*s" "$(( $p * $w ))" ""; dots=${dots// /.}
	# print those dots on a fixed-width space plus the percentage etc. 
	printf "\r\e[K|%-*s| %3d %% %s" "$w" "$dots" "$p" "$*" #>&2 ## use to write to stderr
}

sleeping() {

	local sleep_interval=$1

	# init; minor delay to allow other regular logs to complete, so as to avoid intermixing of sleeping and regular logs
	sleep 1s
	progress_bar 0

	for ((i=0; i<$sleep_interval; i++)); do

		sleep 1s

		progress_bar $(( 100 * (i+1)/sleep_interval ))
	done

	# final newline to finish progress bar
	echo ""
}

initialize() {

	echo "ISPD23 -- 0)"

	## sanity check for mode
	if [[ "$1" == "testing" ]]; then
		echo "ISPD23 -- 0) Working in \"$1\" mode ..."
	elif [[ "$1" == "production" ]]; then
		echo "ISPD23 -- 0) Working in \"$1\" mode ..."
	else
		echo "ISPD23 -- 0) ERROR: work mode \"$1\" is unrecognized; abort further processing ..."
		exit 1
	fi
	echo "ISPD23 -- 0)"

	echo "ISPD23 -- 0) Initialize work on round \"$round\" ..."
	echo "ISPD23 -- 0)  Time: $(date)"
	echo "ISPD23 -- 0)  Time stamp: $(date +%s)"
	echo "ISPD23 -- 0)"
	
	## query drive for root folder, extract columns 1 and 2 from response
	## store into associative array; key is google file/folder ID, value is actual file/folder name
	
	echo "ISPD23 -- 0)  Checking Google root folder (Google folder ID \"$google_root_folder\") ..."

	## query quota
	google_quota "ISPD23 -- 0)   " 

	## fix, if needed, the json file for current session in json file
	google_fix_json

	if [[ "$1" == "testing" ]]; then

		while read -r a b; do
			google_team_folders[$a]=$b
		done < <(./gdrive list --no-header -q "parents in '$google_root_folder' and trashed = false and (name contains '_test')" | awk '{print $1" "$2}')

#	# NOTE that's the only remaining option, given the check done above, so a simple else suffices
#	elif [[ "$1" == "production" ]]; then

	else
		while read -r a b; do
			google_team_folders[$a]=$b
		done < <(./gdrive list --no-header -q "parents in '$google_root_folder' and trashed = false and not (name contains '_test')" | awk '{print $1" "$2}')
	fi
	
	echo "ISPD23 -- 0)   Found ${#google_team_folders[@]} team folders:"
	for team in "${google_team_folders[@]}"; do
		echo "ISPD23 -- 0)    \"$team\""
	done
	echo "ISPD23 -- 0)"
	
	# init local array for folder references, helpful for faster gdrive access later on throughout all other procedures
	#
	echo "ISPD23 -- 0)   Obtain all Google folder IDs ..."
	
	## iterate over keys / google IDs
	for google_team_folder in "${!google_team_folders[@]}"; do
	
		team="${google_team_folders[$google_team_folder]}"

		echo "ISPD23 -- 0)    Checking for team \"$team\" (Google folder ID \"$google_team_folder\") ..."

		## fix, if needed, the json file for current session in json file
		google_fix_json

		google_round_folder=$(./gdrive list --no-header -q "parents in '$google_team_folder' and trashed = false and name = '$round'" | awk '{print $1}')

		# NOTE the last grep is to filter out non-email entries, 'False' in particular (used by gdrive for global link sharing), which cannot be considered otherwise in the -E expression
		google_share_emails[$team]=$(./gdrive share list $google_team_folder | tail -n +2 | awk '{print $4}' | grep -Ev "$emails_excluded_for_notification" | grep '@')
	
		for benchmark in $benchmarks; do
	
			id_internal="$team---$benchmark"

			## fix, if needed, the json file for current session in json file
			google_fix_json

			# obtain drive references per benchmark
			google_benchmark_folders[$id_internal]=$(./gdrive list --no-header -q "parents in '$google_round_folder' and trashed = false and name = '$benchmark'" | awk '{print $1}')

			# in case the related benchmark folder is missing, create it on the drive
			if [[ ${google_benchmark_folders[$id_internal]} == "" ]]; then

				echo "ISPD23 -- 0)     Init missing Google folder for round \"$round\", benchmark \"$benchmark\" ..."

				## fix, if needed, the json file for current session in json file
				google_fix_json

				# work with empty dummy folders in tmp dir
				mkdir -p $tmp_root_folder/$benchmark
				./gdrive upload -p $google_round_folder -r $tmp_root_folder/$benchmark
				rmdir $tmp_root_folder/$benchmark

				## fix, if needed, the json file for current session in json file
				google_fix_json

				# update the reference for the just created folder
				google_benchmark_folders[$id_internal]=$(./gdrive list --no-header -q "parents in '$google_round_folder' and trashed = false and name = '$benchmark'" | awk '{print $1}')
			fi
		done
	done
	
	# Check corresponding local folders
	#
	echo "ISPD23 -- 0)   Checking local root folder $teams_root_folder/ ..."
	
	## iterate over values / actual names
	for team in "${google_team_folders[@]}"; do

		# generate folders in case they're missing, otherwise no action (no overwrite)
		for benchmark in $benchmarks; do
			mkdir -p $teams_root_folder/$team/$benchmark/downloads
			mkdir -p $teams_root_folder/$team/$benchmark/work
			mkdir -p $teams_root_folder/$team/$benchmark/backup_work
			mkdir -p $teams_root_folder/$team/$benchmark/uploads
	
			touch $teams_root_folder/$team/$benchmark/downloads/dl_history
		done
	done

	## init string vars
	benchmarks_string_max_length=""
	teams_string_max_length=""

	for team in "${google_team_folders[@]}"; do

		if [[ ${#team} -gt $teams_string_max_length ]]; then
			teams_string_max_length=${#team}
		fi
	done

	for benchmark in $benchmarks; do

		if [[ ${#benchmark} -gt $benchmarks_string_max_length ]]; then
			benchmarks_string_max_length=${#benchmark}
		fi
	done

	echo "ISPD23 -- 0)"
	echo "ISPD23 -- 0) Done"
	echo "ISPD23 -- "
}

google_downloads() {

	## query quota
	google_quota "ISPD23 -- 1)  " 

	## iterate over keys / google IDs
	for google_team_folder in "${!google_team_folders[@]}"; do

		team=${google_team_folders[$google_team_folder]}
		team_folder="$teams_root_folder/$team"

		echo "ISPD23 -- 1)  Checking all benchmark folders for team \"$team\" for new submission files ..."

		for benchmark in $benchmarks; do

		(
			id_internal="$team---$benchmark"
			google_benchmark_folder=${google_benchmark_folders[$id_internal]}

			## NOTE relatively verbose; could be turned off
			#echo "ISPD23 -- 1)   Checking benchmark \"$benchmark\" (Google folder ID \"$google_benchmark_folder\") ..."

			downloads_folder="$team_folder/$benchmark/downloads"
			declare -A basename_folders=()

			# array of [google_ID]=google_file_name
			declare -A google_folder_files=()
			# array of [google_ID]=file_type
			declare -A google_folder_files_type=()

			## fix, if needed, the json file for current session in json file
			google_fix_json

			while read -r a b c; do

				google_folder_files[$a]=$b
				google_folder_files_type[$a]=$c

				# NOTE no error handling for the gdrive call itself; would have to jump in before awk and array assignment -- not really needed, since the error can be inferred from other log lines, like:
				## ISPD23 -- 1)  Download new submission file "to" (Google file ID "Failed") into dedicated folder
				## Failed to get file: googleapi: Error 404: File not found: Failed., notFound
				## ISPD23_daemon_procedures.sh: line 168: google_folder_files[$a]: bad array subscript
				## awk: cmd. line:1: (FILENAME=- FNR=1) fatal: attempt to access field -2

				# NOTE for google_folder_files_type, we're only interested in "dir" versus any other file. Since folders may have spaces as well, we need to go from
				# back (right to left); we cannot assume that the file type is 3rd position. Also note that the same issue can occur for non-dir files, but we do not bother here about those
				## some examples
				#1upYhtbufP8-G3S1aJr9AcdXZed57w1vn   old result          dir             2023-02-02 17:01:00
				#1sBKwXVHNd1iSDPDkdEcwo66bmbDufClS   sha256_0202.zip     bin    1.7 MB   2023-02-02 17:03:15
				#128fBdGnDOLfZ5EN6gwsehT8I453ueUFs   sha256_3.zip        bin    1.5 MB   2023-02-02 13:32:42
				#1ZD4hzgwHdldCLh4dvtIMRVs6WGi_bvfY   sha256_sdc.zip      bin    1.7 MB   2023-02-02 12:12:51
				#1fuXzMuq-cEE0ANwVvgLTZv0S1j424RNi   method-01-13-1008   dir             2023-01-13 06:08:27

			done < <(./gdrive list --no-header -q "parents in '$google_benchmark_folder' and trashed = false and not (name contains 'results')" 2> /dev/null | awk '{print $1" "$2" "$(NF-2)}')

			## pre-processing: list files within (sub)folders, if any
			for folder in "${!google_folder_files_type[@]}"; do

				if [[ ${google_folder_files_type[$folder]} != "dir" ]]; then
					continue
				fi

				## fix, if needed, the json file for current session in json file
				google_fix_json

				# add files of subfolder to google_folder_files
				while read -r a b c; do

					google_folder_files[$a]=$b
					google_folder_files_type[$a]=$c

					# NOTE no error handling for the gdrive call itself; would have to jump in before awk and array assignment -- not really needed, since the error can be inferred from other log lines; see note above

				done < <(./gdrive list --no-header -q "parents in '$folder' and trashed = false and not (name contains 'results')" 2> /dev/null | awk '{print $1" "$2" "$(NF-2)}')
			done

			## iterate over keys / google IDs
			for file in "${!google_folder_files[@]}"; do

				# cross-check w/ already downloaded ones, considering unique Google IDS, memorized in history file
				if [[ $(grep -c $file $downloads_folder/dl_history) != 0 ]]; then
					continue
				fi

				# skip subfolders (if any); the files of 1st level subfolders are already included in google_folder_files array (see loop above), other subfolders
				# of level 2 or more are ignored on purpose
				if [[ ${google_folder_files_type[$file]} == "dir" ]]; then
					continue
				fi

				google_file_name=${google_folder_files[$file]}
				basename=${google_file_name%.*}
				local_file_name=${google_folder_files[$file]}

				## DBG
				#echo "ispd23 -- file: $file"
				#echo "ispd23 -- google_folder_files_type: ${google_folder_files_type[$file]}"
				#echo "ISPD23 -- google_file_name: $google_file_name"
				#echo "ISPD23 -- basename: $basename"
				#echo "ISPD23 -- local_file_name: $local_file_name"

				# sanity check for malformed file names with only suffix, like ".nfs000000001f6680dd00000194" -- simply ignore such files
				if [[ $basename == "" ]]; then
					continue
				fi

				# sanity checks:
				#
				# 1) if file name and basename are the same, this means there's no file extension in the current string. This implies, most likely, that
				# the file is one of multiple files with the same basename in the same folder (gdrive handles such instances as "aes (1).zip", "aes (2).zip" etc.;
				# the dropping of the file extensions happens because awk-based parsing (see loops above) considers only 1 word for the file name); thus, we need
				# to get the full file name again, including spaces
				# 2) for long filenames: gdrive puts "..." in the middle of long file names, but only for the short ID obtained above, not for the actual file
				# download; thus, we need to get the full file name again
				#
				if [[ "$basename" == "$google_file_name" || "$google_file_name" == *"..."* ]]; then

					## fix, if needed, the json file for current session in json file
					google_fix_json

					# another call to gdrive, to get the full file name including any spaces etc
					google_file_name=$(./gdrive info $file | grep "Name: ")
					google_file_name=${google_file_name##Name: }

					# for the local file, replace spaces, if any, w/ "_"
					local_file_name=$(echo $google_file_name | sed 's/ /_/g')

					# update basename as well, considering the updated local file name (w/o any spaces)
					basename=${local_file_name%.*}

					## DBG
					#echo "ISPD23 -- google_file_name: $google_file_name"
					#echo "ISPD23 -- basename: $basename"
					#echo "ISPD23 -- local_file_name: $local_file_name"
				fi

				## if there's still no file extensions, we're looking at some Google doc, spreadsheet, etc. -- these can be safely ignored as well
				if [[ "$basename" == "$local_file_name" ]]; then
					continue
				fi

				# first, if not available yet, init a separate folder for each set of files with common basename
				# (assuming that different submissions downloaded at once at least have different basenames)
				if ! [[ ${basename_folders[$basename]+_} ]]; then

					# actual init of download folder w/ timestamp;
					downloads_folder_="$downloads_folder/downloads_$(date +%s)"

					mkdir $downloads_folder_

					## DBG
					#echo "ISPD23 -- new downloads_folder_: $downloads_folder_"

					# memorize new folder in basenames array
					basename_folders[$basename]="$downloads_folder_"
					## DBG
					#declare -p basename_folders
				else
					downloads_folder_=${basename_folders[$basename]}
					## DBG
					#echo "ISPD23 -- existing downloads_folder_: $downloads_folder_"
				fi

				## fix, if needed, the json file for current session in json file
				google_fix_json

				echo "ISPD23 -- 1)  Download new submission file \"$google_file_name\" (Google file ID \"$file\") to \"$downloads_folder_\" ..."
				./gdrive download -f --path $downloads_folder_ $file #> /dev/null 2>&1

				# post-processing if download succeeds
				if [[ $? == 0 ]]; then

					# memorize to not download again
					echo $file >> $downloads_folder/dl_history

					# move files locally if needed
					if [[ "$google_file_name" != "$local_file_name" ]]; then

						echo "ISPD23 -- 1)   Rename file locally, w/o any spaces, to: \"$downloads_folder_/$local_file_name\""

						## NOTE quotes for google_file_name are essential to capture any spaces; for local_file_name there are no spaces by definition
						mv "$downloads_folder_/$google_file_name" $downloads_folder_/$local_file_name
					fi

					# unpack archive, if applicable
					if [[ $(file $downloads_folder_/$local_file_name | awk '{print $2}') == "Zip" ]]; then

						echo "ISPD23 -- 1)   Unpacking zip file \"$local_file_name\" into \"$downloads_folder_\" ..."
						# NOTE only mute regular stdout, but keep stderr
						unzip -j $downloads_folder_/$local_file_name -d $downloads_folder_ > /dev/null #2>&1
						rm $downloads_folder_/$local_file_name #> /dev/null 2>&1
					fi
				fi

				# chances are that processing is too fast, resulting in clashes for timestamp in folders for same benchmarks, hence slow down on purpose here
				sleep 1s
			done
		) &

		done
	done

	# wait for all parallel runs to finish
	wait
}

google_uploads() {

	parallel_uploads=0

	## iterate over keys / google IDs
	for google_team_folder in "${!google_team_folders[@]}"; do

		## check and fix, if needed, the json file for current session in json file
		google_fix_json

		team=${google_team_folders[$google_team_folder]}
		ongoing_runs=$(ls $teams_root_folder/$team/*/work/* -d 2> /dev/null | wc -l)

		for benchmark in $benchmarks; do

			id_internal="$team---$benchmark"
			uploads_folder="$teams_root_folder/$team/$benchmark/uploads"
			backup_work_folder="$teams_root_folder/$team/$benchmark/backup_work"

			# handle all the uploads folders that might have accumulated through batch processing
			for folder in $(ls $uploads_folder); do

				## 0)  only max_parallel_uploads should be triggered at once
				if [[ "$parallel_uploads" == "$max_parallel_uploads" ]]; then
					break 3
				fi

				## 1) count parallel uploads (i.e., uploads started within the same cycle)
				((parallel_uploads = parallel_uploads + 1))

				## 2) begin parallel uploads

				# NOTE init vars once, before parallel runs start
				google_benchmark_folder=${google_benchmark_folders[$id_internal]}
				folder_=${folder##*_}
				benchmark_=$(printf "%-"$benchmarks_string_max_length"s" $benchmark)
				team_=$(printf "%-"$teams_string_max_length"s" $team)
				id_run="[ $round -- $team_ -- $benchmark_ -- $folder_ ]"

			(
				echo "ISPD23 -- 4)  $id_run: Upload results folder \"$uploads_folder/$folder\" into team's benchmark folder (Google folder ID \"$google_benchmark_folder\") ..."

				## fix, if needed, the json file for current session in json file
				google_fix_json

				./gdrive upload -p $google_benchmark_folder -r $uploads_folder/$folder #> /dev/null 2>&1

				## proceed only if upload succeeded
				if [[ $? -ne 0 ]]; then
					# NOTE use exit, not contine, as we are at the main level in a subshell here now
					exit 1
				fi

				## cleanup
				rm -rf $uploads_folder/$folder

				## fix, if needed, the json file for current session in json file
				google_fix_json

				## also send out email notification of successful upload
				#
				echo "ISPD23 -- 4)  $id_run: Send out email about uploaded results folder ..."
				# NOTE errors could be suppressed here, but they can also just be sent out. In case it fails, these might be helpful and can be checked from the sent mailbox
				#google_uploaded_folder=$(./gdrive list --no-header -q "parents in '$google_benchmark_folder' and trashed = false and name = '$folder'" 2> /dev/null | awk '{print $1}')
				google_uploaded_folder=$(./gdrive list --no-header -q "parents in '$google_benchmark_folder' and trashed = false and name = '$folder'" | awk '{print $1}')

				# NOTE we use this id as subject for both emails, begin and end of processing, to put them into thread at receipents mailbox
				subject="Re: [ ISPD23 Contest: $round round -- $team -- $benchmark -- reference ${folder##*_} ]"

				text="The results for your latest submission are ready in your corresponding Google Drive folder."
				text+="\n\n"

				text+="Direct link: https://drive.google.com/drive/folders/$google_uploaded_folder"
				text+="\n\n"

				rpt=$backup_work_folder/downloads_$folder_/reports/errors.rpt
				if [[ -e $rpt ]]; then
					# NOTE only indicate on errors, do not print out in email
					#text+=$(cat $rpt)
					text+="Errors: Some errors occurred -- see errors.txt for details. (Note: errors.txt is the same as reports.zip/errors.rpt;";
					text+=" it is copied again into the main folder only for your convenience, offering direct viewing access through the Google Drive website.)"
					text+="\n\n"
				else
					text+="Errors: No errors occurred."
					text+="\n\n"
				fi

				rpt=$backup_work_folder/downloads_$folder_/reports/warnings.rpt
				if [[ -e $rpt ]]; then
					# NOTE only indicate on warnings, do not print out in email
					#text+=$(cat $rpt)
					text+="Warnings: Some warnings occurred -- see warnings.txt for details. (Note: warnings.txt is the same as reports.zip/warnings.rpt;";
					text+=" it is copied again into the main folder only for your convenience, offering direct viewing access through the Google Drive website.)"
					text+="\n\n"
				else
					text+="Warnings: No warnings occurred."
					text+="\n\n"
				fi

				rpt=$backup_work_folder/downloads_$folder_/reports/scores.rpt.summary
				if [[ -e $rpt ]]; then

					rpt_=$backup_work_folder/downloads_$folder_/reports/errors.rpt
					if [[ -e $rpt_ ]]; then
						text+="SCORES ONLY FOR INFORMATION. THIS SUBMISSION IS INVALID DUE TO SOME ERRORS."
						text+="\n\n"
					fi

					# NOTE print out scores summary in email
					text+=$(cat $rpt)
					text+="\n\n"
				fi

				text+="Processing status: You have currently $ongoing_runs more run(s) ongoing in total, and ${runs_queued[$id_internal]} more run(s) queued for this particular benchmark."
				text+=" "
				text+="At this point, the evaluation server may start $((max_parallel_runs - $ongoing_runs)) more concurrent run(s), of any benchmark(s), for you."
				text+=" "
				text+="You can upload as many submissions as you like, but processing is subject to these run limits."

				send_email "$text" "$subject" "${google_share_emails[$team]}"
			) &

			done
		done
	done

	# wait for all parallel runs to finish
	wait

	## query quota
	google_quota "ISPD23 -- 4)  " 
}

check_eval() {

	## iterate over values / actual names
	for team in "${google_team_folders[@]}"; do

		for benchmark in $benchmarks; do

			work_folder="$teams_root_folder/$team/$benchmark/work"
			backup_work_folder="$teams_root_folder/$team/$benchmark/backup_work"

			# handle all work folders
			## NOTE only folders are in here, all folders are non-empty, and all folders are named downloads_TIMESTAMP
			for folder in $(ls $work_folder); do

				benchmark_=$(printf "%-"$benchmarks_string_max_length"s" $benchmark)
				team_=$(printf "%-"$teams_string_max_length"s" $team)
				id_run="[ $round -- $team_ -- $benchmark_ -- ${folder##*_} ]"

				## 0) enter work folder silently
				cd $work_folder/$folder > /dev/null

				echo "ISPD23 -- 3)"
				echo "ISPD23 -- 3)  $id_run: Checking work folder \"$work_folder/$folder\""

				## 0) init to check status of processes
				
				# notation: 0 -- still running; 1 -- done; 2 -- error
				declare -A status=()

				# check init steps for fails; does not matter which one failed
				if [[ -e FAILED.link_work_dir ]]; then
					status[init]=2
				elif [[ -e FAILED.check_submission ]]; then
					status[init]=2
				else
					status[init]=1
				fi

				## 0) if there's no init error, start parallel subshells to continuously monitor the actual evaluation processes

				if [[ ${status[init]} == 1 ]]; then
				
				# NOTE we need this double subshell to avoid stalling further processing; otherwise, I
				# think, the two inner subshells would be locking into the next wait command, even
				# from any other procedure
				(

					###
					# Innovus design checks
					###
					(

					# NOTE subshell should be started only once, to avoid race conditions -- handle via PID file
				 	# NOTE ignore errors for cat, in case PID file not existing yet; for ps, ignore
					# related file errors and others errors and also drop output, just keep status/exit code
					running=$(ps --pid $(cat PID.monitor.inv_checks 2> /dev/null) > /dev/null 2>&1; echo $?)
					if [[ $running != 0 ]]; then
						echo $$ > PID.monitor.inv_checks
					else
						exit 2
					fi

#					echo "ISPD23 -- 3)  $id_run:  Process monitor subshell started for Innovus design checks."

					while true; do

						# NOTE sleep a little right in the beginning, to avoid immediate but useless errors concerning log file not found; is only relevant
						# for the very first run just following right after starting the process, but should still be employed here as fail-safe measure
						# NOTE merged w/ regular sleep, which is needed anyway (and was previously done at the end of the loop)
						sleep 2s

						if [[ -e DONE.inv_checks ]]; then
							break
						else
							errors=0

							# check for any errors
							# NOTE limit to 1k errors since tools may flood log files w/ INTERRUPT messages etc, which would then stall grep
							errors_run=$(grep -m 1000 -E "$innovus_errors_for_checking" checks.log* | grep -Ev "$innovus_errors_excluded_for_checking")
							# also check for interrupts
							errors_interrupt=$(ps --pid $(cat PID.inv_checks) > /dev/null; echo $?)

							if [[ $errors_run != "" ]]; then

								# NOTE begin logging w/ linebreak, to differentiate from other ongoing logs like sleep progress bar
								echo -e "\nISPD23 -- 2)  $id_run:  Some error occurred for Innovus design checks."
								echo "ISPD23 -- ERROR: process failed for Innovus design checks -- $errors_run" >> reports/errors.rpt

								errors=1
					
							# NOTE merged with check for errors into 'elif', as errors might lead to immediate process exit, which would then result in both
							# errors reported at once; whereas we like to keep sole interrupt, runtime errors separate
							elif [[ $errors_interrupt != 0 ]]; then

								# NOTE also check again for DONE flag file, to avoid race condition where
								# process just finished but DONE did not write out yet
								sleep 1s
								if [[ -e DONE.inv_checks ]]; then
									break
								fi

								echo -e "\nISPD23 -- 2)  $id_run:  Innovus design checks got interrupted."
								echo "ISPD23 -- ERROR: process failed for Innovus design checks -- INTERRUPT, runtime error" >> reports/errors.rpt

								errors=1
							fi

							# also check process state/evaluation outcome of other process(es)
							#
							# NOTE no need to abort process multiple times in case all is cancelled/brought down due to some failure for some single
							# process; use elif statemets to abort each process only once
							if [[ -e FAILED.TI.ALL ]]; then

								echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus Trojan insertion failed. Also abort Innovus design checks ..."
								echo "ISPD23 -- ERROR: process failed for Innovus design checks -- aborted due to failure for Innovus Trojan insertion" >> reports/errors.rpt

								errors=1

							elif [[ -e FAILED.lec_checks ]]; then

								echo -e "\nISPD23 -- 2)  $id_run:  For some reason, LEC design checks failed. Also abort Innovus design checks ..."
								echo "ISPD23 -- ERROR: process failed for Innovus design checks -- aborted due to failure for LEC design checks" >> reports/errors.rpt

								errors=1

							elif [[ -e FAILED.inv_PPA ]]; then

								echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus PPA evaluation failed. Also abort Innovus design checks ..."
								echo "ISPD23 -- ERROR: process failed for Innovus design checks -- aborted due to failure for Innovus PPA evaluation" >> reports/errors.rpt

								errors=1
							fi

							# for any errors, try killing the process and mark as failed
							if [[ $errors != 0 ]]; then

								# NOTE not all cases/conditions require killing, but for simplicity this is unified here; trying again to kill wont hurt
								cat PID.inv_checks | xargs kill -9 2> /dev/null
								date > FAILED.inv_checks

								# NOTE as this important eval process failed, the other eval process(es) should be killed as well
								# NOTE not all cases/conditions require killing again, but for simplicity this is unified here; trying to kill again wont hurt
								# NOTE do not set FAILED file for the other process(es) here; this is covered by the other monitoring subshell(s)
								cat PID.lec_checks | xargs kill -9 2> /dev/null
								cat PID.inv_PPA | xargs kill -9 2> /dev/null

								exit 1
							fi
						fi
					done

					## parse rpt, log files for failures
					## put summary into warnings.rpts; also extract violations count into checks_summary.rpt
					## set/mark status via PASSED/FAILED files
					parse_inv_checks

					) & # Innovus design checks


					###
					# Innovus PPA evaluation 
					###
					(

					# NOTE subshell should be started only once, to avoid race conditions -- handle via PID file
				 	# NOTE ignore errors for cat, in case PID file not existing yet; for ps, ignore
					# related file errors and others errors and also drop output, just keep status/exit code
					running=$(ps --pid $(cat PID.monitor.inv_PPA 2> /dev/null) > /dev/null 2>&1; echo $?)
					if [[ $running != 0 ]]; then
						echo $$ > PID.monitor.inv_PPA
					else
						exit 2
					fi

#					echo "ISPD23 -- 3)  $id_run:  Process monitor subshell started for Innovus PPA evaluation."

					while true; do

						# NOTE sleep a little right in the beginning, to avoid immediate but useless errors concerning log file not found; is only relevant
						# for the very first run just following right after starting the process, but should still be employed here as fail-safe measure
						# NOTE merged w/ regular sleep, which is needed anyway (and was previously done at the end of the loop)
						sleep 2s

						if [[ -e DONE.inv_PPA ]]; then
							break
						else
							errors=0

							# check for any errors
							# NOTE limit to 1k errors since tools may flood log files w/ INTERRUPT messages etc, which would then stall grep
							errors_run=$(grep -m 1000 -E "$innovus_errors_for_checking" PPA.log* | grep -Ev "$innovus_errors_excluded_for_checking")
							# also check for interrupts
							errors_interrupt=$(ps --pid $(cat PID.inv_PPA) > /dev/null; echo $?)

							if [[ $errors_run != "" ]]; then

								# NOTE begin logging w/ linebreak, to differentiate from other ongoing logs like sleep progress bar
								echo -e "\nISPD23 -- 2)  $id_run:  Some error occurred for Innovus PPA evaluation."
								echo "ISPD23 -- ERROR: process failed for Innovus PPA evaluation -- $errors_run" >> reports/errors.rpt

								errors=1
						
							# NOTE merged with check for errors into 'elif', as errors might lead to immediate process exit, which would then result in both
							# errors reported at once; whereas we like to keep sole interrupt, runtime errors separate
							elif [[ $errors_interrupt != 0 ]]; then

								# NOTE also check again for DONE flag file, to avoid race condition where
								# process just finished but DONE did not write out yet
								sleep 1s
								if [[ -e DONE.inv_PPA ]]; then
									break
								fi

								echo -e "\nISPD23 -- 2)  $id_run:  Innovus PPA evaluation got interrupted."
								echo "ISPD23 -- ERROR: process failed for Innovus PPA evaluation -- INTERRUPT, runtime error" >> reports/errors.rpt

								errors=1
							fi

							# also check process state/evaluation outcome of other process(es)
							#
							# NOTE no need to abort process multiple times in case all is cancelled/brought down due to some failure for some single
							# process; use elif statemets to abort each process only once
							if [[ -e FAILED.TI.ALL ]]; then

								echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus Trojan insertion failed. Also abort Innovus PPA evaluation ..."
								echo "ISPD23 -- ERROR: process failed for Innovus PPA evaluation -- aborted due to failure for Innovus Trojan insertion" >> reports/errors.rpt

								errors=1

							elif [[ -e FAILED.lec_checks ]]; then

								echo -e "\nISPD23 -- 2)  $id_run:  For some reason, LEC design checks failed. Also abort Innovus PPA evaluation ..."
								echo "ISPD23 -- ERROR: process failed for Innovus PPA evaluation -- aborted due to failure for LEC design checks" >> reports/errors.rpt

								errors=1

							elif [[ -e FAILED.inv_checks ]]; then

								echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus design checks failed. Also abort Innovus PPA evaluation ..."
								echo "ISPD23 -- ERROR: process failed for Innovus PPA evaluation -- aborted due to failure for Innovus design checks" >> reports/errors.rpt

								errors=1
							fi

							# for any errors, try killing the process and mark as failed
							if [[ $errors != 0 ]]; then

								# NOTE not all cases/conditions require killing, but for simplicity this is unified here; trying again to kill wont hurt
								cat PID.inv_PPA | xargs kill -9 2> /dev/null
								date > FAILED.inv_PPA

								# NOTE as this important eval process failed, the other eval process(es) should be killed as well
								# NOTE not all cases/conditions require killing again, but for simplicity this is unified here; trying to kill again wont hurt
								# NOTE do not set FAILED file for the other process(es) here; this is covered by the other monitoring subshell(s)
								cat PID.lec_checks | xargs kill -9 2> /dev/null
								cat PID.inv_checks | xargs kill -9 2> /dev/null

								exit 1
							fi
						fi
					done

					## parse rpt, log files for failures
					## put summary into warnings.rpts; also extract violations count into checks_summary.rpt
					## set/mark status via PASSED/FAILED files
					parse_inv_PPA

					) & # Innovus PPA evaluation


					###
					# LEC design checks
					###
					(

					# NOTE subshell should be started only once, to avoid race conditions -- handle via PID file
				 	# NOTE ignore errors for cat, in case PID file not existing yet; for ps, ignore
					# related file errors and others errors and also drop output, just keep status/exit code
					running=$(ps --pid $(cat PID.monitor.lec_checks 2> /dev/null) > /dev/null 2>&1; echo $?)
					if [[ $running != 0 ]]; then
						echo $$ > PID.monitor.lec_checks
					else
						exit 2
					fi

#					echo "ISPD23 -- 3)  $id_run:  Process monitor subshell started for LEC design checks."

					while true; do

						# NOTE sleep a little right in the beginning, to avoid immediate but useless errors concerning log file not found; is only relevant
						# for the very first run just following right after starting the process, but should still be employed here as fail-safe measure
						# NOTE merged w/ regular sleep, which is needed anyway (and was previously done at the end of the loop)
						sleep 2s

						if [[ -e DONE.lec_checks ]]; then
							break
						else
							errors=0

							# check for any errors
							# NOTE limit to 1k errors since tools may flood log files w/ INTERRUPT messages etc, which would then stall grep
							errors_run=$(grep -m 1000 -E "$lec_errors_for_checking" lec.log)
							# also check for interrupts
							errors_interrupt=$(ps --pid $(cat PID.lec_checks) > /dev/null; echo $?)

							if [[ $errors_run != "" ]]; then

								# NOTE begin logging w/ linebreak, to differentiate from other ongoing logs like sleep progress bar
								echo -e "\nISPD23 -- 2)  $id_run:  Some error occurred for LEC design checks."
								echo "ISPD23 -- ERROR: process failed for LEC design checks -- $errors_run" >> reports/errors.rpt

								errors=1
						
							# NOTE merged with check for errors into 'elif', as errors might lead to immediate process exit, which would then result in both
							# errors reported at once; whereas we like to keep sole interrupt, runtime errors separate
							elif [[ $errors_interrupt != 0 ]]; then

								# NOTE also check again for DONE flag file, to avoid race condition where
								# process just finished but DONE did not write out yet
								sleep 1s
								if [[ -e DONE.lec_checks ]]; then
									break
								fi

								echo -e "\nISPD23 -- 2)  $id_run:  LEC design checks got interrupted."
								echo "ISPD23 -- ERROR: process failed for LEC design checks -- INTERRUPT, runtime error" >> reports/errors.rpt

								errors=1
							fi

							# also check process state/evaluation outcome of other process(es)
							#
							# NOTE no need to abort process multiple times in case all is cancelled/brought down due to some failure for some single
							# process; use elif statemets to abort each process only once
							if [[ -e FAILED.TI.ALL ]]; then

								echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus Trojan insertion failed. Also abort LEC design checks ..."
								echo "ISPD23 -- ERROR: process failed for LEC design checks -- aborted due to failure for Innovus Trojan insertion" >> reports/errors.rpt

								errors=1

							elif [[ -e FAILED.inv_PPA ]]; then

								echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus PPA evaluation failed. Also abort LEC design checks ..."
								echo "ISPD23 -- ERROR: process failed for LEC design checks -- aborted due to failure for Innovus PPA evaluation" >> reports/errors.rpt

								errors=1

							elif [[ -e FAILED.inv_checks ]]; then

								echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus design checks failed. Also abort LEC design checks ..."
								echo "ISPD23 -- ERROR: process failed for LEC design checks -- aborted due to failure for Innovus design checks" >> reports/errors.rpt

								errors=1
							fi

							# for any errors, try killing the process and mark as failed
							if [[ $errors != 0 ]]; then

								# NOTE not all cases/conditions require killing, but for simplicity this is unified here; trying again to kill wont hurt
								cat PID.lec_checks | xargs kill -9 2> /dev/null
								date > FAILED.lec_checks

								# NOTE as this important eval process failed, the other eval process(es) should be killed as well
								# NOTE not all cases/conditions require killing again, but for simplicity this is unified here; trying to kill again wont hurt
								# NOTE do not set FAILED file for the other process(es) here; this is covered by the other monitoring subshell(s)
								cat PID.inv_checks | xargs kill -9 2> /dev/null
								cat PID.inv_PPA | xargs kill -9 2> /dev/null

								exit 1
							fi
						fi
					done

					## parse rpt, log files for failures
					## put summary into warnings.rpts; also extract violations count into checks_summary.rpt
					## set/mark status via PASSED/FAILED files
					parse_lec_checks

					) & # LEC design checks

				) &

				fi

				### check status of above processes

				## Innovus PPA evaluation
				if [[ -e PASSED.inv_PPA ]]; then

					status[inv_PPA]=1

					echo "ISPD23 -- 3)  $id_run:  Innovus PPA evaluation: done"

				elif [[ -e FAILED.inv_PPA ]]; then

					status[inv_PPA]=2

					echo "ISPD23 -- 3)  $id_run:  Innovus PPA evaluation: failed"

				# in case init steps failed, this check is not running at all -- mark as failed but
				# don't report on status
				elif [[ ${status[init]} == 2 ]]; then

					status[inv_PPA]=2
				else
					status[inv_PPA]=0

					echo "ISPD23 -- 3)  $id_run:  Innovus PPA evaluation: still working ..."
				fi

				## Innovus design checks
				if [[ -e PASSED.inv_checks ]]; then

					status[inv_checks]=1

					echo "ISPD23 -- 3)  $id_run:  Innovus design checks: done"

				elif [[ -e FAILED.inv_checks ]]; then

					status[inv_checks]=2

					echo "ISPD23 -- 3)  $id_run:  Innovus design checks: failed"

				# in case init steps failed, this check is not running at all -- mark as failed but
				# don't report on status
				elif [[ ${status[init]} == 2 ]]; then

					status[inv_checks]=2
				else
					status[inv_checks]=0

					echo "ISPD23 -- 3)  $id_run:  Innovus design checks: still working ..."
				fi

				## LEC design checks
				if [[ -e PASSED.lec_checks ]]; then

					status[lec_checks]=1

					echo "ISPD23 -- 3)  $id_run:  LEC design checks: done"

				elif [[ -e FAILED.lec_checks ]]; then

					status[lec_checks]=2

					echo "ISPD23 -- 3)  $id_run:  LEC design checks: failed"

				# in case init steps failed, this check is not running at all -- mark as failed but
				# don't report on status
				elif [[ ${status[init]} == 2 ]]; then

					status[lec_checks]=2
				else
					status[lec_checks]=0

					echo "ISPD23 -- 3)  $id_run:  LEC design checks: still working ..."
				fi

				## Innovus Trojan insertion
				# NOTE processes handled via TI_wrapper.sh, not above
				if [[ -e DONE.TI.ALL ]]; then

					status[inv_TI]=1

					echo "ISPD23 -- 3)  $id_run:  Innovus Trojan insertion: done"

				elif [[ -e FAILED.TI.ALL ]]; then

					status[inv_TI]=2

					echo "ISPD23 -- 3)  $id_run:  Innovus Trojan insertion: failed"

				# in case init steps failed, this check is not running at all -- mark as failed but
				# don't report on status
				elif [[ ${status[init]} == 2 ]]; then

					status[inv_TI]=2
				else
					status[inv_TI]=0

					runs_total=$(ls TI/* 2> /dev/null | wc -l)
					# NOTE STARTED.TI.* would cover all runs that are started by TI_wrapper, but some might still wait for licenses, whereas DONE.source.TI.*
					# files relate to processes that have really started
					runs_started=$(ls DONE.source.TI.* 2> /dev/null | wc -l)
					runs_done=$(ls DONE.TI.* 2> /dev/null | wc -l)
					runs_failed=$(ls FAILED.TI.* 2> /dev/null | wc -l)
					((runs_pending = runs_total - runs_started))
					((runs_ongoing = runs_started - runs_done - runs_failed ))
					echo "ISPD23 -- 3)  $id_run:  Innovus Trojan insertion: still working -- $runs_ongoing run(s) ongoing, $runs_done run(s) done, $runs_failed run(s) failed, $runs_pending run(s) pending, $runs_total run(s) in total ..."
				fi

				## 2) if not done yet, and no error occurred, then continue, i.e., skip the further processing for now
				if [[ ${status[inv_checks]} == 0 || ${status[lec_checks]} == 0 || ${status[inv_PPA]} == 0 || ${status[inv_TI]} == 0 ]]; then
					
					# first return to previous main dir silently
					cd - > /dev/null

					continue
				fi

				## 3) compute scores
				echo "ISPD23 -- 3)  $id_run:  Computing scores ..."
				# NOTE only mute regular stdout, which is put into log file already, but keep stderr
				scripts/scores.sh 6 $baselines_root_folder/$benchmark 1 $dbg_files > /dev/null

				## 4) create related upload folder, w/ same timestamp as work and download folder
				uploads_folder="$teams_root_folder/$team/$benchmark/uploads/results_${folder##*_}"
				mkdir $uploads_folder

				## 5) pack and results files into uploads folder
				echo "ISPD23 -- 3)  $id_run:  Packing results files into uploads folder \"$uploads_folder\" ..."

				## report files
				#
				# -j means to smash reports/ folder; just put files into zip archive directly
				# include regular rpt files, not others (like, *.rpt.extended files)
				# NOTE only mute regular stdout, but keep stderr
				zip -j $uploads_folder/reports.zip reports/*.rpt > /dev/null
				# also include detailed timing reports
				# NOTE only mute regular stdout, but keep stderr
				zip -r $uploads_folder/reports.zip timingReports/ > /dev/null

				## log files
				#
				# NOTE only mute regular stdout, but keep stderr
				zip $uploads_folder/logs.zip *.log* > /dev/null

				# delete again the logs related to Trojan insertion; these details should not be disclosed to participants
				# NOTE but for dbg mode, we keep these log files
				if [[ $dbg_files == "0" ]]; then
					# NOTE mute also stderr, as files might not exist in case some runs failed
					zip -d $uploads_folder/logs.zip TI.*.log* > /dev/null 2>&1
				fi

				## status files
				#
				# NOTE files are already included in reports.zip but we put them still again into main folder, as txt file -- this way, it can be readily viewed in Google Drive
				# NOTE mute stderr which occurs in case the files are not there
				cp reports/errors.rpt $uploads_folder/errors.txt 2> /dev/null
				cp reports/warnings.rpt $uploads_folder/warnings.txt 2> /dev/null
				cp reports/scores.rpt $uploads_folder/scores.txt 2> /dev/null

				## processed files; only for dbg mode, share again
				#
				if [[ $dbg_files == "1" ]]; then
					echo "ISPD23 -- 3)  $id_run:  Including backup of processed files to uploads folder \"$uploads_folder\" ..."
					mv processed_files.zip $uploads_folder/ #2> /dev/null
				fi

				## GDS from Trojan insertion
				#
				# NOTE mute stderr which occurs in case the files are not there
				cp *.gds.gz $uploads_folder/ 2> /dev/null

				## DEF and netlist from Trojan insertion; only for dbg mode
				if [[ $dbg_files == "1" ]]; then

					#
					## NOTE code for listing Trojans is copied from TI_wrapper.sh
					#

					# key: running ID; value: trojan_name
					# NOTE associative array is not really needed, but handling of such seems easier than plain indexed array
					declare -A trojans
					trojan_counter=0

					for file in TI/*; do

						trojan_name=${file##TI/}
						trojan_name=${trojan_name%%.v}
						trojans[$trojan_counter]=$trojan_name

						((trojan_counter = trojan_counter + 1))
					done

					for trojan in "${trojans[@]}"; do
						zip $uploads_folder/Trojan_designs.zip design."$trojan".* > /dev/null 2>&1
					done
				fi

				## 6) backup work dir
				echo "ISPD23 -- 3)  $id_run:  Backup work folder to \"$backup_work_folder/$folder".zip"\" ..."

				# in case the same backup folder already exists (which probably only happens for manual re-runs), store away that previous folder, marking it with its timestamp
				if [[ -d $backup_work_folder/$folder ]]; then

					previous_backup_work_folder_date=$(ls -l --time-style=+%s $backup_work_folder/$folder -d | awk '{print $(NF-1)}')
					mv $backup_work_folder/$folder $backup_work_folder/$previous_backup_work_folder_date"__"$folder

					# also move the zip archive in that backup folder
					mv $backup_work_folder/$folder'.zip' $backup_work_folder/$previous_backup_work_folder_date"__"$folder/
				fi
				
				# actual backup; move from work folder to backup folder
				mv $work_folder/$folder $backup_work_folder/

				# return to previous main dir silently; goes together with the final 'cd -' command at the end
				cd - > /dev/null

				# compress backup
				cd $backup_work_folder > /dev/null

#				# NOTE deprecated; general rm is not good practice. For example, reports for Trojan insertion are in main folder, and should neither be moved to
#				reports/ (as they should not be shared) nor removed altogether. Also, keeping any other report that was previously overlooked is better practice.
#				# silent cleanup of rpt files lingering around in main folder
#				# NOTE As of now, only a 0-byte power.rpt file occurs here (the proper file is in reports/power.rpt). Not sure why this happens
#				# though. Also, instead of deleting, moving to reports/ would be an option -- but, not for that 0-byte power.rpt file
#				rm $folder/*.rpt > /dev/null 2>&1
#
#				# silent cleanup of particular `false' rpt files
#				# NOTE As of now, only a 0-byte power.rpt file matches here (the proper file is already in reports/power.rpt). Not sure where this file comes from.
				rm $folder/power.rpt > /dev/null 2>&1

				# actual compress call
				zip -y -r $folder'.zip' $folder/ > /dev/null 2>&1

				# cleanup
				rm -r $folder/

				# unzip all rpt files again, also those *.rpt.ext etc; rpt files should be readily accessible for debugging
				unzip $folder'.zip' $folder/reports/* > /dev/null 2>&1

#				# NOTE deprecated; log files can be GBs large in case of interrupts
#				# unzip all log files again; log files should be readily accessible for debugging
#				# NOTE only mute regular stdout, but keep stderr
#				unzip $folder'.zip' $folder/*.log* > /dev/null #2>&1

				# unzip Trojan ECO log files again; these log files should be readily accessible for debugging, even at the risk of large files (but haven't seen
				# such issues yet)
				unzip $folder'.zip' $folder/TI.*.log* > /dev/null 2>&1

				cd - > /dev/null
			done
		done
	done
}

check_submission() {

	# NOTE id_run is passed through from calling function, start_eval()
	echo "ISPD23 -- 2)  $id_run:  Basic checks ..."

	status=0

	##
	## check for assets maintained in DEF
	##
	#
	# NOTE trivial checks for matching of names -- could be easily cheated on, e.g,., by swapping names w/ some less complex assets, or even just putting the asset names in some comment.
	# However, subsequent LEC design check does check for equivalence of all FF assets.
	# Further, the evaluation scripts would fail if the assets are missing.
	# So, this here is really only an initial quick check to short-cut further efforts if needed.
	(
		echo "ISPD23 -- 2)  $id_run:   Assets check ..."

		## consider versions of assets w/ extended escape of special chars, so that grep later on can match
		# NOTE escaping is handled in benchmarks/_release/scripts/init.sh
		readarray -t design_assets < design.assets
		readarray -t escaped_design_assets < design.assets.escaped
		errors=0

		for ((i=0; i<${#design_assets[@]}; i++)); do
			asset=${design_assets[$i]}
			escaped_asset=${escaped_design_assets[$i]}

			# for DEF format, each token/word is separated, so we can use -w here
			# NOTE grep -q returing 0 means found, returning 1 means not found, returning 2 etc means other errors
			grep -q -w $escaped_asset design.def
			if [[ $? != 0 ]]; then

				errors=1
				
				echo "ISPD23 -- ERROR: the asset \"$asset\" is not maintained in the DEF." >> reports/errors.rpt
			fi
		done

		if [[ $errors == 0 ]]; then
			echo "ISPD23 -- 2)  $id_run:   Assets check passed."
		else
			echo "ISPD23 -- 2)  $id_run:   Assets check failed."
		fi

		exit $errors
	) &
	pid_check_assets=$!

	##
	## pins checks
	##
	(
		echo "ISPD23 -- 2)  $id_run:   Pins check ..."

		# NOTE only mute regular stdout, which is put into log file already, but keep stderr
		scripts/check_pins.sh > /dev/null

		# parse rpt for FAIL or ERROR
		# NOTE grep -q returing 0 means found, returning 1 means not found, returning 2 etc means other errors
		errors=$(grep -q -E "FAIL|ERROR" reports/check_pins.rpt; echo $?)
		if [[ $errors != 1 ]]; then

			echo "ISPD23 -- ERROR: pins check failed -- see check_pins.rpt for more details." >> reports/errors.rpt
			echo "ISPD23 -- 2)  $id_run:   Pins check failed."

			exit 1
		else

			echo "ISPD23 -- 2)  $id_run:   Pins check passed."
			exit 0
		fi
	) &
	pid_check_pins=$!

	# wait for subshells and memorize their exit code in case it's non-zero
	wait $pid_check_assets || status=$?
	wait $pid_check_pins || status=$?

	if [[ $status != 0 ]]; then

		echo "ISPD23 -- 2)  $id_run:  Some basic check(s) failed."
	else
		echo "ISPD23 -- 2)  $id_run:  All basic checks passed."
	fi

	return $status
}

link_work_dir() {

	errors=0

	##
	## link submission files to common names used by scripts
	##

	## DEF, including sanity checks
	def_files=$(ls *.def 2> /dev/null | wc -l)
	if [[ $def_files != 1 ]]; then

		echo "ISPD23 -- ERROR: there are $def_files DEF files in the submission's work directory, which shouldn't happen." >> reports/errors.rpt

		errors=1
	fi
	## NOTE don't force here, to avoid circular links from design.def to design.def itself, in case the submitted file's name is already the same
	## NOTE suppress stderr for 'File exists' -- happens when submission uses same name already -- but keep all others
	ln -s *.def design.def 2>&1 | grep -v "File exists"
	
	## netlist, including sanity checks
	netlist_files=$(ls *.v 2> /dev/null | wc -l)
	if [[ $netlist_files != 1 ]]; then

		echo "ISPD23 -- ERROR: there are $netlist_files netlist files in the submission's work directory, which shouldn't happen." >> reports/errors.rpt

		errors=1
	fi
	## NOTE don't force here, to avoid circular links from design.v to itself, in case the submitted file's name is already the same
	## NOTE suppress stderr for 'File exists' -- happens when submission uses same name already -- but keep all others
	ln -s *.v design.v 2>&1 | grep -v "File exists"

	## link files related to benchmark into work dir
	# NOTE force here in order to guarantee that the correct files are used, namely those from the reference folders
	ln -sf $baselines_root_folder/$benchmark/*.sdc . 
	ln -sf $baselines_root_folder/$benchmark/design.assets* .
	ln -sf $baselines_root_folder/$benchmark/design.v design_original.v
	ln -sf $baselines_root_folder/$benchmark/design.def design_original.def
	ln -sf $baselines_root_folder/$benchmark/reports/*.data reports/
	ln -sf $baselines_root_folder/$benchmark/TI .
	# NOTE copy this instead of linking, as details might depend on the design/submission, so should not be mixed across teams
	cp $baselines_root_folder/$benchmark/rc_model.bin .

	## link scripts into work dir, using dedicated subfolder

	mkdir scripts
	cd scripts > /dev/null

	for script in $scripts; do
		ln -sf $eval_scripts_folder/$script .
	done
	
	cd - > /dev/null

	## link files related to library into work dir

	mkdir ASAP7
	cd ASAP7 > /dev/null

	for file in $(ls $baselines_root_folder/$benchmark/ASAP7); do
		ln -sf $baselines_root_folder/$benchmark/ASAP7/$file .
	done

	cd - > /dev/null

	if [[ $errors != 0 ]]; then

		echo "ISPD23 -- 2)  $id_run:  Error occurred during init of submission files."
	fi

	return $errors
}

parse_lec_checks() {

	errors=0

	#
	# non-equivalence issues
	#
	## NOTE failure on those is considered as error/constraint violation
	#
# NOTE such line is only present if errors/issues found at all
# NOTE multiple, differently formated occurrence of "Non-equivalent" -- use that from "report compare data" command, at end of rpt file
#
# Example 1:
##Compared points      PO     DFF       Total   
##--------------------------------------------------------------------------------
##Equivalent           66     147       213     
##--------------------------------------------------------------------------------
##Non-equivalent       0      6         6       
# Example 2:
##Compared points      PO     DFF    DLAT      Total
##--------------------------------------------------------------------------------
##Equivalent           136    732    3         871
##--------------------------------------------------------------------------------
##Non-equivalent       0      2      0         2

	issues=$(tail -n 2 reports/check_equivalence.rpt | grep "Non-equivalent" | awk '{print $NF}')
	string="LEC: Equivalence issues:"

	if [[ $issues != "" ]]; then

		errors=1

		echo "ISPD23 -- ERROR: $string $issues -- see check_equivalence.rpt for more details." >> reports/errors.rpt
	else
		issues=0
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

	#
	# unreachable issues
	#
	## NOTE failure on those is considered as error/constraint violation
	#
# NOTE such line is only present if errors/issues found at all
# NOTE multiple, differently formated occurrence of "Unreachable" -- use that from "report unmapped points" command, at end of related rpt file
#
# Example 1:
##Unmapped points   DFF    Z         Total   
##--------------------------------------------------------------------------------
##Unreachable       1      3         4       
# Example 2:
##Unmapped points   DLAT      Total
##--------------------------------------------------------------------------------
##Unreachable       31        31

	issues=$(tail -n 2 reports/check_equivalence.rpt.unmapped | grep "Unreachable" | awk '{print $NF}')
	string="LEC: Unreachable points issues:"

	if [[ $issues != "" ]]; then

		errors=1

		echo "ISPD23 -- ERROR: $string $issues -- see check_equivalence.rpt for more details." >> reports/errors.rpt
	else
		issues=0
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

	#
	# different connectivity issues during parsing
	#
	## NOTE these are hinting on cells used as dummy fillers
	#

# Example:
#// Warning: (RTL2.5) Net is referenced without an assignment. Design verification will be based on set_undriven_signal setting (occurrence:7) 
# NOTE such line is only present if errors/issues found at all
# NOTE such line, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design

	issues=$(grep "Warning: (RTL2.5) Net is referenced without an assignment. Design verification will be based on set_undriven_signal setting" lec.log | awk '{print $NF}' | awk 'NR==2')
	issues=${issues##*:}
	issues=${issues%*)}
	string="LEC: Unassigned nets issues:"

	if [[ $issues != "" ]]; then

		issues_baseline=$(grep "ISPD23 -- $string" $baselines_root_folder/$benchmark/reports/checks_summary.rpt | awk '{print $NF}')

		if (( issues > (issues_baseline + issues_margin) )); then

			errors=1

			echo "ISPD23 -- ERROR: $string $issues -- exceeds the allowed margin of $((issues_baseline + issues_margin)) issues -- see lec.log for more details." >> reports/errors.rpt
		else
			echo "ISPD23 -- WARNING: $string $issues -- see lec.log for more details." >> reports/warnings.rpt
		fi
	else
		issues=0
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

# Example:
#// Warning: (RTL2.13) Undriven pin is detected (occurrence:3)
#
# NOTE such line is only present if errors/issues found at all
# NOTE such line, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design

	issues=$(grep "Warning: (RTL2.13) Undriven pin is detected" lec.log | awk '{print $NF}' | awk 'NR==2')
	issues=${issues##*:}
	issues=${issues%*)}
	string="LEC: Undriven pins issues:"

	if [[ $issues != "" ]]; then

		issues_baseline=$(grep "ISPD23 -- $string" $baselines_root_folder/$benchmark/reports/checks_summary.rpt | awk '{print $NF}')

		if (( issues > (issues_baseline + issues_margin) )); then

			errors=1

			echo "ISPD23 -- ERROR: $string $issues -- exceeds the allowed margin of $((issues_baseline + issues_margin)) issues -- see lec.log for more details." >> reports/errors.rpt
		else
			echo "ISPD23 -- WARNING: $string $issues -- see lec.log for more details." >> reports/warnings.rpt
		fi
	else
		issues=0
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

# Example:
#// Warning: (RTL14) Signal has input but it has no output (occurrence:2632)
#
# NOTE such line is only present if errors/issues found at all
# NOTE such issues often occur for baseline layouts as well. These checks here are the only warnings related to cells
# inserted and connected to inputs but otherwise useless (no output), so we need to keep that check
# NOTE such line, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design

	issues=$(grep "Warning: (RTL14) Signal has input but it has no output" lec.log | awk '{print $NF}' | awk 'NR==2')
	issues=${issues##*:}
	issues=${issues%*)}
	string="LEC: Net output floating issues:"

	if [[ $issues != "" ]]; then

		issues_baseline=$(grep "ISPD23 -- $string" $baselines_root_folder/$benchmark/reports/checks_summary.rpt | awk '{print $NF}')

		if (( issues > (issues_baseline + issues_margin) )); then

			errors=1

			echo "ISPD23 -- ERROR: $string $issues -- exceeds the allowed margin of $((issues_baseline + issues_margin)) issues -- see lec.log for more details." >> reports/errors.rpt
		else
			echo "ISPD23 -- WARNING: $string $issues -- see lec.log for more details." >> reports/warnings.rpt
		fi
	else
		issues=0
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

# Example for two related issues:
#// Warning: (HRC3.5a) Open input/inout port connection is detected (occurrence:3)
#// Note: (HRC3.5b) Open output port connection is detected (occurrence:139)
#
# NOTE such lines are only present if errors/issues found at all
# NOTE such lines, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design

	issues_a=$(grep "Warning: (HRC3.5a) Open input/inout port connection is detected" lec.log | awk '{print $NF}' | awk 'NR==2')
	issues_b=$(grep "Note: (HRC3.5b) Open output port connection is detected" lec.log | awk '{print $NF}' | awk 'NR==2')
	issues_a=${issues_a##*:}
	issues_a=${issues_a%*)}
	issues_b=${issues_b##*:}
	issues_b=${issues_b%*)}
	issues=0
	string="LEC: Open ports issues:"

	if [[ $issues_a != "" ]]; then
		((issues = issues + issues_a))
	fi
	if [[ $issues_b != "" ]]; then
		((issues = issues + issues_b))
	fi
	
	if [[ $issues != 0 ]]; then

		issues_baseline=$(grep "ISPD23 -- $string" $baselines_root_folder/$benchmark/reports/checks_summary.rpt | awk '{print $NF}')

		if (( issues > (issues_baseline + issues_margin) )); then

			errors=1

			echo "ISPD23 -- ERROR: $string $issues -- exceeds the allowed margin of $((issues_baseline + issues_margin)) issues -- see lec.log for more details." >> reports/errors.rpt
		else
			echo "ISPD23 -- WARNING: $string $issues -- see lec.log for more details." >> reports/warnings.rpt
		fi
	else
		issues=0
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

# Example:
#// Warning: (HRC3.10a) An input port is declared, but it is not completely used in the module (occurrence:674)
#
# NOTE such line is only present if errors/issues found at all
# NOTE such line, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design

	issues=$(grep "Warning: (HRC3.10a) An input port is declared, but it is not completely used in the module" lec.log | awk '{print $NF}' | awk 'NR==2')
	issues=${issues##*:}
	issues=${issues%*)}
	string="LEC: Input port not fully used issues:"

	if [[ $issues != "" ]]; then

		issues_baseline=$(grep "ISPD23 -- $string" $baselines_root_folder/$benchmark/reports/checks_summary.rpt | awk '{print $NF}')

		if (( issues > (issues_baseline + issues_margin) )); then

			errors=1

			echo "ISPD23 -- ERROR: $string $issues -- exceeds the allowed margin of $((issues_baseline + issues_margin)) issues -- see lec.log for more details." >> reports/errors.rpt
		else
			echo "ISPD23 -- WARNING: $string $issues -- see lec.log for more details." >> reports/warnings.rpt
		fi
	else
		issues=0
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

# Example:
#// Warning: (HRC3.16) A wire is declared, but not used in the module (occurrence:1)
#
# NOTE such line is only present if errors/issues found at all
# NOTE such line, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design

	issues=$(grep "Warning: (HRC3.16) A wire is declared, but not used in the module" lec.log | awk '{print $NF}' | awk 'NR==2')
	issues=${issues##*:}
	issues=${issues%*)}
	string="LEC: Unused wire issues:"

	if [[ $issues != "" ]]; then

		issues_baseline=$(grep "ISPD23 -- $string" $baselines_root_folder/$benchmark/reports/checks_summary.rpt | awk '{print $NF}')

		if (( issues > (issues_baseline + issues_margin) )); then

			errors=1

			echo "ISPD23 -- ERROR: $string $issues -- exceeds the allowed margin of $((issues_baseline + issues_margin)) issues -- see lec.log for more details." >> reports/errors.rpt
		else
			echo "ISPD23 -- WARNING: $string $issues -- see lec.log for more details." >> reports/warnings.rpt
		fi
	else
		issues=0
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

	#
	# evaluate criticality of issues
	#
	if [[ $errors == 1 ]]; then

		echo -e "\nISPD23 -- 2)  $id_run:  Some critical LEC design check(s) failed."

		date > FAILED.lec_checks
		exit 1
	else
		echo -e "\nISPD23 -- 2)  $id_run:  LEC design checks done; all passed."

		date > PASSED.lec_checks
		exit 0
	fi
}

parse_inv_PPA() {

	errors=0

	# timing; see timing.rpt for "View : ALL" and extract FEPs for setup, hold checks
	#
	## NOTE failure on those is considered as error/constraint violation
	#

	# setup 
# Example:
## SETUP                  WNS    TNS   FEP   
##------------------------------------------
# View : ALL           16.703  0.000     0  
#    Group : in2out       N/A    N/A     0  
#    Group : reg2out   16.703  0.000     0  
#    Group : in2reg   151.422    0.0     0  
#    Group : reg2reg  149.277    0.0     0  

	issues=$(grep "View : ALL" reports/timing.rpt | awk '{print $NF}' | awk 'NR==1')
	string="Innovus: Timing issues for setup:"

	if [[ $issues != 0 ]]; then

		errors=1

		echo "ISPD23 -- ERROR: $string $issues -- see timing.rpt for more details." >> reports/errors.rpt
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

	# hold 
# Example:
## HOLD                   WNS    TNS   FEP   
##------------------------------------------
# View : ALL           17.732  0.000     0  
#    Group : in2out       N/A    N/A     0  
#    Group : reg2out  305.300  0.000     0  
#    Group : in2reg    17.732    0.0     0  
#    Group : reg2reg  188.440    0.0     0  

	issues=$(grep "View : ALL" reports/timing.rpt | awk '{print $NF}' | awk 'NR==2')
	string="Innovus: Timing issues for hold:"

	if [[ $issues != 0 ]]; then

		errors=1

		echo "ISPD23 -- ERROR: $string $issues -- see timing.rpt for more details." >> reports/errors.rpt
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

	#
	# evaluate criticality of issues
	#
	if [[ $errors == 1 ]]; then

		echo -e "\nISPD23 -- 2)  $id_run:  Some critical Innovus PPA evaluation step(s) failed."

		date > FAILED.inv_PPA
		exit 1
	else
		echo -e "\nISPD23 -- 2)  $id_run:  Innovus PPA evaluation done; all passed."

		date > PASSED.inv_PPA
		exit 0
	fi
}

parse_inv_checks() {

	errors=0

	# routing issues like dangling wires, floating metals, open pins, etc.; see *.conn.rpt -- we need "*" for file since name is defined by module name, not the verilog file name
	# NOTE the related file floating_signals.rpt does not have to be parsed; it just provides more details but metrics/values are already covered in the lec.log file
# Example:
#    5 total info(s) created.
# NOTE such line is only present if errors/issues found at all

	issues=$(grep "total info(s) created" reports/*.conn.rpt | awk '{print $1}')
	string="Innovus: Basic routing issues:"

	if [[ $issues != "" ]]; then

		issues_baseline=$(grep "ISPD23 -- $string" $baselines_root_folder/$benchmark/reports/checks_summary.rpt | awk '{print $NF}')

		if (( issues > (issues_baseline + issues_margin) )); then

			errors=1

			echo "ISPD23 -- ERROR: $string $issues -- exceeds the allowed margin of $((issues_baseline + issues_margin)) issues -- see *.conn.rpt and floating_signals.rpt for more details." >> reports/errors.rpt
		else
			echo "ISPD23 -- WARNING: $string $issues -- see *.conn.rpt and floating_signals.rpt for more details." >> reports/warnings.rpt
		fi
	else
		issues=0
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

	# IO pins; see *.checkPin.rpt for illegal and unplaced pins from summary
# Example:
#	====================================================================================================================================
#	                                                     checkPinAssignment Summary
#	====================================================================================================================================
#	Partition            | pads  | pins   | legal  | illegal | internal | internal illegal | FT     | FT illegal | constant | unplaced |
#	====================================================================================================================================
#	present_encryption   |     0 |    213 |    212 |       0 |        0 |                0 |      0 |          0 |        0 |        1 |
#	====================================================================================================================================
#	TOTAL                |     0 |    213 |    212 |       0 |        0 |                0 |      0 |          0 |        0 |        1 |
#	====================================================================================================================================

	issues=$(grep "TOTAL" reports/*.checkPin.rpt | awk '{ sum = $9 + $13 + $17 + $21; print sum }')
	string="Innovus: Module pin issues:"

	if [[ $issues != 0 ]]; then

		issues_baseline=$(grep "ISPD23 -- $string" $baselines_root_folder/$benchmark/reports/checks_summary.rpt | awk '{print $NF}')

		if (( issues > (issues_baseline + issues_margin) )); then

			errors=1

			echo "ISPD23 -- ERROR: $string $issues -- exceeds the allowed margin of $((issues_baseline + issues_margin)) issues -- see *.checkPin.rpt for more details." >> reports/errors.rpt
		else
			echo "ISPD23 -- WARNING: $string $issues -- see *.checkPin.rpt for more details." >> reports/warnings.rpt
		fi
	else
		issues=0
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

	# DRC routing issues; see *.geom.rpt for "Total Violations"
	#
	## NOTE failure on those is considered as error/constraint violation
	#
# Example:
#  Total Violations : 2 Viols.
# NOTE such line is only present if errors/issues found at all

	issues=$(grep "Total Violations :" reports/*.geom.rpt | awk '{print $(NF-1)}')
	string="Innovus: DRC issues:"

	if [[ $issues != "" ]]; then

		errors=1

		echo "ISPD23 -- ERROR: $string $issues -- see *.geom.rpt for more details." >> reports/errors.rpt
	else
		issues=0
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

	# placement and routing issues; see check_design.rpt file for summary
# Example:
#	**INFO: Identified 21 error(s) and 0 warning(s) during 'check_design -type {place cts route}'.

	issues=$(grep "**INFO: Identified" reports/check_design.rpt | awk '{ sum = $3 + $6; print sum }')
	string="Innovus: Placement and/or routing issues:"

	if [[ $issues != 0 ]]; then

		issues_baseline=$(grep "ISPD23 -- $string" $baselines_root_folder/$benchmark/reports/checks_summary.rpt | awk '{print $NF}')

		if (( issues > (issues_baseline + issues_margin) )); then

			errors=1

			# NOTE false positives for VDD, VSS vias at M4, M5, M6; report file has incomplete info, full details are in check.logv
			echo "ISPD23 -- ERROR: $string $issues -- exceeds the allowed margin of $((issues_baseline + issues_margin)) issues -- see check_design.rpt and checks.logv for more details." >> reports/errors.rpt
		else
			echo "ISPD23 -- WARNING: $string $issues -- see check_design.rpt and checks.logv for more details." >> reports/warnings.rpt
		fi
	else
		issues=0
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

	# more placement issues; see check_place.rpt file for summary
# Example:
# #########################################################
# ## Total instances with placement violations: 30
# #########################################################
#
# NOTE such line is only present if errors/issues found at all; otherwise the below appears
## No violations found ##

	issues=$(grep "Total instances with placement violations:" reports/check_place.rpt | awk '{print $NF}')
	string="Innovus: Further placement issues:"

	if [[ $issues != "" ]]; then

		# NOTE we want to explicitly ignore issues for vertical pin alignment -- these arise from different innovus version's handling of tracks, more specifically from using Innovus 21 in
		# the backend versus use of an older version by the participants. See also https://github.com/Centre-for-Hardware-Security/asap7_reference_design/blob/main/scripts/innovus.tcl for
		# lines marked 'this series of commands makes innovus 21 happy :)' but note that we _cannot_ use these commands here in the backend when loading up the design for evaluation, as
		# that would purge placement and routing altogether
# Example:
# ### 2022 Vertical Pin-Track Alignment Violation>
		issues__vertical_pin_not_aligned=$(grep "Vertical Pin-Track Alignment Violation" reports/check_place.rpt | awk '{print $2}')
		if [[ $issues__vertical_pin_not_aligned != "" ]]; then
			((issues = issues - issues__vertical_pin_not_aligned))
		fi

		issues_baseline=$(grep "ISPD23 -- $string" $baselines_root_folder/$benchmark/reports/checks_summary.rpt | awk '{print $NF}')

		if (( issues > (issues_baseline + issues_margin) )); then

			errors=1

			echo "ISPD23 -- ERROR: $string $issues -- exceeds the allowed margin of $((issues_baseline + issues_margin)) issues -- see check_place.rpt for more details, but note that vertical-pin violations can be, and are, safely ignored." >> reports/errors.rpt
		else
			echo "ISPD23 -- WARNING: $string $issues -- see check_place.rpt for more details, but note that vertical-pin violations can be, and are, safely ignored." >> reports/warnings.rpt
		fi
	else
		issues=0
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

## (TODO) deactivated for now
# NOTE only parse peak noises; ignore violations as we have to use NLDM libs as CCS libs gave larger mismatch in timing
# NOTE make sure to differentiate b/w VH and VL peak noises correctly
#
#	# noise issues; see noise.rpt for summary
## Example:
## Glitch Violations Summary :
## --------------------------
## Number of DC tolerance violations (VH + VL) =  35
## Number of Receiver Output Peak violations (VH + VL) =  0
## Number of total problem noise nets =  12
#
#	issues=$(grep "Number of DC tolerance violations" reports/noise.rpt | awk '{print $NF}')
#	string="Innovus: DC tolerance issues:"
#
#	if [[ $issues != 0 ]]; then
#
#		issues_baseline=$(grep "ISPD23 -- $string" $baselines_root_folder/$benchmark/reports/checks_summary.rpt | awk '{print $NF}')
#
#		if (( issues > (issues_baseline + issues_margin) )); then
#
#			errors=1
#
#			echo "ISPD23 -- ERROR: $string $issues -- exceeds the allowed margin of $((issues_baseline + issues_margin)) issues -- see noise.rpt for more details." >> reports/errors.rpt
#		else
#			echo "ISPD23 -- WARNING: $string $issues -- see noise.rpt for more details." >> reports/warnings.rpt
#		fi
#	else
#		issues=0
#	fi
#
#	echo "ISPD23 : $string $issues" >> reports/checks_summary.rpt
#
#	issues=$(grep "Number of Receiver Output Peak violations" reports/noise.rpt | awk '{print $NF}')
#	string="Innovus: Receiver output peak issues:"
#
#	if [[ $issues != 0 ]]; then
#
#		issues_baseline=$(grep "ISPD23 -- $string" $baselines_root_folder/$benchmark/reports/checks_summary.rpt | awk '{print $NF}')
#
#		if (( issues > (issues_baseline + issues_margin) )); then
#
#			errors=1
#
#			echo "ISPD23 -- ERROR: $string $issues -- exceeds the allowed margin of $((issues_baseline + issues_margin)) issues -- see noise.rpt for more details." >> reports/errors.rpt
#		else
#			echo "ISPD23 -- WARNING: $string $issues -- see noise.rpt for more details." >> reports/warnings.rpt
#		fi
#	else
#		issues=0
#	fi
#
#	echo "ISPD23 : $string $issues" >> reports/checks_summary.rpt
#
#	issues=$(grep "Number of total problem noise nets" reports/noise.rpt | awk '{print $NF}')
#	string="Innovus: Noise net issues:"
#
#	if [[ $issues != 0 ]]; then
#
#		issues_baseline=$(grep "ISPD23 -- $string" $baselines_root_folder/$benchmark/reports/checks_summary.rpt | awk '{print $NF}')
#
#		if (( issues > (issues_baseline + issues_margin) )); then
#
#			errors=1
#
#			echo "ISPD23 -- ERROR: $string $issues -- exceeds the allowed margin of $((issues_baseline + issues_margin)) issues -- see noise.rpt for more details." >> reports/errors.rpt
#		else
#			echo "ISPD23 -- WARNING: $string $issues -- see noise.rpt for more details." >> reports/warnings.rpt
#		fi
#	else
#		issues=0
#	fi
#
#	echo "ISPD23 : $string $issues" >> reports/checks_summary.rpt

	# PDN stripes checks; see reports/check_stripes.rpt for false versus valid results
	#
	## NOTE failure on those is considered as error/constraint violation
	#
# Example:
#PDN stripes checks
#==================
#Check by area
#-------------
#M2 ---- VDD  ---> valid
#M2 ---- VSS  ---> valid
#M3 ---- VDD  ---> valid
#M3 ---- VSS  ---> false
# [...]
#Final result: false
#
#Check by coordinates
#--------------------
#M2 ---- VDD  ---> valid ---- valid
#M2 ---- VSS  ---> valid ---- false
# [...]
#Final result: false
#
#Check by box width
#------------------
#M2 ---- VDD  ---> valid
#M2 ---- VSS  ---> valid
# [...]
#Final result: valid

	issues=$(grep "Final result: false" reports/check_stripes.rpt | wc -l)
	string="Innovus: PDN stripes checks failures:"

	if [[ $issues != 0 ]]; then

		errors=1

		echo "ISPD23 -- ERROR: $string $issues -- see check_stripes.rpt for more details." >> reports/errors.rpt
	fi

	echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

	#
	# evaluate criticality of issues
	#
	if [[ $errors == 1 ]]; then

		echo -e "\nISPD23 -- 2)  $id_run:  Some critical Innovus design check(s) failed."

		date > FAILED.inv_checks
		exit 1
	else
		echo -e "\nISPD23 -- 2)  $id_run:  Innovus design checks done; all passed."

		date > PASSED.inv_checks
		exit 0
	fi
}

start_eval() {

	## iterate over keys / google IDs
	for google_team_folder in "${!google_team_folders[@]}"; do

		team="${google_team_folders[$google_team_folder]}"
		team_=$(printf "%-"$teams_string_max_length"s" $team)

		## fix, if needed, the json file for current session in json file
		google_fix_json

#		# NOTE deprecated
#		# NOTE updated here, that is once during every cycle, to make sure that recently revised shares by teams themselves are reflected right away in emails 
#		# NOTE the last grep is to filter out non-email entries, 'False' in particular (used by gdrive for global link sharing), which cannot be considered otherwise in the -E expression
#		google_share_emails[$team]=$(./gdrive share list $google_team_folder | tail -n +2 | awk '{print $4}' | grep -Ev "$emails_excluded_for_notification" | grep '@')

		queued_runs_sum=0
		# NOTE init the current runs from all work folders of all benchmarks; ignore errors for ls, which are probably only due to empty folders
		ongoing_runs=$(ls $teams_root_folder/$team/*/work/* -d 2> /dev/null | wc -l)

		for benchmark in $benchmarks; do

			id_internal="$team---$benchmark"
			downloads_folder="$teams_root_folder/$team/$benchmark/downloads"
			work_folder="$teams_root_folder/$team/$benchmark/work"
			benchmark_=$(printf "%-"$benchmarks_string_max_length"s" $benchmark)

			# NOTE handle folders in array, as this allows to go over and exclude files first (after reverting the order obtained by ls --group-directories-first below;
			# there is no counterpart option --group-files-first), which helps to get a more accurate number for queued runs
			folders_=( $(ls $downloads_folder/* -d --group-directories-first 2> /dev/null) )
			queued_runs=${#folders_[@]}

			idx=${#folders_[@]}
			unset folders
			for e in "${folders_[@]}"; do
				folders[--idx]="$e"
			done

			# handle all downloads folders
			for folder_ in "${folders[@]}"; do

				folder=${folder_##*/}

				id_run="[ $round -- $team_ -- $benchmark_ -- ${folder##*_} ]"

				## 0) skip files
				if ! [[ -d $downloads_folder/$folder ]]; then

					((queued_runs = queued_runs - 1))

					# also delete any other file than dl_history
					if [[ $folder != "dl_history" ]]; then
						rm $downloads_folder/$folder
					fi

					continue
				fi

				## 0) folders might be empty, namely when download of submission files failed -- delete empty folders
				if [[ $(ls $downloads_folder/$folder/ | wc -l) == 0 ]]; then

					((queued_runs = queued_runs - 1))
					rmdir $downloads_folder/$folder

					continue
				fi

				## 0) only max_runs runs in parallel should be running at once per team
				if [[ $ongoing_runs -ge $max_parallel_runs ]]; then

#					# NOTE do not break, only continue, to allow evaluating queued runs for all benchmarks
					continue
				fi

				## 0) start process, and update run counts
				((queued_runs = queued_runs - 1))
				((ongoing_runs = ongoing_runs + 1))

				echo "ISPD23 -- 2)  $id_run: Start processing within work folder \"$work_folder/$folder\" ..."

			## start frame of code to be run in parallel
			## https://unix.stackexchange.com/a/103921
			(

				# 1) init folder
				echo "ISPD23 -- 2)  $id_run:  Init work folder ..."
				
				## copy downloaded folder in full to work folder
				cp -rf $downloads_folder/$folder $work_folder/

				### 
				### switch to work folder
				### 
				cd $work_folder/$folder > /dev/null

				## record files processed; should be useful to share along w/ results to participants, to allow them double-checking the processed files
				# NOTE "in *" catches all files, also those including spaces and other special characters
				for file in *; do

					# log MD5
					# NOTE md5sum still needs quotes to capture files w/ spaces etc as one file
					md5sum "$file" >> processed_files_MD5.rpt

					# pack processed files again; only for dbg mode, to be uploaded again for double-checking
					# NOTE only mute regular stdout, but keep stderr
					if [[ $dbg_files == "1" ]]; then
						zip processed_files.zip $file > /dev/null
					fi
				done

				## init reports folder (only now, to not include in md5 hashes)
				mkdir reports
				mv processed_files_MD5.rpt reports/

				# 2) send out email notification of start 

				echo "ISPD23 -- 2)  $id_run:  Send out email about processing start ..."

				# NOTE we use this id as subject for both emails, begin and end of processing, to put them into thread at receipents mailbox
				subject="[ ISPD23 Contest: $round round -- $team -- $benchmark -- reference ${folder##*_} ]"

				text="The processing of your latest submission has started. You will receive another email once results are ready."
				text+="\n\n"

				text+="MD5 hash and name of files processed in this latest submission are as follows:"
				text+="\n"
				text+=$(cat reports/processed_files_MD5.rpt)
				text+="\n\n"

				# NOTE the number for queued runs is more accurate here, but still does not account for empty folders that are not yet processed
				text+="Processing status: You have currently $ongoing_runs run(s) ongoing in total, and $queued_runs more run(s) queued for this particular benchmark."
				text+=" "
				text+="At this point, the evaluation server may start $((max_parallel_runs - $ongoing_runs)) more concurrent run(s), of any benchmark(s), for you."
				text+=" "
				text+="You can upload as many submissions as you like, but processing is subject to these run limits."

				send_email "$text" "$subject" "${google_share_emails[$team]}"

				# 3) link scripts and design files needed for evaluation

				link_work_dir

				if [[ $? != 0 ]]; then

					echo "ISPD23 -- 2)  $id_run:  Abort further processing ..."

					# mark as failed, via file, to allow check_eval to clear and prepare to upload this run
					date > FAILED.link_work_dir

					# also return to previous main dir
					cd - > /dev/null

					# cleanup downloads dir, to avoid processing again; do so even considering it failed, because it would likely fail again then anyway unless we are fixing things
					rm -r $downloads_folder/$folder

					# exit subshell for processing of this submission
					exit 1
				fi

				# 4) check submission; simple checks

				check_submission

				if [[ $? != 0 ]]; then

					echo "ISPD23 -- 2)  $id_run:  Abort further processing ..."

					# mark as failed, via file, to allow check_eval to clear and prepare to upload this run
					date > FAILED.check_submission

					# also return to previous main dir
					cd - > /dev/null

					# cleanup downloads dir, to avoid processing again; do so even considering it failed,
					# because it would likely fail again then anyway unless we are fixing things
					rm -r $downloads_folder/$folder

					# exit subshell for processing of this submission
					exit 1
				fi

				# 5) start processing for actual checks
			
				echo "ISPD23 -- 2)  $id_run:  Starting LEC design checks ..."

				# NOTE redirect both stdout and stderr to log file; stderr mainly because the license checkout message is put into stderr which is otherwise filling
				# the the log as well
				call_lec scripts/lec.do > lec.log 2>&1 &
				echo $! > PID.lec_checks

				echo "ISPD23 -- 2)  $id_run:  Starting Innovus design checks ..."

				# NOTE for design checks and evaluation, vdi are sufficient.
				#
				# NOTE vdi is limited to 50k instances per license --> ruled out for aes w/ its ~260k instances
				if [[ $benchmark == "aes" ]]; then

					# NOTE only mute regular stdout, which is put into log file already, but keep stderr
					call_invs_only scripts/checks.tcl -stylus -log checks > /dev/null &
					echo $! > PID.inv_checks
				else
					call_vdi_only scripts/checks.tcl -stylus -log checks > /dev/null &
					echo $! > PID.inv_checks
				fi

				echo "ISPD23 -- 2)  $id_run:  Starting Innovus PPA evaluation ..."

				if [[ $benchmark == "aes" ]]; then

					call_invs_only scripts/PPA.tcl -log PPA > /dev/null &
					echo $! > PID.inv_PPA
				else
					call_vdi_only scripts/PPA.tcl -log PPA > /dev/null &
					echo $! > PID.inv_PPA
				fi

				echo "ISPD23 -- 2)  $id_run:  Starting Innovus Trojan insertion ..."

				# NOTE this wrapper already covers error handling, monitor subshells, and generation of status files
				# NOTE separate subshell required such that interrupts on daemon still keep the monitoring subprocesses for TI running
				# NOTE for id_run, we need quotes since the string itself contains spaces
				( scripts/TI_wrapper.sh $daemon_settings_file "$id_run" ) &

				# 6) cleanup downloads dir, to avoid processing again

				rm -r $downloads_folder/$folder #2> /dev/null
			) &

			done

		# once all folders are processed, we should have the exact number of still queued runs for this benchmark
		runs_queued[$id_internal]=$queued_runs
		((queued_runs_sum = queued_runs_sum + queued_runs))

		done

	echo "ISPD23 -- 2)  [ $team_ ]: Currently $ongoing_runs run(s) ongoing, $queued_runs_sum more run(s) queued, and would be allowed to start $((max_parallel_runs - $ongoing_runs)) more run(s)."

	done

	# wait for all parallel runs to finish
	wait
}
