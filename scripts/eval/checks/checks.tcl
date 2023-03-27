####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD, in collaboration with Mohammad Eslami and Samuel Pagliarini, TalTech
#
# Script to perform design checks on the submission files (design.def, design.v).
#
####

####
# general settings
####

set_multi_cpu_usage -local_cpu 8 -keep_license true

set_db design_process_node 7
set_db design_tech_node N7

set lef_path "ASAP7/asap7_tech_4x_201209.lef ASAP7/asap7sc7p5t_28_L_4x_220121a.lef ASAP7/asap7sc7p5t_28_SL_4x_220121a.lef"
set def_path design.def
set netlist_path design.v

####
# init
####

source design_name.tcl

read_physical -lefs $lef_path
read_netlist $netlist_path
# preserve shapes/layout as is
read_def $def_path -preserve_shape

init_design

# delete all kinds of fillers (decaps, tap cells, filler cells, metal fills)
delete_filler -cells [ get_db -u [ get_db insts -if { .is_physical } ] .base_cell.name ]
delete_metal_fill

####
# design checks
####

# covers routing issues like dangling wires, floating metals, open pins, etc.; check $design_name.conn.rpt
# NOTE false positives for dangling VDD, VSS at M1
# NOTE also captures dangling wires, if any, of unplaced insts; if there are no related wires it probably won't flag those unplaced insts
check_connectivity -error 100000 -warning 100000 -check_wire_loops
mv $design_name.conn.rpt reports/

# covers IO pins; check $design_name.checkPin.rpt
check_pin_assignment
mv $design_name.checkPin.rpt reports/

# covers routing DRCs; check $design_name.geom.*.rpt
# NOTE also captures min area violation of wires, if any, for unplaced insts; if there are no related wires it probably won't flag those unplaced insts
set_db check_drc_limit 100000
check_drc -layer_range {2 10} -out_file $design_name.geom.layers_2_to_10__all.rpt
# NOTE exclude MAR on M1 as there can be false positives
set_db check_drc_disable_rules min_area
check_drc -layer_range {1} -out_file $design_name.geom.layer_1__excl_MAR.rpt
mv $design_name.geom.*.rpt reports/

# covers placement and routing issues
# NOTE false positives for VDD, VSS vias at M4, M5, M6; report file has incomplete info, full details are in check.logv
# NOTE covers unplaced insts
check_design -type {place route} > reports/check_design.rpt

# covers more placement issues
check_place reports/check_place.rpt

# custom checks for PDN mesh
set out [open reports/check_PDN.rpt w]
puts $out "PDN mesh checks"
puts $out "==============="
close $out
source scripts/check_stripes_area_stylus.tcl
source scripts/check_stripes_coors_stylus.tcl
source scripts/check_stripes_width_stylus.tcl
source scripts/check_stripes_set2set_stylus.tcl
source scripts/check_rails_stylus.tcl

####
# security evaluation
####

# exploitable regions
# NOTE covers unplaced insts most robust, as in triggering an error in logv (via segmentation violation in the binary)
source scripts/exploitable_regions.tcl

# routing track utilization
# NOTE M1 is skipped (even when explicitly setting "-layer 1:10") because M1 is not made available for routing in lib files
report_route -include_regular_routes -track_utilization > reports/track_utilization.rpt

####
# mark done; exit
####

date > DONE.inv_checks
exit
