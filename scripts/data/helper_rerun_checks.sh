#!/bin/bash

##############
## init
##############

root_dir=$(pwd)

source /data/nyu_projects/ISPD23/scripts/gdrive/ISPD23_daemon.settings
source /data/nyu_projects/ISPD23/scripts/gdrive/ISPD23_daemon_procedures.sh

##############
## main code
##############

for team in /data/nyu_projects/ISPD23_prod/final/*; do

	if [[ $team == "_production" || $team == "_test" ]]; then
		continue
	fi

	team_=${team#*/}
#	echo $team_

	for des in $team/*; do

		des_=${des##*/}
#		echo $des_

#		## dbg only
#		if [[ $des_ == "aes" ]]; then
#			continue
#		fi

		## drop old status files, if any
		rm $des/valid.before 2> /dev/null
		rm $des/valid.after 2> /dev/null
		rm $des/invalid.after 2> /dev/null

		for run in $des/backup_work/*; do

		(
			if [[ $run == *".zip" || $run != *"downloads"* ]]; then
				continue
			fi

			if [[ -e $run/reports/errors.rpt ]]; then
				continue
			fi

			## valid run
			echo $run

			## report valid runs before check
			run_=${run#*/downloads_}
			echo $run_ >> $des/valid.before

			## unpack submission design files into work dir
			# NOTE first unpack the constant-named linked files, then unpack the actual file the links point to
			unzip -jo $run".zip" \*/design.{def,v} -d $run > /dev/null
			for file in $run/design.{def,v}; do
				dst=$(ls -l $file | awk '{print $NF}')
#				echo $dst
				unzip -jo $run".zip" \*/$dst -d $run
			done

			## also unpack required ASAP7 files into work dir
			unzip -jo $run".zip" \*/ASAP7/\*.lef -d $run > /dev/null

			## enter work dir
			cd $run

			## re-organize ASAP7 files
			mkdir -p ASAP7
			mv *.lef ASAP7/

			## link check scripts; point to test/dev dir, NOT to prod dir
			mkdir -p scripts
			ln -sf /data/nyu_projects/ISPD23/scripts/eval/checks/check*.tcl scripts/
			
#			## list folder content
#			ls -l

			## run check; derived from ISPD23_daemon_procedures.sh
			#
			# NOTE vdi is limited to 50k instances per license --> ruled out for aes w/ its ~260k instances
			if [[ $des_ == "aes" ]]; then

				# NOTE only mute regular stdout, which is put into log file already, but keep stderr
				call_invs_only scripts/checks.tcl -stylus -log checks__rerun_PDN > /dev/null
			else
				call_vdi_invs scripts/checks.tcl -stylus -log checks__rerun_PDN > /dev/null
			fi

			## parse check results; derived from parse_inv_checks in ISPD23_daemon_procedures.sh
			#
			errors=0
			issues=$(grep "Final result: false" reports/check_PDN.rpt | wc -l)
			string="Innovus: PDN checks failures:"

			if [[ $issues != 0 ]]; then

				errors=1

				echo "ISPD23 -- ERROR: $string $issues -- see check_PDN.rpt for more details." >> reports/errors.rpt
			fi

			echo "ISPD23 -- $string $issues" >> reports/checks_summary.rpt

			#
			# evaluate criticality of issues
			#
			if [[ $errors == 1 ]]; then

				echo -e "\nISPD23 -- 2)  $run:  Some critical Innovus design check(s) failed."

				date > FAILED.inv_checks
			else
				echo -e "\nISPD23 -- 2)  $run:  Innovus design checks done; all passed."

				date > PASSED.inv_checks
			fi

			## cleanup
			rm -r scripts
			rm -r ASAP7
			rm *.def
			rm *.v

			## update archive
			cd ../

			zip -d downloads_$run_".zip" downloads_$run_/reports/check_stripes.rpt > /dev/null
			zip downloads_$run_".zip" downloads_$run_/reports/check_PDN.rpt > /dev/null
			zip downloads_$run_".zip" downloads_$run_/reports/checks_summary.rpt > /dev/null

			zip downloads_$run_".zip" downloads_$run_/checks__rerun_PDN.* > /dev/null

			zip downloads_$run_".zip" downloads_$run_/reports/errors.rpt > /dev/null

			zip -d downloads_$run_".zip" downloads_$run_/PASSED.inv_checks > /dev/null
			zip downloads_$run_".zip" downloads_$run_/{PASSED,FAILED}.inv_checks > /dev/null

			## return silently to root dir
			cd $root_dir > /dev/null

			## report valid runs after check
			if ! [[ -e $run/reports/errors.rpt ]]; then
				echo $run_ >> $des/valid.after
			else
				echo $run_ >> $des/invalid.after
			fi
		) &

		done
	done
done

wait
