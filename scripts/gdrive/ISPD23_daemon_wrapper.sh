#!/bin/bash

while true; do

	# kill any remaining daemon
	killall daemon.sh 2> /dev/null

	# move latest log (from prior run) to the back of set of log files
	logs=$(ls daemon.log* 2> /dev/null | tail -n 1)
	logs=${logs##*log}
	logs=$((logs + 1))
	mv daemon.log daemon.log$logs 2> /dev/null

	./daemon.sh | tee daemon.log
done	
