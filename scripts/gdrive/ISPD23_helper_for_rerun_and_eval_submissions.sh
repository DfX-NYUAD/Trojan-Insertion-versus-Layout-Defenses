#!/bin/bash

# TODO init, eval as main options

dest_root="/data/nyu_projects/ISPD23/data/final/_test/"
source_root="/data/nyu_projects/ISPD23_prod/data/final/"

declare -A best_runs_zip

best_runs_zip[misty_could_not_legalize_91_to_135_inst]="$source_root/NTHU-TCLAB/misty/backup_work/downloads_1677736602.zip"
best_runs_zip[sha256_could_not_legalize_6_inst]="$source_root/NTHU-TCLAB/sha256/backup_work/downloads_1677678658.zip"

# TODO run ranking.sh (production mode, team _production); extract latest best runs from there

#best_runs_zip[aes_1]="/data/nyu_projects/ISPD23_prod/data/alpha/NTHU-TCLAB/aes/backup_work/downloads_1676469396.zip"
#best_runs_zip[aes_2]="/data/nyu_projects/ISPD23_prod/data/alpha/FDEDA/aes/backup_work/downloads_1676058656.zip"
#best_runs_zip[aes_3]="/data/nyu_projects/ISPD23_prod/data/alpha/CUEDA/aes/backup_work/downloads_1676569668.zip"
#best_runs_zip[aes_4]="/data/nyu_projects/ISPD23_prod/data/alpha/XDSecurity-II/aes/backup_work/downloads_1676638139.zip"
#best_runs_zip[camellia_1]="/data/nyu_projects/ISPD23_prod/data/alpha/NTHU-TCLAB/camellia/backup_work/downloads_1676058663.zip"
#best_runs_zip[camellia_2]="/data/nyu_projects/ISPD23_prod/data/alpha/FDEDA/camellia/backup_work/downloads_1676289428.zip"
#best_runs_zip[camellia_3]="/data/nyu_projects/ISPD23_prod/data/alpha/CUEDA/camellia/backup_work/downloads_1676535048.zip"
#best_runs_zip[camellia_4]="/data/nyu_projects/ISPD23_prod/data/alpha/XDSecurity-II/camellia/backup_work/downloads_1676574630.zip"
#best_runs_zip[camellia_base]="/data/nyu_projects/ISPD23/benchmarks/_release/_final/camellia/camellia.zip"
#best_runs_zip[cast_1]="/data/nyu_projects/ISPD23_prod/data/alpha/NTHU-TCLAB/cast/backup_work/downloads_1676483549.zip"
#best_runs_zip[cast_2]="/data/nyu_projects/ISPD23_prod/data/alpha/FDEDA/cast/backup_work/downloads_1676428951.zip"
#best_runs_zip[cast_3]="/data/nyu_projects/ISPD23_prod/data/alpha/CUEDA/cast/backup_work/downloads_1676634862.zip"
#best_runs_zip[cast_4]="/data/nyu_projects/ISPD23_prod/data/alpha/XDSecurity-II/cast/backup_work/downloads_1676625160.zip"
#best_runs_zip[misty_1]="/data/nyu_projects/ISPD23_prod/data/alpha/NTHU-TCLAB/misty/backup_work/downloads_1676481536.zip"
#best_runs_zip[misty_2]="/data/nyu_projects/ISPD23_prod/data/alpha/FDEDA/misty/backup_work/downloads_1676181535.zip"
#best_runs_zip[misty_3]="/data/nyu_projects/ISPD23_prod/data/alpha/CUEDA/misty/backup_work/downloads_1676561274.zip"
#best_runs_zip[misty_4]="/data/nyu_projects/ISPD23_prod/data/alpha/XDSecurity-II/misty/backup_work/downloads_1676563645.zip"
#best_runs_zip[seed_1]="/data/nyu_projects/ISPD23_prod/data/alpha/NTHU-TCLAB/seed/backup_work/downloads_1676058663.zip"
#best_runs_zip[seed_2]="/data/nyu_projects/ISPD23_prod/data/alpha/FDEDA/seed/backup_work/downloads_1676202915.zip"
#best_runs_zip[seed_3]="/data/nyu_projects/ISPD23_prod/data/alpha/CUEDA/seed/backup_work/downloads_1676538817.zip"
#best_runs_zip[seed_4]="/data/nyu_projects/ISPD23_prod/data/alpha/XDSecurity-II/seed/backup_work/downloads_1676565750.zip"
#best_runs_zip[sha256_1]="/data/nyu_projects/ISPD23_prod/data/alpha/NTHU-TCLAB/sha256/backup_work/downloads_1676058668.zip"
#best_runs_zip[sha256_2]="/data/nyu_projects/ISPD23_prod/data/alpha/FDEDA/sha256/backup_work/downloads_1676819179.zip"
#best_runs_zip[sha256_3]="/data/nyu_projects/ISPD23_prod/data/alpha/CUEDA/sha256/backup_work/downloads_1676540336.zip"
#best_runs_zip[sha256_4]="/data/nyu_projects/ISPD23_prod/data/alpha/XDSecurity-II/sha256/backup_work/downloads_1676625433.zip"

