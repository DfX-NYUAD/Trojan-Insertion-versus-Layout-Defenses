#!/bin/bash

for run in data/nyu_projects/ISPD23_prod/data/final/*/*/backup_work/*.zip; do

	dir=${run%/*}
	zip=${run##*/}

	cd $dir
	pwd
	echo $zip

	## actual unzip operation; overwrite any existing files w/o prompt/query
	unzip -o $zip

	## re-link all scripts away from 'ISPD23_prod', towards 'ISPD23' -- helpful in case some re-runs should be done on 'test' dir scripts, not affecting any 'prod' dir scripts
	for script in $(find downloads_*/scripts -type l); do

		ln_orig_dst=$(ls -l $script | awk '{print $NF}')
		ln_new_dst=$(echo $ln_orig_dst | sed 's/ISPD23_prod/ISPD23/g')

		ln -sf $ln_new_dst downloads_*/scripts/
	done

	cd - > /dev/null
	
	echo
	echo
done
