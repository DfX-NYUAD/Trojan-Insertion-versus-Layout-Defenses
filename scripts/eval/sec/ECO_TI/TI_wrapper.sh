#!/bin/bash

####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD, in collaboration with Mohammad Eslami and Samuel Pagliarini, TalTech
#
# Script to handle (start, monitor, kill) the ECO TI processes and log their output in the same format as the main daemon.
#
####

## fixed settings; typically not to be modified
#
daemon_settings_file=$1
id_run=$2
err_rpt="reports/errors.rpt"
warn_rpt="reports/warnings.rpt"

## other settings
# TODO NOTE for testing only
TI_mode="reg"
# runs
max_current_runs_default=6
max_current_runs_aes=6
# dbg
dbg_log=0
dbg_log_verbose=0
# NOTE dbg_files is sourced from $daemon_settings_file below

## init stuff; main code further below

# TODO incorporate different modes via prefix for Trojans, e.g., advanced_camellia_burn_random
# also add related dummy files
# --> not sure, maybe these modes should only be covered in here

# TODO make use of $trojan_name"."$TI_mode wherever needed

# TODO process management corner case: if reg (or adv) mode already succeeds w/o any violations, the adv and adv2 runs (or adv2) can be cancelled

source $daemon_settings_file

# sanity checks: all parameters provided?
if [[ $daemon_settings_file == "" ]]; then

	echo "ISPD23 -- ERROR: cannot run Trojan insertion -- 1st parameter, daemon_settings_file, is not provided." | tee -a $err_rpt
	exit 1
fi
if [[ $id_run == "" ]]; then

	id_run="Dummy ID -- make sure to provide 2nd parameter to TI_wrapper.sh for an actual ID of choice"
	echo "ISPD23 -- WARNING: For Trojan insertion -- 2nd parameter, id_run, is not provided. Setting to \"$id_run\"." | tee -a $warn_rpt
fi

## procedures
#
start_TI() {

	# dbg_log
	if [[ $dbg_log == 1 ]]; then
		echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, start_TI ENTRY for Trojan \"$trojan_name\"."
	fi

	# only wait in case some Trojan has been already started (to make sure TI_settings.tcl has been sourced and can be overwritten)
	if [[ "$previous_trojan_name" != "NA" ]]; then

		while true; do

			# dbg_log_verbose
			if [[ $dbg_log_verbose == 1 ]]; then
				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, start_TI WHILE for Trojan \"$trojan_name\"."
			fi

			sleep 1s

			## wait -- at least -- until prior TI call has fully started (i.e., Innovus session has started up and the TI_settings.tcl file has been sourced)
			if [[ -e DONE.source.TI.$previous_trojan_name ]]; then

				# wait further in case max runs are already ongoing
				#
				runs_started=$(ls STARTED.TI.* 2> /dev/null | wc -l)
				# NOTE must also cover any failed run
				runs_done=$(ls {DONE.TI.*,FAILED.TI.*} 2> /dev/null | wc -l)
				((runs_ongoing = runs_started - runs_done))

				# design-specific limits
				if [[ "$trojan_name" == *"aes"* ]]; then
					max_current_runs=$max_current_runs_aes
				else
					max_current_runs=$max_current_runs_default
				fi

				# start this run in case there's budget
				if [[ $runs_ongoing -lt $max_current_runs ]]; then

					# NOTE might trigger race condition w/ other start_TI processes that also want to start their job; thus, mark start right away
					date > STARTED.TI.$trojan_name

					break
				fi
			fi

			## sanity check and exit handling; process might have been cancelled in the meantime, namely for any failure for PPA eval, LEC checks, and/or design checks,
			## as well as for any runtime error for other Trojans
			## NOTE cannot be merged with the above, as DONE.source.TI.* might be there already, but still gets marked as failure
			if [[ -e FAILED.TI.$trojan_name ]]; then

				# dbg_log
				if [[ $dbg_log == 1 ]]; then
					echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, start_TI EXIT 1 for Trojan \"$trojan_name\"."
				fi

				exit 1
			fi
		done
	fi

	echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, initializing for Trojan \"$trojan_name\"."

	## init TI_settings.tcl for current Trojan
	# NOTE only mute regular stdout, which is put into log file already, but keep stderr
	scripts/TI_init.sh $trojan_name $TI_mode $dbg_files > /dev/null

	## some error occurred
	# NOTE specific error is already logged via TI_init.sh; no need to log again
	if [[ $? != 0 ]]; then

		echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, failed to start for Trojan \"$trojan_name\". More details are reported in \"$err_rpt\"."

		# set failure flag/file for this Trojan; this helps the monitor subshells below to kill other processes as well
		date > FAILED.TI.$trojan_name

#		# NOTE deprecated; not needed anymore, to fix possible race conditions w/ other start_TI processs, as the relevant code above also checks for FAILED_TI.* status files
#		# also unmark start again
#		rm STARTED.TI.$trojan_name

		# dbg_log
		if [[ $dbg_log == 1 ]]; then
			echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, start_TI EXIT 1 for Trojan \"$trojan_name\"."
		fi

		exit 1
	fi

	## actual Innovus call
	date > STARTED.TI.$trojan_name

	# NOTE for ECO TI, vdi should be sufficient, but also use invs license if vdi ones are already busy; this should help to get the many parallel ECO runs through the
	# pipeline, but minor limitation or impact is that, if the backend is already busy, 'aes' submissions for some team w/o other runs would still not get started
	#
	# NOTE vdi is limited to 50k instances per license --> ruled out for aes w/ its ~260k instances
	if [[ "$trojan_name" == *"aes"* ]]; then

		call_invs_only scripts/TI.tcl -log TI.$trojan_name > /dev/null &
		echo $! > PID.TI.$trojan_name
	else
		call_vdi_invs scripts/TI.tcl -log TI.$trojan_name > /dev/null &
		echo $! > PID.TI.$trojan_name
	fi

	# dbg_log
	if [[ $dbg_log == 1 ]]; then
		echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, start_TI EXIT 0 for Trojan \"$trojan_name\"."
	fi
}

