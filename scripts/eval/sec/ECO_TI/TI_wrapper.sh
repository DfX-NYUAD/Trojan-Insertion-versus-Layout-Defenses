#!/bin/bash

####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD, in collaboration with Mohammad Eslami and Samuel Pagliarini, TalTech
#
####

## fixed settings; typically not to be modified
#
benchmark=$1
id_run=$2
err_rpt="reports/errors.rpt"

## procedures
#
start_TI() {

	## wait until prior TI call has fully started, i.e., until Innovus session has started up and the TI_settings.tcl file has been sourced
	if [[ "$previous_trojan_name" != "NA" ]]; then

		while true; do

			if [[ -e DONE.source.TI_$previous_trojan_name ]]; then
				break
			fi

			sleep 1s
		done
	fi

	echo -e "\nISPD23 -- 2)  $id_run:  Starting Innovus Trojan insertion, Trojan \"$trojan_name\"."

	## init TI_settings.tcl for current Trojan
	# NOTE only mute regular stdout, which is put into log file already, but keep stderr
	scripts/TI_init.sh $trojan_name > /dev/null

	## some error occurred
	# NOTE specific error is already logged via TI_init.sh; no need to log again
	if [[ $? != 0 ]]; then

		echo -e "\nISPD23 -- 2)  $id_run:  Failed to start Innovus Trojan insertion, Trojan \"$trojan_name\". More details are reported in \"$err_rpt\"."

		# set failure flag/file for this Trojan; this helps the monitor subshells below to kill other processes as well
		date > FAILED.TI_$trojan_name

		exit 1
	fi

	## actual Innovus call
	innovus -nowin -files scripts/TI.tcl -log TI_$trojan_name > /dev/null &
	echo $! > PID.TI_$trojan_name
}

#
## main code
#

## 0) parameter checks
#
if [[ $benchmark == "" ]]; then

	echo "ISPD23 -- ERROR: cannot conduct Trojan insertion -- 1st parameter, benchmark, is not provided." >> $err_rpt

	# set failure flag/file for all Trojan insertion
	date > FAILED.TI_ALL

	exit 1
fi

## 1) wait until design db becomes available (db is generated through scripts/eval/des/PPA.tcl)
#
while true; do

	if [[ -e design.enc && -d design.enc.dat ]]; then
		break
	fi

	## sanity check: if we reach here (i.e., did not already break above) and this file exists, this means that PPA evaluation finished but, somehow, saveDesign failed
	## also conduct sanity check for any other failure in PPA.tcl
	if [[ -e DONE.inv_PPA || -e FAILED.inv_PPA ]]; then

		err_string="Failure for Trojan insertion: design database was not initialized since, for some reason, Innovus PPA evaluation failed."
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
case $benchmark in

	#TODO merge those cases w/ same trojan_name, using eg aes|camellia)
	#TODO
	aes)
	;;

	camellia)
		previous_trojan_name="NA"
		trojan_name="camellia_burn_8_32"
		trojans[0]=$trojan_name
		start_TI
		if [[ $? != 0 ]]; then
			# NOTE break; don't start further TI processes
			break;
		fi

		previous_trojan_name=$trojan_name
		trojan_name="camellia_fault_16_5"
		trojans[1]=$trojan_name
		start_TI
		if [[ $? != 0 ]]; then
			# NOTE break; don't start further TI processes
			# NOTE prior TI processes will be killed by monitor subshells
			break;
		fi

		previous_trojan_name=$trojan_name
		trojan_name="camellia_leak_16_5"
		trojans[2]=$trojan_name
		start_TI
		if [[ $? != 0 ]]; then
			# NOTE break; don't start further TI processes
			# NOTE prior TI processes will be killed by monitor subshells
			break;
		fi
	;;

	#TODO
	cast)
	;;

	#TODO
	misty)
	;;

	#TODO
	seed)
	;;

	#TODO
	sha256)
	;;

	*)
		echo "ISPD23 -- ERROR: cannot conduct Trojan insertion -- Unknown benchmark \"$benchmark\"." >> $err_rpt

		# set failure flag/file for all Trojan insertion
		date > FAILED.TI_ALL

		exit 1
	;;
esac

