#!/bin/bash

####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD, in collaboration with Mohammad Eslami and Samuel Pagliarini, TalTech
#
####

## fixed settings; typically not to be modified
#
id_run=$1
inv_call=$2
err_rpt="reports/errors.rpt"
max_current_runs=3

## procedures
#
start_TI() {

	# only wait in case some Trojan has been already started (to make sure TI_settings.tcl has been sourced and can be overwritten)
	if [[ "$previous_trojan_name" != "NA" ]]; then

		while true; do

#			# dbg
#			echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, start_TI for Trojan \"$trojan_name\"."

			sleep 1s

			## wait -- at least -- until prior TI call has fully started (i.e., Innovus session has started up and the TI_settings.tcl file has been sourced)
			if [[ -e DONE.source.$previous_trojan_name ]]; then

				# wait further in case max runs are already ongoing
				# NOTE use this instead of process status from 'ps pid', as status from 'ps' would also cover errors, not only processes done
				runs_started=$(ls STARTED.TI_* 2> /dev/null | wc -l)
				runs_done=$(ls DONE.TI_* 2> /dev/null | wc -l)
				((runs_ongoing = runs_started - runs_done))

				# once some runs are done and new ones allowed, start this
				if [[ $runs_ongoing -lt $max_current_runs ]]; then

					# NOTE might result in race condition w/ other start_TI processes; thus, mark start ASAP and, if any init error occurs, unmark again later on
					date > STARTED.TI_$trojan_name

					break
				fi
			fi

			## sanity check; process might have been cancelled in the meantime
			if [[ -e FAILED.TI_$trojan_name ]]; then
				exit 1
			fi
		done
	fi

	echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, starting for Trojan \"$trojan_name\"."

	## init TI_settings.tcl for current Trojan
	# NOTE only mute regular stdout, which is put into log file already, but keep stderr
	scripts/TI_init.sh $trojan_name > /dev/null

	## some error occurred
	# NOTE specific error is already logged via TI_init.sh; no need to log again
	if [[ $? != 0 ]]; then

		echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, failed to start for Trojan \"$trojan_name\". More details are reported in \"$err_rpt\"."

		# set failure flag/file for this Trojan; this helps the monitor subshells below to kill other processes as well
		date > FAILED.TI_$trojan_name
		# also unmark start again
		rm STARTED.TI_$trojan_name

		exit 1
	fi

	## actual Innovus call
	date > STARTED.TI_$trojan_name
	$inv_call scripts/TI.tcl -log TI_$trojan_name > /dev/null &
	echo $! > PID.TI_$trojan_name
}