monitor() {

	## monitor subshell
	# NOTE derived from scripts/gdrive/ISPD23_daemon_procedures.sh, check_eval(), but also revised here, mainly for use of STARTED.TI.* files

	# dbg_log
	if [[ $dbg_log == 1 ]]; then
		echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, monitor ENTRY for Trojan \"$trojan_name\"."
	fi

	while true; do

		# dbg_log_verbose
		if [[ $dbg_log_verbose == 1 ]]; then
			echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, monitor WHILE for Trojan \"$trojan\"."
		fi

		# NOTE sleep a little right in the beginning, to avoid immediate but useless errors concerning log file not found; is only relevant for the very first run just
		# following right after starting the process, but should still be employed here as fail-safe measure
		# NOTE merged w/ regular sleep, which is needed anyway (and was previously done at the end of the loop)
		sleep 2s

		errors=0
		bring_down_other_runs_as_well=0

		# hasn't started yet
		if ! [[ -e STARTED.TI.$trojan ]]; then

			# is already marked as failure (by some other run; see below)
			if [[ -e FAILED.TI.$trojan ]]; then

				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, cancelled for Trojan \"$trojan\", via an interrupt for some other Trojan."

				# NOTE Importantly, this, and all other process issues below, are to be handled only as warnings for the logs/reports. This is to not flag scores as invalid; any
				# Trojan run may fail while still providing valid scores (namely, that the submission layout is "stronger" than our Trojan insertion)

				echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- cancelled, runtime error; triggered by an runtime error for some other Trojan" >> $warn_rpt

				# stop to wait, exit monitor process (w/ error) directly here, as there's no need for killing
				exit 1
			fi

			# else (if not marked as failure), continue to wait
			# NOTE it's important to _not_ explicitly use continue here, but rather follow the remaining part (which checks for failures in other processes)

		# has started, and already done (w/o errors and w/o mark for failure)
		elif [[ -e DONE.TI.$trojan ]]; then

			echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, done for Trojan \"$trojan\"."

			# stop to wait, exit monitor process (w/o error)
			exit 0

		# has started, but got marked as failure (by some other run; see below)
		elif [[ -e FAILED.TI.$trojan ]]; then

			echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, interrupt for Trojan \"$trojan\", indirectly via an interrupt for some other Trojan process."
			echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- INTERRUPT, runtime error; triggered indirectly by an runtime error for some other Trojan process" >> $warn_rpt

			# mark as error, to enable killing further below
			errors=1

		# has started, but not done yet
		else
			# dbg_log_verbose
			if [[ $dbg_log_verbose == 1 ]]; then
				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, still going on for Trojan \"$trojan\"."
			fi

			# check for any errors -- these would be errors in the flow, like failure to legalize placement etc.
			#
			# NOTE limit to 1k errors since tools may flood log files w/ INTERRUPT messages etc, which would then stall grep
			# NOTE mute stderr since log file might not exist yet for first few runs of check, depending on overall workload of backend
			errors_run=$(grep -m 1000 -E "$innovus_errors_for_checking" TI."$trojan".log* 2> /dev/null | grep -Ev "$innovus_errors_excluded_for_checking")

			if [[ $errors_run != "" ]]; then

				# NOTE begin logging w/ linebreak, to differentiate from other ongoing logs like sleep progress bar
				# NOTE id_run passed through as global var
				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, some failure occurred for Trojan \"$trojan\"."

				# NOTE only in dbg mode we want to share details directly into this report to be uploaded; also note, in the backend all details are available
				# anyway in the logs
				if [[ $dbg_files == "1" ]]; then

					echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- $errors_run" >> $warn_rpt
				else
					echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- details remain undisclosed, on purpose" >> $warn_rpt
				fi

				errors=1

				# NOTE not needed really, but stated here explicitly to differentiate to the scenario below
				bring_down_other_runs_as_well=0
		
			# also check for interrupts
			#
			# NOTE merged with check for errors into 'elif', as errors might lead to immediate process exit, which would then result in both
			# case covered at once; whereas we like to keep actual interrupt, runtime errors separate
			#
			# NOTE this will also capture any run where some error occurs that is listed specifically in $innovus_errors_excluded_for_checking but results in
			# termination by innovus itself
			#
			# NOTE only check when PID file already exist; might not be the case even though the STARTED file exists (which is the pre-requisite to reach here), as the
			# STARTED file was set ASAP in start_TI(), to avoid race condition for starting jobs

			elif [[ -e PID.TI.$trojan ]]; then

				errors_interrupt=$(ps --pid $(cat PID.TI.$trojan) > /dev/null 2>&1; echo $?)
				if [[ $errors_interrupt != 0 ]]; then

					# NOTE also check again for DONE flag file, to avoid race condition where
					# process just finished but DONE did not write out yet
					sleep 1s
					if [[ -e DONE.TI.$trojan ]]; then
						break
					fi

					echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, interrupt for Trojan \"$trojan\"."
					echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- INTERRUPT, runtime error" >> $warn_rpt

					errors=1

					# NOTE a runtime issue on any Trojan means it cannot be properly evaluated, and it should be re-submitted and re-tried to evaluate properly.
					# Thus, it is also best/most effective to cancel all others right away, and return failure results early on
					bring_down_other_runs_as_well=1
				fi
			fi
		fi

		# independently for own status (thus outside of the main 'if' statement above), also check process state/evaluation outcome of other process(es)
		#
		# NOTE no need to abort process multiple times in case all is cancelled/brought down due to some failure for some single
		# process; use elif statements to abort each process only once
		if [[ -e FAILED.lec_checks ]]; then

			echo -e "\nISPD23 -- 2)  $id_run:  For some reason, LEC design checks failed. Also cancel/interrupt Innovus Trojan insertion, Trojan \"$trojan\" ..."
			echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- cancelled or interrupted due to failure for LEC design checks" >> $warn_rpt

			errors=1

		elif [[ -e FAILED.inv_PPA ]]; then

			echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus PPA evaluation failed. Also cancel/interrupt Innovus Trojan insertion, Trojan \"$trojan\" ..."
			echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- cancelled or interrupted due to failure for Innovus PPA evaluation" >> $warn_rpt

			errors=1

		elif [[ -e FAILED.inv_checks ]]; then

			echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus design checks failed. Also cancel/interrupt Innovus Trojan insertion, Trojan \"$trojan\" ..."
			echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- cancelled or interrupted due to failure for Innovus design checks" >> $warn_rpt

			errors=1
		fi

		# for any errors, mark as failed and kill, and stop monitor process
		if [[ $errors != 0 ]]; then

			# NOTE if needed/requested, mark all (other) runs for failure
			# NOTE killing of other is handled in their related monitor process, namely once the FAIL status file exists
			if [[ $bring_down_other_runs_as_well == 1 ]]; then

				for trojan_ in "${trojans[@]}"; do
					date > FAILED.TI.$trojan_
				done

			# else, only mark this as failed
			else
				date > FAILED.TI.$trojan
			fi

			# NOTE mute stderr for cat, as the process might not have been started yet (then the PID file won't exist)
			cat PID.TI.$trojan 2> /dev/null | xargs kill -9 2> /dev/null

			# dbg_log
			if [[ $dbg_log == 1 ]]; then
				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, monitor EXIT 1 for Trojan \"$trojan\"."
			fi

			exit 1
		fi
	done
}

