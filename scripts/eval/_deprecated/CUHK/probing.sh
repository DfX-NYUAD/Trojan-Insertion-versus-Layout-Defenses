#!/bin/bash

## simple wrapper

innovus_bin=$1
benchmark=$2

# subshell w/ same PID as process; simplifies killing process if needed
sh -c 'echo $$ > PID.summarize_assets; exec '$(echo $innovus_bin)' -stylus -files summarize_assets.tcl -log summarize_assets > /dev/null 2>&1'
./probing_eval --bm_name $benchmark --cell_file cells_summary.rpt --net_file nets_summary.rpt > probing_eval.log

mv nets_summary.rpt nets_summary.rpt.back
mv cells_summary.rpt cells_summary.rpt.back

mv $benchmark'_nets_ea.rpt' 'nets_ea.rpt'
mv $benchmark'_cells_ea.rpt' 'cells_ea.rpt'

date > DONE.probing
