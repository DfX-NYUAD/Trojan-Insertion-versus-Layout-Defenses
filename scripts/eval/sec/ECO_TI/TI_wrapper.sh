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
# runs
max_current_runs_default=6
max_current_runs_aes=6
# dbg
dbg_log=0
dbg_log_verbose=0
# NOTE dbg_files is sourced from $daemon_settings_file below

## init stuff; main code further below

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

	# NOTE we have to init/"freeze" this vars locally, at the beginning of the call; otherwise, any update on the same-name global vars could throw off the procedure
	local trojan=$1
	local TI_mode=$2
	local prev_trojan_TI=$3

	# NOTE syntax for status files is $trojan"."$TI_mode
	local trojan_TI=$trojan"."$TI_mode

	# dbg_log
	if [[ $dbg_log == 1 ]]; then
		echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, start_TI ENTRY for Trojan \"$trojan\", TI mode \"$TI_mode\"."
	fi

	## initially wait until design db becomes available (db is generated through scripts/eval/des/PPA.tcl)
	#
	while true; do

		# dbg_log_verbose
		if [[ $dbg_log_verbose == 1 ]]; then
			echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, start_TI WHILE - DB INIT - for Trojan \"$trojan\", TI mode \"$TI_mode\"."
		fi

		if [[ -e DONE.save.$TI_mode ]]; then
			break
		fi

		## sanity check: if we reach here (i.e., did not already break above) and DONE.inv_PPA exists, this means that PPA evaluation finished but, somehow, saveDesign failed
		## sanity check (more reasonable): some other failure occurred for PPA evaluation, making that script PPA.tcl error out and stop.
		if [[ -e DONE.inv_PPA || -e FAILED.inv_PPA ]]; then

			err_string="Innovus Trojan insertion, cancelled as design database for TI mode \"$TI_mode\" was not initialized since, for some reason, Innovus PPA evaluation failed."
			echo -e "\nISPD23 -- 2)  $id_run: $err_string"
			echo "ISPD23 -- WARNING: $err_string" >> $warn_rpt

			date > CANCELLED.TI.$trojan_TI

			# dbg_log
			if [[ $dbg_log == 1 ]]; then
				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, start_TI EXIT 1 for Trojan \"$trojan\", TI mode \"$TI_mode\"."
			fi

			exit 1
		fi

		# NOTE this will take a while; we can wait bit longer here
		sleep 10s
	done

	## then, only wait again (and check status) in case some Trojan has been already started (to make sure TI_settings.tcl has been sourced and can be overwritten)
	#
	if [[ "$prev_trojan_TI" != "NA.NA" ]]; then

		while true; do

			# dbg_log_verbose
			if [[ $dbg_log_verbose == 1 ]]; then
				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, start_TI WHILE - MAIN LOOP - for Trojan \"$trojan\", TI mode \"$TI_mode\"."
			fi

			## status check and exit handling; process might have been cancelled in the meantime, namely for any failure for PPA eval, LEC checks, and/or design checks,
			## as well as for any case where some "inferior" TI mode already sufficed to insert Trojan w/o any violations; see below in process monitor() for handling/processing
			## of all these cases
			##
			if [[ -e CANCELLED.TI.$trojan_TI ]]; then

				# dbg_log
				if [[ $dbg_log == 1 ]]; then
					echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, start_TI EXIT 1 for Trojan \"$trojan\", TI mode \"$TI_mode\"."
				fi

				exit 1
			fi

			## wait until _prior_ Trojan run has fully started (i.e., Innovus session has started up and the TI_settings.tcl file has been sourced)
			#
			# NOTE check for both regular and for dummy status files; the latter have the additional suffix ".dummy" and are generated when the process
			# got cancelled, specifically to allow this run here to proceed while allowing to differentiate from real/actual source operations being done
			
			# NOTE checking for files with * wildcards using '-e' does not work; go by files count instead
			status_files=$(ls DONE.source.TI.$prev_trojan_TI* 2> /dev/null | wc -l)
			if [[ $status_files != 0 ]]; then

				# wait further in case max runs are already ongoing
				#
				runs_started=$(ls STARTED.TI.* 2> /dev/null | wc -l)
				# NOTE also consider any failed and cancelled run
				runs_done=$(ls {DONE.TI.*,FAILED.TI.*,CANCELLED.TI.*} 2> /dev/null | wc -l)
				((runs_ongoing = runs_started - runs_done))

				# design-specific limits
				if [[ "$trojan" == *"aes"* ]]; then
					max_current_runs=$max_current_runs_aes
				else
					max_current_runs=$max_current_runs_default
				fi

				# start this run in case there's budget; meaning to break the wait loop and move on
				if [[ $runs_ongoing -lt $max_current_runs ]]; then

					break
				fi
			fi

			sleep 1s
		done
	fi

	# NOTE there might a race condition w/ other start_TI processes that also want to start their job at the same time; thus, mark start ASAP.
	# NOTE mark as started even before TI_init.sh helps for the count of runs above; otherwise, if TI_init.sh fails, we could have e.g., -1 runs ongoing because of 1x FAILED but 0x STARTED
	date > STARTED.TI.$trojan_TI

	echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, initializing for Trojan \"$trojan\", TI mode \"$TI_mode\"."

	## init TI_settings.tcl for current Trojan
	# NOTE covers semaphore check and lock
	# NOTE only mute regular stdout, which is put into log file already, but keep stderr
	#
	scripts/TI_init.sh $trojan $TI_mode $dbg_files > /dev/null
	TI_init_status=$?

	## some error occurred
	# NOTE specific error is already logged via TI_init.sh; no need to log again
	#
	if [[ $TI_init_status == 1 ]]; then

		echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, failed to start for Trojan \"$trojan\", TI mode \"$TI_mode\". More details are reported in \"$err_rpt\"."

		# set failure flag/file for this Trojan
		date > FAILED.TI.$trojan_TI

		# dbg_log
		if [[ $dbg_log == 1 ]]; then
			echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, start_TI EXIT 1 for Trojan \"$trojan\", TI mode \"$TI_mode\"."
		fi

		# NOTE since TI.tcl won't be even started, we need to clear the semaphore here
		rm scripts/TI_settings.tcl.semaphore.$trojan_TI 2> /dev/null

		exit 1

	## got cancelled while waiting for the semaphore; didn't start the process; just exit from here
	#
	elif [[ $TI_init_status == 2 ]]; then

		# dbg_log
		if [[ $dbg_log == 1 ]]; then
			echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, start_TI EXIT 1 for Trojan \"$trojan\", TI mode \"$TI_mode\"."
		fi

		# NOTE since TI.tcl won't be even started, we need to clear the semaphore here
		# NOTE unlikely that this sempahore is there, but not impossible (i.e., once a race condition happens for the semaphore while loop in TI_init.sh)
		rm scripts/TI_settings.tcl.semaphore.$trojan_TI 2> /dev/null

		exit 1
	fi

	# dbg_log
	if [[ $dbg_log == 1 ]]; then
		cat scripts/TI_settings.tcl
	fi

	## actual Innovus call
	# NOTE covers semaphore release once the config file is fully sourced
	#

	# NOTE vdi is limited to 50k instances per license --> ruled out for aes w/ its ~260k instances
	if [[ "$trojan" == *"aes"* ]]; then

		call_invs_only scripts/TI.tcl -log TI.$trojan_TI > /dev/null &
		echo $! > PID.TI.$trojan_TI
	else
		# NOTE for ECO TI, vdi should be sufficient, but also use invs license if vdi ones are already busy; this should help to get the many parallel ECO runs through the
		# pipeline, but minor limitation or impact is that, if the backend is already busy, 'aes' submissions for some team w/o other runs would not get started right away
		call_vdi_invs scripts/TI.tcl -log TI.$trojan_TI > /dev/null &
		echo $! > PID.TI.$trojan_TI
	fi

	# dbg_log
	if [[ $dbg_log == 1 ]]; then
		echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, start_TI EXIT 0 for Trojan \"$trojan\", TI mode \"$TI_mode\"."
	fi
}

