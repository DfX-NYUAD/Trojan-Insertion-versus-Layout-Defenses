####
# settings
####
set_multi_cpu_usage -local_cpu 8
set_db design_process_node 7
set_db design_tech_node N7

set lef_path "asap7_tech_4x_201209.lef asap7sc7p5t_28_L_4x_220121a.lef asap7sc7p5t_28_R_4x_220121a.lef asap7sc7p5t_28_SL_4x_220121a.lef"
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
#check_tracks > check_tracks.rpt

####
# mark done; exit
####
date > DONE.check
exit
