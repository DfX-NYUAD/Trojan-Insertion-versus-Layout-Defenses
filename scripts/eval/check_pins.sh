#!/bin/bash

####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD
#
####

## fixed settings; typically not to be modified
#
## files
rpt="reports/check_pins.rpt"
data_orig="reports/check_pins.DEF_orig.data"
DEF_sub="design.def"
DEF_orig="design_original.def"
## math
scale="6"
margin="0.00001"

## helper function
## required for correctly printing out and sourcing in associative arrays w/ special characters in bash 4.2
## obtained from https://stackoverflow.com/a/45665578

function array2file {
	# local variable for the keys
	declare -a keys
	
	# check if the array exists, to protect against injection
	# by passing a crafted string
	declare -p "$1" >/dev/null || return 1;
	
	printf "declare -A %s\n" "$1"
	
	# create a string with all the keys so we can iterate
	# because we can't use eval at for's declaration
	# we do it this way to allow for spaces in the keys, since that's valid
	eval "keys=(\"\${!$1[@]}\")"
	
	for k in "${keys[@]}"
	do
		printf "%s[\"${k//\"/\\\\\"}\"]=" "$1"
		# the extra quoting here protects against spaces
		# within the element's value - injection doesn't work here
		# but we still need to make sure there's consistency
		eval "printf \"\\\"%s\\\"\n\" \"\${$1[\"${k//\"/\\\"}\"]}\""
	done
}

#######

# init, cleanup
rm $rpt 2> /dev/null

# parse DEF files for dimensions using regex
#
echo "Parse DEF files for dimensions ..."

# NOTE calculations assume that LL corner is (0,0)

## DEF example
#DIEAREA ( 0 0 ) ( 134140 128240 ) ;
die_sub_x=$(grep -w 'DIEAREA' $DEF_sub | awk '{print $7}')
die_sub_y=$(grep -w 'DIEAREA' $DEF_sub | awk '{print $8}')
die_orig_x=$(grep -w 'DIEAREA' $DEF_orig | awk '{print $7}')
die_orig_y=$(grep -w 'DIEAREA' $DEF_orig | awk '{print $8}')

# parse DEF files for pins using regex
#
echo "Parse DEF files for pins ..."

## two DEF examples below:
## 1)
#- valid + NET valid + DIRECTION OUTPUT + USE SIGNAL
#  + LAYER metal2 ( -70 0 ) ( 70 140 )
#  + PLACED ( 108490 0 ) N ;
## 2)
#- VDD + NET VDD + SPECIAL + DIRECTION INOUT + USE POWER
# + PORT
#  + LAYER metal5 ( -400 0 ) ( 400 800 )
#  + FIXED ( 0 18520 ) E
# + PORT
# [...]
#  + FIXED ( 108760 128240 ) S
# ;
regex_start="^- (\S+) [+] NET (\S+) [+] [^;]+"
regex_middle="[^;]+"
## NOTE the below would also capture the VDD/VSS statements -- these are ignored for now, as checking placement of related pins is not so important
## regex_end="(PLACED|FIXED) [(] ([0-9]+) ([0-9]+) [)] \S\s*[;]*"
regex_end="(PLACED|FIXED) [(] ([0-9]+) ([0-9]+) [)] \S [;]"
regex_full="$regex_start""$regex_middle""$regex_end"

## NOTE backslashes in string are properly escaped by readarray
readarray -t lines_sub < <(grep -Pzo "$regex_full" $DEF_sub)

