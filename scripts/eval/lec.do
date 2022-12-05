//// lec_64 -nogui -xl -dofile lec.do
////
//// template derived from "Sample Dofile" from "Conformal Equivalence Checking User Guide"

// setup
set parallel option -threads 16

// just load all available lib and lef files
read library -both -liberty ASAP7/*.lib 
read lef file ASAP7/*.lef

read design -golden _design_original.v
read design -revised design.v

// Enter LEC mode but w/o auto mapping
set system mode lec -nomap

// To specify pipeline retiming, requires Conformal XL license
analyze retiming

// Map key points automatically
map key points

// NOTE on comparing of assets
//
// Option: after auto-map, add assets explicitly as points -- but, works only for DFFs for cell assets, not
//  combinational ones.	And, DFFs are already added automatically, at least for those layouts I've tried; not sure
//  about larger layouts where some DFFs might be skipped?
//
// Conclusion: not so useful, requires handling of assets from files (also see below on notation), and not really
//  needed in any case -- the subsequent evaluation (probing, exploit_regions scripts) will error out if some assets
//  are not there in the design -- however, mere presence of assets doesn't mean there's no cheating. Thus, the best
//  we can do, it seems, is to rely on LEC here to capture at least any mismatches in DFFs.
//
// Example command for adding points:
//  add mapped points REG REG -type DFF DFF // can also be done for PIs, POs, etc.
//  add mapped points -net NET NET // will also just extract DFFs connected by the net
//
// Points can also be read in batch mode, using "read mapped points FILE"
//
// Notation:
//  key_reg_reg\[0\]\[0\] -- notation in assets files
//  \key_reg_reg[0][0] -- notation in verilog
//  key_reg_reg[0][0] -- notation accepted by LEC
// Conclusion: need to interpret strings to get rid of escaping special chars
//
// Take-away: not done for now, but might be good to just add (most likely redundantly, but not sure) all DFF assets
//  as points -- only DFFs, other gates will error out -- as well as net assets as points, via batch mode, and via
//  additional map files generated from assets files by bash taking care of i) interpretation of strings to rid
//  escaping special chars and ii) for cell assets, adding only DFFs.

// Analyzes the netlists and sets up the flattened design for accurate comparison
analyze setup

// To specify datapath analysis, requires Conformal XL license
analyze datapath -merge

// To run comparison
add compare point -all
compare

// reports
report verification > check_equivalence.rpt
echo >> check_equivalence.rpt
report statistics >> check_equivalence.rpt
echo >> check_equivalence.rpt
report unmapped points >> check_equivalence.rpt
echo >> check_equivalence.rpt
report compare data >> check_equivalence.rpt
// NOTE redundant report but helps for parsing
report unmapped points >> check_equivalence.rpt.unmapped

// mark done; exit
date > DONE.lec
exit -force
