####
# settings
####
set_multi_cpu_usage -local_cpu 8
#TODO update to 7, also set both process and node
set_db design_process_node 45

set lef_path NangateOpenCellLibrary.lef
set def_path design.def
set netlist_path design.v

####
# init
####
read_physical -lefs $lef_path
read_netlist $netlist_path
read_def $def_path -preserve_shape

init_design

####
# checks w/ rpt files auto-generated
####
# NOTE covers routing issues like dangling wires, floating metals, open pins, etc.; check *.conn.rpt for "IMPVFC", "Net"
# NOTE does NOT flag cells not connected or routed at all -- those are caught by LEC, flagged as "Unreachable" points
check_connectivity
# NOTE covers IO pins; check *.checkPin.rpt for "ERROR" as well as for "Illegal*", "Unplaced"
check_pin_assignment
# NOTE covers DRC for routing; check *.geom.rpt for "Total Violations"
check_drc
# NOTE standard limit of 1,000 violations is good enough to flag invalid layouts
#check_drc -limit 99999

####
# checks w/o rpt files auto-generated
####
# NOTE covers placement and routing issues
check_design -type route > check_route.rpt

## NOTE errors out; probably not needed anyway as long as other checks here and later on check_DRC is done
## TODO check again for ASAP7
#check_tracks > check_tracks.rpt

####
# mark done; exit
####
date > DONE.check
exit
