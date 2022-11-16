#!/bin/bash

#######

src="cells_ea.rpt"
bk="cells_ea.rpt.back"
scale=6

DEF="design.def"
LEF="NangateOpenCellLibrary.lef"
ca="cells.assets"

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

echo "Initializing cell assets ..."

# read cell assets into array
readarray -t ca_ < $ca
#declare -p ca_

# declare another, associative array; fast to access later on
declare -A ca__
for line in "${ca_[@]}"; do
	# simple array; actually only indices matter actually, dummy value of 1 to indicate is asset; other non-assets
	# cells are identified as such by absence of related index in array
	ca__[$line]=1
done

echo "Initializing LEF macros ..."

# init array of macro sizes from LEF; copied directly from gnuplot_exploit_regions.sh
#
declare -A cell_width=()
macro_size="UNDEF"
macro_name="UNDEF"

# go line by line, split lines into array
#
while read -a line; do

	# substring matching for pattern in line; ignore other lines
	if [[ "${line[0]}" == "MACRO" ]]; then

		macro_name=${line[1]}
		# reset macro_size; helps to memorize only 1st SIZE that follows, not others; works together w/ lines below
		macro_size="UNDEF"

	# double-check; for first few lines w/o any macro parsed yet, ignore SIZE lines
	elif [[ "$macro_name" != "UNDEF" && "${line[0]}" == "SIZE" ]]; then 

		macro_size=${line[1]}
	fi

	if [[ "$macro_size" != "UNDEF" ]]; then
#		echo "$macro_name: $macro_size"

		cell_width[$macro_name]=$macro_size

		# reset macro again; helps to repeat assignments as well as catching another SIZE statement before
		# next macro begins
		macro_name="UNDEF"
		macro_size="UNDEF"
	fi

done < $LEF

# NOTE here be dragons (little ones though): expects size of rows to come first in LEF; but, would still work in case
# there are only single-row cells, which is true for Nangate
core_row_height=$(grep -w 'SIZE' $LEF | head -n 1 | awk '{print $4}')

echo "Initializing DEF cells ..."

## DEF
#

declare -A cell_area=()

# NOTE '-' in front
#- key_sbox\/U20 OAI221_X1 + PLACED ( 61180 16520 ) FN
#- CTS_ccl_BUF_CRYPTOCLK_G0_L1_6 CLKBUF_X3 + FIXED ( 52440 66920 ) N + WEIGHT 1
#- FE_OFC9_n581 BUF_X16 + SOURCE TIMING + PLACED ( 50920 75320 ) FS 
regex_line_DEF="^- (\S+) (\S+).+[+] (PLACED|FIXED).[(] ([0-9]+) ([0-9]+) [)].+"

# pre-filter DEF parsing; speeds up loop below
readarray -t DEF_ < <(grep -E "$regex_line_DEF" $DEF)

lines_size=${#DEF_[@]}
for ((i=0; i<$lines_size; i++)); do

	# progress bar
	prog $(( 100 * (i+1)/lines_size ))

	line=${DEF_[$i]}

	if [[ "$line" =~ $regex_line_DEF ]]; then

#		declare -p BASH_REMATCH

		cell_name=${BASH_REMATCH[1]}
		cell_macro=${BASH_REMATCH[2]}

		# only process those components which are an asset
		# NOTE ``How to Find a Missing Index in an Associative Array''
		# https://www.fosslinux.com/45772/associative-array-bash.htm
		if [ ${ca__[$cell_name]+_} ]; then

			cell_width_=${cell_width[$cell_macro]}
			cell_area[$cell_name]=$(bc -l <<< "($cell_width_ * $core_row_height)")

#			echo "PARSED ASSET CELL: $cell_name - $cell_macro - ${cell_area[$cell_name]}"
		fi
	fi
done
# final newline for progressbar
echo "" 

# backup and clear orig file
mv $src $bk

echo "Obtaining stats ..."

# obtain stats first; going over all inst
#
expos_max=0
expos_total=0
expos_area_total=0
expos_count=0

#INSTANCE		AREA		EXPOSED AREA		PERC EXPOSED
#Instance: key_reg_reg\[7\]\[9\]  angle  : 0  side : N  Area_Exposed: 1.44 Perc_Exposed: 1.2030075188
regex_line_rpt="(Instance: )(\S+)(\s+angle.+)(Exposed: )([0-9]+[.][0-9]+)"

declare -A cell_ea=()
declare -A cell_ea_perc=()
readarray -t bk_ < $bk

lines_size=${#bk_[@]}
for ((i=0; i<$lines_size; i++)); do

	# progress bar
	prog $(( 100 * (i+1)/lines_size ))

	line=${bk_[$i]}

	if [[ "$line" =~ $regex_line_rpt ]]; then

		# https://serverfault.com/a/660888
#		declare -p BASH_REMATCH

		((expos_count = expos_count + 1))

		cell_name=${BASH_REMATCH[2]}
		cell_ea_perc[$cell_name]=${BASH_REMATCH[5]}

		# NOTE for small cells and/or relatively low evaluation accuracy, we may see percentage > 100;
		# limit those cases to 100
		if [[ $(bc -l <<< "${cell_ea_perc[$cell_name]} > 100") -eq 1 ]]; then

			cell_ea_perc[$cell_name]=100
		fi

		# update max
		if [[ $(bc -l <<< "${cell_ea_perc[$cell_name]} > $expos_max") -eq 1 ]]; then

			expos_max=${cell_ea_perc[$cell_name]}
		fi

		expos_total=$(bc -l <<< "scale=$scale; ($expos_total + ${cell_ea_perc[$cell_name]})")
		cell_ea[$cell_name]=$(bc -l <<< "scale=$scale; (${cell_area[$cell_name]} * (${cell_ea_perc[$cell_name]} / 100))")
		expos_area_total=$(bc -l <<< "scale=$scale; ($expos_area_total + ${cell_ea[$cell_name]})")

#		echo "EA FOR ASSET CELL: $cell_name - ${cell_area[$cell_name]} - ${cell_ea_perc[$cell_name]} - ${cell_ea[$cell_name]}"
#		echo "EA TOTAL: $expos_area_total"
	fi
done

# final newline for progressbar
echo "" 

expos_avg=$(bc -l <<< "scale=$scale; ($expos_total / $expos_count)")

echo "Total exposed area across cell assets: $expos_area_total" >> $src
echo "Max exposure [%] across cell assets: $expos_max" >> $src
echo "Avg exposure [%] across cell assets: $expos_avg" >> $src
echo "" >> $src


echo "Write back rpt file ..."

# print back inst second
#
for ((i=0; i<${#bk_[@]}; i++)); do

	line=${bk_[$i]}

	#Instance: key_reg_reg\[7\]\[9\]  angle  : 0  side : N  Area_Exposed: 1.44 Perc_Exposed: 1.2030075188
	if [[ "$line" =~ $regex_line_rpt ]]; then

		cell_name=${BASH_REMATCH[2]}

		# TODO generalize for other angles and sides
		echo "Instance: $cell_name angle: 0 side: N Area_Exposed: ${cell_ea[$cell_name]} Perc_Exposed: ${cell_ea_perc[$cell_name]}" >> $src
	fi
done