#
## main code
#

## 0) wait until design db becomes available (db is generated through scripts/eval/des/PPA.tcl)
#
while true; do

	if [[ -e DONE.save.forTI.$TI_mode ]]; then
		break
	fi

	## sanity check: if we reach here (i.e., did not already break above) and DONE.inv_PPA exists, this means that PPA evaluation finished but, somehow, saveDesign failed
	## sanity check (more reasonable): any other occured failure for PPA evaluation, making that script PPA.tcl error out and stop.
	if [[ -e DONE.inv_PPA || -e FAILED.inv_PPA ]]; then

		err_string="Innovus Trojan insertion: failed altogether as design database was not initialized since, for some reason, Innovus PPA evaluation failed."
		echo -e "\nISPD23 -- 2)  $id_run: $err_string"
		echo "ISPD23 -- WARNING: $err_string" >> $warn_rpt

		# set failure flag/file for all Trojan insertion
		date > FAILED.TI.ALL
		exit 1
	fi

	sleep 1s
done

## 1) init global data structures

# key: running ID; value: trojan_name
# NOTE associative array is not really needed, but handling of such seems easier than plain indexed array
declare -A trojans
trojan_counter=0

for file in TI/*; do

	trojan_name=${file##TI/}
	trojan_name=${trojan_name%%.*}

	# NOTE this is required to sort out duplicate files that differ only in the file suffix
	if [[ "${trojans[$((trojan_counter-1))]}" == $trojan_name ]]; then
		continue	
	fi

	trojans[$trojan_counter]=$trojan_name
	((trojan_counter = trojan_counter + 1))
done

##  2) init start_TI processes; all in parallel, but wait during init phase, as there's only one common config file, which can be updated only once some prior TI process has fully started
##	waiting is handled via start_TI procedure itself, not here
#

trojan_name="NA"

for trojan in "${trojans[@]}"; do

	previous_trojan_name=$trojan_name
	trojan_name=$trojan

	start_TI &
done

## 3) start monitor for all TI processes
#
for trojan in "${trojans[@]}"; do

	monitor &
done
# wait for all monitor subshells to end
wait

# 4) final status checks across all Trojans
#

failed=$(ls FAILED.TI.* 2> /dev/null | wc -l)

# NOTE sanity check on 0 Trojans; just exit quietly
if [[ $trojan_counter == 0 ]]; then

	date > DONE.TI.ALL
	exit 0

elif [[ $failed == 0 ]]; then

#	# NOTE redundant to log in main daemon
#	echo -e "\nISPD23 -- 2)  $id_run: Innovus Trojan insertion, all $trojan_counter run(s) done without failure."

	date > DONE.TI.ALL
	exit 0

elif [[ $failed == $trojan_counter ]]; then

#	# NOTE redundant to log in main daemon
#	echo -e "\nISPD23 -- 2)  $id_run: Innovus Trojan insertion, ALL $failed/$trojan_counter runs failed."

	date > FAILED.TI.ALL
	exit 1

# NOTE some but not all runs failed; still mark as done for main daemon
else

#	# NOTE redundant to log in main daemon
#	echo -e "\nISPD23 -- 2)  $id_run: Innovus Trojan insertion, $failed/$trojan_counter run(s) failed but remaining run(s) are done without failure."

	date > DONE.TI.ALL
	exit 0
fi
