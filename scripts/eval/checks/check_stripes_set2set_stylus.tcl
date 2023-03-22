##########################################
#
# Script for ISPD'23 contest. Mohammad Eslami and Samuel Pagliarini, TalTech, in collaboration with Johann Knechtel, NYUAD
#
# Script for checking the set2set distance of power stripes based on coordinates
# to be used in stylus version
# Date: 2023.03.21
# ISPD'23 Contest
#
##########################################


set out [open reports/check_set2set.rpt a]
puts $out "Check for set2set "
puts $out "--------------------"


deselect_obj -all
set c_flag "valid"

# power net names
set p_names {VDD VSS}

# the loop strats from M3 layer and continue checking until M4
for {set j 3} {$j < 5} {incr j} {

 set coors  ""
 set sub_result ""
 set refrence ""

# a loop for selecting VDD and VSS for each metal layer 
 for {set k 0} {$k < 2} {incr k} {
select_routes -nets [lindex $p_names $k] -shapes stripe -layer M$j
# the stripes on the even layers are horizontal while the rest are vertical
 if {$j == 4} {
# if the stripe is horizontal, we capture the lly coordinates of the stripes
  set coors [get_db selected .rect.ll.y]
  } else {
# if the stripe is vertical, we capture the llx coordinates of the stripes
   set coors [get_db selected .rect.ll.x]
   }

 set coors [lsort -dictionary $coors]
 for {set i 0} {$i < [expr [llength $coors] - 1]} {incr i} {
  set sub_result [expr [lindex $coors [ expr $i + 1]] - [lindex $coors $i] ]
    

     if { ($sub_result < 13 && $j == 3) || ($sub_result < 22 && $j == 4)} {
      set compare "valid"
     } else {
       set compare "false"
	   set c_flag "false"
       }
 }
 deselect_obj -all
# debugging report 
  puts $out "M$j ---- [lindex $p_names $k]  ---> $compare"
 } 
}

puts $out "Final result: $c_flag" 
puts $out ""

puts $c_flag
close $out
