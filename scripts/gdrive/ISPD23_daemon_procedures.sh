#!/bin/bash

send_email() {
	local text=$1
	local subject=$2
	local emails=$3

	# unroll emails explicitly; use of ${emails[@]} won't work within larger string
	local emails_string=""
	for email in $emails; do
		emails_string="$emails_string $email"
	done

	ssh dfx "echo '$text' | mailx -A gmail -s '$subject' $emails_string" > /dev/null 2>&1
}

# https://unix.stackexchange.com/a/415450
progress_bar() {
	local w=1 p=$1;  shift
	# create a string of spaces, then change them to dots
	printf -v dots "%*s" "$(( $p * $w ))" ""; dots=${dots// /.}
	# print those dots on a fixed-width space plus the percentage etc. 
	printf "\r\e[K|%-*s| %3d %% %s" "$w" "$dots" "$p" "$*" >&2
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

google_downloads() {

	## iterate over keys / google IDs
	for google_team_folder in "${!google_team_folders[@]}"; do

		team=${google_team_folders[$google_team_folder]}
		team_folder="$teams_root_folder/$team"

		echo "3)  Checking team folder \"$team\" (Google team folder ID \"$google_team_folder\") for new submission files ..."

		for benchmark in $benchmarks; do

		(
			id="$team:$benchmark"

			# NOTE relatively verbose; turned off for now
#			echo "3)   Checking for benchmark \"$benchmark\" ..."

			downloads_folder="$team_folder/$benchmark/downloads"
			declare -A basename_folders=()

			# array of [google_ID]=actual_file_name
			declare -A google_folder_files=()
			# array of [google_ID]=file_type
			declare -A google_folder_files_type=()

			google_benchmark_folder=${google_benchmark_folders[$id]}
			while read -r a b c; do
				google_folder_files[$a]=$b
				google_folder_files_type[$a]=$c
			done < <(./gdrive list --no-header -q "parents in '$google_benchmark_folder' and trashed = false and not (name contains 'results')" 2> /dev/null | awk '{print $1" "$2" "$3}')

			## pre-processing: list files within (sub)folders, if any
			for folder in "${!google_folder_files_type[@]}"; do

				if [[ ${google_folder_files_type[$folder]} != "dir" ]]; then
					continue
				fi

				# add files of subfolder to google_folder_files
				while read -r a b; do
					google_folder_files[$a]=$b
				done < <(./gdrive list --no-header -q "parents in '$folder' and trashed = false and not (name contains 'results')" 2> /dev/null | awk '{print $1" "$2}')
			done

			## iterate over keys / google IDs
			for file in "${!google_folder_files[@]}"; do

				# cross-check w/ already downloaded ones, considering unique Google IDS, memorized in history file
				if [[ $(grep -c $file $downloads_folder/dl_history) != '0' ]]; then
					continue
				fi

				# skip folders (if any), as their files are already included in the google_folder_files array
				if [[ ${google_folder_files_type[$file]} == "dir" ]]; then
					continue
				fi

				actual_file_name=${google_folder_files[$file]}
				basename=${actual_file_name%.*}
				## DBG
				#echo "basename: $basename"

				# sanity check for malformated file names with only suffix, like ".nfs000000001f6680dd00000194"
				if [[ $basename == "" ]]; then
					continue
				fi

				# first, if not available yet, init a separate folder for each set of files with common basename
				# (assuming that different submissions downloaded at once at least have different basenames)
				if ! [[ ${basename_folders[$basename]+_} ]]; then

					# actual init of download folder w/ timestamp;
					downloads_folder_="$downloads_folder/downloads_$(date +%s)"

					## NOTE not silent on purpose, to see about name clashes from too fast processing
					mkdir $downloads_folder_
					#mkdir $downloads_folder_ 2> /dev/null

					## DBG
					#echo "new downloads_folder_: $downloads_folder_"

					# memorize new folder in basenames array
					basename_folders[$basename]="$downloads_folder_"
					## DBG
					#declare -p basename_folders
				else
					downloads_folder_=${basename_folders[$basename]}
					## DBG
					#echo "existing downloads_folder_: $downloads_folder_"
				fi

				echo "3)   Download new submission file \"$actual_file_name\" (Google file ID \"$file\") into dedicated folder \"$downloads_folder_\" ..."
				./gdrive download -f --path $downloads_folder_ $file > /dev/null 2>&1

				# memorize to not download again, but only if the download succeeded
				if [[ $? == 0 ]]; then

					echo $file >> $downloads_folder/dl_history
				fi

				# unpack archive, if applicable
				## NOTE for long filenames, gdrive will put "..." in the middle, which leads to $actual_file_name not matched as is; replaced "..." w/ properp "*" wildcard
				actual_file_name_=$(echo $actual_file_name | sed 's/\.\.\./*/g')
				if [[ $(file $downloads_folder_/$actual_file_name_ | awk '{print $2}') == 'Zip' ]]; then

					echo "3)   Unpacking zip file \"$actual_file_name_\" into dedicated folder \"$downloads_folder_\" ..."
					unzip -j $downloads_folder_/$actual_file_name_ -d $downloads_folder_ > /dev/null 2>&1
					rm $downloads_folder_/$actual_file_name_ > /dev/null 2>&1
				## else, if these are regular files, chances are good that processing is too fast,
				## resulting in clashes for timestamp in folders, hence slow down on purpose here
				else
					sleep 1s
				fi
			done
		) &

		done
	done

	wait
}

google_uploads() {

	count_parallel_uploads=0

	## iterate over keys / google IDs
	for google_team_folder in "${!google_team_folders[@]}"; do

		for benchmark in $benchmarks; do

			team=${google_team_folders[$google_team_folder]}

			id="$team:$benchmark"

			uploads_folder="$teams_root_folder/$team/$benchmark/uploads"

			# handle all the uploads folders that might have accumulated through batch processing
			for folder in $(ls $uploads_folder); do

				## 0)  only max_parallel_uploads should be triggered at once
				if [[ "$count_parallel_uploads" == "$max_parallel_uploads" ]]; then
					break 3
				fi

				## 0) only proceed for non-empty folder
				if [[ $(ls $uploads_folder/$folder/ | wc -l) == '0' ]]; then

					continue

					# NOTE dont delete here any empty upload folders; should still be under processing
				fi

				## 1) count parallel uploads (i.e., uploads started within the same cycle)
				((count_parallel_uploads = count_parallel_uploads + 1))

			# begin parallel processing
			(
				google_benchmark_folder=${google_benchmark_folders[$id]}

				echo "2)  Upload results folder \"$uploads_folder/$folder\", benchmark \"$benchmark\", team folder \"$team\" (Google team folder ID \"$google_team_folder\", benchmark folder ID \"$google_benchmark_folder\") ..."
				./gdrive upload -p $google_benchmark_folder -r $uploads_folder/$folder > /dev/null 2>&1

				## cleanup locally, but only if upload succeeded
				if [[ $? -ne 0 ]]; then
					# NOTE replace continue w/ exit, as we are at the main level in a subshell here now
					##continue
					exit
				fi

				rm -rf $uploads_folder/$folder

				## also send out email notification of successful upload
				#
				echo "2)  Send out email about uploaded results folder \"$uploads_folder/$folder\", benchmark \"$benchmark\", team \"$team\" ..."

				google_uploaded_folder=$(./gdrive list --no-header -q "parents in '$google_benchmark_folder' and trashed = false and name = '$folder'" 2> /dev/null | awk '{print $1}')
				text="The evaluation results for your latest $round round submission, benchmark $benchmark, are available in your corresponding Google Drive folder, within subfolder \"$folder\".\n\nDirect link: https://drive.google.com/drive/folders/$google_uploaded_folder"
				subject="[ISPD22] Results ready for $round round, benchmark $benchmark, folder $folder"

				send_email "$text" "$subject" "${google_share_emails[$team]}"
			) &

			done
		done
	done

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

				## silently create related upload folder, w/ same timestamp as work and download folder
				uploads_folder="$teams_root_folder/$team/$benchmark/uploads/results_${folder##*_}"
				mkdir $uploads_folder > /dev/null 2>&1

				echo "1)"
				echo "1)  Checking work folder \"$work_folder/$folder\""
				# (related uploads folder: \"$uploads_folder\") ..."

				## enter work folder
				cd $work_folder/$folder

				## check status of processes
				#
				# notation: 0 -- still running; 1 -- done; 2 -- error
				declare -A status=()

				## exploit eval
				#
				if [[ -e DONE.exploit_eval ]]; then
					echo "1)   Exploitable regions: done"
					status[exploit_eval]=1
				else
					echo "1)   Exploitable regions: still working ..."
					status[exploit_eval]=0
				fi
				## for dbg only (e.g., manual re-upload of work folders just moved from backup_up to work again)
				#status[exploit_eval]=1
				#
				# also check for any errors; if found, mark to kill and proceed
				# note the * for the log files, to make sure to check all log files for iterative runs w/ threshold adapted
				#
				errors=$(grep -E "$innovus_errors_for_checking" exploit_eval.log* 2> /dev/null | grep -Ev "$innovus_errors_excluded_for_checking")
				if [[ $errors != "" ]]; then

					echo "1)    Exploitable regions: some error occurred for Innovus run ..."
					echo "ERROR: process failed for evaluation of exploitable regions -- $errors" >> errors.rpt

					status[exploit_eval]=2
				fi
				#
				# NOTE interrupt errors will be triggered in massive numbers, resulting in string allocation errors here after some time -- handle manually
				# NOTE handling here is to keep only single error message
				# NOTE memorize status in var as to skip log files for zip archive later on
				errors_interrupt=$(grep -q "INTERRUPT" exploit_eval.log* 2> /dev/null; echo $?)
				if [[ $errors_interrupt == 0 ]]; then

					echo "1)    Exploitable regions: Innovus run got interrupted ..."
					echo "ERROR: process failed for evaluation of exploitable regions -- INTERRUPT" >> errors.rpt

					status[exploit_eval]=2
				fi
			
				## probing
				#
				if [[ -e DONE.probing ]]; then
					echo "1)   Probing: done"
					status[probing]=1
				else
					echo "1)   Probing: still working ..."
					status[probing]=0
				fi
				## for dbg only (e.g., manual re-upload of work folders just moved from backup_up to work again)
				#status[probing]=1
				# 
				errors=$(grep -E "$innovus_errors_for_checking" summarize_assets.log 2> /dev/null | grep -Ev "$innovus_errors_excluded_for_checking")
				if [[ $errors != "" ]]; then

					echo "1)    Probing: some error occurred for Innovus run ..."
					echo "ERROR: process failed for evaluation of probing -- $errors" >> errors.rpt

					status[probing]=2
				fi
				#
				errors_interrupt=$(grep -q "INTERRUPT" summarize_assets.log* 2> /dev/null; echo $?)
				if [[ $errors_interrupt == 0 ]]; then

					echo "1)    Probing: Innovus run got interrupted ..."
					echo "ERROR: process failed for evaluation of probing -- INTERRUPT" >> errors.rpt

					status[probing]=2
				fi

				## if there's any error, kill all the processes; only runs w/o any errors should be kept going
				if [[ ${status[exploit_eval]} == 2 || ${status[probing]} == 2 ]]; then

					echo "1)    Kill all processes, as some error occurred, and move on ..."

					cat PID.exploit_eval | xargs kill 2> /dev/null 
					# also memorize that the exploit eval process was killed; required to break exploit_eval.sh inner loop
					date > KILLED.exploit_eval

					cat PID.summarize_assets | xargs kill 2> /dev/null

				## if no error, and not done yet, then just continue
				elif ! [[ ${status[exploit_eval]} == 1 && ${status[probing]} == 1 ]]; then
					
					# first return to previous main dir
					cd - > /dev/null

					continue
				fi

				## compute scores
				if ! [[ -e errors.rpt ]]; then
					echo "1)   Computing scores ..."
				else
					# NOTE not really skipping the script itself; scores.sh is called in any case to track the related errors, if any, in errors.rpt as well
					echo "1)   Skipping scores, as there were some errors ..."
				fi
				./scores.sh 6 $baselines_root_folder/$benchmark/reports > /dev/null 2>&1

				## cp all rpt files to uploads folder
				echo "1)   Copying report files to uploads folder \"$uploads_folder\" ..."
				cp *.rpt $uploads_folder/

				## re-include processed files to uploads folder
				echo "1)   Including backup of processed files to uploads folder \"$uploads_folder\" ..."
				mv processed_files.zip $uploads_folder/ 2> /dev/null

				## backup work dir
				echo "1)   Backup work folder to \"$backup_work_folder/$folder".zip"\" ..."
				mv $work_folder/$folder $backup_work_folder/

				# return to previous main dir
				cd - > /dev/null

				# also compress backup
				cd $backup_work_folder

				## for interrupts, delete the probably excessively large log files before zipping
				if [[ $errors_interrupt == 0 ]]; then
					rm $folder/exploit_eval.log*
					rm $folder/summarize_assets.log*
				fi

				zip -y -r $folder'.zip' $folder/ > /dev/null 2>&1

				rm -r $folder/

				# unzip rpt, sh, log files again, as these should remain readily accessible
				unzip $folder'.zip' $folder/*.rpt* > /dev/null 2>&1
				unzip $folder'.zip' $folder/*.sh > /dev/null 2>&1
				unzip $folder'.zip' $folder/*.log > /dev/null 2>&1

				cd - > /dev/null
			done
		done
	done
}

check_submission() {

	##
	## check for assets maintained in DEF
	##

	## NOTE trivial checks for matching of names, could be easily cheated on (e.g,., by swapping names w/ some less complex assets, or even just putting the asset names in some comment).
	## However, given that participants may revise the implementation of assets and other logic, doing better is not easy. The subsequent LEC run checks at least for equivalence of DFFs,
	## but not other logic. Further, the probing and exploit regions scripts would also fail if the assets are missing, so this here is really only an initial quick check to short-cut further efforts if possible.

	echo "4)  $id:   Check whether assets are maintained ..."

	# create versions of assets fiels w/ extended escape of special chars, so that grep later on can match
	# https://unix.stackexchange.com/a/211838
	#(TODO) would be sufficient to do this only once, e..g, during init phase for daemon.sh, but shouldn't be much effort/RT so we can just keep doing it again in this procedure
	sed -e 's/\\/\\\\/g' -e 's/\[/\\[/g' -e 's/\]/\\]/g' cells.assets > cells.assets.escaped
	sed -e 's/\\/\\\\/g' -e 's/\[/\\[/g' -e 's/\]/\\]/g' nets.assets > nets.assets.escaped

	readarray -t cells_assets < cells.assets
	readarray -t nets_assets < nets.assets
	readarray -t escaped_cells_assets < cells.assets.escaped
	readarray -t escaped_nets_assets < nets.assets.escaped

	status=0

	(
		error=0

		echo "4)  $id:    Check cell assets ..."
		for ((i=0; i<${#cells_assets[@]}; i++)); do
			asset=${cells_assets[$i]}
			escaped_asset=${escaped_cells_assets[$i]}

			# for DEF format, each token/word is separated, so we can use -w here
			grep -q -w $escaped_asset design.def

			if [[ $? == 1 ]]; then
				error=1
				echo "ERROR: the cell asset \"$asset\" is not maintained in the DEF." >> errors.rpt
			fi
		done
#		echo "4)  $id:    Check cell assets done."

		exit $error
	) &
	pid_cell_assets=$!

	(
		error=0

		echo "4)  $id:    Check net assets ..."
		for ((i=0; i<${#nets_assets[@]}; i++)); do
			asset=${nets_assets[$i]}
			escaped_asset=${escaped_nets_assets[$i]}

			# for DEF format, each token/word is separated, so we can use -w here
			grep -q -w $escaped_asset design.def

			if [[ $? == 1 ]]; then
				error=1
				echo "ERROR: the net asset \"$asset\" is not maintained in the DEF." >> errors.rpt
			fi
		done
#		echo "4)  $id:    Check net assets done."

		exit $error
	) &
	pid_net_assets=$!

	# wait for subshells and memorize their exit code in case it's non-zero
	wait $pid_cell_assets || status=$?
	wait $pid_net_assets || status=$?

	if [[ $status != 0 ]]; then

		echo "4)  $id:   Some asset(s) is/are missing. Skipping other checks ..."

		return 1
	else
		echo "4)  $id:   Check whether assets are maintained passed."
	fi

	# reset status (not needed really as non-zero status would render this code skipped)
	status=0

	##
	## pins checks
	##

	(
		echo "4)  $id:   Pins design checks ..."

		#TODO check_pins.sh
		./check_pins > /dev/null 2>&1

		# parse rpt for FAIL
		errors=$(grep -q "FAIL" check_pins.rpt 2> /dev/null; echo $?)
		if [[ $errors == 0 ]]; then

			echo "ERROR: For pins design check -- see check_pins.rpt for more details." >> errors.rpt
			echo "4)  $id:    Some pins design check(s) failed."

			exit 1
		fi

		echo "4)  $id:   Pins design checks passed."

		exit 0
	) &
	pid_pins_checks=$!

	##
	## PDN checks
	##

	(
		echo "4)  $id:   PDN checks ..."

		sh -c 'echo $$ > PID.pg; exec '$(echo $innovus_bin)' -files pg.tcl -log pg > /dev/null 2>&1' &

#		echo -n "|"

		while true; do

#			echo -n "."

			if [[ -e DONE.pg ]]; then

#				echo "|"

				break
			else
				# also check for any errors; if found, kill and return
				#
				errors=$(grep -E "$innovus_errors_for_checking" pg.log 2> /dev/null | grep -Ev "$innovus_errors_excluded_for_checking")
				if [[ $errors != "" ]]; then

#					echo "|"

					echo "4)  $id:    Some error occurred for PDN checks. Killing process ..."

					echo "ERROR: process failed for PDN design checks -- $errors" >> errors.rpt

					cat PID.pg | xargs kill 2> /dev/null

					exit 1
				fi
			fi

			sleep 1s
		done

		# post-process reports
		./check_pg.sh $baselines_root_folder/$benchmark/reports > /dev/null 2>&1

		# parse errors.rpt for "ERROR: For PG check"
		errors=$(grep -q "ERROR: For PG check" errors.rpt 2> /dev/null; echo $?)
		if [[ $errors == 0 ]]; then

			echo "4)  $id:    Some failure occurred during PDN design checks."

			exit 1
		fi
		# also parse rpt for FAIL 
		errors=$(grep -q "FAIL" pg_metals_eval.rpt 2> /dev/null; echo $?)
		if [[ $errors == 0 ]]; then

			echo "ERROR: For PG check -- see pg_metals_eval.rpt for more details." >> errors.rpt
			echo "4)  $id:    Some PDN design check(s) failed."

			exit 1
		fi

		echo "4)  $id:   PDN checks passed."

		exit 0
	) &
	pid_PDN_checks=$!

	##
	## LEC checks
	##

	(
		echo "4)  $id:   LEC design checks ..."

		sh -c 'echo $$ > PID.lec; exec /opt/cadence/installs/CONFRML181/bin/lec_64 -nogui -xl -dofile lec.do > lec.log 2>&1' &

#		echo -n "|"

		while true; do

#			echo -n "."

			if [[ -e DONE.lec ]]; then

#				echo "|"

				break
			else
				# also check for any errors; if found, kill and return
				#
				errors=$(grep -E "Error|StackTrace|License check failed!" lec.log 2> /dev/null)
				if [[ $errors != "" ]]; then

#					echo "|"

					echo "4)  $id:    Some error occurred for LEC run. Killing process ..."

					echo "ERROR: process failed for LEC design checks -- $errors" >> errors.rpt

					cat PID.lec | xargs kill 2> /dev/null

					exit 1
				fi
			fi

			sleep 1s
		done

		##
		## parse rpt, log files for errors
		## put summary into warnings.rpts; also extract violations count into checks_summary.rpt
		##
		error=0

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
		issues=$(tail -n 2 check_equivalence.rpt | grep "Non-equivalent" 2> /dev/null | awk '{print $NF}')
		if [[ $issues != "" ]]; then

			echo "ERROR: LEC design checks failure -- $issues equivalence issues; see check_equivalence.rpt for more details." >> errors.rpt
			echo "Equivalence issues: $issues" >> checks_summary.rpt

			error=1
		else
			echo "Equivalence issues: 0" >> checks_summary.rpt
		fi

		#
		# unreachable issues
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

		issues=$(tail -n 2 check_equivalence.rpt.unmapped | grep "Unreachable" 2> /dev/null | awk '{print $NF}')
		if [[ $issues != "" ]]; then

			echo "WARNING: LEC design checks failure -- $issues unreachable points issues; see check_equivalence.rpt for more details." >> warnings.rpt
			echo "Unreachable points issues: $issues" >> checks_summary.rpt
		else
			echo "Unreachable points issues: 0" >> checks_summary.rpt
		fi

		#
		# different connectivity issues during parsing
		#
		## NOTE these are hinting on cells used as dummy fillers
		#

# Example:
#// Warning: (RTL2.13) Undriven pin is detected (occurrence:3)
#
# NOTE such line is only present if errors/issues found at all
# NOTE such line, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design
		issues=$(grep "Warning: (RTL2.13) Undriven pin is detected" lec.log 2> /dev/null | awk '{print $8}' | awk 'NR==2')
		issues=${issues##*:}
		issues=${issues%*)}
		if [[ $issues != "" ]]; then

			echo "WARNING: LEC design checks failure -- $issues undriven pins issues" >> warnings.rpt
			echo "Undriven pins issues: $issues" >> checks_summary.rpt
		else
			echo "Undriven pins issues: 0" >> checks_summary.rpt
		fi

# Example:
#// Note: (HRC3.5b) Open output port connection is detected (occurrence:139)
#
# NOTE such line is only present if errors/issues found at all
# NOTE such issues often occur for baseline layouts as well, but these are the only warning related to cells inserted and connected to inputs but otherwise useless (no output), so we need to keep that check
# NOTE such line, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design
		issues=$(grep "Note: (HRC3.5b) Open output port connection is detected" lec.log 2> /dev/null | awk '{print $10}' | awk 'NR==2')
		issues=${issues##*:}
		issues=${issues%*)}
		if [[ $issues != "" ]]; then

			echo "WARNING: LEC design checks failure -- $issues open output ports issues" >> warnings.rpt
			echo "Open output ports issues: $issues" >> checks_summary.rpt
		else
			echo "Open output ports issues: 0" >> checks_summary.rpt
		fi

# Example:
#// Warning: (RTL14) Signal has input but it has no output (occurrence:2632)
#
# NOTE such line is only present if errors/issues found at all
# NOTE such issues often occur for baseline layouts as well, but these are the only warning related to cells inserted and connected to inputs but otherwise useless (no output), so we need to keep that check
# NOTE such line, if present, may well be present for both golden and revised; the string post-processing keeps only the relevant number, namely for the revised design
		issues=$(grep "Warning: (RTL14) Signal has input but it has no output" lec.log 2> /dev/null | awk '{print $12}' | awk 'NR==2')
		issues=${issues##*:}
		issues=${issues%*)}
		if [[ $issues != "" ]]; then

			echo "WARNING: LEC design checks failure -- $issues net output floating issues" >> warnings.rpt
			echo "Net output floating issues: $issues" >> checks_summary.rpt
		else
			echo "Net output floating issues: 0" >> checks_summary.rpt
		fi

		if [[ $error == 1 ]]; then

			echo "4)  $id:   Some critical LEC design check(s) failed."
			exit 1
		fi

		echo "4)  $id:   LEC design checks done."

		exit 0
	) &
	pid_LEC_checks=$!

	##
	## basic design checks
	##

	(
		echo "4)  $id:   Basic design checks ..."

		sh -c 'echo $$ > PID.check; exec '$(echo $innovus_bin)' -stylus -files check.tcl -log check > /dev/null 2>&1' &

#		echo -n "|"

		while true; do

#			echo -n "."

			if [[ -e DONE.check ]]; then

#				echo "|"

				break
			else
				# also check for any errors; if found, kill and return
				#
				errors=$(grep -E "$innovus_errors_for_checking" check.log 2> /dev/null | grep -Ev "$innovus_errors_excluded_for_checking")
				if [[ $errors != "" ]]; then

#					echo "|"

					echo "4)  $id:    Some error occurred for Innovus run for basic checks. Killing process ..."

					echo "ERROR: process failed for basic design checks -- $errors" >> errors.rpt

					cat PID.check | xargs kill 2> /dev/null

					exit 1
				fi
			fi

			sleep 1s
		done

		##
		## parse rpt files for failures
		## put summary into warnings.rpt; also extract violations count into checks_summary.rpt
		##

		# routing issues like dangling wires, floating metals, open pins, etc.; check *.conn.rpt -- we need "*" for file since name is defined by module name, not the verilog file name
# Example:
#    5 total info(s) created.
# NOTE such line is only present if errors/issues found at all
		issues=$(grep "total info(s) created" *.conn.rpt 2> /dev/null | awk '{print $1}')

		if [[ $issues != "" ]]; then

			echo "WARNING: Basic design checks failure -- $issues routing issues; see *.conn.rpt for more details." >> warnings.rpt
			echo "Basic routing issues: $issues" >> checks_summary.rpt
		else
			echo "Basic routing issues: 0" >> checks_summary.rpt
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
		issues=$(grep "TOTAL" *.checkPin.rpt 2> /dev/null | awk '{ sum = $9 + $13 + $17 + $21; print sum }')
		if [[ $issues != '0' ]]; then

			echo "WARNING: Basic design checks failure -- $issues pin issues; see *.checkPin.rpt for more details." >> warnings.rpt
			echo "Module pin issues: $issues" >> checks_summary.rpt
		else
			echo "Module pin issues: 0" >> checks_summary.rpt
		fi

		# placement and routing; check check_route.rpt file for unplaced components as well as for summary
# Example:
#	*info: Unplaced = 0           
		issues=$(grep "*info: Unplaced =" check_route.rpt 2> /dev/null | awk '{print $4}')
		if [[ $issues != '0' ]]; then

			echo "WARNING: Basic design checks failure -- $issues unplaced component(s) issues; see check_route.rpt for more details." >> warnings.rpt
			echo "Unplaced components issues: $issues" >> checks_summary.rpt
		else
			echo "Unplaced components issues: 0" >> checks_summary.rpt
		fi
# Example:
#	*** Message Summary: 1 warning(s), 0 error(s) 
		issues=$(grep "*** Message Summary:" check_route.rpt 2> /dev/null | awk '{ sum = $4 + $6; print sum }')
		if [[ $issues != '0' ]]; then

			echo "WARNING: Basic design checks failure -- $issues placement and/or routing issues; see check_route.rpt for more details." >> warnings.rpt
			echo "Placement and/or routing issues: $issues" >> checks_summary.rpt
		else
			echo "Placement and/or routing issues: 0" >> checks_summary.rpt
		fi

		# DRC routing issues; check *.geom.rpt for "Total Violations"
# Example:
#  Total Violations : 2 Viols.
# NOTE such line is only present if errors/issues found at all
		issues=$(grep "Total Violations :" *.geom.rpt 2> /dev/null | awk '{print $4}')
		if [[ $issues != "" ]]; then

			echo "WARNING: Basic design checks failure -- $issues DRC issues; see *.geom.rpt for more details." >> warnings.rpt
			echo "DRC issues: $issues" >> checks_summary.rpt
		else
			echo "DRC issues: 0" >> checks_summary.rpt
		fi

		echo "4)  $id:   Basic design checks done."

		exit 0
	) &
	pid_basic_checks=$!

	# wait for subshells and memorize their exit code in case it's non-zero
	wait $pid_pins_checks || status=$?
	wait $pid_PDN_checks || status=$?
	wait $pid_LEC_checks || status=$?
	wait $pid_basic_checks || status=$?

	echo "4)  $id:  All checks done"

	return $status
}

link_work_dir() {

	error=0

	##
	## link submission files to common names used by scripts
	##

	## DEF, including sanity checks
	def_files=$(ls *.def 2> /dev/null | wc -l)
	if [[ $def_files != '1' ]]; then

		echo "ERROR: there are $def_files DEF files in the submission download's work directory, which shouldn't happen." >> errors.rpt
		error=1
	fi
	## NOTE don't force here, to avoid circular links from design.def to design.def itself, in case the submitted file's name is already the same; also remain silent
	ln -s *.def design.def 2> /dev/null
	
	## netlist, including sanity checks
	netlist_files=$(ls *.v 2> /dev/null | wc -l)
	if [[ $netlist_files > '1' ]]; then

		echo "ERROR: there are $netlist_files netlist files in the submission download's work directory, which shouldn't happen." >> errors.rpt
		error=1

	elif [[ $netlist_files == '0' ]]; then

		echo "WARNING: there is no netlist files found in the submission download's work directory. Continuing with original baseline netlist. If the circuitry in your DEF deviates from this netlist, you'd want to re-upload the DEF along with the netlist." >> warnings.rpt
		ln -sf $baselines_root_folder/$benchmark/design_original.v design.v

	#elif [[ $netlist_files -eq 1 ]]; then
	else
		## NOTE don't force here, to avoid circular links from design.v to itself, in case the submitted file's name is already the same; also remain silent
		ln -s *.v design.v 2> /dev/null
	fi

	## link scripts into work dir
	for script in $scripts; do
		ln -sf $scripts_folder/$script .
	done

	## link runtime files related to benchmark into work dir
	ln -sf $baselines_root_folder/$benchmark/mmmc.tcl .
	ln -sf $baselines_root_folder/$benchmark/design.sdc .
	ln -sf $baselines_root_folder/$benchmark/NangateOpenCellLibrary.lib .
	ln -sf $baselines_root_folder/$benchmark/NangateOpenCellLibrary.lef .
	ln -sf $baselines_root_folder/$benchmark/cells.assets .
	ln -sf $baselines_root_folder/$benchmark/nets.assets .
	# NOTE note the '_' prefix which is used to differentiate this true original file with any submission also named design_original
	ln -sf $baselines_root_folder/$benchmark/design_original.v _design_original.v
	ln -sf $baselines_root_folder/$benchmark/design_original.def _design_original.def

	return $error
}

start_eval() {

	## iterate over keys / google IDs
	for google_team_folder in "${!google_team_folders[@]}"; do

		team="${google_team_folders[$google_team_folder]}"

		count_parallel_runs=0

		for benchmark in $benchmarks; do

			downloads_folder="$teams_root_folder/$team/$benchmark/downloads"
			work_folder="$teams_root_folder/$team/$benchmark/work"

			# handle all downloads folders
			for folder in $(ls $downloads_folder); do

				id="[ $team -- $benchmark -- ${folder##*_} ]"

				## 0)  only max_runs runs in parallel should be started at once per team
				if [[ "$count_parallel_runs" == "$max_parallel_runs" ]]; then
					break 2
				fi

				## 0) only consider actual folders; ignore files
				if ! [[ -d $downloads_folder/$folder ]]; then
					continue
				fi

				## 0) folders might be empty (when download of submission files failed at that time)
				# -- just delete empty folders and move on
				if [[ $(ls $downloads_folder/$folder/ | wc -l) == '0' ]]; then
					rmdir $downloads_folder/$folder
					continue
				fi

				echo "4)  $id: Start processing within dedicated work folder \"$work_folder/$folder\" ..."

				## 1) count parallel runs (i.e., runs started within the same cycle)
				((count_parallel_runs = count_parallel_runs + 1))

			## start parallel processing
			(
				## 1) send out email notification of start 
				#
				echo "4)  $id:  Send out email about processing start ..."

				text="The evaluation for your latest $round round submission, benchmark $benchmark, has started. You will receive another email once results are available.\n\nMD5 and name of files processed in this run:\n"
				# NOTE cd to the directory such that paths are not revealed, only filenames
				cd $downloads_folder/$folder
				for file in $(ls); do
					text+=$(md5sum $file 2> /dev/null)"\n"
				done
				# return silently to previous main dir
				cd - > /dev/null

				subject="[ISPD22] Processing started for $round round, benchmark $benchmark (internal ref: ${folder##*_})"

				send_email "$text" "$subject" "${google_share_emails[$team]}"

				# 2) init folder
				echo "4)  $id:  Init work folder ..."
				
				## copy downloaded folder in full to work folder
				cp -rf $downloads_folder/$folder $work_folder/

				### switch to work folder
				### 
				cd $work_folder/$folder

				## track files processed; useful once results are retrieved by participants
				for file in $(ls); do

					# log MD5
					md5sum $file 2> /dev/null >> processed_files_MD5.rpt

					# also include the actual zipped submission files
					zip processed_files.zip $file > /dev/null

				done

				## link scripts and design files needed for evaluation
				link_work_dir

				if [[ $? != 0 ]]; then

					echo "4)  $id:   Error occurred during file init."

					# also mark as done in case of an error, to allow check_eval to clear and prepare to upload this run
					date > DONE.exploit_eval
					date > DONE.probing

					# also return silently to previous main dir
					cd - > /dev/null

					# cleanup downloads dir, to avoid processing again; do so even considering it failed,
					# because it would likely fail again then anyway unless we are fixing things
					rm -r $downloads_folder/$folder

					# NOTE replace continue w/ exit, as we are at the main level in a subshell here now
					##continue
					exit
				fi

				# 3) check submission
				echo "4)  $id:  Check submission files ..."

				check_submission

				if [[ $? != 0 ]]; then

					echo "4)  $id:   Submission is not valid/legal."

					# also mark as done in case of an error, to allow check_eval to clear and prepare to upload this run
					date > DONE.exploit_eval
					date > DONE.probing

					# also return silently to previous main dir
					cd - > /dev/null

					# cleanup downloads dir, to avoid processing again; do so even considering it failed,
					# because it would likely fail again then anyway unless we are fixing things
					rm -r $downloads_folder/$folder

					# NOTE replace continue w/ exit, as we are at the main level in a subshell here now
					##continue
					exit
				fi

				### done w/ init files within work folder, switch silently back to previous dir
				###
				cd - > /dev/null

				# 4) actual processing
			
				## exploit_eval
				##
				## start frame of code to be run in parallel
				## https://unix.stackexchange.com/a/103921
				(
					cd $work_folder/$folder

					# prepare scripts
					if [[ "$benchmarks_10_metal_layers" == *"$benchmark"* ]]; then

						echo "4)  $id:  Exploitable regions: start background run for script version considering 10 metal layers..."

						# cleanup scripts not needed
						rm exploit_regions_metal1--metal6.tcl

					elif [[ "$benchmarks_6_metal_layers" == *"$benchmark"* ]]; then

						echo "4)  $id:  Exploitable regions: start background run for script version considering 6 metal layers..."

						rm exploit_regions.tcl
						ln -s exploit_regions_metal1--metal6.tcl exploit_regions.tcl
					else
						echo "ERROR: benchmark cannot be matched to some exploit-regions script version, which shouldn't happen." >> errors.rpt

						# also mark as done in case of an error, to allow check_eval to clear and prepare to upload this run
						date > DONE.exploit_eval

						return
					fi

					# runs scripts wrapper
					./exploit_eval.sh $innovus_bin > /dev/null 2>&1

				## end frame of code to be run in parallel
				) &


				## probing
				##
				(
					cd $work_folder/$folder

					echo "4)  $id:  Probing: start background run ..."

					./probing.sh $innovus_bin $benchmark > /dev/null 2>&1
				) &

				# 5) cleanup downloads dir, to avoid processing again
				rm -r $downloads_folder/$folder 2> /dev/null
			) &

			done
		done
	done

	wait
}