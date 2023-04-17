#!/bin/bash

for file in ../../final.*/*/*/backup_work/*.zip; do

	file_=${file#*/}
	file_=${file_#*/}
	file_=${file_#*/}

	ls $file
	ls ../../final/$file_ 2> /dev/null
done
