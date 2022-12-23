#!/bin/bash

source ISPD23_daemon.settings
source ISPD23_daemon_procedures.sh

initialize "production"

echo ""

emails_string_all=""

## iterate over keys / google IDs
for google_team_folder in "${!google_team_folders[@]}"; do

	team=${google_team_folders[$google_team_folder]}
	team_=$(printf "%-"$teams_string_max_length"s" $team)

	team_emails=${google_share_emails[$team]}

	# unroll emails explicitly; use of ${emails[@]} won't work within larger string
	emails_string=""
	for email in $team_emails; do
		emails_string+="$email; "
	done

	echo "Team $team_ : $emails_string"

	emails_string_all+=$emails_string
done

echo "ALL : $emails_string_all"
echo ""
