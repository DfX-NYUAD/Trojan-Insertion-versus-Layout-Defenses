#!/bin/bash

## simple wrapper for parallel processing

innovus -files probing_cells.tcl -log probing_cells &
echo $! > PID_dfx_cells                                                                                                                                                                                                                
innovus -files probing_nets.tcl -log probing_nets &
echo $! > PID_dfx_nets
wait

./post_process_probing_cells.sh &
./post_process_probing_nets.sh &
wait

zip probing.zip *_ea.rpt* probing_*.cmd probing_*.log*

date > DONE_dfx