## TODO auto-generate from file
#best_runs_zip[aes_1]="/data/nyu_projects/ISPD23/data/final/_test/aes/backup_work/downloads_1676469396.zip"
#best_runs_zip[aes_2]="/data/nyu_projects/ISPD23/data/final/_test/aes/backup_work/downloads_1676058656.zip"
#best_runs_zip[aes_3]="/data/nyu_projects/ISPD23/data/final/_test/aes/backup_work/downloads_1676569668.zip"
#best_runs_zip[aes_4]="/data/nyu_projects/ISPD23/data/final/_test/aes/backup_work/downloads_1676638139.zip"
#best_runs_zip[camellia_1]="/data/nyu_projects/ISPD23/data/final/_test/camellia/backup_work/downloads_1676058663.zip"
#best_runs_zip[camellia_2]="/data/nyu_projects/ISPD23/data/final/_test/camellia/backup_work/downloads_1676289428.zip"
#best_runs_zip[camellia_3]="/data/nyu_projects/ISPD23/data/final/_test/camellia/backup_work/downloads_1676535048.zip"
#best_runs_zip[camellia_4]="/data/nyu_projects/ISPD23/data/final/_test/camellia/backup_work/downloads_1676574630.zip"
#best_runs_zip[cast_1]="/data/nyu_projects/ISPD23/data/final/_test/cast/backup_work/downloads_1676483549.zip"
#best_runs_zip[cast_2]="/data/nyu_projects/ISPD23/data/final/_test/cast/backup_work/downloads_1676428951.zip"
#best_runs_zip[cast_3]="/data/nyu_projects/ISPD23/data/final/_test/cast/backup_work/downloads_1676634862.zip"
#best_runs_zip[cast_4]="/data/nyu_projects/ISPD23/data/final/_test/cast/backup_work/downloads_1676625160.zip"
#best_runs_zip[misty_1]="/data/nyu_projects/ISPD23/data/final/_test/misty/backup_work/downloads_1676481536.zip"
#best_runs_zip[misty_2]="/data/nyu_projects/ISPD23/data/final/_test/misty/backup_work/downloads_1676181535.zip"
#best_runs_zip[misty_3]="/data/nyu_projects/ISPD23/data/final/_test/misty/backup_work/downloads_1676561274.zip"
#best_runs_zip[misty_4]="/data/nyu_projects/ISPD23/data/final/_test/misty/backup_work/downloads_1676563645.zip"
#best_runs_zip[seed_1]="/data/nyu_projects/ISPD23/data/final/_test/seed/backup_work/downloads_1676058663.zip"
#best_runs_zip[seed_2]="/data/nyu_projects/ISPD23/data/final/_test/seed/backup_work/downloads_1676202915.zip"
#best_runs_zip[seed_3]="/data/nyu_projects/ISPD23/data/final/_test/seed/backup_work/downloads_1676538817.zip"
#best_runs_zip[seed_4]="/data/nyu_projects/ISPD23/data/final/_test/seed/backup_work/downloads_1676565750.zip"
#best_runs_zip[sha256_1]="/data/nyu_projects/ISPD23/data/final/_test/sha256/backup_work/downloads_1676058668.zip"
#best_runs_zip[sha256_2]="/data/nyu_projects/ISPD23/data/final/_test/sha256/backup_work/downloads_1676819179.zip"
#best_runs_zip[sha256_3]="/data/nyu_projects/ISPD23/data/final/_test/sha256/backup_work/downloads_1676540336.zip"
#best_runs_zip[sha256_4]="/data/nyu_projects/ISPD23/data/final/_test/sha256/backup_work/downloads_1676625433.zip"

## iterate over keys
for des_run in "${!best_runs_zip[@]}"; do

	file=${best_runs_zip[$des_run]}
	design=${des_run%%_*}
	run_folder=${file%%.*}
	run=${file##*/}
	run=${run%%.*}
	target="$dest_root/$design/downloads/$run"

	echo "Design: $design"
	echo "Run: $run"
	echo "Run folder: $run_folder"
	echo "File: $file"
	echo "Target folder: $target"
	echo
	echo

	## commands to init submission for rerun

	# init folder as expected by daemon to pick up work
	mkdir $target

	# extract submission files into the folder
	unzip -j $file \*/\*.def \*/\*.v -d $target

	# drop all symbolic linked files -- this will keep only the actual submission files, nothing else
	find $target -type l -delete

#	## commands to eval rerun, once done, for errors 
#	## NOTE deprecated
#	#unzip $file "*/TI_*.logv" > /dev/null
#	#ack "ERROR" $run/
#	#rm -r $run
#
##	ls $run_folder/reports/errors.rpt 2> /dev/null
#
#	head -n 25 $run_folder/reports/errors.rpt 2> /dev/null
#	echo
#	echo
#
#	head -n 25 $run_folder/reports/*checkPlace.rpt 2> /dev/null
#	echo
#	echo
#
#	head -n 25 $run_folder/reports/check_design.rpt 2> /dev/null
#	echo
#	echo
#
#	echo
#	echo
done
