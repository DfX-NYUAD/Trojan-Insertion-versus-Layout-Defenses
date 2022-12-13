#!/bin/bash

google_check_fix_json() {

	## for some reason, probably race condition or other runtime conflict, the gdrive tool sometimes messes up the
	## syntax when handling/updating the json file
	## the issue is simply "}}" instead of "}" -- simple fixing via sed
	sed 's/}}/}/g' -i $google_json_file
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
	
	## query drive for root folder, extract columns 1 and 2 from response
	## store into associative array; key is google file/folder ID, value is actual file/folder name
	
	echo "ISPD23 -- 0)  Checking Google root folder \"$google_root_folder\" ..."

	## check and fix, if needed, the json file for current session in json file
	google_check_fix_json

	while read -r a b; do
		google_team_folders[$a]=$b
	# NOTE use this for testing, to work on _test folders only
	done < <(./gdrive list --no-header -q "parents in '$google_root_folder' and trashed = false and (name contains '_test')" | awk '{print $1" "$2}')
	## NOTE use this for actual runs
	#done < <(./gdrive list --no-header -q "parents in '$google_root_folder' and trashed = false and not (name contains '_test')" | awk '{print $1" "$2}')
	
	echo "ISPD23 -- 0)   Found ${#google_team_folders[@]} team folders:"
	for team in "${google_team_folders[@]}"; do
		echo "ISPD23 -- 0)    \"$team\""
	done
	echo "ISPD23 -- 0)"
	
	# init local array for folder references, helpful for faster gdrive access later on throughout all other procedures
	#
	echo "ISPD23 -- 0)   Obtain all Google folder IDs/references ..."
	
	## iterate over keys / google IDs
	for google_team_folder in "${!google_team_folders[@]}"; do
	
		team="${google_team_folders[$google_team_folder]}"
	
		google_round_folder=$(./gdrive list --no-header -q "parents in '$google_team_folder' and trashed = false and name = '$round'" | awk '{print $1}')
	
		# NOTE the last grep is to filter out non-email entries, 'False' in particular (used by gdrive for global link sharing), which cannot be considered otherwise in the -E expression
		google_share_emails[$team]=$(./gdrive share list $google_round_folder | tail -n +2 | awk '{print $4}' | grep -Ev "$emails_excluded_for_notification" | grep '@')
	
		for benchmark in $benchmarks; do
	
			id_internal="$team --- $benchmark"

			# obtain drive references per benchmark
			google_benchmark_folders[$id_internal]=$(./gdrive list --no-header -q "parents in '$google_round_folder' and trashed = false and name = '$benchmark'" | awk '{print $1}')

			# in case the related benchmark folder is missing, create it on the drive
			if [[ ${google_benchmark_folders[$id_internal]} == "" ]]; then

				echo "ISPD23 -- 0)    Init missing Google folder for round \"$round\", team \"$team\", benchmark \"$benchmark\" ..."

				# work with empty dummy folders in tmp dir
				mkdir -p $tmp_root_folder/$benchmark
				./gdrive upload -p $google_round_folder -r $tmp_root_folder/$benchmark
				rmdir $tmp_root_folder/$benchmark

				# update the reference for the just created folder
				google_benchmark_folders[$id_internal]=$(./gdrive list --no-header -q "parents in '$google_round_folder' and trashed = false and name = '$benchmark'" | awk '{print $1}')
			fi
		done
	done
	
	# Check corresponding local folders
	#
	echo "ISPD23 -- 0)   Check corresponding local folders in $teams_root_folder/ ..."
	
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
}

google_downloads() {

	## check and fix, if needed, the json file for current session in json file
	google_check_fix_json

	## iterate over keys / google IDs
	for google_team_folder in "${!google_team_folders[@]}"; do

		team=${google_team_folders[$google_team_folder]}
		team_folder="$teams_root_folder/$team"

		echo "ISPD23 -- 1)  Checking team folder \"$team\" (Google team folder ID \"$google_team_folder\") for new submission files ..."

		for benchmark in $benchmarks; do

		(
			id_internal="$team --- $benchmark"
			google_benchmark_folder=${google_benchmark_folders[$id_internal]}

			## NOTE relatively verbose; could be turned off
			#echo "ISPD23 -- 1)   Checking benchmark \"$benchmark\" (Google benchmark folder ID \"$google_benchmark_folder\") ..."

			downloads_folder="$team_folder/$benchmark/downloads"
			declare -A basename_folders=()

			# array of [google_ID]=actual_file_name
			declare -A google_folder_files=()
			# array of [google_ID]=file_type
			declare -A google_folder_files_type=()

			while read -r a b c; do
				google_folder_files[$a]=$b
				google_folder_files_type[$a]=$c
			# NOTE no error handling for the gdrive call itself; would have to jump in before awk and array assignment -- not really needed, since the error can be inferred from other log lines, like:
				## ISPD23 -- 1)  Download new submission file "to" (Google file ID "Failed") into dedicated folder
				## Failed to get file: googleapi: Error 404: File not found: Failed., notFound
				##
				## ISPD23_daemon_procedures.sh: line 168: google_folder_files[$a]: bad array subscript
			done < <(./gdrive list --no-header -q "parents in '$google_benchmark_folder' and trashed = false and not (name contains 'results')" 2> /dev/null | awk '{print $1" "$2" "$3}')

			## pre-processing: list files within (sub)folders, if any
			for folder in "${!google_folder_files_type[@]}"; do

				if [[ ${google_folder_files_type[$folder]} != "dir" ]]; then
					continue
				fi

				# add files of subfolder to google_folder_files
				while read -r a b c; do
					google_folder_files[$a]=$b
					google_folder_files_type[$a]=$c
				# NOTE no error handling for the gdrive call itself; would have to jump in before awk and array assignment -- not really needed, since the error can be inferred from other log lines; see note above
				done < <(./gdrive list --no-header -q "parents in '$folder' and trashed = false and not (name contains 'results')" 2> /dev/null | awk '{print $1" "$2" "$3}')
			done

			## iterate over keys / google IDs
			for file in "${!google_folder_files[@]}"; do

				# cross-check w/ already downloaded ones, considering unique Google IDS, memorized in history file
				if [[ $(grep -c $file $downloads_folder/dl_history) != '0' ]]; then
					continue
				fi

				# skip subfolders (if any), as their files are already included in the google_folder_files array
				if [[ ${google_folder_files_type[$file]} == "dir" ]]; then
					continue
				fi

				actual_file_name=${google_folder_files[$file]}
				basename=${actual_file_name%.*}
				## DBG
				#echo "ISPD23 -- basename: $basename"

				# sanity check for malformated file names with only suffix, like ".nfs000000001f6680dd00000194"
				if [[ $basename == "" ]]; then
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

				echo "ISPD23 -- 1)  Download new submission file \"$actual_file_name\" (Google file ID \"$file\") into dedicated folder \"$downloads_folder_\" ..."
				./gdrive download -f --path $downloads_folder_ $file #> /dev/null 2>&1

				# memorize to not download again, but only if the download succeeded
				if [[ $? == 0 ]]; then

					echo $file >> $downloads_folder/dl_history
				fi

				# unpack archive, if applicable
				## NOTE for long filenames, gdrive will put "..." in the middle, which leads to	$actual_file_name not matched as is; so, use sed to replace "..." w/ proper * wildcard
				actual_file_name_=$(echo $actual_file_name | sed 's/\.\.\./*/g')
				if [[ $(file $downloads_folder_/$actual_file_name_ | awk '{print $2}') == 'Zip' ]]; then

					echo "ISPD23 -- 1)   Unpacking zip file \"$actual_file_name_\" into dedicated folder \"$downloads_folder_\" ..."
					# NOTE only mute regular stdout, but keep stderr
					unzip -j $downloads_folder_/$actual_file_name_ -d $downloads_folder_ > /dev/null #2>&1
					rm $downloads_folder_/$actual_file_name_ #> /dev/null 2>&1
				fi

				# chances are that processing is too fast, resulting in clashes for timestamp in folders, hence slow down on purpose here
				sleep 1s
			done
		) &

		done
	done

	# wait for all parallel runs to finish
	wait
}