monitor() {

	# NOTE we have to init/"freeze" this vars locally, at the beginning of the call; otherwise, any update on the same-name global vars could throw off the procedure
	local trojan=$1
	local TI_mode=$2
	local trojan_TI=$3

	# NOTE syntax for status files is $trojan"."$TI_mode
	local trojan_TI=$trojan"."$TI_mode

	## monitor subshell
	# NOTE derived from scripts/gdrive/ISPD23_daemon_procedures.sh, check_eval(), but also revised here, mainly for use of STARTED.TI.* files

	# dbg_log
	if [[ $dbg_log == 1 ]]; then
		echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, monitor ENTRY for Trojan \"$trojan\", TI mode \"$TI_mode\"."
	fi

	while true; do

		# dbg_log_verbose
		if [[ $dbg_log_verbose == 1 ]]; then
			echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, monitor WHILE - MAIN LOOP - for Trojan \"$trojan\", TI mode \"$TI_mode\"."
		fi

		# NOTE sleep a little right in the beginning, to avoid immediate but useless errors concerning log file not found; is only relevant for the very first run just
		# following right after starting the process, but should still be employed here as fail-safe measure
		# NOTE merged w/ regular sleep, which is needed anyway (and was previously done at the end of the loop)
		sleep 2s

		local error=0
		local cancelled=0

		# hasn't started yet
		if ! [[ -e STARTED.TI.$trojan_TI ]]; then

			# got cancelled (by some other run; see below)
			if [[ -e CANCELLED.TI.$trojan_TI ]]; then

				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, cancelled for Trojan \"$trojan\", TI mode \"$TI_mode\", via an interrupt for some other check or some other Trojan run."

				# NOTE Importantly, this, and all other process issues below, are to be handled only as warnings for the logs/reports. This is to not flag scores as invalid; any
				# Trojan run may fail while still providing valid scores (namely, that the submission layout is "stronger" than our Trojan insertion)

				echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\", TI mode \"$TI_mode\" -- cancelled; triggered by some other check or some other Trojan run." >> $warn_rpt

				# dbg_log
				if [[ $dbg_log == 1 ]]; then
					echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, monitor EXIT 1 for Trojan \"$trojan\", TI mode \"$TI_mode\"."
				fi

				# mark as cancellation
				# NOTE does not really require marking (again) as cancellation, nor killing, but "wrapping up" as in setting dummy DONE.source.TI file;
				# this is covered further below as well, namely when checking for 'cancelled != 0'
				cancelled=1
			fi

			# else (if not cancelled), continue to wait
			# NOTE it's important to _not_ use continue here, but to execute the remaining code in this main loop (as this checks for failures in other processes)

		# has started at some point, and got just done, w/o errors and w/o being cancelled earlier
		elif [[ -e DONE.TI.$trojan_TI ]]; then

			echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, done for Trojan \"$trojan\", TI mode \"$TI_mode\"."

			## NOTE process management: if reg (or adv) mode already succeeds w/o any violations, then the runs for adv and adv2 (or adv2) can be cancelled. Importantly,
			## this assumes that the order of runs is fixed to reg, adv, then adv2 -- we do ensure this via the naming scheme of TI/*.dummy files
			#

			# skip these checks for adv2 mode
			if [[ $TI_mode == "adv2" ]]; then

				# dbg_log
				if [[ $dbg_log == 1 ]]; then
					echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, monitor EXIT 0 for Trojan \"$trojan\", TI mode \"$TI_mode\"."
				fi

				# stop to wait, exit monitor process (w/o error status; currently not evaluated)
				exit 0
			fi

			# prepare checks
			if [[ $dbg_files == 0 ]]; then
				rpt_drc="*.geom."$trojan_TI".rpt"
			else
				rpt_drc="reports/*.geom."$trojan_TI".rpt"
			fi
			# NOTE timing rpts are always placed in reports/ folder, independent of dbg mode, as they are meant to be shared with participants in any case
			rpt_timing="reports/timing."$trojan_TI".rpt"

			## actual checks; derived from scores.sh

			# DRC; init vios_total
			vios_string=$(grep "Total Violations :" $rpt_drc 2> /dev/null | awk '{print $4}')
			if [[ $vios_string == "" ]]; then
				vios_total=0
			else
				vios_total=$vios_string
			fi

			# setup
			vios_string=$(grep "View : ALL" $rpt_timing | awk 'NR==1' | awk '{print $NF}')
			((vios_total = vios_total + vios_string))
			# hold
			vios_string=$(grep "View : ALL" $rpt_timing | awk 'NR==2' | awk '{print $NF}')
			((vios_total = vios_total + vios_string))

			# DRV
			while read line; do

				if [[ "$line" != *"Check : "* ]]; then
					continue
				fi

				vios_string=$(echo $line | awk '{print $NF}')
				((vios_total = vios_total + vios_string))

			done < $rpt_timing

			# no violations; mark other, more advanced runs for cancellation
			if [[ $vios_total == 0 ]]; then

				string="Innovus Trojan insertion, Trojan \"$trojan\", TI mode \"$TI_mode\", passed without any violations. Cancelling the run(s) for more advanced TI mode(s)."
				echo -e "\nISPD23 -- 2)  $id_run:  $string"
				echo "ISPD23 -- WARNING: $string" >> $warn_rpt

				if [[ $TI_mode == "reg" ]]; then

					date > CANCELLED.TI.$trojan".adv"
					date > CANCELLED.TI.$trojan".adv2"

				elif [[ $TI_mode == "adv" ]]; then

					date > CANCELLED.TI.$trojan".adv2"
				fi
			else
				string="Innovus Trojan insertion, Trojan \"$trojan\", TI mode \"$TI_mode\", passed with some violations. Continuing the run(s) for more advanced TI mode(s), if planned for."
				echo -e "\nISPD23 -- 2)  $id_run:  $string"
				echo "ISPD23 -- WARNING: $string" >> $warn_rpt
			fi

			# dbg_log
			if [[ $dbg_log == 1 ]]; then
				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, monitor EXIT 0 for Trojan \"$trojan\", TI mode \"$TI_mode\"."
			fi

			# stop to wait, exit monitor process (w/o error status; currently not evaluated)
			exit 0

		# has started at some point, and not done yet, but got cancelled (by some other run; see below)
		elif [[ -e CANCELLED.TI.$trojan_TI ]]; then

			echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, interrupt for Trojan \"$trojan\", TI mode \"$TI_mode\", indirectly via an interrupt for some other check or some other Trojan run."
			echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\", TI mode \"$TI_mode\" -- INTERRUPT; triggered indirectly by some other check or some other Trojan run." >> $warn_rpt

			# mark as cancellation (again), as it still requires killing, which is handled further below
			cancelled=1

		# has started at some point, but not done yet and not cancelled yet
		else
			# dbg_log_verbose
			if [[ $dbg_log_verbose == 1 ]]; then
				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, still going on for Trojan \"$trojan\", TI mode \"$TI_mode\"."
			fi

			# check for any errors -- these would be errors in the flow, like failure to legalize placement etc.
			#
			# NOTE limit to 1k errors since tools may flood log files w/ INTERRUPT messages etc, which would then stall grep
			# NOTE mute stderr since log file might not exist yet for first few runs of check, depending on overall workload of backend
			errors_run=$(grep -m 1000 -E "$innovus_errors_for_checking" TI."$trojan".log* 2> /dev/null | grep -Ev "$innovus_errors_excluded_for_checking")

			if [[ $errors_run != "" ]]; then

				# NOTE begin logging w/ linebreak, to differentiate from other ongoing logs like sleep progress bar
				# NOTE id_run passed through as global var
				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, some failure occurred for Trojan \"$trojan\", TI mode \"$TI_mode\"."

				# NOTE only in dbg mode we want to share details directly into this report to be uploaded; also note, in the backend all details are available
				# anyway in the logs
				if [[ $dbg_files == "1" ]]; then

					echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\", TI mode \"$TI_mode\" -- $errors_run" >> $warn_rpt
				else
					echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\", TI mode \"$TI_mode\" -- details remain undisclosed, on purpose" >> $warn_rpt
				fi

				error=1

			# also check for interrupts
			#
			# NOTE merged with check for errors into 'elif', as errors might lead to immediate process exit, which would then result in both
			# case covered at once; whereas we like to keep actual interrupt, runtime errors separate
			#
			# NOTE this will also capture any run where some error occurs that is listed specifically in $innovus_errors_excluded_for_checking
			#
			# NOTE only check when PID file already exist; might not be the case even though the STARTED file exists (which is the pre-requisite to reach here), as the
			# STARTED file was set ASAP in start_TI(), to avoid race condition for starting jobs

			elif [[ -e PID.TI.$trojan_TI ]]; then

				errors_interrupt=$(ps --pid $(cat PID.TI.$trojan_TI) > /dev/null 2>&1; echo $?)
				if [[ $errors_interrupt != 0 ]]; then

					# NOTE also check again for DONE flag file, to avoid race condition where
					# process just finished but DONE did not write out yet
					sleep 2s
					if [[ -e DONE.TI.$trojan_TI ]]; then
						break
					fi

					echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, interrupt for Trojan \"$trojan\", TI mode \"$TI_mode\"."
					echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\", TI mode \"$TI_mode\" -- INTERRUPT, runtime error" >> $warn_rpt

					error=1
				fi
			fi
		fi

		# independently of own status (thus outside of the main 'if' statement above), also check process state/evaluation outcome of other process(es)
		#
		# NOTE no need to abort process multiple times in case all is cancelled/brought down due to some failure for some single
		# process; use elif statements to abort each process only once
		if [[ -e FAILED.lec_checks ]]; then

			echo -e "\nISPD23 -- 2)  $id_run:  For some reason, LEC design checks failed. Also cancel/interrupt Innovus Trojan insertion, Trojan \"$trojan\", TI mode \"$TI_mode\" ..."
			echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\", TI mode \"$TI_mode\" -- cancelled or interrupted due to failure for LEC design checks" >> $warn_rpt

			# mark as cancellation, which still requires killing further below
			cancelled=1

		elif [[ -e FAILED.inv_PPA ]]; then

			echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus PPA evaluation failed. Also cancel/interrupt Innovus Trojan insertion, Trojan \"$trojan\", TI mode \"$TI_mode\" ..."
			echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\", TI mode \"$TI_mode\" -- cancelled or interrupted due to failure for Innovus PPA evaluation" >> $warn_rpt

			# mark as cancellation, which still requires killing further below
			cancelled=1

		elif [[ -e FAILED.inv_checks ]]; then

			echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus design checks failed. Also cancel/interrupt Innovus Trojan insertion, Trojan \"$trojan\", TI mode \"$TI_mode\" ..."
			echo "ISPD23 -- WARNING: process failed for Innovus Trojan insertion, Trojan \"$trojan\", TI mode \"$TI_mode\" -- cancelled or interrupted due to failure for Innovus design checks" >> $warn_rpt

			# mark as cancellation, which still requires killing further below
			cancelled=1
		fi

		# for any errors or cancellation, mark accordingly, kill the process, and stop monitor process
		if [[ $error != 0 || $cancelled != 0 ]]; then

			if [[ $error != 0 ]]; then
				date > FAILED.TI.$trojan_TI
			elif [[ $cancelled != 0 ]]; then
				date > CANCELLED.TI.$trojan_TI
			fi

			# NOTE mute stderr for cat, as the process might not have been started yet (then the PID file won't exist)
			# NOTE also mute stderr for kill, as the process might not run anymore, and also to cover the above, where there's no PID provided via xargs
			cat PID.TI.$trojan_TI 2> /dev/null | xargs kill -9 2> /dev/null

			# at this point, if the source operation didn't happen yet, we also need to write out this dummy status file, in order to allow other Trojan
			# runs (waiting for this source operation) to continue
			if ! [[ -e DONE.source.TI.$trojan_TI ]]; then
				date > DONE.source.TI.$trojan_TI".dummy"
			fi

			# sanity check/release of the semaphore which might still be locked TI_init.sh
			# NOTE only release the semaphore of this run, not of any other that might have started in the meantime
			rm -f scripts/TI_settings.tcl.semaphore.$trojan_TI

			# dbg_log
			if [[ $dbg_log == 1 ]]; then
				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion, monitor EXIT 1 for Trojan \"$trojan\", TI mode \"$TI_mode\"."
			fi

			exit 1
		fi
	done
}

