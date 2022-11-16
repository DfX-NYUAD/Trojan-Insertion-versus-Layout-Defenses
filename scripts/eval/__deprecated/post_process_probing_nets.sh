#!/bin/bash

src="nets_ea.rpt"
bk="nets_ea.rpt.back"
scale=12

# backup and clear orig file
mv $src $bk

echo "Obtaining stats ..."

# obtain stats first; going over all nets
#
expos_perc_max=0
expos_perc_total=0
expos_area_total=0
expos_count=0

#NET_NAME	TOT_NET_AREA	TOT_EXPOSED_PERC
#key_reg\[7\][9]		0.51205		41.011619959

regex_line="(.+\S)(\s+)([0-9]+[.][0-9]+)(\s+)([0-9]+[.][0-9]+)"

while read line; do

	if [[ "$line" =~ $regex_line ]]; then

		# https://serverfault.com/a/660888
#		declare -p BASH_REMATCH

		((expos_count = expos_count + 1))

		curr_net_area=${BASH_REMATCH[3]}
		curr_net_expos=${BASH_REMATCH[5]}

		# NOTE for small nets and/or relatively low evaluation accuracy, we may see percentage > 100;
		# limit those cases to 100
		if [[ $(bc -l <<< "$curr_net_expos > 100") -eq 1 ]]; then
			curr_net_expos=100
		fi

		# update max
		if [[ $(bc -l <<< "$curr_net_expos > $expos_perc_max") -eq 1 ]]; then
#			echo $line
#			echo $curr_net_expos

			expos_perc_max=$curr_net_expos
		fi

		expos_perc_total=$(bc -l <<< "scale=$scale; ($expos_perc_total + $curr_net_expos)")
		expos_area_total=$(bc -l <<< "scale=$scale; ($expos_area_total + ($curr_net_area * ($curr_net_expos / 100)))")
	fi

done < $bk

expos_perc_avg=$(bc -l <<< "scale=$scale; ($expos_perc_total / $expos_count)")

echo "Total exposed area across net assets: $expos_area_total" >> $src
echo "Max exposure [%] across net assets: $expos_perc_max" >> $src
echo "Avg exposure [%] across net assets: $expos_perc_avg" >> $src
echo "" >> $src


echo "Write back rpt file ..."

# print back nets second
#
## also print header for rows definition
echo "#NetName TotalAreaNet PercentageExposedAreaNet" >> $src
while read line; do

	if [[ "$line" =~ $regex_line ]]; then

		# restore backslashes in front of slashes etc -- only needed because of read line not maintaining them
		curr_net_name=$(echo ${BASH_REMATCH[1]} | sed -e 's/\//\\\//g' -e 's/\[/\\[/g' -e 's/\]/\\]/g')

		curr_net_area=${BASH_REMATCH[3]}

		# limit exposure percentage also during write-back
		curr_net_expos=${BASH_REMATCH[5]}
		if [[ $(bc -l <<< "$curr_net_expos > 100") -eq 1 ]]; then
			curr_net_expos="100.0"
		fi

		echo "$curr_net_name $curr_net_area $curr_net_expos"  >> $src
	fi

done < $bk
