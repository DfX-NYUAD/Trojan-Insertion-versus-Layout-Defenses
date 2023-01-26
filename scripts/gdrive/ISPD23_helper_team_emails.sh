#!/bin/bash

source ISPD23_daemon.settings

echo "Team emails"
echo "==========="

while read -r a b; do
	google_team_folders[$a]=$b
done < <(./gdrive list --no-header -q "parents in '$google_root_folder' and trashed = false and not (name contains '_test')" | awk '{print $1" "$2}')

emails_string_all=""

## iterate over keys / google IDs
for google_team_folder in "${!google_team_folders[@]}"; do

	team=${google_team_folders[$google_team_folder]}

	google_share_emails[$team]=$(./gdrive share list $google_team_folder | tail -n +2 | awk '{print $4}' | grep -Ev "$emails_excluded_for_notification" | grep '@')

	team_emails=${google_share_emails[$team]}

	# unroll emails explicitly; use of ${emails[@]} won't work within larger string
	emails_string=""
	for email in $team_emails; do
		emails_string+="$email; "
	done

	echo "Team $team : $emails_string"

	emails_string_all+=$emails_string
done
echo ""

echo "ALL : $emails_string_all"
echo ""
