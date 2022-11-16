#!/bin/bash

while true; do

	# kill any remaining daemon
	killall ISPD23_daemon.sh 2> /dev/null

	# move latest log (from prior run) to the back of set of log files
	logs=$(ls ISPD23.log* 2> /dev/null | tail -n 1)
	logs=${logs##*log}
	logs=$((logs + 1))
	mv ISPD23.log ISPD23.log$logs 2> /dev/null

## didn't work out w/ filtering of sleep command
#
#	# move latest error log (from prior run) to the back of set of error log files
#	errs=$(ls ISPD23.err* 2> /dev/null | tail -n 1)
#	errs=${errs##*err}
#	errs=$((errs + 1))
#	mv ISPD23.err ISPD23.err$errs 2> /dev/null
#
#	# https://stackoverflow.com/a/692407
#	./ISPD23_daemon.sh > >(tee ISPD23.log) 2> >(tee ISPD23.err >&2)


	# https://stackoverflow.com/a/34593886
	# exclude lines w/ carriage return, i.e., those for progress_bar()
	./ISPD23_daemon.sh |& tee >(awk '!/\r/' > ISPD23.log)
done