## count parsed pins; cannot go by number of all lines but only by those w/ PLACED|FIX coord lines
pins_sub_parsed=0
for ((i=0; i<${#lines_sub[@]}; i++)); do

	line=${lines_sub[$i]}

	if [[ "$line" =~ $regex_end ]]; then
		pins_sub_parsed=$((pins_sub_parsed + 1))
	fi
done

## extract pin counts from DEF headers
pins_sub_DEF=$(grep -E '(PINS )[0-9]+' $DEF_sub | awk '{print $2}')

## work on original DEF; parsing only required if data file is not present
if ! [[ -e $data_orig ]]; then

	readarray -t lines_orig < <(grep -Pzo "$regex_full" $DEF_orig)

	pins_orig_parsed=0
	for ((i=0; i<${#lines_orig[@]}; i++)); do

		line=${lines_orig[$i]}

		if [[ "$line" =~ $regex_end ]]; then
			pins_orig_parsed=$((pins_orig_parsed + 1))
		fi
	done

	pins_orig_DEF=$(grep -E '(PINS )[0-9]+' $DEF_orig | awk '{print $2}')

	# NOTE store pins_orig_parsed and pins_orig_DEF only later on, not yet; this way, the check for file existence
	# can still be used for process control

# NOTE sourcing all data at this point
else
	source $data_orig
fi

## cross-check pin counts
## NOTE mark mismatch for pin counts across submission and original DEF as error. Any mismatch in parsed versus
## header-stated counts should affect both files in the same way, so would still result in the same numbers; whereas, any
## mismatch in numbers across files hints on some real issues, like comparing different designs with each other.
if [[ $pins_sub_parsed != $pins_sub_DEF ]]; then
	echo "WARNING: For submission DEF, number of parsed pins ($pins_sub_parsed) differs from number specified in DEF ($pins_sub_DEF). This is most likely only due to VDD/VSS pins not parsed here ..." | tee -a $rpt
fi
if [[ $pins_orig_parsed != $pins_orig_DEF ]]; then
	echo "WARNING: For original DEF, number of parsed pins ($pins_orig_parsed) differs from number specified in DEF ($pins_orig_DEF). This is most likely only due to VDD/VSS pins not parsed here ..." | tee -a $rpt
fi
if [[ $pins_sub_parsed != $pins_orig_parsed ]]; then
	echo "ERROR: There is a mismatch in number of parsed pins for the submission DEF ($pins_sub_parsed) versus the original DEF ($pins_orig_parsed)." | tee -a $rpt
fi

## build up arrays for pin coordinates
##

### submission DEF
declare -A coords_x_sub
declare -A coords_y_sub
for ((i=0; i<${#lines_sub[@]}; i++)); do

	line=${lines_sub[$i]}

	if [[ "$line" =~ $regex_start ]]; then
#		declare -p BASH_REMATCH

		# sanity check: net strings should match
		if [[ "${BASH_REMATCH[1]}" != "${BASH_REMATCH[2]}" ]]; then
			echo "ERROR: For submission DEF, string mismatch for net names in the following line: \"$line\""
		fi

		curr_pin=${BASH_REMATCH[1]}
	fi

#	echo $curr_pin
#	echo $line

	if [[ "$line" =~ $regex_end ]]; then
#		declare -p BASH_REMATCH

		coords_x_sub[$curr_pin]=${BASH_REMATCH[2]}
		coords_y_sub[$curr_pin]=${BASH_REMATCH[3]}
	fi
done
#declare -p coords_x_sub
#declare -p coords_y_sub

### original DEF
##
## NOTE parsing only required if data file is not present
if ! [[ -e $data_orig ]]; then
	declare -A coords_x_orig
	declare -A coords_y_orig
	for ((i=0; i<${#lines_orig[@]}; i++)); do

		line=${lines_orig[$i]}

		if [[ "$line" =~ $regex_start ]]; then
#		declare -p BASH_REMATCH

			# sanity check: net strings should match
			if [[ "${BASH_REMATCH[1]}" != "${BASH_REMATCH[2]}" ]]; then
				echo "ERROR: For original DEF, string mismatch for net names in the following line: \"$line\""
			fi

			curr_pin=${BASH_REMATCH[1]}
		fi

#	echo $curr_pin
#	echo $line

		if [[ "$line" =~ $regex_end ]]; then
#		declare -p BASH_REMATCH

			coords_x_orig[$curr_pin]=${BASH_REMATCH[2]}
			coords_y_orig[$curr_pin]=${BASH_REMATCH[3]}
		fi
	done

	# store all results in data file
	echo "pins_orig_parsed=$pins_orig_parsed" >> $data_orig
	echo "pins_orig_DEF=$pins_orig_DEF" >> $data_orig
	array2file coords_x_orig >> $data_orig
	array2file coords_y_orig >> $data_orig

#else, all data was already read in above
fi

# cross-check pin coordinates
#

echo "Cross-check pin coordinates ..."

## NOTE awk is for printing leading zero, which is omitted by bc
die_ratio_x=$(bc -l <<< "scale=$scale; ($die_sub_x / $die_orig_x)" | awk '{printf "%f", $0}')

## NOTE for range of y-coordinates, we allow for the full height of the die, assuming LL corner is (0,0)
## can be pre-computed once, not needed to calculate w/in loop
allowed_y_pin_lower=$(bc -l <<< "scale=$scale; 0" | awk '{printf "%f", $0}')
allowed_y_pin_upper=$(bc -l <<< "scale=$scale; $die_sub_y" | awk '{printf "%f", $0}')

## iterate over pins from original DEF (keys of assoc array)
for curr_pin in "${!coords_x_orig[@]}"; do

	# sanity check if pin is also present in submitted DEF
	## NOTE ``How to Find a Missing Index in an Associative Array''
	## https://www.fosslinux.com/45772/associative-array-bash.htm
	if ! [[ ${coords_x_sub[$curr_pin]+_} ]]; then
		echo "ERROR: The pin \"$curr_pin\" of the original DEF is not present in the submitted DEF." | tee -a $rpt
		continue
	fi

	## NOTE for range of x-coordinates, we allow for the same coordinate but rescaled according to die ratio
	## also consider some margin to avoid mismatches due to rounding
	allowed_x_pin_lower=$(bc -l <<< "scale=$scale; (${coords_x_orig[$curr_pin]} * ($die_ratio_x - $margin))" | awk '{printf "%f", $0}')
	allowed_x_pin_upper=$(bc -l <<< "scale=$scale; (${coords_x_orig[$curr_pin]} * ($die_ratio_x + $margin))" | awk '{printf "%f", $0}')
	if (( $(echo "$allowed_x_pin_lower <= ${coords_x_sub[$curr_pin]}" | bc -l) && $(echo "$allowed_x_pin_upper >= ${coords_x_sub[$curr_pin]}" | bc -l) )); then

		echo "PASS: For pin \"$curr_pin\" in the submitted DEF, the x-coordinate (${coords_x_sub[$curr_pin]}) falls within the allowed range ($allowed_x_pin_lower -- $allowed_x_pin_upper)." | tee -a $rpt
	else
		echo "FAIL: For pin \"$curr_pin\" in the submitted DEF, the x-coordinate (${coords_x_sub[$curr_pin]}) falls out of the allowed range ($allowed_x_pin_lower -- $allowed_x_pin_upper)." | tee -a $rpt
	fi

	## NOTE for range of y-coordinates, we allow for the full height of the die, assuming LL corner is (0,0)
	if (( $(echo "$allowed_y_pin_lower <= ${coords_y_sub[$curr_pin]}" | bc -l) && $(echo "$allowed_y_pin_upper >= ${coords_y_sub[$curr_pin]}" | bc -l) )); then

		echo "PASS: For pin \"$curr_pin\" in the submitted DEF, the y-coordinate (${coords_y_sub[$curr_pin]}) falls within the allowed range ($allowed_y_pin_lower -- $allowed_y_pin_upper)." | tee -a $rpt
	else
		echo "FAIL: For pin \"$curr_pin\" in the submitted DEF, the y-coordinate (${coords_y_sub[$curr_pin]}) falls out of the allowed range ($allowed_y_pin_lower -- $allowed_y_pin_upper)." | tee -a $rpt
	fi
done
