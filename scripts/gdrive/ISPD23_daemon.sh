#!/bin/bash

####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD
#
####

source ISPD23_daemon.settings
source ISPD23_daemon_procedures.sh

# initializing

# NOTE this expects the team folder in the Google root drive and, to begin with, an empty subfolder for the current
# round. The related benchmark sub-subfolders will be initialized by this script
initialize

## continuous loop: file downloads, script runs, file uploads
#
while true; do

##NOTE use for deadline mode
#	#https://epoch.vercel.app
#	#2022-03-30 21:00:00 GST (UTC+4)
#	if [[ $(date +%s) < 1648659600 ]]; then

#		# NOTE turned off for automated runs at participant's local end
#		echo "ISPD23 -- 1) Download new submissions, if any ..."
#		echo "ISPD23 -- 1)  Time: $(date)"
#		echo "ISPD23 -- 1)  Time stamp: $(date +%s)"
#
#		google_downloads
#
#		echo "ISPD23 -- 1)"
#		echo "ISPD23 -- 1) Done"
#		echo "ISPD23 -- "


		echo "ISPD23 -- 2) Start evaluation processing of newly downloaded submission files, if any ..."
		echo "ISPD23 -- 2)  Time: $(date)"
		echo "ISPD23 -- 2)  Time stamp: $(date +%s)"
		echo "ISPD23 -- 2)"

		start_eval

		echo "ISPD23 -- 2)"
		echo "ISPD23 -- 2) Done"
		echo "ISPD23 -- "

#	else
#		echo "ISPD23 -- 1, 2) Deadline passed -- no more downloads and start of evaluation ..."
#		echo "ISPD23 -- 1, 2)"
#		echo "ISPD23 -- "
#	fi

	echo "ISPD23 -- 3) Check status of ongoing evaluation processing, if any ..."
	echo "ISPD23 -- 3)  Time: $(date)"
	echo "ISPD23 -- 3)  Time stamp: $(date +%s)"

	check_eval

	echo "ISPD23 -- 3)"
	echo "ISPD23 -- 3) Done"
	echo "ISPD23 -- "


#	# NOTE turned off for automated runs at participant's local end
#	echo "ISPD23 -- 4) Upload new results, if any ..."
#	echo "ISPD23 -- 4)  Time: $(date)"
#	echo "ISPD23 -- 4)  Time stamp: $(date +%s)"
#
#	google_uploads
#
#	echo "ISPD23 -- 4) Done"
#	echo "ISPD23 -- "


	echo "ISPD23 -- 5) Sleep/wait for $check_interval s ..."
	echo "ISPD23 -- 5)  Time: $(date)"
	echo "ISPD23 -- 5)  Time stamp: $(date +%s)"
	echo "ISPD23 -- 5)"
	echo "ISPD23 -- 5) Sleeping ..."

	sleeping $check_interval

	echo "ISPD23 -- 5) Done"
	echo "ISPD23 -- "
done
