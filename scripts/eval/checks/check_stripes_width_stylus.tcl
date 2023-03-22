##########################################
#
# Script for ISPD'23 contest. Mohammad Eslami and Samuel Pagliarini, TalTech, in collaboration with Johann Knechtel, NYUAD
#
# Script for checking the power stripes based on box width
# to be used in stylus version
# Date: 2022.12.29
# ISPD'23 Contest
#
##########################################

set out [open reports/check_stripes.rpt a]
puts $out "Check by box width"
puts $out "------------------"

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

  set stripe_wid [get_db selected .rect.width]

  for {set i 0} {$i < [expr [llength $stripe_wid] - 1]} {incr i} {
    if {$i == 0} {
     set refrence [lindex $stripe_wid $i]
    }
    if {($refrence) == [lindex $stripe_wid [ expr $i + 1]]} {
     set compare "valid"
    } else {
      set compare "false"
	  set c_flag "false"
      }
    }
	 deselect_obj -all
# detailed report 
  puts $out "M$j ---- [lindex $p_names $k]  ---> $compare"
 } 
}

puts $out "Final result: $c_flag" 
puts $out ""

close $out