google_uploads() {

	count_parallel_uploads=0

	## check and fix, if needed, the json file for current session in json file
	google_check_fix_json

	## iterate over keys / google IDs
	for google_team_folder in "${!google_team_folders[@]}"; do

		for benchmark in $benchmarks; do

			team=${google_team_folders[$google_team_folder]}
			id_internal="$team --- $benchmark"
			uploads_folder="$teams_root_folder/$team/$benchmark/uploads"

			# handle all the uploads folders that might have accumulated through batch processing
			for folder in $(ls $uploads_folder); do

				## 0)  only max_parallel_uploads should be triggered at once
				if [[ "$count_parallel_uploads" == "$max_parallel_uploads" ]]; then
					break 3
				fi

				## 1) count parallel uploads (i.e., uploads started within the same cycle)
				((count_parallel_uploads = count_parallel_uploads + 1))

				## 2) begin parallel uploads

				# NOTE init vars once, before parallel runs start
				google_benchmark_folder=${google_benchmark_folders[$id_internal]}
				benchmark_=$(printf "%-"$benchmarks_string_max_length"s" $benchmark)
				team_=$(printf "%-"$teams_string_max_length"s" $team)
				id_run="[ $round -- $team_ -- $benchmark_ -- ${folder##*_} ]"
			(
				echo "ISPD23 -- 4)  $id_run: Upload results folder \"$uploads_folder/$folder\" (Google team folder ID \"$google_team_folder\", Google benchmark folder ID \"$google_benchmark_folder\") ..."
				./gdrive upload -p $google_benchmark_folder -r $uploads_folder/$folder #> /dev/null 2>&1

				## cleanup locally, but only if upload succeeded
				if [[ $? -ne 0 ]]; then
					# NOTE use exit, not contine, as we are at the main level in a subshell here now
					exit 1
				fi

				rm -rf $uploads_folder/$folder

				## also send out email notification of successful upload
				#
				echo "ISPD23 -- 4)  $id_run: Send out email about uploaded results folder ..."
				# NOTE errors could be suppressed here, but they can also just be sent out. In case it fails, these might be helpful and can be checked from the sent mailbox
				#google_uploaded_folder=$(./gdrive list --no-header -q "parents in '$google_benchmark_folder' and trashed = false and name = '$folder'" 2> /dev/null | awk '{print $1}')
				google_uploaded_folder=$(./gdrive list --no-header -q "parents in '$google_benchmark_folder' and trashed = false and name = '$folder'" | awk '{print $1}')

				# NOTE we use this id as subject for both emails, begin and end of processing, to put them into thread at receipents mailbox
				subject="Re: [ ISPD23 Contest: $round round -- $team -- $benchmark -- reference ${folder##*_} ]"
				text="The results for your latest submission are ready in your corresponding Google Drive folder.\n\nDirect link: https://drive.google.com/drive/folders/$google_uploaded_folder"

				send_email "$text" "$subject" "${google_share_emails[$team]}"
			) &

			done
		done
	done

	# wait for all parallel runs to finish
	wait
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

				## 0) start parallel subshells to continuously monitor the actual evaluation processes
				#
				# NOTE we need this double subshell to avoid stalling further processing; otherwise, I
				# think, the two inner subshells would be locking into the next wait command, even
				# from any other procedure
			(
				# Innovus design checks
				(
					# NOTE subshell should be started only once, to avoid race conditions -- handle via PID file
				 	# NOTE ignore errors for cat, in case PID file not existing yet; for ps, ignore
					# related file errors and others errors and also drop output, just keep status/exit code
					running=$(ps --pid $(cat PID.monitor.design_checks 2> /dev/null) > /dev/null 2>&1; echo $?)
					if [[ $running != 0 ]]; then
						echo $$ > PID.monitor.design_checks
					else
						exit 2
					fi

#					echo "ISPD23 -- 3)  $id_run:  Process monitor subshell started for Innovus design checks"

					# sleep a little to avoid immediate but useless errors concerning log file not
					# found; is only relevant for the very first run just following right after
					# starting the process, but should still be employed here as fail-safe measure
					sleep 1s

					while true; do

						if [[ -e DONE.design_checks ]]; then
							break
						else
							# check for any errors; if found, try to kill and return
							#
							# NOTE limit to 1k errors since tools may flood log files w/
							# INTERRUPT messages etc, which would then stall grep
							errors=$(grep -m 1000 -E "$innovus_errors_for_checking" check.log* | grep -Ev "$innovus_errors_excluded_for_checking")
							if [[ $errors != "" ]]; then

								echo -e "\nISPD23 -- 2)  $id_run:  Some error occurred for Innovus design checks. Trying to kill process ..."

								echo "ISPD23 -- ERROR: process failed for Innovus design checks -- $errors" >> reports/errors.rpt

								cat PID.design_checks | xargs kill #2> /dev/null

								date > FAILED.design_checks
								exit 1
							fi
						
							# also check for interrupts; if triggered, abort processing
							#
							errors_interrupt=$(ps --pid $(cat PID.design_checks) > /dev/null; echo $?)
							if [[ $errors_interrupt != 0 ]]; then

								# NOTE also check again for DONE flag file, to avoid race condition where
								# process just finished but DONE did not write out yet
								sleep 1s
								if [[ -e DONE.design_checks ]]; then
									break
								fi

								echo -e "\nISPD23 -- 2)  $id_run:  Innovus design checks got interrupted. Abort processing ..."
								echo "ISPD23 -- ERROR: process failed for Innovus design checks -- INTERRUPT" >> reports/errors.rpt

								date > FAILED.design_checks
								exit 1
							fi
						fi

						sleep 1s
					done

					## parse rpt, log files for failures
					## put summary into warnings.rpts; also extract violations count into checks_summary.rpt
					## set/mark status via PASSED/FAILED files
					parse_design_checks
				) &

				# LEC design checks
				(
					# NOTE subshell should be started only once, to avoid race conditions -- handle via PID file
				 	# NOTE ignore errors for cat, in case PID file not existing yet; for ps, ignore
					# related file errors and others errors and also drop output, just keep status/exit code
					running=$(ps --pid $(cat PID.monitor.lec 2> /dev/null) > /dev/null 2>&1; echo $?)
					if [[ $running != 0 ]]; then
						echo $$ > PID.monitor.lec
					else
						exit 2
					fi

#					echo "ISPD23 -- 3)  $id_run:  Process monitor subshell started for LEC design checks ..."

					# sleep a little to avoid immediate but useless errors concerning log file not
					# found; is only relevant for the very first run just following right after
					# starting the process, but should still be employed here as fail-safe measure
					sleep 1s

					while true; do

						if [[ -e DONE.lec ]]; then
							break
						else
							# check for any errors; if found, try to kill and return
							#
							# NOTE limit to 1k errors since tools may flood log files w/
							# INTERRUPT messages etc, which would then stall grep
							errors=$(grep -m 1000 -E "$lec_errors_for_checking" lec.log)
							if [[ $errors != "" ]]; then

								# NOTE begin logging w/ linebreak, to differentiate from other ongoing logs like sleep progress bar
								echo -e "\nISPD23 -- 2)  $id_run:  Some error occurred for LEC design checks. Trying to kill process ..."

								echo "ISPD23 -- ERROR: process failed for LEC design checks -- $errors" >> reports/errors.rpt

								cat PID.lec | xargs kill #2> /dev/null

								date > FAILED.lec
								exit 1
							fi
						
							# also check for interrupts; if triggered, abort processing
							#
							errors_interrupt=$(ps --pid $(cat PID.lec) > /dev/null; echo $?)
							if [[ $errors_interrupt != 0 ]]; then

								# NOTE also check again for DONE flag file, to avoid race condition where
								# process just finished but DONE did not write out yet
								sleep 1s
								if [[ -e DONE.lec ]]; then
									break
								fi

								echo -e "\nISPD23 -- 2)  $id_run:  LEC design checks got interrupted. Abort processing ..."
								echo "ISPD23 -- ERROR: process failed for LEC design checks -- INTERRUPT" >> reports/errors.rpt

								date > FAILED.lec
								exit 1
							fi
						fi

						sleep 1s
					done

					## parse rpt, log files for failures
					## put summary into warnings.rpts; also extract violations count into checks_summary.rpt
					## set/mark status via PASSED/FAILED files
					parse_lec_checks
				) &

			) &

				## 1) check status of processes
				#
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

				## design checks
				if [[ -e PASSED.designs_checks ]]; then
					status[design_checks]=1
					echo "ISPD23 -- 3)  $id_run:  Innovus design checks: done"

				elif [[ -e FAILED.design_checks ]]; then
					status[design_checks]=2
					echo "ISPD23 -- 3)  $id_run:  Innovus design checks: failed"

				# in case init steps failed, this check is not running at all -- mark as failed but
				# don't report on status
				elif [[ ${status[init]} == 2 ]]; then
					status[design_checks]=2
				else
					status[design_checks]=0
					echo "ISPD23 -- 3)  $id_run:  Innovus design checks: still working ..."
				fi

				## LEC design checks
				if [[ -e PASSED.lec ]]; then
					status[lec]=1
					echo "ISPD23 -- 3)  $id_run:  LEC design checks: done"

				elif [[ -e FAILED.lec ]]; then
					status[lec]=2
					echo "ISPD23 -- 3)  $id_run:  LEC design checks: failed"

				# in case init steps failed, this check is not running at all -- mark as failed but
				# don't report on status
				elif [[ ${status[init]} == 2 ]]; then
					status[lec]=2
				else
					status[lec]=0
					echo "ISPD23 -- 3)  $id_run:  LEC design checks: still working ..."
				fi

				## 2) if not done yet (implies no error), then continue, i.e., skip the further processing for now
				if [[ ${status[design_checks]} == 0 || ${status[lec]} == 0 ]]; then
					
					# first return to previous main dir silently
					cd - > /dev/null

					continue
				fi

# TODO activate once 1st order sec metrics are done
#
#				## 3) compute scores
#				echo "ISPD23 -- 3)  $id_run:  Computing scores ..."
#				# NOTE only mute regular stdout, which is put into log file already, but keep stderr
#				scripts/scores.sh 6 $baselines_root_folder/$benchmark/reports > /dev/null

				## 4) create related upload folder, w/ same timestamp as work and download folder
				uploads_folder="$teams_root_folder/$team/$benchmark/uploads/results_${folder##*_}"
				mkdir $uploads_folder

				## 5) pack and results files into uploads folder
				echo "ISPD23 -- 3)  $id_run:  Packing results files into uploads folder \"$uploads_folder\" ..."

				# -j means to smash reports/ folder; just put files into zip archive directly
				# include regular rpt files, not others (like, *.rpt.extended files)
				# NOTE only mute regular stdout, but keep stderr
				zip -j $uploads_folder/reports.zip reports/*.rpt > /dev/null

				# also include detailed timing reports
				# NOTE only mute regular stdout, but keep stderr
				zip -r $uploads_folder/reports.zip timingReports/ > /dev/null

				# also share log files
				# NOTE only mute regular stdout, but keep stderr
				zip $uploads_folder/logs.zip *.log* > /dev/null

#				# NOTE deprecated
#				## put processed files again into uploads folder
#				echo "ISPD23 -- 3)  $id_run:  Including backup of processed files to uploads folder \"$uploads_folder\" ..."
#				mv processed_files.zip $uploads_folder/ #2> /dev/null

				## 6) backup work dir
				echo "ISPD23 -- 3)  $id_run:  Backup work folder to \"$backup_work_folder/$folder".zip"\" ..."
				mv $work_folder/$folder $backup_work_folder/

				# return to previous main dir silently; goes together with the final 'cd -' command at the end
				cd - > /dev/null

				# compress backup
				cd $backup_work_folder > /dev/null

				# silent cleanup of rpt files lingering around in main folder
				# NOTE As of now, only a 0-byte power.rpt file occurs here (the proper file is in reports/power.rpt). Not sure why this happens
				# though. Also, instead of deleting, moving to reports/ would be an option -- but, not for that 0-byte power.rpt file
				rm $folder/*.rpt > /dev/null 2>&1

				# NOTE only mute regular stdout, but keep stderr
				zip -y -r $folder'.zip' $folder/ > /dev/null #2>&1

				rm -r $folder/

				# unzip all rpt files again, also those *.rpt.ext etc; rpt files should be readily accessible for debugging
				# NOTE only mute regular stdout, but keep stderr
				unzip $folder'.zip' $folder/reports/* > /dev/null #2>&1
#				# NOTE deprecated; log files can be GBs large in case of interrupts
#				#unzip $folder'.zip' $folder/*.log > /dev/null #2>&1

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
			grep -q -w $escaped_asset design.def

			if [[ $? == 1 ]]; then

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
	pid_assets=$!

# TODO revise checks; currently off: pins, PDN
# TODO should be done as simple scripts, ideally w/o need for loading DEF, or least just loading DEF and then quick
# checks. Otherwise, long Innovus design checks should be move to related subshells in the start_eval() procedure
#
#	##
#	## pins checks
#	##
#
#	(
#		echo "ISPD23 -- 2)  $id_run:   Pins design checks ..."
#
#		# NOTE only mute regular stdout, which is put into log file already, but keep stderr
#		scripts/check_pins.sh > /dev/null
#
#		# parse rpt for FAIL
#		##errors=$(grep -q "FAIL" reports/check_pins.rpt 2> /dev/null; echo $?)
#		errors=$(grep -q "FAIL" reports/check_pins.rpt; echo $?)
#		if [[ $errors == 0 ]]; then
#
#			echo "ISPD23 -- ERROR: For pins design check -- see check_pins.rpt for more details." >> errors.rpt
#
#			exit 1
#		fi
#
#		echo "ISPD23 -- 2)  $id_run:   Pins design checks passed."
#
#		exit 0
#	) &
#	pid_pins_checks=$!
#
#	##
#	## PDN checks
#	##
#
#	(
#		echo "ISPD23 -- 2)  $id_run:   PDN checks ..."
#
#		# NOTE only mute regular stdout, which is put into log file already, but keep stderr
#		bash -c 'echo $$ > PID.pg; exec innovus -nowin -files scripts/pg.tcl -log pg > /dev/null' &
#
#		# sleep a little to avoid immediate but useless errors concerning log file not found
#		sleep 1s
#
#		while true; do
#
#			if [[ -e DONE.pg ]]; then
#
#				break
#			else
#				# check for any errors; if found, try to kill and return
#				#
#				errors=$(grep -E "$innovus_errors_for_checking" pg.log* | grep -Ev "$innovus_errors_excluded_for_checking")
#				if [[ $errors != "" ]]; then
#
#					echo "ISPD23 -- 2)  $id_run:   Some error occurred for PDN checks. Trying to kill process ..."
#
#					echo "ISPD23 -- ERROR: process failed for PDN design checks -- $errors" >> reports/errors.rpt
#
#					cat PID.pg | xargs kill #2> /dev/null
#
#					exit 1
#				fi
#
#				# TODO add checking for INTERRUPT, as in design checks
#			fi
#
#			sleep 1s
#		done
#
#		# post-process reports
#		# NOTE only mute regular stdout, which is put into log file already, but keep stderr
#		scripts/check_pg.sh $baselines_root_folder/$benchmark/reports > /dev/null
#
#		# parse errors.rpt for "ERROR: For PG check"
#		##errors=$(grep -q "ERROR: For PG check" reports/errors.rpt 2> /dev/null; echo $?)
#		errors=$(grep -q "ERROR: For PG check" reports/errors.rpt; echo $?)
#		if [[ $errors == 0 ]]; then
#
#			echo "ISPD23 -- 2)  $id_run:   Some failure occurred during PDN design checks."
#
#			exit 1
#		fi
#		# also parse rpt for FAIL 
#		##errors=$(grep -q "FAIL" reports/pg_metals_eval.rpt 2> /dev/null; echo $?)
#		errors=$(grep -q "FAIL" reports/pg_metals_eval.rpt; echo $?)
#		if [[ $errors == 0 ]]; then
#
#			echo "ISPD23 -- ERROR: For PG check -- see pg_metals_eval.rpt for more details." >> reports/errors.rpt
#			echo "ISPD23 -- 2)  $id_run:   Some PDN design check(s) failed."
#
#			exit 1
#		fi
#
#		echo "ISPD23 -- 2)  $id_run:   PDN checks passed."
#
#		exit 0
#	) &
#	pid_PDN_checks=$!

	# wait for subshells and memorize their exit code in case it's non-zero
	wait $pid_assets || status=$?
# TODO revise checks; currently off: pins, PDN
#	wait $pid_pins_checks || status=$?
#	wait $pid_PDN_checks || status=$?

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
	if [[ $def_files != '1' ]]; then

		echo "ISPD23 -- ERROR: there are $def_files DEF files in the submission's work directory, which shouldn't happen." >> reports/errors.rpt

		errors=1
	fi
	## NOTE don't force here, to avoid circular links from design.def to design.def itself, in case the submitted file's name is already the same
	## NOTE suppress stderr for 'File exists' -- happens when submission uses same name already -- but keep all others
	ln -s *.def design.def 2>&1 | grep -v "File exists"
	
	## netlist, including sanity checks
	netlist_files=$(ls *.v 2> /dev/null | wc -l)
	if [[ $netlist_files != '1' ]]; then

		echo "ISPD23 -- ERROR: there are $netlist_files netlist files in the submission's work directory, which shouldn't happen." >> reports/errors.rpt

		errors=1
	fi
	## NOTE don't force here, to avoid circular links from design.v to itself, in case the submitted file's name is already the same
	## NOTE suppress stderr for 'File exists' -- happens when submission uses same name already -- but keep all others
	ln -s *.v design.v 2>&1 | grep -v "File exists"

	## init reports folder; mv any already existing report (should be only processed_files_MD5.rpt at this point)
	mkdir reports
	mv *.rpt reports/

	## link files related to benchmark into work dir
	# NOTE force here in order to guarantee that the correct files are used, namely those from the reference folders
	ln -sf $baselines_root_folder/$benchmark/*.sdc . 
	ln -sf $baselines_root_folder/$benchmark/design.assets* .
	ln -sf $baselines_root_folder/$benchmark/design.v design_original.v
	ln -sf $baselines_root_folder/$benchmark/design.def design_original.def

	## link scripts into work dir, using dedicated subfolder

	mkdir scripts
	cd scripts > /dev/null

	for script in $scripts; do
		ln -sf $scripts_folder/$script .
	done
	
	cd - > /dev/null

	## link files related to library into work dir

	mkdir ASAP7
	cd ASAP7 > /dev/null

	for file in $(ls $baselines_root_folder/$benchmark/ASAP7); do
		ln -sf $baselines_root_folder/$benchmark/ASAP7/$file .
	done
## NOTE deprecated; handling of files separately and explicitly
#	ln -sf $baselines_root_folder/$benchmark/ASAP7/$qrc_file .
#	for file in $lib_files; do
#		ln -sf $baselines_root_folder/$benchmark/ASAP7/$file .
#	done
#	for file in $lef_files; do
#		ln -sf $baselines_root_folder/$benchmark/ASAP7/$file .
#	done

	cd - > /dev/null

	if [[ $errors != 0 ]]; then

		echo "ISPD23 -- 2)  $id_run:  Error occurred during init of submission files."
	fi

	return $errors
}

# TODO declare any other issues as error as well the moment its value exceeds (baseline + 10)
parse_lec_checks() {

	errors=0

	#
	# non-equivalence issues
	#
	## NOTE failure on those considered as error/constraint violation
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
	if [[ $issues != "" ]]; then

		echo "ISPD23 -- ERROR: LEC design checks failure -- $issues equivalence issues; see check_equivalence.rpt for more details." >> reports/errors.rpt
		echo "ISPD23 -- LEC: Equivalence issues: $issues" >> reports/checks_summary.rpt

		errors=1
	else
		echo "ISPD23 -- LEC: Equivalence issues: 0" >> reports/checks_summary.rpt
	fi

	#
	# unreachable issues
	#
	## NOTE failure on those considered as error/constraint violation
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
	if [[ $issues != "" ]]; then

		echo "ISPD23 -- ERROR: LEC design checks failure -- $issues unreachable points issues; see check_equivalence.rpt for more details." >> reports/errors.rpt
		echo "ISPD23 -- LEC: Unreachable points issues: $issues" >> reports/checks_summary.rpt

		errors=1
	else
		echo "ISPD23 -- LEC: Unreachable points issues: 0" >> reports/checks_summary.rpt
	fi

	#
	# different connectivity issues during parsing
	#
	## NOTE these are hinting on cells used as dummy fillers
	#

# Example:
#// Warning: (RTL2.5) Net is referenced without an assignment. Design verification will be based on set_undriven_signal setting (occurrence:7) 
# NOTE such line is only present if errors/issues found at all
# NOTE such line, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design
	issues=$(grep "Warning: (RTL2.5) Net is referenced without an assignment. Design verification will be based on set_undriven_signal setting" lec.log | awk '{print $18}' | awk 'NR==2')
	issues=${issues##*:}
	issues=${issues%*)}
	if [[ $issues != "" ]]; then

		echo "ISPD23 -- WARNING: LEC design checks failure -- $issues unassigned nets issues" >> reports/warnings.rpt
		echo "ISPD23 -- LEC: Unassigned nets issues: $issues" >> reports/checks_summary.rpt
	else
		echo "ISPD23 -- LEC: Unassigned nets issues: 0" >> reports/checks_summary.rpt
	fi

# Example:
#// Warning: (RTL2.13) Undriven pin is detected (occurrence:3)
#
# NOTE such line is only present if errors/issues found at all
# NOTE such line, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design
	issues=$(grep "Warning: (RTL2.13) Undriven pin is detected" lec.log | awk '{print $8}' | awk 'NR==2')
	issues=${issues##*:}
	issues=${issues%*)}
	if [[ $issues != "" ]]; then

		echo "ISPD23 -- WARNING: LEC design checks failure -- $issues undriven pins issues" >> reports/warnings.rpt
		echo "ISPD23 -- LEC: Undriven pins issues: $issues" >> reports/checks_summary.rpt
	else
		echo "ISPD23 -- LEC: Undriven pins issues: 0" >> reports/checks_summary.rpt
	fi

# Example:
#// Warning: (RTL14) Signal has input but it has no output (occurrence:2632)
#
# NOTE such line is only present if errors/issues found at all
# NOTE such issues often occur for baseline layouts as well. These checks here are the only warnings related to cells
# inserted and connected to inputs but otherwise useless (no output), so we need to keep that check
# NOTE such line, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design
	issues=$(grep "Warning: (RTL14) Signal has input but it has no output" lec.log | awk '{print $12}' | awk 'NR==2')
	issues=${issues##*:}
	issues=${issues%*)}
	if [[ $issues != "" ]]; then

		echo "ISPD23 -- WARNING: LEC design checks failure -- $issues net output floating issues" >> reports/warnings.rpt
		echo "ISPD23 -- LEC: Net output floating issues: $issues" >> reports/checks_summary.rpt
	else
		echo "ISPD23 -- LEC: Net output floating issues: 0" >> reports/checks_summary.rpt
	fi

# Example for two related issues:
#// Warning: (HRC3.5a) Open input/inout port connection is detected (occurrence:3)
#// Note: (HRC3.5b) Open output port connection is detected (occurrence:139)
#
# NOTE such lines are only present if errors/issues found at all
# NOTE such lines, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design
	issues_a=$(grep "Warning: (HRC3.5a) Open input/inout port connection is detected" lec.log | awk '{print $10}' | awk 'NR==2')
	issues_b=$(grep "Note: (HRC3.5b) Open output port connection is detected" lec.log | awk '{print $10}' | awk 'NR==2')
	issues_a=${issues_a##*:}
	issues_a=${issues_a%*)}
	issues_b=${issues_b##*:}
	issues_b=${issues_b%*)}

	issues=0
	if [[ $issues_a != "" ]]; then
		((issues = issues + issues_a))
	fi
	if [[ $issues_b != "" ]]; then
		((issues = issues + issues_b))
	fi
	
	if [[ $issues != 0 ]]; then

		echo "ISPD23 -- WARNING: LEC design checks failure -- $issues open ports issues" >> reports/warnings.rpt
		echo "ISPD23 -- LEC: Open ports issues: $issues" >> reports/checks_summary.rpt
	else
		echo "ISPD23 -- LEC: Open ports issues: 0" >> reports/checks_summary.rpt
	fi

# Example:
#// Warning: (HRC3.10a) An input port is declared, but it is not completely used in the module (occurrence:674)
#
# NOTE such line is only present if errors/issues found at all
# NOTE such line, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design
	issues=$(grep "Warning: (HRC3.10a) An input port is declared, but it is not completely used in the module" lec.log | awk '{print $18}' | awk 'NR==2')
	issues=${issues##*:}
	issues=${issues%*)}
	if [[ $issues != "" ]]; then

		echo "ISPD23 -- WARNING: LEC design checks failure -- $issues input port not fully used issues" >> reports/warnings.rpt
		echo "ISPD23 -- LEC: Input port not fully used issues: $issues" >> reports/checks_summary.rpt
	else
		echo "ISPD23 -- LEC: Input port not fully used issues: 0" >> reports/checks_summary.rpt
	fi

# Example:
#// Warning: (HRC3.16) A wire is declared, but not used in the module (occurrence:1)
#
# NOTE such line is only present if errors/issues found at all
# NOTE such line, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design
	issues=$(grep "Warning: (HRC3.16) A wire is declared, but not used in the module" lec.log | awk '{print $14}' | awk 'NR==2')
	issues=${issues##*:}
	issues=${issues%*)}
	if [[ $issues != "" ]]; then

		echo "ISPD23 -- WARNING: LEC design checks failure -- $issues unused wire issues" >> reports/warnings.rpt
		echo "ISPD23 -- LEC: Unused wire issues: $issues" >> reports/checks_summary.rpt
	else
		echo "ISPD23 -- LEC: Unused wire issues: 0" >> reports/checks_summary.rpt
	fi

	#
	# evaluate criticality of issues
	#
	if [[ $errors == 1 ]]; then

		echo -e "\nISPD23 -- 2)  $id_run:  Some critical LEC design check(s) failed."

		date > FAILED.lec
		exit 1
	else
		echo -e "\nISPD23 -- 2)  $id_run:  LEC design checks done; all passed."

		date > PASSED.lec
		exit 0
	fi
}

# TODO declare any other issues as error as well the moment its value exceeds (baseline + 10)
parse_design_checks() {

	errors=0

	# routing issues like dangling wires, floating metals, open pins, etc.; check *.conn.rpt -- we need "*" for file since name is defined by module name, not the verilog file name
# Example:
#    5 total info(s) created.
# NOTE such line is only present if errors/issues found at all
	issues=$(grep "total info(s) created" reports/*.conn.rpt | awk '{print $1}')

	if [[ $issues != "" ]]; then

		# NOTE the related file floating_signals.rpt does not have to be parsed; it just provides more
		# details but metrics/values are already covered in the lec.log file
		echo "ISPD23 -- WARNING: Innovus design checks failure -- $issues basic routing issues; see *.conn.rpt and floating_signals.rpt for more details." >> reports/warnings.rpt
		echo "ISPD23 -- Innovus: Basic routing issues: $issues" >> reports/checks_summary.rpt
	else
		echo "ISPD23 -- Innovus: Basic routing issues: 0" >> reports/checks_summary.rpt
	fi

	# IO pins; check *.checkPin.rpt for illegal and unplaced pins from summary
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
	if [[ $issues != '0' ]]; then

		echo "ISPD23 -- WARNING: Innovus design checks failure -- $issues module pin issues; see *.checkPin.rpt for more details." >> reports/warnings.rpt
		echo "ISPD23 -- Innovus: Module pin issues: $issues" >> reports/checks_summary.rpt
	else
		echo "ISPD23 -- Innovus: Module pin issues: 0" >> reports/checks_summary.rpt
	fi

	# placement and routing; check check_design.rpt file for summary
# Example:
#	**INFO: Identified 21 error(s) and 0 warning(s) during 'check_design -type {place cts route}'.
	issues=$(grep "**INFO: Identified" reports/check_design.rpt | awk '{ sum = $3 + $6; print sum }')
	if [[ $issues != '0' ]]; then

		echo "ISPD23 -- WARNING: Innovus design checks failure -- $issues placement and/or routing issues; see check_design.rpt for more details." >> reports/warnings.rpt
		echo "ISPD23 -- Innovus: Placement and/or routing issues: $issues" >> reports/checks_summary.rpt
	else
		echo "ISPD23 -- Innovus: Placement and/or routing issues: 0" >> reports/checks_summary.rpt
	fi

## NOTE deprecated, deactivated for now
#
#	# noise issues; check noise.rpt for summary
## Example:
## Glitch Violations Summary :
## --------------------------
## Number of DC tolerance violations (VH + VL) =  35
## Number of Receiver Output Peak violations (VH + VL) =  0
## Number of total problem noise nets =  12
#
#	issues=$(grep "Number of DC tolerance violations" reports/noise.rpt | awk '{print $10}')
#	if [[ $issues != '0' ]]; then
#
#		echo "ISPD23 -- WARNING: Innovus design checks failure -- $issues DC tolerance issues; see noise.rpt for more details." >> reports/warnings.rpt
#		echo "ISPD23 -- Innovus: DC tolerance issues: $issues" >> reports/checks_summary.rpt
#	else
#		echo "ISPD23 -- Innovus: DC tolerance issues: 0" >> reports/checks_summary.rpt
#	fi
#
#	issues=$(grep "Number of Receiver Output Peak violations" reports/noise.rpt | awk '{print $11}')
#	if [[ $issues != '0' ]]; then
#
#		echo "ISPD23 -- WARNING: Innovus design checks failure -- $issues receiver output peak issues; see noise.rpt for more details." >> reports/warnings.rpt
#		echo "ISPD23 -- Innovus: Receiver output peak issues: $issues" >> reports/checks_summary.rpt
#	else
#		echo "ISPD23 -- Innovus: Receiver output peak issues: 0" >> reports/checks_summary.rpt
#	fi
#
#	issues=$(grep "Number of total problem noise nets" reports/noise.rpt | awk '{print $8}')
#	if [[ $issues != '0' ]]; then
#
#		echo "ISPD23 -- WARNING: Innovus design checks failure -- $issues noise net issues; see noise.rpt for more details." >> reports/warnings.rpt
#		echo "ISPD23 -- Innovus: Noise net issues: $issues" >> reports/checks_summary.rpt
#	else
#		echo "ISPD23 -- Innovus: Noise net issues: 0" >> reports/checks_summary.rpt
#	fi

	# DRC routing issues; check *.geom.rpt for "Total Violations"
	#
	## NOTE failure on those considered as error/constraint violation
	#
# Example:
#  Total Violations : 2 Viols.
# NOTE such line is only present if errors/issues found at all
	issues=$(grep "Total Violations :" reports/*.geom.rpt | awk '{print $4}')
	if [[ $issues != "" ]]; then

		echo "ISPD23 -- ERROR: Innovus design checks failure -- $issues DRC issues; see *.geom.rpt for more details." >> reports/errors.rpt
		echo "ISPD23 -- Innovus: DRC issues: $issues" >> reports/checks_summary.rpt

		errors=1
	else
		echo "ISPD23 -- Innovus: DRC issues: 0" >> reports/checks_summary.rpt
	fi

	# timing; check timing.rpt for "View : ALL" and extract FEPs for setup, hold checks
	#
	## NOTE failure on those considered as error/constraint violation
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
	issues=$(grep "View : ALL" reports/timing.rpt | awk '{print $6}' | awk 'NR==1')
	if [[ $issues != "0" ]]; then

		echo "ISPD23 -- ERROR: Innovus design checks failure -- $issues timing issues for setup; see timing.rpt for more details." >> reports/errors.rpt
		echo "ISPD23 -- Innovus: Timing issues for setup: $issues" >> reports/checks_summary.rpt

		errors=1
	else
		echo "ISPD23 -- Innovus: Timing issues for setup: 0" >> reports/checks_summary.rpt
	fi

	# hold 
# Example:
## HOLD                   WNS    TNS   FEP   
##------------------------------------------
# View : ALL           17.732  0.000     0  
#    Group : in2out       N/A    N/A     0  
#    Group : reg2out  305.300  0.000     0  
#    Group : in2reg    17.732    0.0     0  
#    Group : reg2reg  188.440    0.0     0  
	issues=$(grep "View : ALL" reports/timing.rpt | awk '{print $6}' | awk 'NR==2')
	if [[ $issues != "0" ]]; then

		echo "ISPD23 -- ERROR: Innovus design checks failure -- $issues timing issues for hold; see timing.rpt for more details." >> reports/errors.rpt
		echo "ISPD23 -- Innovus: Timing issues for hold: $issues" >> reports/checks_summary.rpt

		errors=1
	else
		echo "ISPD23 -- Innovus: Timing issues for hold: 0" >> reports/checks_summary.rpt
	fi

	#
	# evaluate criticality of issues
	#
	if [[ $errors == 1 ]]; then

		echo -e "\nISPD23 -- 2)  $id_run:  Some critical Innovus design check(s) failed."

		date > FAILED.design_checks
		exit 1
	else
		echo -e "\nISPD23 -- 2)  $id_run:  Innovus design checks done; all passed."

		date > PASSED.designs_checks
		exit 0
	fi
}

start_eval() {

	## iterate over keys / google IDs
	for google_team_folder in "${!google_team_folders[@]}"; do

		team="${google_team_folders[$google_team_folder]}"
		team_=$(printf "%-"$teams_string_max_length"s" $team)

		# NOTE init the current ongoing runs from the work folder of all benchmarks; ignore errors for
		# ls, which are probably only due to empy folders
		count_parallel_runs=$(ls $teams_root_folder/$team/*/work/* -d 2> /dev/null | wc -l)
		echo "ISPD23 -- 2)  [ $team_ ]: Currently $count_parallel_runs run(s) ongoing; allowed to start $((max_parallel_runs - $count_parallel_runs)) more run(s) ..."

		for benchmark in $benchmarks; do

			downloads_folder="$teams_root_folder/$team/$benchmark/downloads"
			work_folder="$teams_root_folder/$team/$benchmark/work"
			benchmark_=$(printf "%-"$benchmarks_string_max_length"s" $benchmark)

			# handle all downloads folders
			for folder in $(ls $downloads_folder); do

				id_run="[ $round -- $team_ -- $benchmark_ -- ${folder##*_} ]"

				## 0)  only max_runs runs in parallel should be running at once per team
				if [[ $count_parallel_runs -ge $max_parallel_runs ]]; then
					break 2
				fi

				## 0) only consider actual folders; ignore files
				if ! [[ -d $downloads_folder/$folder ]]; then
					continue
				fi

				## 0) folders might be empty (when download of submission files failed at that time) -- just delete empty folders and move on
				if [[ $(ls $downloads_folder/$folder/ | wc -l) == '0' ]]; then
					rmdir $downloads_folder/$folder
					continue
				fi

				echo "ISPD23 -- 2)  $id_run: Start processing within dedicated work folder \"$work_folder/$folder\" ..."

				## 0) count parallel runs (i.e., runs started within the same cycle)
				((count_parallel_runs = count_parallel_runs + 1))

			## start frame of code to be run in parallel
			## https://unix.stackexchange.com/a/103921
			(
				## 1) send out email notification of start 
				#
				echo "ISPD23 -- 2)  $id_run:  Send out email about processing start ..."

				# NOTE we use this id as subject for both emails, begin and end of processing, to put them into thread at receipents mailbox
				subject="[ ISPD23 Contest: $round round -- $team -- $benchmark -- reference ${folder##*_} ]"

				text="The processing of your latest submission has started. You will receive another email once results are ready.\n\nNote: you have currently $count_parallel_runs run(s) ongoing and would be allowed to start $((max_parallel_runs - $count_parallel_runs)) more concurrent run(s) -- you can upload as many submissions as you like, but start of processing is subject to these run limits.\n\nMD5 hash and name of files processed in this latest submission are as follows:\n"

				# NOTE cd to the directory such that paths are not revealed/included into email, only filenames
				cd $downloads_folder/$folder > /dev/null
				for file in $(ls); do
					text+=$(md5sum $file 2> /dev/null)"\n"
				done

				send_email "$text" "$subject" "${google_share_emails[$team]}"

				# return to previous main dir
				cd - > /dev/null

				# 2) init folder
				echo "ISPD23 -- 2)  $id_run:  Init work folder ..."
				
				## copy downloaded folder in full to work folder
				cp -rf $downloads_folder/$folder $work_folder/

				### switch to work folder
				### 
				cd $work_folder/$folder > /dev/null

				## record files processed; should be useful to share along w/ results to participants, to allow them double-checking the processed files
				for file in $(ls); do

					# log MD5
					md5sum $file >> processed_files_MD5.rpt

#					# NOTE deprecated
#					# pack processed files again, to be shared again to teams for double-checking
#					# NOTE only mute regular stdout, but keep stderr
#					zip processed_files.zip $file > /dev/null
				done

				## link scripts and design files needed for evaluation

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

				# 3) check submission; simple checks

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

				# 4) start processing for actual checks
			
				echo "ISPD23 -- 2)  $id_run:  Starting LEC design checks ..."
#				# NOTE deprecated, not needed to wrap again in another subshell -- still kept here as
#				note for the related syntax
#				bash -c 'echo $$ > PID.lec; exec lec_64 -nogui -xl -dofile scripts/lec.do > lec.log' &
				lec_64 -nogui -xl -dofile scripts/lec.do > lec.log &
				echo $! > PID.lec

				echo "ISPD23 -- 2)  $id_run:  Starting Innovus design checks ..."
#				# NOTE deprecated, not needed to wrap again in another subshell -- still kept here as
#				note for the related syntax
#				bash -c 'echo $$ > PID.design_checks; exec innovus -nowin -stylus -files scripts/check.tcl -log check > /dev/null' &
				# NOTE only mute regular stdout, which is put into log file already, but keep stderr
				innovus -nowin -stylus -files scripts/check.tcl -log check > /dev/null &
				echo $! > PID.design_checks

				# 5) cleanup downloads dir, to avoid processing again
				rm -r $downloads_folder/$folder #2> /dev/null
			) &

			done
		done
	done

	# wait for all parallel runs to finish
	wait
}
