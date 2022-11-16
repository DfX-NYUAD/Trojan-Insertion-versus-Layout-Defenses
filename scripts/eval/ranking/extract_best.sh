#!/bin/bash

root_folder=~/ISPD22/data
round=final
root_folder_dfx=dfx:/home/jk176/ISPD22/data/final/__best/

best_folder="best_$(date +%s)"

mkdir $best_folder
cd $best_folder

mkdir reports

echo "Generating reports ..."
date
for metric in OVERALL des; do
#for metric in des_issues OVERALL des_perf des des_area fsp_fi_ea_n ti_sts fsp_fi_ea_c ti_fts fsp_fi ti des_p_total; do
	(../ranking.sh $metric 1 1 1 1 | column -t > reports/$metric) &
done
wait
echo "Done"
date

echo "Print OVERALL report ..."
pattern=""
for team in $(ls $root_folder/$round); do
	for des in $(ls $root_folder/$round/$team); do

		pattern=$pattern" -e $des"
	done

	break
done
cat reports/OVERALL | grep -e "Benchmark" $pattern | grep -v "scores.rpt"

echo "Print des report ..."
pattern=""
for team in $(ls $root_folder/$round); do
	for des in $(ls $root_folder/$round/$team); do

		pattern=$pattern" -e $des"
	done

	break
done
cat reports/des | grep -e "Benchmark" $pattern | grep -v "scores.rpt"

echo "Extracting ZIP files ..."
date
for team in $(ls $root_folder/$round); do

	mkdir $team

	for des in $(ls $root_folder/$round/$team); do

		mkdir $team/$des

		best=$(grep "$team/$des" reports/des)
		zip_file=$(echo ${best%*/scores.rpt}".zip")

		cp $zip_file $team/$des/ 2> /dev/null
	done
done
echo "Done"
date

cd - > /dev/null

read -p "Copy to dfx? 0/1: " copy

if [[ $copy == 1 ]]; then

	echo "Copying ..."
	date

#	# NOTE drop comment-out if blind benchmarks should not be copied again
#	rm -r $best_folder/*/openMSP430_2
#	rm -r $best_folder/*/SPARX

	scp -r $best_folder $root_folder_dfx

	echo "Done"
	date
fi
