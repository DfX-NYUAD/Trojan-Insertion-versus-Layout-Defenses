#!/bin/bash

for res in $(cat OVERALL | grep jk176); do
	echo $res
	file=$(echo ${res::-10})
	cat $file"/checks_summary.rpt"
done | less