monitor() {

	## monitor subshell
	# NOTE derived from scripts/gdrive/ISPD23_daemon_procedures.sh, check_eval(), but also revised here, mainly for use of STARTED.TI_* files

	while true; do

#		# dbg
#		echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, monitor for Trojan \"$trojan\"."

		# NOTE sleep a little right in the beginning, to avoid immediate but useless errors concerning log file not found; is only relevant for the very first run just
		# following right after starting the process, but should still be employed here as fail-safe measure
		# NOTE merged w/ regular sleep, which is needed anyway (and was previously done at the end of the loop)
		sleep 5s

		errors=0

		# hasn't started yet
		if ! [[ -e STARTED.TI_$trojan ]]; then

			# also check other TI processes
			for trojan_other in "${trojans[@]}"; do

				if [[ "$trojan" == "$trojan_other" ]]; then
					continue
				fi

				if [[ -e FAILED.TI_$trojan_other ]]; then

					echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, failed for some reason for Trojan \"$trojan_other\". Also cancel Innovus Trojan insertion for Trojan \"$trojan\" ..."
					echo "ISPD23 -- ERROR: cancelled Innovus Trojan insertion, Trojan \"$trojan\" -- cancelled due to failure for Innovus Trojan insertion, Trojan \"$trojan_other\"" >> $err_rpt

					errors=1

					# NOTE no need to abort process multiple times in case all is cancelled/brought down due to some failure for some single
					break
				fi
			done

			# no other process failed yet; just continue waiting to start (else, the error handling is done at the end of the main 'while' loop)
			if [[ $errors == 0 ]]; then
				continue
			fi

		# has started, and already done (w/o errors)
		elif [[ -e DONE.TI_$trojan ]]; then

			echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, done for Trojan \"$trojan\"."

			break

		# has started, but not done yet
		else
#			# dbg
#			echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, still going on for Trojan \"$trojan\"."

			# check for any errors
			# NOTE limit to 1k errors since tools may flood log files w/ INTERRUPT messages etc, which would then stall grep
			errors_run=$(grep -m 1000 -E "$innovus_errors_for_checking" TI_"$trojan".log* | grep -Ev "$innovus_errors_excluded_for_checking")
			if [[ $errors_run != "" ]]; then

				# NOTE begin logging w/ linebreak, to differentiate from other ongoing logs like sleep progress bar
				# NOTE id_run passed through as global var
				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, some error occurred for Trojan \"$trojan\"."
				echo "ISPD23 -- ERROR: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- $errors_run" >> $err_rpt

				errors=1
			fi
		
			# also check for interrupts
			# cat errors to /dev/null as PID file might not even exist, namely when TI_init.sh fails
			errors_interrupt=$(ps --pid $(cat PID.TI_$trojan 2> /dev/null) > /dev/null 2>&1; echo $?)
			if [[ $errors_interrupt != 0 ]]; then

				# NOTE also check again for DONE flag file, to avoid race condition where
				# process just finished but DONE did not write out yet
				sleep 1s
				if [[ -e DONE.TI_$trojan ]]; then
					break
				fi

				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, got interrupted for Trojan \"$trojan\"."
				echo "ISPD23 -- ERROR: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- INTERRUPT" >> $err_rpt

				errors=1
			fi

			# also check other TI processes
			# NOTE copied from above
			for trojan_other in "${trojans[@]}"; do

				if [[ "$trojan" == "$trojan_other" ]]; then
					continue
				fi

				if [[ -e FAILED.TI_$trojan_other ]]; then

					echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, failed for some reason for Trojan \"$trojan_other\". Also abort Innovus Trojan insertion for Trojan \"$trojan\" ..."
					echo "ISPD23 -- ERROR: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- aborted due to failure for Innovus Trojan insertion, Trojan \"$trojan_other\"" >> $err_rpt

					errors=1

					# NOTE no need to abort process multiple times in case all is cancelled/brought down due to some failure for some single
					break
				fi
			done

			# also check process state/evaluation outcome of other process(es)
			#
			# NOTE no need to abort process multiple times in case all is cancelled/brought down due to some failure for some single
			# process; use elif statements to abort each process only once
			if [[ -e FAILED.lec_checks ]]; then

				echo -e "\nISPD23 -- 2)  $id_run:  For some reason, LEC design checks failed. Also abort Innovus Trojan insertion, Trojan \"$trojan\" ..."
				echo "ISPD23 -- ERROR: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- aborted due to failure for LEC design checks" >> $err_rpt

				errors=1

			elif [[ -e FAILED.inv_PPA ]]; then

				echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus PPA evaluation failed. Also abort Innovus Trojan insertion, Trojan \"$trojan\" ..."
				echo "ISPD23 -- ERROR: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- aborted due to failure for Innovus PPA evaluation" >> $err_rpt

				errors=1

			elif [[ -e FAILED.inv_checks ]]; then

				echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus design checks failed. Also abort Innovus Trojan insertion, Trojan \"$trojan\" ..."
				echo "ISPD23 -- ERROR: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- aborted due to failure for Innovus design checks" >> $err_rpt

				errors=1
			fi
		fi

		# for any errors, mark as failed and kill, and stop monitor process
		if [[ $errors != 0 ]]; then

			date > FAILED.TI_$trojan

			# NOTE mute stderr for cat, as the process might not have been started yet (then the PID file won't exist)
			cat PID.TI_$trojan 2> /dev/null | xargs kill 2> /dev/null

			exit 1
		fi
	done
}

#
## main code
#

## 1) wait until design db becomes available (db is generated through scripts/eval/des/PPA.tcl)
#
while true; do

	if [[ -e design.enc && -d design.enc.dat ]]; then
		break
	fi

	## sanity check: if we reach here (i.e., did not already break above) and DONE.inv_PPA exists, this means that PPA evaluation finished but, somehow, saveDesign failed
	## sanity check (more reasonable): any other failure for PPA evaluation
	if [[ -e DONE.inv_PPA || -e FAILED.inv_PPA ]]; then

		err_string="Innovus Trojan insertion: failed altogether as design database was not initialized since, for some reason, Innovus PPA evaluation failed."
		echo -e "\nISPD23 -- 2)  $id_run: $err_string"
		echo "ISPD23 -- ERROR: $err_string" >> $err_rpt

		# set failure flag/file for all Trojan insertion
		date > FAILED.TI_ALL
		exit 1
	fi

	sleep 1s
done

##  2) start TI processes; all in parallel, but wait during init phase, as there's only one common config file, which can be updated only once some prior TI process has fully started -- waiting is handled via start_TI procedure
#

# key: running ID; value: trojan_name
# NOTE associative array is not really needed, but handling of such seems easier than plain indexed array
declare -A trojans

trojan_name="NA"
trojan_counter=0

for file in TI/*; do

	previous_trojan_name=$trojan_name
	trojan_name=${file##TI/}
	trojan_name=${trojan_name%%.v}
	trojans[$trojan_counter]=$trojan_name

	((trojan_counter = trojan_counter + 1))

	start_TI &
done

## 3) monitor all TI processes
#
for trojan in "${trojans[@]}"; do

	monitor &
done
# wait for all monitor subshells to end
wait

# 4) final status checks across all Trojans
#
# NOTE "if [[ -e FAILED.TI_* ]]; then" does not work; thus, check for files via `ls' and its exit code
success=$(ls FAILED.TI_* > /dev/null 2>&1; echo $?)
if [[ $success == 0 ]]; then

	echo -e "\nISPD23 -- 2)  $id_run: Innovus Trojan insertion, some run(s) failed."

	date > FAILED.TI_ALL
	exit 1
else
	echo -e "\nISPD23 -- 2)  $id_run: Innovus Trojan insertion, all run(s) done."

	date > DONE.TI_ALL
	exit 0
fi
