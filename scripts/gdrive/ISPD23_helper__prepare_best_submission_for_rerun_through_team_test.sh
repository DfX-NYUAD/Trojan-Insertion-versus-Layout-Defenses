#!/bin/bash

dest_root="/data/nyu_projects/ISPD23/data/final/_test/"

# TODO run ranking.sh (production mode, team _production); extract from output

declare -A best_runs_zip

#best_runs_zip[aes_1]="/data/nyu_projects/ISPD23_prod/data/alpha/NTHU-TCLAB/aes/backup_work/downloads_1676469396.zip"
#best_runs_zip[aes_2]="/data/nyu_projects/ISPD23_prod/data/alpha/FDEDA/aes/backup_work/downloads_1676058656.zip"
#best_runs_zip[aes_3]="/data/nyu_projects/ISPD23_prod/data/alpha/CUEDA/aes/backup_work/downloads_1676569668.zip"
best_runs_zip[aes_4]="/data/nyu_projects/ISPD23_prod/data/alpha/XDSecurity-II/aes/backup_work/downloads_1676638139.zip"
#best_runs_zip[camellia_1]="/data/nyu_projects/ISPD23_prod/data/alpha/NTHU-TCLAB/camellia/backup_work/downloads_1676058663.zip"
#best_runs_zip[camellia_2]="/data/nyu_projects/ISPD23_prod/data/alpha/FDEDA/camellia/backup_work/downloads_1676289428.zip"
#best_runs_zip[camellia_3]="/data/nyu_projects/ISPD23_prod/data/alpha/CUEDA/camellia/backup_work/downloads_1676535048.zip"
#best_runs_zip[camellia_4]="/data/nyu_projects/ISPD23_prod/data/alpha/XDSecurity-II/camellia/backup_work/downloads_1676574630.zip"
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

## iterate over keys
for des_run in "${!best_runs_zip[@]}"; do

	file=${best_runs_zip[$des_run]}
	design=${des_run%%_*}
	folder=${file##*/}
	folder=${folder%%.*}

#	echo $file
#	echo $design
#	echo $folder

	# generate folder as expected by daemon
	target="$dest_root/$design/downloads/$folder"
	mkdir $target

	# extract submission files into the folder
	unzip -j $file */*.def */*.v -d $target

	# drop all symbolic linked files -- this will keep only the actual submission files, nothing else
	find $target -type l -delete
done