#
## main code
#

## 1) init global data structures

# key: running ID; value: $TI_mode_ID"_"$TI_mode"__"$trojan
# NOTE associative array is not really needed, but handling of such seems easier than plain indexed array
declare -A TI_mode__trojan
trojan_counter=0

for file in TI/*.dummy; do

	# drop path
	str=${file##TI/}
	# drop dummy suffix
	str=${str%%.dummy}
	# drop TI_mode_ID
	str=${str#*_}

	TI_mode__trojan[$trojan_counter]=$str
	((trojan_counter = trojan_counter + 1))
done

##  2) init start_TI processes; all in parallel, but wait during init phase, as there's only one common config file, which can be updated only once some prior TI process has fully started
##  NOTE waiting is handled via start_TI() itself, not here
#

# NOTE init for 'prev_trojan_TI'
trojan="NA"
TI_mode="NA"

# NOTE we need to go explicitly in order of the key, running ID; the regular iterator '${TI_mode__trojan[@]}' does not provide that
for ((i=0; i<$trojan_counter; i++)); do

	str=${TI_mode__trojan[$i]}

	# NOTE refers to previous Trojan; follows the same syntax as other status files
	prev_trojan_TI=$trojan"."$TI_mode

	# NOTE syntax to parse: $TI_mode"__"$trojan
	trojan=${str#*__}
	TI_mode=${str%__*}

	# NOTE we have init/"freeze" this vars locally, at the beginning of the call; otherwise, any update on the same-name global vars could throw off the procedure
	start_TI $trojan $TI_mode $prev_trojan_TI &
done

## 3) start monitor for all TI processes
#
# NOTE we need to go explicitly in order of the key, running ID; the regular iterator '${TI_mode__trojan[@]}' does not provide that
for ((i=0; i<$trojan_counter; i++)); do

	str=${TI_mode__trojan[$i]}

	# NOTE syntax to parse: $TI_mode"__"$trojan
	trojan=${str#*__}
	TI_mode=${str%__*}

	# NOTE we have init/"freeze" this vars locally, at the beginning of the call; otherwise, any update on the same-name global vars could throw off the procedure
	monitor $trojan $TI_mode &
done
# wait for all monitor subshells to end
wait

# 4) final status checks across all Trojans
# NOTE logs for all cases are already covered by main daemon
#

failed=$(ls FAILED.TI.* 2> /dev/null | wc -l)

# NOTE code could be simplied/merged, but is kept like this for better clarity, and ease of revision later on
#

# NOTE sanity check on 0 Trojans; just exit quietly
if [[ $trojan_counter == 0 ]]; then

	date > DONE.TI.ALL
	exit 0

elif [[ $failed == 0 ]]; then

	date > DONE.TI.ALL
	exit 0

elif [[ $failed == $trojan_counter ]]; then

	date > FAILED.TI.ALL
	exit 1

# NOTE some but not all runs failed or got cancelled; in any case, all is done
else
	date > DONE.TI.ALL
	exit 0
fi
