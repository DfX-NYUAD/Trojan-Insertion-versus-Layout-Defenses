#!/bin/bash

####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD, in collaboration with Mohammad Eslami and Samuel Pagliarini, TalTech
#
# Helper script to study/debug different ECO modes for Trojan insertion.
#
####

trojan_name="misty_leak_16_5_targeted"
dbg_files="1"

for db_mode in reg adv adv2; do

	sed -i "s/set TI_mode SET_VIA_TI_HELPER_DBG/set TI_mode \"$db_mode\"/g" scripts/TI.tcl

	for TI_mode in reg adv adv2; do

		scripts/TI_init.sh $trojan_name $TI_mode $dbg_files

		innovus -nowin -lic_startup vdi -files scripts/TI.tcl -overwrite -log TI.test."$db_mode"_db_"$TI_mode"_ECO

	done

	sed -i "s/set TI_mode \"$db_mode\"/set TI_mode SET_VIA_TI_HELPER_DBG/g" scripts/TI.tcl

	mv TI.test."$db_mode"_db_* results_"$db_mode"_db/
	mv design."$trojan_name".* results_"$db_mode"_db/
	mv reports/*.{reg,adv,adv2}.* results_"$db_mode"_db/
done
