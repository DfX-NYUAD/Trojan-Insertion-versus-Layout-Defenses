##########################################
#
# Script for ISPD'23 contest. Mohammad Eslami and Samuel Pagliarini, TalTech, in collaboration with Johann Knechtel, NYUAD
#
# Script for checking the power stripes based on coordinates
# to be used in stylus version
# Date: 2022.12.28
# ISPD'23 Contest
#
##########################################

set out [open reports/check_PDN.rpt a]
puts $out "Check by coordinates"
puts $out "--------------------"

deselect_obj -all

# power net names
set p_names {VDD VSS}

set c_flag "valid"

# the loop strats from M2 layer and continue checking until M9
for {set j 2} {$j < 10} {incr j} {

 set coors  ""
 set sub_result ""
 set refrence ""

# a loop for selecting VDD and VSS for each metal layer 
 for {set k 0} {$k < 2} {incr k} {
select_routes -nets [lindex $p_names $k] -shapes stripe -layer M$j
# the stripes on the even layers are horizontal while the rest are vertical
 if {[expr $j / 2] == 0} {
# if the stripe is horizontal, we capture the lly coordinates of the stripes
  set coors [get_db selected .rect.ll.y]
  } else {
# if the stripe is vertical, we capture the llx coordinates of the stripes
   set coors [get_db selected .rect.ll.x]
   }

 set coors [lsort -dictionary $coors]
 for {set i 0} {$i < [expr [llength $coors] - 1]} {incr i} {
  set sub_result [expr [lindex $coors [ expr $i + 1]] - [lindex $coors $i] ]
     if {$i == 0} {
      set refrence [expr int($sub_result)]
     }
# here we compare the integer part for each coordinate pair to measure the distance
     if {[expr int($sub_result)] == $refrence} {
      set compare "valid"
     } else {
       set compare "false"
       set c_flag "false"
	   puts " [expr int($sub_result)] != $refrence"
   	  }
 }
 deselect_obj -all
# detailed report 
 puts $out "M$j ---- [lindex $p_names $k]  ---> $compare ---- $c_flag"
 }
}

puts $out "Final result: $c_flag" 
puts $out ""

close $out
