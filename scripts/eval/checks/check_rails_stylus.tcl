##########################################
#
# Script for ISPD'23 contest. Mohammad Eslami and Samuel Pagliarini, TalTech, in collaboration with Johann Knechtel, NYUAD
#
# Script for checking the length of the follow pins and the power stripes on M2 layer
# to be used in stylus version
# Date: 2023.03.22
# ISPD'23 Contest
#
##########################################

set out [open reports/check_stripes.rpt a]
puts $out "Check for power rails "
puts $out "--------------------"

deselect_obj -all

set sub_result ""

select_routes -shape FOLLOWPIN -layer M1
set fol_pins_len [get_db selected .rect.length]
deselect_obj -all

select_routes -shape STRIPE -layer M2
set m2_len [get_db selected .rect.length]
deselect_obj -all


for {set i 0} {$i < [expr [llength $fol_pins_len] - 1]} {incr i} {
  set sub_result [expr [lindex $fol_pins_len $i] - [lindex $m2_len $i] ]
    
     if {$sub_result == 0} {
      set compare "valid"
     } else {
       set compare "false"
	   set nth $i
	   set i [llength $fol_pins_len]
       }
}

deselect_obj -all

# debugging report
if {$compare == false} {
 puts $out "The length of follow pin number $nth is <[lindex $fol_pins_len $nth]> and does not match with the length of the stripe number $nth on M2 layer which is <[lindex $m2_len $nth]>"
 }

puts $out "Final result: $compare" 
puts $out ""

close $out
