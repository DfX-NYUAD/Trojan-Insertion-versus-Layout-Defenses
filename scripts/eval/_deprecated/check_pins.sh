#!/bin/bash

## settings
#
# files
rpt="check_pins.rpt"
DEF_sub="design.def"
DEF_orig="design_original.def"
# math
scale="6"
margin="0.000001"
threshold="0.1"

#######

# progress bar function
# https://unix.stackexchange.com/a/415450
prog() {
local w=1 p=$1;  shift
# create a string of spaces, then change them to dots
printf -v dots "%*s" "$(( $p * $w ))" ""; dots=${dots// /.};
# print those dots on a fixed-width space plus the percentage etc. 
printf "\r\e[K|%-*s| %3d %% %s" "$w" "$dots" "$p" "$*"; 
}

#######

# init, cleanup
rm $rpt 2> /dev/null

# parse DEF files for dimensions using regex
#
echo "Parse DEF files for dimensions ..."

## DEF example
#DIEAREA ( 0 0 ) ( 134140 128240 ) ;
die_sub_x=$(grep -w 'DIEAREA' $DEF_sub | awk '{print $7}')
die_sub_y=$(grep -w 'DIEAREA' $DEF_sub | awk '{print $8}')
die_orig_x=$(grep -w 'DIEAREA' $DEF_orig | awk '{print $7}')
die_orig_y=$(grep -w 'DIEAREA' $DEF_orig | awk '{print $8}')

## awk for printing leading zero, which is omitted by bc
die_ratio_x=$(bc -l <<< "scale=$scale; ($die_sub_x / $die_orig_x)" | awk '{printf "%f", $0}')
die_ratio_y=$(bc -l <<< "scale=$scale; ($die_sub_y / $die_orig_y)" | awk '{printf "%f", $0}')
die_ratio_x_lower=$(bc -l <<< "scale=$scale; $die_ratio_x - $threshold" | awk '{printf "%f", $0}')
die_ratio_x_upper=$(bc -l <<< "scale=$scale; $die_ratio_x + $threshold" | awk '{printf "%f", $0}')
die_ratio_y_lower=$(bc -l <<< "scale=$scale; $die_ratio_y - $threshold" | awk '{printf "%f", $0}')
die_ratio_y_upper=$(bc -l <<< "scale=$scale; $die_ratio_y + $threshold" | awk '{printf "%f", $0}')

echo "Ratio submission DEF / original DEF for x-coordinates: $die_ratio_x" | tee -a $rpt
echo " Allowed range for ratio for x-coordinates for pins: $die_ratio_x_lower--$die_ratio_x_upper" | tee -a $rpt
echo "Ratio submission DEF / original DEF for y-coordinates: $die_ratio_y" | tee -a $rpt
echo " Allowed range for ratio for y-coordinates for pins: $die_ratio_y_lower--$die_ratio_y_upper" | tee -a $rpt

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
## NOTE this will also capture the VDD/VSS statements -- but, these are ignored here for now, as checks of related pins
## are arguably not important
##regex_end="(PLACED|FIXED) [(] ([0-9]+) ([0-9]+) [)] \S\s*[;]*"
regex_end="(PLACED|FIXED) [(] ([0-9]+) ([0-9]+) [)] \S [;]"
regex_full="$regex_start""$regex_middle""$regex_end"
## NOTE backslashes in string are properly escaped by readarray
readarray -t lines_sub < <(grep -Pzo "$regex_full" $DEF_sub)
readarray -t lines_orig < <(grep -Pzo "$regex_full" $DEF_orig)

## count parsed pins; cannot go by number of all lines but only by those PLACED|FIX coord lines
pins_sub_parsed=0
for ((i=0; i<${#lines_sub[@]}; i++)); do

	line=${lines_sub[$i]}

	if [[ "$line" =~ $regex_end ]]; then
		pins_sub_parsed=$((pins_sub_parsed + 1))
	fi
done
pins_orig_parsed=0
for ((i=0; i<${#lines_orig[@]}; i++)); do

	line=${lines_orig[$i]}

	if [[ "$line" =~ $regex_end ]]; then
		pins_orig_parsed=$((pins_orig_parsed + 1))
	fi
done

pins_sub_DEF=$(grep -E '(PINS )[0-9]+' $DEF_sub | awk '{print $2}')
pins_orig_DEF=$(grep -E '(PINS )[0-9]+' $DEF_orig | awk '{print $2}')

if [[ $pins_sub_parsed != $pins_sub_DEF ]]; then
	echo "WARNING: For submission DEF, number of parsed pins ($pins_sub_parsed) differs from number specified in DEF ($pins_sub_DEF). This is most likely only due to VDD/VSS pins not parsed here ..." | tee -a $rpt
fi
if [[ $pins_orig_parsed != $pins_orig_DEF ]]; then
	echo "WARNING: For original DEF, number of parsed pins ($pins_orig_parsed) differs from number specified in DEF ($pins_orig_DEF). This is most likely only due to VDD/VSS pins not parsed here ..." | tee -a $rpt
fi
if [[ $pins_sub_parsed != $pins_orig_parsed ]]; then
	echo "WARNING: There is a mismatch in number of parsed pins for the submission DEF ($pins_sub_parsed) versus the original DEF ($pins_orig_parsed)." | tee -a $rpt
fi

## build up arrays for of pin coordinates
### submission DEF
declare -A coords_x_sub
declare -A coords_y_sub
for ((i=0; i<${#lines_sub[@]}; i++)); do

	line=${lines_sub[$i]}

	if [[ "$line" =~ $regex_start ]]; then
#		declare -p BASH_REMATCH

		# sanity check: net strings should match
		if [[ "${BASH_REMATCH[1]}" != "${BASH_REMATCH[2]}" ]]; then
			echo "WARNING: For submission DEF, string mismatch for net names in the following line: \"$line\""
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
#
### original DEF
declare -A coords_x_orig
declare -A coords_y_orig
for ((i=0; i<${#lines_orig[@]}; i++)); do

	line=${lines_orig[$i]}

	if [[ "$line" =~ $regex_start ]]; then
#		declare -p BASH_REMATCH

		# sanity check: net strings should match
		if [[ "${BASH_REMATCH[1]}" != "${BASH_REMATCH[2]}" ]]; then
			echo "WARNING: For original DEF, string mismatch for net names in the following line: \"$line\""
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
#declare -p coords_x_orig
#declare -p coords_y_orig

# cross-check pin coordinates
#
echo "Cross-check pin coordinates ..."
## iterate over pins from original DEF (keys of assoc array)
for curr_pin in "${!coords_x_orig[@]}"; do

	# sanity check if pin is also present in submitted DEF
	## NOTE ``How to Find a Missing Index in an Associative Array''
	## https://www.fosslinux.com/45772/associative-array-bash.htm
	if ! [[ ${coords_x_sub[$curr_pin]+_} ]]; then
		echo "WARNING: The pin \"$curr_pin\" of the original DEF is not present in the submitted DEF." | tee -a $rpt
		continue
	fi

	# NOTE here be (little) dragons -- just assume that all four coords_x/y_sub/orig are initialized the moment
	# coords_x_orig is there and the pin is found in both sub and orig DEF; should be fine, as some error would have
	# occurred already above for assignment
	pin_ratio_x=$(bc -l <<< "scale=$scale; (${coords_x_sub[$curr_pin]} + $margin) / (${coords_x_orig[$curr_pin]} + $margin)" | awk '{printf "%f", $0}')
	pin_ratio_y=$(bc -l <<< "scale=$scale; (${coords_y_sub[$curr_pin]} + $margin) / (${coords_y_orig[$curr_pin]} + $margin)" | awk '{printf "%f", $0}')

#	echo "Curr pin: $curr_pin"
#	echo " Ratio x-coords: $pin_ratio_x"
#	echo " Ratio y-coords: $pin_ratio_y"

	x_pin_lower=$(bc -l <<< "scale=$scale; (${coords_x_sub[$curr_pin]} * $die_ratio_x_lower)" | awk '{printf "%f", $0}')
	x_pin_upper=$(bc -l <<< "scale=$scale; (${coords_x_sub[$curr_pin]} * $die_ratio_x_upper)" | awk '{printf "%f", $0}')
	if ! (( $(echo "$die_ratio_x_lower <= $pin_ratio_x" | bc -l) && $(echo "$die_ratio_x_upper >= $pin_ratio_x" | bc -l) )); then

		echo "FAIL: For pin \"$curr_pin\" in the submitted DEF, the x-coordinate (${coords_x_sub[$curr_pin]}) falls out of the allowed range ($x_pin_lower--$x_pin_upper)." | tee -a $rpt
	else
		echo "PASS: For pin \"$curr_pin\" in the submitted DEF, the x-coordinate (${coords_x_sub[$curr_pin]}) falls within the allowed range ($x_pin_lower--$x_pin_upper)." | tee -a $rpt
	fi

	y_pin_lower=$(bc -l <<< "scale=$scale; (${coords_y_sub[$curr_pin]} * $die_ratio_y_lower)" | awk '{printf "%f", $0}')
	y_pin_upper=$(bc -l <<< "scale=$scale; (${coords_y_sub[$curr_pin]} * $die_ratio_y_upper)" | awk '{printf "%f", $0}')
	if ! (( $(echo "$die_ratio_y_lower <= $pin_ratio_y" | bc -l) && $(echo "$die_ratio_y_upper >= $pin_ratio_y" | bc -l) )); then

		echo "FAIL: For pin \"$curr_pin\" in the submitted DEF, the y-coordinate (${coords_y_sub[$curr_pin]}) falls out of the allowed range ($y_pin_lower--$y_pin_upper)." | tee -a $rpt
	else
		echo "PASS: For pin \"$curr_pin\" in the submitted DEF, the y-coordinate (${coords_y_sub[$curr_pin]}) falls within the allowed range ($y_pin_lower--$y_pin_upper)." | tee -a $rpt
	fi
done
