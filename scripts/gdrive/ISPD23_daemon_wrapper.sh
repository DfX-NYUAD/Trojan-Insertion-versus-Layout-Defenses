#!/bin/bash

while true; do

	# kill any remaining daemon
	killall ISPD23_daemon.sh 2> /dev/null

	# move latest log (from prior run) to the back of set of log files
	logs=$(ls ISPD23.log* 2> /dev/null | tail -n 1)
	logs=${logs##*log}
	logs=$((logs + 1))
	mv ISPD23.log ISPD23.log$logs 2> /dev/null

	# move latest error log (from prior run) to the back of set of error log files
	errs=$(ls ISPD23.err* 2> /dev/null | tail -n 1)
	errs=${errs##*err}
	errs=$((errs + 1))
	mv ISPD23.err ISPD23.err$errs 2> /dev/null

	# keep log and err log files separate
#TODO filter out dots etc from sleeping command
#TODO w/ errors logged separately, bring them back to all the procedures, don't redirect to /dev/null
	./ISPD23_daemon.sh > >(tee ISPD23.log) 2> >(tee ISPD23.err >&2)
done

#TODO current fail for __test for google_downloads probably due to PRESENT subfolder missing --> integrate init
# procedure for subfolders into ISPD23_daemon_procedures.sh as well, currently that's in some separate script
