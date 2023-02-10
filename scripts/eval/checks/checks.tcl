####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD, in collaboration with Mohammad Eslami and Samuel Pagliarini, TalTech
#
####

####
# general settings
####

set_multi_cpu_usage -local_cpu 24

set_db design_process_node 7
set_db design_tech_node N7

set lef_path "ASAP7/asap7_tech_4x_201209.lef ASAP7/asap7sc7p5t_28_L_4x_220121a.lef ASAP7/asap7sc7p5t_28_SL_4x_220121a.lef"
set def_path design.def
set netlist_path design.v

####
# init
####

read_physical -lefs $lef_path
read_netlist $netlist_path
# preserve shapes/layout as is
read_def $def_path -preserve_shape

init_design

# delete all kinds of fillers (decaps, tap cells, filler cells)
delete_filler -cells [ get_db -u [ get_db insts -if { .is_physical } ] .base_cell.name ]

####
# design checks
####

# covers routing issues like dangling wires, floating metals, open pins, etc.; check *.conn.rpt
# NOTE false positives for dangling VDD, VSS at M1
check_connectivity -error 100000 -warning 100000 -check_wire_loops
mv *.conn.rpt reports/

# covers IO pins; check *.checkPin.rpt
check_pin_assignment
mv *.checkPin.rpt reports/

# covers routing DRCs; check *.geom.rpt
check_drc -limit 100000
mv *.geom.rpt reports/

# covers placement and routing issues
# NOTE false positives for VDD, VSS vias at M4, M5, M6; report file has incomplete info, full details are in check.logv
check_design -type {place route} > reports/check_design.rpt

# custom checks for PDN stripes
set out [open reports/check_stripes.rpt w]
puts $out "PDN stripes checks"
puts $out "=================="
close $out
source scripts/check_stripes_area_stylus.tcl
source scripts/check_stripes_coors_stylus.tcl
source scripts/check_stripes_width_stylus.tcl

####
# security evaluation: 1st order, alpha round
####

# exploitable regions
source scripts/exploitable_regions.tcl

# routing track utilization
# NOTE M1 is skipped (even when explicitly setting "-layer 1:10") because M1 is not made available for routing in lib files
report_route -include_regular_routes -track_utilization > reports/track_utilization.rpt

####
# mark done; exit
####

date > DONE.inv_checks
exit
