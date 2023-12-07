//////
//
// Script for ISPD'23 contest. Johann Knechtel, NYUAD, in collaboration with Mohammad Eslami and Samuel Pagliarini, TalTech
//
// Template derived from "Sample Dofile" from "Conformal Equivalence Checking User Guide"
//
//////

// setup
set parallel option -threads 16

// just load all available lib and lef files
read library -both -liberty ASAP7/*.lib 
read lef file ASAP7/*.lef

read design -golden design_original.v
read design -revised design.v

// Enter LEC mode but w/o auto mapping
set system mode lec -nomap

// To specify pipeline retiming, requires Conformal XL license
analyze retiming

// Map key points automatically
map key points

// Analyzes the netlists and sets up the flattened design for accurate comparison
analyze setup

// To specify datapath analysis, requires Conformal XL license
analyze datapath -merge

// To run comparison
add compare point -all
compare

// reports
report floating signals > reports/floating_signals.rpt
report verification > reports/check_equivalence.rpt
echo >> reports/check_equivalence.rpt
report statistics >> reports/check_equivalence.rpt
echo >> reports/check_equivalence.rpt
report unmapped points >> reports/check_equivalence.rpt
echo >> reports/check_equivalence.rpt
report compare data >> reports/check_equivalence.rpt
// NOTE redundant but helps for internal parsing
report unmapped points > reports/check_equivalence.rpt.unmapped

// mark done; exit
date > DONE.lec_checks
exit -force