## 3) monitor all TI processes
#
for trojan in "${trojans[@]}"; do

	## monitor subshell
	# NOTE derived from scripts/gdrive/ISPD23_daemon_procedures.sh, check_eval()
	(

	# sleep a little to avoid immediate but useless errors concerning log file not
	# found; is only relevant for the very first run just following right after
	# starting the process, but should still be employed here as fail-safe measure
	sleep 1s

	while true; do

		if [[ -e DONE.TI_$trojan ]]; then

			echo -e "\nISPD23 -- 2)  $id_run:  Done with Innovus Trojan insertion, Trojan \"$trojan\"."

			break
		else
			errors=0

			# check for any errors
			# NOTE limit to 1k errors since tools may flood log files w/ INTERRUPT messages etc, which would then stall grep
			errors_run=$(grep -m 1000 -E "$innovus_errors_for_checking" TI_"$trojan".log* | grep -Ev "$innovus_errors_excluded_for_checking")
			if [[ $errors_run != "" ]]; then

				# NOTE begin logging w/ linebreak, to differentiate from other ongoing logs like sleep progress bar
				# NOTE id_run passed through as global var
				echo -e "\nISPD23 -- 2)  $id_run:  Some error occurred for Innovus Trojan insertion, Trojan \"$trojan\"."
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

				echo -e "\nISPD23 -- 2)  $id_run:  Innovus Trojan insertion got interrupted, Trojan \"$trojan\"."
				echo "ISPD23 -- ERROR: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- INTERRUPT" >> $err_rpt

				errors=1
			fi

			# also check other TI processes
			for trojan_other in "${trojans[@]}"; do
				if [[ "$trojan" == "$trojan_other" ]]; then
					continue
				fi

				if [[ -e FAILED.TI_$trojan_other ]]; then

					echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus Trojan insertion failed, Trojan \"$trojan_other\". Also abort Innovus Trojan insertion, Trojan \"$trojan\" ..."
					echo "ISPD23 -- ERROR: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- aborted due to failure for Innovus Trojan insertion, Trojan \"$trojan_other\"" >> $err_rpt

					errors=1
				fi
			done

			# also check other processes
			if [[ -e FAILED.lec_checks ]]; then

				echo -e "\nISPD23 -- 2)  $id_run:  For some reason, LEC design checks failed. Also abort Innovus Trojan insertion, Trojan \"$trojan\" ..."
				echo "ISPD23 -- ERROR: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- aborted due to failure for LEC design checks" >> $err_rpt

				errors=1
			fi
			if [[ -e FAILED.inv_PPA ]]; then

				echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus PPA evaluation failed. Also abort Innovus Trojan insertion, Trojan \"$trojan\" ..."
				echo "ISPD23 -- ERROR: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- aborted due to failure for Innovus PPA evaluation" >> $err_rpt

				errors=1
			fi
			if [[ -e FAILED.inv_checks ]]; then

				echo -e "\nISPD23 -- 2)  $id_run:  For some reason, Innovus design checks failed. Also abort Innovus Trojan insertion, Trojan \"$trojan\" ..."
				echo "ISPD23 -- ERROR: process failed for Innovus Trojan insertion, Trojan \"$trojan\" -- aborted due to failure for Innovus design checks" >> $err_rpt

				errors=1
			fi

			# for any errors, mark as failed and kill this and all other TI processes
			if [[ $errors != '0' ]]; then

				date > FAILED.TI_$trojan

				# NOTE not all cases/conditions require killing, but for simplicity this is unified here; trying again to kill wont hurt
				# NOTE do not set FAILED file for the other processes here; this is covered by the other monitoring subshells
				for trojan_ in "${trojans[@]}"; do
					cat PID.TI_$trojan_ | xargs kill 2> /dev/null
				done

				exit 1
			fi
		fi

		sleep 1s
	done

	) &
done

# wait for all monitor subshells to end
wait

# 4) final status checks across all Trojans
#
# NOTE "if [[ -e FAILED.TI_* ]]; then" does not work; thus, check for files via `ls' and its exit code
errors=$(ls FAILED.TI_* > /dev/null 2>&1; echo $?)
if [[ $errors == '0' ]]; then

	echo -e "\nISPD23 -- 2)  $id_run: Some Innovus Trojan insertion run(s) failed."

	date > FAILED.TI_ALL
	exit 1
else
	echo -e "\nISPD23 -- 2)  $id_run: Innovus Trojan insertion run(s) done."

	date > DONE.TI_ALL
	exit 0
fi
