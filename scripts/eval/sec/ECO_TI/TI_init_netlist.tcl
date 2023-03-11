#!/usr/bin/tclsh

####
#
# Script for ISPD'23 contest. Mohammad Eslami and Samuel Pagliarini, TalTech, in collaboration with Johann Knechtel, NYUAD
#
# Script to insert Trojan logic into netlists.
#
####

#####################
# init
#####################

## source dynamic config file; generated through the TI_init.sh helper script
#
source scripts/TI_settings.tcl

## source other settings
#
source benchmark_name.tcl

#####################
# main body
#####################


if {$benchmark == "aes"} {
set mod_keyword "module aes_128 ("
} elseif { $benchmark == "camellia" } {
set mod_keyword "module Camellia ("
} elseif { $benchmark == "cast" } {
set mod_keyword "module CAST128_key_scheduler ("
} elseif { $benchmark == "misty" } {
set mod_keyword "module top ("
} elseif { $benchmark == "seed" } {
set mod_keyword "module SEED ("
} elseif { $benchmark == "sha256" } {
set mod_keyword "module sha256 ("
} else {
puts "ERROR! Please set the benchmark variable from the list"
}


 proc listFromFile {filename} {
     set read_text [open $filename r]
     set data [split [string trim [read $read_text]] "\n" ]
     close $read_text
     return $data
 }
set list_of_nets [listFromFile $netlist_for_trojan_insertion]

set file_len [llength $list_of_nets]
set mod_keeper ""
set endmod_keeper ""

for {set i 0} {$i < $file_len } {incr i} {
     set x [lindex $list_of_nets $i]
     if {$x == $mod_keyword} {
    #  puts "$i $x"
      set start_idx $i
	  }
	  }
	  
for {set i $start_idx} {$i < $file_len } {incr i} {
     set x [lindex $list_of_nets $i]
     if {$x == "endmodule"} {
     # puts "$i $x"
      set end_idx $i
	  #	puts [lindex $list_of_nets $i]

	  set i $file_len
	  }
	}
	
	# puts [lindex $list_of_nets $i]
for {set i $start_idx} {$i < $file_len } {incr i} {
     set x [lindex $list_of_nets $i]
     if {$x == "   // Internal wires"} {
    #  puts "$i $x"
      set wire_idx $i
	  set i $file_len
	  }
	}
	

#=========================================== AES128 ===========================================

	
#================Process starts for burn_targeted Trojan insertion ======================
	
	if {$trojan_name == "aes_burn_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx

			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
	
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]
		set lines [linsert $lines $wire_idx "wire reset_n;" ]


		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 

#================Process starts for fault_targeted Trojan insertion ======================
	
	} elseif {$trojan_name == "aes_fault_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx
		
		set org_targ_node0 "k5\[41\]"
		set org_targ_node1 "k5\[79\]"
		set org_targ_node2 "k5\[125\]"
		set org_targ_node3 "k5\[40\]"
		set org_targ_node4 "k5\[76\]"
		
		for {set m $start_idx} {$m < $end_idx} {incr m} {
			set cur_line [lindex $lines $m]
			if {[string first ".A($org_targ_node0)" $cur_line ] != -1 || [string first ".A1($org_targ_node0)" $cur_line ] != -1 || [string first ".A2($org_targ_node0)" $cur_line ] != -1 || [string first ".B($org_targ_node0)" $cur_line ] != -1 || [string first ".B1($org_targ_node0)" $cur_line ] != -1 || [string first ".B2($org_targ_node0)" $cur_line ] != -1 || [string first ".C($org_targ_node0)" $cur_line ] != -1 || [string first ".CI($org_targ_node0)" $cur_line ] != -1 || [string first ".C1($org_targ_node0)" $cur_line ] != -1 || [string first ".C2($org_targ_node0)" $cur_line ] != -1 || [string first ".D($org_targ_node0)" $cur_line ] != -1 || [string first ".D1($org_targ_node0)" $cur_line ] != -1 || [string first ".D2($org_targ_node0)" $cur_line ] != -1} {
			# puts $cur_line 
			set lines [lreplace $lines $m $m [regsub -all {k5\[41\]} [lindex $lines $m] htnet0 ] ]
			# puts [lindex $lines $m]
			} elseif {[string first ".A($org_targ_node1)" $cur_line ] != -1 || [string first ".A1($org_targ_node1)" $cur_line ] != -1 || [string first ".A2($org_targ_node1)" $cur_line ] != -1 || [string first ".B($org_targ_node1)" $cur_line ] != -1 || [string first ".B1($org_targ_node1)" $cur_line ] != -1 || [string first ".B2($org_targ_node1)" $cur_line ] != -1 || [string first ".C($org_targ_node1)" $cur_line ] != -1 || [string first ".CI($org_targ_node1)" $cur_line ] != -1 || [string first ".C1($org_targ_node1)" $cur_line ] != -1 || [string first ".C2($org_targ_node1)" $cur_line ] != -1 || [string first ".D($org_targ_node1)" $cur_line ] != -1 || [string first ".D1($org_targ_node1)" $cur_line ] != -1 || [string first ".D2($org_targ_node1)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {k5\[79\]} [lindex $lines $m] htnet1 ] ]
			
			} elseif {[string first ".A($org_targ_node2)" $cur_line] != -1 || [string first ".A1($org_targ_node2)" $cur_line] != -1 || [string first ".A2($org_targ_node2)" $cur_line] != -1 || [string first ".B($org_targ_node2)" $cur_line ] != -1 || [string first ".B1($org_targ_node2)" $cur_line ] != -1 || [string first ".B2($org_targ_node2)" $cur_line ] != -1 || [string first ".C($org_targ_node2)" $cur_line ] != -1 || [string first ".CI($org_targ_node2)" $cur_line ] != -1 || [string first ".C1($org_targ_node2)" $cur_line ] != -1 || [string first ".C2($org_targ_node2)" $cur_line ] != -1 || [string first ".D($org_targ_node2)" $cur_line ] != -1 || [string first ".D1($org_targ_node2)" $cur_line ] != -1 || [string first ".D2($org_targ_node2)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {k5\[125\]} [lindex $lines $m] htnet2 ] ]
			
			} elseif {[string first ".A($org_targ_node3)" $cur_line] != -1 || [string first ".A1($org_targ_node3)" $cur_line] != -1 || [string first ".A2($org_targ_node3)" $cur_line] != -1 || [string first ".B($org_targ_node3)" $cur_line ] != -1 || [string first ".B1($org_targ_node3)" $cur_line ] != -1 || [string first ".B2($org_targ_node3)" $cur_line ] != -1 || [string first ".C($org_targ_node3)" $cur_line ] != -1 || [string first ".CI($org_targ_node3)" $cur_line ] != -1 || [string first ".C1($org_targ_node3)" $cur_line ] != -1 || [string first ".C2($org_targ_node3)" $cur_line ] != -1 || [string first ".D($org_targ_node3)" $cur_line ] != -1 || [string first ".D1($org_targ_node3)" $cur_line ] != -1 || [string first ".D2($org_targ_node3)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {k5\[40\]} [lindex $lines $m] htnet3 ] ]
			
			} elseif {[string first ".A($org_targ_node4)" $cur_line] != -1 || [string first ".A1($org_targ_node4)" $cur_line] != -1 || [string first ".A2($org_targ_node4)" $cur_line] != -1 || [string first ".B($org_targ_node4)" $cur_line ] != -1 || [string first ".B1($org_targ_node4)" $cur_line ] != -1 || [string first ".B2($org_targ_node4)" $cur_line ] != -1 || [string first ".C($org_targ_node4)" $cur_line ] != -1 || [string first ".CI($org_targ_node4)" $cur_line ] != -1 || [string first ".C1($org_targ_node4)" $cur_line ] != -1 || [string first ".C2($org_targ_node4)" $cur_line ] != -1 || [string first ".D($org_targ_node4)" $cur_line ] != -1 || [string first ".D1($org_targ_node4)" $cur_line ] != -1 || [string first ".D2($org_targ_node4)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {k5\[76\]} [lindex $lines $m] htnet4 ] ]
			}
		}
		
			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
		set lines [linsert $lines $wire_idx "wire htnet4;" ]
		set lines [linsert $lines $wire_idx "wire htnet3;" ]
		set lines [linsert $lines $wire_idx "wire htnet2;" ]
		set lines [linsert $lines $wire_idx "wire htnet1;" ]		
		set lines [linsert $lines $wire_idx "wire htnet0;" ]
		set lines [linsert $lines $wire_idx "wire reset_n;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
		
#================Process starts for leak_targeted Trojan insertion ======================
	
	} elseif {$trojan_name == "aes_leak_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx


			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
				
		set lines [linsert $lines $wire_idx "wire htnet1;" ]
		set lines [linsert $lines $wire_idx "wire reset_n;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
#================Process starts for burn_random Trojan insertion ======================
	
	} elseif {$trojan_name == "aes_burn_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx

			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
	
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]
		set lines [linsert $lines $wire_idx "wire reset_n;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 

#================Process starts for fault_random Trojan insertion ======================
	
	} elseif {$trojan_name == "aes_fault_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx
		
		set org_rand_node0 "k9\[61\]"
		set org_rand_node1 "k9\[62\]"
		set org_rand_node2 "k9\[63\]"
		set org_rand_node3 "k9\[64\]"
		set org_rand_node4 "k9\[65\]"
		
		for {set m $start_idx} {$m < $end_idx} {incr m} {
			set cur_line [lindex $lines $m]
			if {[string first ".A($org_rand_node0)" $cur_line ] != -1 || [string first ".A1($org_rand_node0)" $cur_line ] != -1 || [string first ".A2($org_rand_node0)" $cur_line ] != -1 || [string first ".B($org_rand_node0)" $cur_line ] != -1 || [string first ".B1($org_rand_node0)" $cur_line ] != -1 || [string first ".B2($org_rand_node0)" $cur_line ] != -1 || [string first ".C($org_rand_node0)" $cur_line ] != -1 || [string first ".CI($org_rand_node0)" $cur_line ] != -1 || [string first ".C1($org_rand_node0)" $cur_line ] != -1 || [string first ".C2($org_rand_node0)" $cur_line ] != -1 || [string first ".D($org_rand_node0)" $cur_line ] != -1 || [string first ".D1($org_rand_node0)" $cur_line ] != -1 || [string first ".D2($org_rand_node0)" $cur_line ] != -1} {
			# puts $cur_line 
			set lines [lreplace $lines $m $m [regsub -all {k9\[61\]} [lindex $lines $m] htnet0 ] ]
			# puts [lindex $lines $m]
			} elseif {[string first ".A($org_rand_node1)" $cur_line] != -1 || [string first ".A1($org_rand_node1)" $cur_line] != -1 || [string first ".A2($org_rand_node1)" $cur_line] != -1 || [string first ".B($org_rand_node1)" $cur_line] != -1 || [string first ".B1($org_rand_node1)" $cur_line ] != -1 || [string first ".B2($org_rand_node1)" $cur_line ] != -1 || [string first ".C($org_rand_node1)" $cur_line ] != -1 || [string first ".CI($org_rand_node1)" $cur_line ] != -1|| [string first ".C1($org_rand_node1)" $cur_line ] != -1 || [string first ".C2($org_rand_node1)" $cur_line ] != -1 || [string first ".D($org_rand_node1)" $cur_line ] != -1 || [string first ".D1($org_rand_node1)" $cur_line ] != -1 || [string first ".D2($org_rand_node1)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {k9\[62\]} [lindex $lines $m] htnet1 ] ]
			
			} elseif {[string first ".A($org_rand_node2)" $cur_line] != -1 || [string first ".A1($org_rand_node2)" $cur_line] != -1 || [string first ".A2($org_rand_node2)" $cur_line] != -1 || [string first ".B($org_rand_node2)" $cur_line ] != -1 || [string first ".B1($org_rand_node2)" $cur_line ] != -1 || [string first ".B2($org_rand_node2)" $cur_line ] != -1 || [string first ".C($org_rand_node2)" $cur_line ] != -1 || [string first ".CI($org_rand_node2)" $cur_line ] != -1 || [string first ".C1($org_rand_node2)" $cur_line ] != -1 || [string first ".C2($org_rand_node2)" $cur_line ] != -1 || [string first ".D($org_rand_node2)" $cur_line ] != -1 || [string first ".D1($org_rand_node2)" $cur_line ] != -1 || [string first ".D2($org_rand_node2)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {k9\[63\]} [lindex $lines $m] htnet2 ] ]
			
			} elseif {[string first ".A($org_rand_node3)" $cur_line] != -1 || [string first ".A1($org_rand_node3)" $cur_line] != -1 || [string first ".A2($org_rand_node3)" $cur_line] != -1 || [string first ".B($org_rand_node3)" $cur_line ] != -1 || [string first ".B1($org_rand_node3)" $cur_line ] != -1 || [string first ".B2($org_rand_node3)" $cur_line ] != -1 || [string first ".C($org_rand_node3)" $cur_line ] != -1 || [string first ".CI($org_rand_node3)" $cur_line ] != -1 || [string first ".C1($org_rand_node3)" $cur_line ] != -1 || [string first ".C2($org_rand_node3)" $cur_line ] != -1 || [string first ".D($org_rand_node3)" $cur_line ] != -1 || [string first ".D1($org_rand_node3)" $cur_line ] != -1 || [string first ".D2($org_rand_node3)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {k9\[64\]} [lindex $lines $m] htnet3 ] ]
			
			} elseif {[string first ".A($org_rand_node4)" $cur_line] != -1 || [string first ".A1($org_rand_node4)" $cur_line] != -1 || [string first ".A2($org_rand_node4)" $cur_line] != -1 || [string first ".B($org_rand_node4)" $cur_line ] != -1 || [string first ".B1($org_rand_node4)" $cur_line ] != -1 || [string first ".B2($org_rand_node4)" $cur_line ] != -1 || [string first ".C($org_rand_node4)" $cur_line ] != -1 || [string first ".CI($org_rand_node4)" $cur_line ] != -1 || [string first ".C1($org_rand_node4)" $cur_line ] != -1 || [string first ".C2($org_rand_node4)" $cur_line ] != -1 || [string first ".D($org_rand_node4)" $cur_line ] != -1 || [string first ".D1($org_rand_node4)" $cur_line ] != -1 || [string first ".D2($org_rand_node4)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {k9\[65\]} [lindex $lines $m] htnet4 ] ]
			}
		}
		
			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
		set lines [linsert $lines $wire_idx "wire htnet4;" ]
		set lines [linsert $lines $wire_idx "wire htnet3;" ]
		set lines [linsert $lines $wire_idx "wire htnet2;" ]
		set lines [linsert $lines $wire_idx "wire htnet1;" ]		
		set lines [linsert $lines $wire_idx "wire htnet0;" ]
		set lines [linsert $lines $wire_idx "wire reset_n;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
		
#================Process starts for leak_random Trojan insertion ======================
	
	} elseif {$trojan_name == "aes_leak_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx


			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
				
		set lines [linsert $lines $wire_idx "wire htnet1;" ]
		set lines [linsert $lines $wire_idx "wire reset_n;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
	}
	
#============================================================================================
#=========================================== SEED ===========================================
#============================================================================================


#================Process starts for burn_targeted Trojan insertion ======================
	
	if {$trojan_name == "seed_burn_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx

			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
	
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 

#================Process starts for fault_targeted Trojan insertion ======================
	
	} elseif {$trojan_name == "seed_fault_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx
		
		set org_targ_node0 "int_dout_45"
		set org_targ_node1 "SEED_randomize_data_reg\[111\]"
		set org_targ_node2 "int_dout_46"
		set org_targ_node3 "SEED_randomize_data_reg\[110\]"
		set org_targ_node4 "SEED_randomize_data_reg\[108\]"
		
		for {set m $start_idx} {$m < $end_idx} {incr m} {
			set cur_line [lindex $lines $m]
			if {[string first ".A($org_targ_node0)" $cur_line ] != -1 || [string first ".A1($org_targ_node0)" $cur_line ] != -1 || [string first ".A2($org_targ_node0)" $cur_line ] != -1 || [string first ".B($org_targ_node0)" $cur_line ] != -1 || [string first ".B1($org_targ_node0)" $cur_line ] != -1 || [string first ".B2($org_targ_node0)" $cur_line ] != -1 || [string first ".C($org_targ_node0)" $cur_line ] != -1 || [string first ".CI($org_targ_node0)" $cur_line ] != -1 || [string first ".C1($org_targ_node0)" $cur_line ] != -1 || [string first ".C2($org_targ_node0)" $cur_line ] != -1 || [string first ".D($org_targ_node0)" $cur_line ] != -1 || [string first ".D1($org_targ_node0)" $cur_line ] != -1 || [string first ".D2($org_targ_node0)" $cur_line ] != -1} {
			# puts $cur_line 
			set lines [lreplace $lines $m $m [regsub -all {int_dout_45} [lindex $lines $m] htnet0 ] ]
			# puts [lindex $lines $m]
			} elseif {[string first ".A($org_targ_node1)" $cur_line ] != -1 || [string first ".A1($org_targ_node1)" $cur_line ] != -1 || [string first ".A2($org_targ_node1)" $cur_line ] != -1 || [string first ".B($org_targ_node1)" $cur_line ] != -1 || [string first ".B1($org_targ_node1)" $cur_line ] != -1 || [string first ".B2($org_targ_node1)" $cur_line ] != -1 || [string first ".C($org_targ_node1)" $cur_line ] != -1 || [string first ".CI($org_targ_node1)" $cur_line ] != -1 || [string first ".C1($org_targ_node1)" $cur_line ] != -1 || [string first ".C2($org_targ_node1)" $cur_line ] != -1 || [string first ".D($org_targ_node1)" $cur_line ] != -1 || [string first ".D1($org_targ_node1)" $cur_line ] != -1 || [string first ".D2($org_targ_node1)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {SEED_randomize_data_reg\[111\]} [lindex $lines $m] htnet1 ] ]
			
			} elseif {[string first ".A($org_targ_node2)" $cur_line] != -1 || [string first ".A1($org_targ_node2)" $cur_line] != -1 || [string first ".A2($org_targ_node2)" $cur_line] != -1 || [string first ".B($org_targ_node2)" $cur_line ] != -1 || [string first ".B1($org_targ_node2)" $cur_line ] != -1 || [string first ".B2($org_targ_node2)" $cur_line ] != -1 || [string first ".C($org_targ_node2)" $cur_line ] != -1 || [string first ".CI($org_targ_node2)" $cur_line ] != -1 || [string first ".C1($org_targ_node2)" $cur_line ] != -1 || [string first ".C2($org_targ_node2)" $cur_line ] != -1 || [string first ".D($org_targ_node2)" $cur_line ] != -1 || [string first ".D1($org_targ_node2)" $cur_line ] != -1 || [string first ".D2($org_targ_node2)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {int_dout_46} [lindex $lines $m] htnet2 ] ]
			
			} elseif {[string first ".A($org_targ_node3)" $cur_line] != -1 || [string first ".A1($org_targ_node3)" $cur_line] != -1 || [string first ".A2($org_targ_node3)" $cur_line] != -1 || [string first ".B($org_targ_node3)" $cur_line ] != -1 || [string first ".B1($org_targ_node3)" $cur_line ] != -1 || [string first ".B2($org_targ_node3)" $cur_line ] != -1 || [string first ".C($org_targ_node3)" $cur_line ] != -1 || [string first ".CI($org_targ_node3)" $cur_line ] != -1 || [string first ".C1($org_targ_node3)" $cur_line ] != -1 || [string first ".C2($org_targ_node3)" $cur_line ] != -1 || [string first ".D($org_targ_node3)" $cur_line ] != -1 || [string first ".D1($org_targ_node3)" $cur_line ] != -1 || [string first ".D2($org_targ_node3)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {SEED_randomize_data_reg\[110\]} [lindex $lines $m] htnet3 ] ]
			
			} elseif {[string first ".A($org_targ_node4)" $cur_line] != -1 || [string first ".A1($org_targ_node4)" $cur_line] != -1 || [string first ".A2($org_targ_node4)" $cur_line] != -1 || [string first ".B($org_targ_node4)" $cur_line ] != -1 || [string first ".B1($org_targ_node4)" $cur_line ] != -1 || [string first ".B2($org_targ_node4)" $cur_line ] != -1 || [string first ".C($org_targ_node4)" $cur_line ] != -1 || [string first ".CI($org_targ_node4)" $cur_line ] != -1 || [string first ".C1($org_targ_node4)" $cur_line ] != -1 || [string first ".C2($org_targ_node4)" $cur_line ] != -1 || [string first ".D($org_targ_node4)" $cur_line ] != -1 || [string first ".D1($org_targ_node4)" $cur_line ] != -1 || [string first ".D2($org_targ_node4)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {SEED_randomize_data_reg\[108\]} [lindex $lines $m] htnet4 ] ]
			}
		}
		
			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
		set lines [linsert $lines $wire_idx "wire htnet4;" ]
		set lines [linsert $lines $wire_idx "wire htnet3;" ]
		set lines [linsert $lines $wire_idx "wire htnet2;" ]
		set lines [linsert $lines $wire_idx "wire htnet1;" ]		
		set lines [linsert $lines $wire_idx "wire htnet0;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
		
#================Process starts for leak_targeted Trojan insertion ======================
	
	} elseif {$trojan_name == "seed_leak_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx


			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
				
		set lines [linsert $lines $wire_idx "wire htnet1;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
#================Process starts for burn_random Trojan insertion ======================
	
	} elseif {$trojan_name == "seed_burn_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx

			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
	
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 

#================Process starts for fault_random Trojan insertion ======================
	
	} elseif {$trojan_name == "seed_fault_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx
		
		set org_rand_node0 "SEED_randomize_data_reg\[100\]"
		set org_rand_node1 "SEED_randomize_data_reg\[101\]"
		set org_rand_node2 "SEED_randomize_data_reg\[102\]"
		set org_rand_node3 "SEED_randomize_data_reg\[103\]"
		set org_rand_node4 "SEED_randomize_data_reg\[104\]"
		
		for {set m $start_idx} {$m < $end_idx} {incr m} {
			set cur_line [lindex $lines $m]
			if {[string first ".A($org_rand_node0)" $cur_line ] != -1 || [string first ".A1($org_rand_node0)" $cur_line ] != -1 || [string first ".A2($org_rand_node0)" $cur_line ] != -1 || [string first ".B($org_rand_node0)" $cur_line ] != -1 || [string first ".B1($org_rand_node0)" $cur_line ] != -1 || [string first ".B2($org_rand_node0)" $cur_line ] != -1 || [string first ".C($org_rand_node0)" $cur_line ] != -1 || [string first ".CI($org_rand_node0)" $cur_line ] != -1 || [string first ".C1($org_rand_node0)" $cur_line ] != -1 || [string first ".C2($org_rand_node0)" $cur_line ] != -1 || [string first ".D($org_rand_node0)" $cur_line ] != -1 || [string first ".D1($org_rand_node0)" $cur_line ] != -1 || [string first ".D2($org_rand_node0)" $cur_line ] != -1} {
			# puts $cur_line 
			set lines [lreplace $lines $m $m [regsub -all {SEED_randomize_data_reg\[100\]} [lindex $lines $m] htnet0 ] ]
			# puts [lindex $lines $m]
			} elseif {[string first ".A($org_rand_node1)" $cur_line] != -1 || [string first ".A1($org_rand_node1)" $cur_line] != -1 || [string first ".A2($org_rand_node1)" $cur_line] != -1 || [string first ".B($org_rand_node1)" $cur_line] != -1 || [string first ".B1($org_rand_node1)" $cur_line ] != -1 || [string first ".B2($org_rand_node1)" $cur_line ] != -1 || [string first ".C($org_rand_node1)" $cur_line ] != -1 || [string first ".CI($org_rand_node1)" $cur_line ] != -1|| [string first ".C1($org_rand_node1)" $cur_line ] != -1 || [string first ".C2($org_rand_node1)" $cur_line ] != -1 || [string first ".D($org_rand_node1)" $cur_line ] != -1 || [string first ".D1($org_rand_node1)" $cur_line ] != -1 || [string first ".D2($org_rand_node1)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {SEED_randomize_data_reg\[101\]} [lindex $lines $m] htnet1 ] ]
			
			} elseif {[string first ".A($org_rand_node2)" $cur_line] != -1 || [string first ".A1($org_rand_node2)" $cur_line] != -1 || [string first ".A2($org_rand_node2)" $cur_line] != -1 || [string first ".B($org_rand_node2)" $cur_line ] != -1 || [string first ".B1($org_rand_node2)" $cur_line ] != -1 || [string first ".B2($org_rand_node2)" $cur_line ] != -1 || [string first ".C($org_rand_node2)" $cur_line ] != -1 || [string first ".CI($org_rand_node2)" $cur_line ] != -1 || [string first ".C1($org_rand_node2)" $cur_line ] != -1 || [string first ".C2($org_rand_node2)" $cur_line ] != -1 || [string first ".D($org_rand_node2)" $cur_line ] != -1 || [string first ".D1($org_rand_node2)" $cur_line ] != -1 || [string first ".D2($org_rand_node2)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {SEED_randomize_data_reg\[102\]} [lindex $lines $m] htnet2 ] ]
			
			} elseif {[string first ".A($org_rand_node3)" $cur_line] != -1 || [string first ".A1($org_rand_node3)" $cur_line] != -1 || [string first ".A2($org_rand_node3)" $cur_line] != -1 || [string first ".B($org_rand_node3)" $cur_line ] != -1 || [string first ".B1($org_rand_node3)" $cur_line ] != -1 || [string first ".B2($org_rand_node3)" $cur_line ] != -1 || [string first ".C($org_rand_node3)" $cur_line ] != -1 || [string first ".CI($org_rand_node3)" $cur_line ] != -1 || [string first ".C1($org_rand_node3)" $cur_line ] != -1 || [string first ".C2($org_rand_node3)" $cur_line ] != -1 || [string first ".D($org_rand_node3)" $cur_line ] != -1 || [string first ".D1($org_rand_node3)" $cur_line ] != -1 || [string first ".D2($org_rand_node3)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {SEED_randomize_data_reg\[103\]} [lindex $lines $m] htnet3 ] ]
			
			} elseif {[string first ".A($org_rand_node4)" $cur_line] != -1 || [string first ".A1($org_rand_node4)" $cur_line] != -1 || [string first ".A2($org_rand_node4)" $cur_line] != -1 || [string first ".B($org_rand_node4)" $cur_line ] != -1 || [string first ".B1($org_rand_node4)" $cur_line ] != -1 || [string first ".B2($org_rand_node4)" $cur_line ] != -1 || [string first ".C($org_rand_node4)" $cur_line ] != -1 || [string first ".CI($org_rand_node4)" $cur_line ] != -1 || [string first ".C1($org_rand_node4)" $cur_line ] != -1 || [string first ".C2($org_rand_node4)" $cur_line ] != -1 || [string first ".D($org_rand_node4)" $cur_line ] != -1 || [string first ".D1($org_rand_node4)" $cur_line ] != -1 || [string first ".D2($org_rand_node4)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {SEED_randomize_data_reg\[104\]} [lindex $lines $m] htnet4 ] ]
			}
		}
		
			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
		set lines [linsert $lines $wire_idx "wire htnet4;" ]
		set lines [linsert $lines $wire_idx "wire htnet3;" ]
		set lines [linsert $lines $wire_idx "wire htnet2;" ]
		set lines [linsert $lines $wire_idx "wire htnet1;" ]		
		set lines [linsert $lines $wire_idx "wire htnet0;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
		
#================Process starts for leak_random Trojan insertion ======================
	
	} elseif {$trojan_name == "seed_leak_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx


			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
				
		set lines [linsert $lines $wire_idx "wire htnet1;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
	}

#================================================================================================
#=========================================== CAMELLIA ===========================================
#================================================================================================


#================Process starts for burn_targeted Trojan insertion ======================
	
	if {$trojan_name == "camellia_burn_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx

			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
	
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 

#================Process starts for fault_targeted Trojan insertion ======================
	
	} elseif {$trojan_name == "camellia_fault_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx
		
		set org_targ_node0 "kl\[0\]"
		set org_targ_node1 "kl\[15\]"
		set org_targ_node2 "kl\[100\]"
		set org_targ_node3 "kl\[51\]"
		set org_targ_node4 "kl\[83\]"
		
		for {set m $start_idx} {$m < $end_idx} {incr m} {
			set cur_line [lindex $lines $m]
			if {[string first ".A($org_targ_node0)" $cur_line ] != -1 || [string first ".A1($org_targ_node0)" $cur_line ] != -1 || [string first ".A2($org_targ_node0)" $cur_line ] != -1 || [string first ".B($org_targ_node0)" $cur_line ] != -1 || [string first ".B1($org_targ_node0)" $cur_line ] != -1 || [string first ".B2($org_targ_node0)" $cur_line ] != -1 || [string first ".C($org_targ_node0)" $cur_line ] != -1 || [string first ".CI($org_targ_node0)" $cur_line ] != -1 || [string first ".C1($org_targ_node0)" $cur_line ] != -1 || [string first ".C2($org_targ_node0)" $cur_line ] != -1 || [string first ".D($org_targ_node0)" $cur_line ] != -1 || [string first ".D1($org_targ_node0)" $cur_line ] != -1 || [string first ".D2($org_targ_node0)" $cur_line ] != -1} {
			# puts $cur_line 
			set lines [lreplace $lines $m $m [regsub -all {kl\[0\]} [lindex $lines $m] htnet0 ] ]
			# puts [lindex $lines $m]
			} elseif {[string first ".A($org_targ_node1)" $cur_line ] != -1 || [string first ".A1($org_targ_node1)" $cur_line ] != -1 || [string first ".A2($org_targ_node1)" $cur_line ] != -1 || [string first ".B($org_targ_node1)" $cur_line ] != -1 || [string first ".B1($org_targ_node1)" $cur_line ] != -1 || [string first ".B2($org_targ_node1)" $cur_line ] != -1 || [string first ".C($org_targ_node1)" $cur_line ] != -1 || [string first ".CI($org_targ_node1)" $cur_line ] != -1 || [string first ".C1($org_targ_node1)" $cur_line ] != -1 || [string first ".C2($org_targ_node1)" $cur_line ] != -1 || [string first ".D($org_targ_node1)" $cur_line ] != -1 || [string first ".D1($org_targ_node1)" $cur_line ] != -1 || [string first ".D2($org_targ_node1)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {kl\[15\]} [lindex $lines $m] htnet1 ] ]
			
			} elseif {[string first ".A($org_targ_node2)" $cur_line] != -1 || [string first ".A1($org_targ_node2)" $cur_line] != -1 || [string first ".A2($org_targ_node2)" $cur_line] != -1 || [string first ".B($org_targ_node2)" $cur_line ] != -1 || [string first ".B1($org_targ_node2)" $cur_line ] != -1 || [string first ".B2($org_targ_node2)" $cur_line ] != -1 || [string first ".C($org_targ_node2)" $cur_line ] != -1 || [string first ".CI($org_targ_node2)" $cur_line ] != -1 || [string first ".C1($org_targ_node2)" $cur_line ] != -1 || [string first ".C2($org_targ_node2)" $cur_line ] != -1 || [string first ".D($org_targ_node2)" $cur_line ] != -1 || [string first ".D1($org_targ_node2)" $cur_line ] != -1 || [string first ".D2($org_targ_node2)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {kl\[100\]} [lindex $lines $m] htnet2 ] ]
			
			} elseif {[string first ".A($org_targ_node3)" $cur_line] != -1 || [string first ".A1($org_targ_node3)" $cur_line] != -1 || [string first ".A2($org_targ_node3)" $cur_line] != -1 || [string first ".B($org_targ_node3)" $cur_line ] != -1 || [string first ".B1($org_targ_node3)" $cur_line ] != -1 || [string first ".B2($org_targ_node3)" $cur_line ] != -1 || [string first ".C($org_targ_node3)" $cur_line ] != -1 || [string first ".CI($org_targ_node3)" $cur_line ] != -1 || [string first ".C1($org_targ_node3)" $cur_line ] != -1 || [string first ".C2($org_targ_node3)" $cur_line ] != -1 || [string first ".D($org_targ_node3)" $cur_line ] != -1 || [string first ".D1($org_targ_node3)" $cur_line ] != -1 || [string first ".D2($org_targ_node3)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {kl\[51\]} [lindex $lines $m] htnet3 ] ]
			
			} elseif {[string first ".A($org_targ_node4)" $cur_line] != -1 || [string first ".A1($org_targ_node4)" $cur_line] != -1 || [string first ".A2($org_targ_node4)" $cur_line] != -1 || [string first ".B($org_targ_node4)" $cur_line ] != -1 || [string first ".B1($org_targ_node4)" $cur_line ] != -1 || [string first ".B2($org_targ_node4)" $cur_line ] != -1 || [string first ".C($org_targ_node4)" $cur_line ] != -1 || [string first ".CI($org_targ_node4)" $cur_line ] != -1 || [string first ".C1($org_targ_node4)" $cur_line ] != -1 || [string first ".C2($org_targ_node4)" $cur_line ] != -1 || [string first ".D($org_targ_node4)" $cur_line ] != -1 || [string first ".D1($org_targ_node4)" $cur_line ] != -1 || [string first ".D2($org_targ_node4)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {kl\[83\]} [lindex $lines $m] htnet4 ] ]
			}
		}
		
			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
		set lines [linsert $lines $wire_idx "wire htnet4;" ]
		set lines [linsert $lines $wire_idx "wire htnet3;" ]
		set lines [linsert $lines $wire_idx "wire htnet2;" ]
		set lines [linsert $lines $wire_idx "wire htnet1;" ]		
		set lines [linsert $lines $wire_idx "wire htnet0;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
		
#================Process starts for leak_targeted Trojan insertion ======================
	
	} elseif {$trojan_name == "camellia_leak_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx


			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
				
		set lines [linsert $lines $wire_idx "wire htnet1;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
#================Process starts for burn_random Trojan insertion ======================
	
	} elseif {$trojan_name == "camellia_burn_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx

			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
	
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 

#================Process starts for fault_random Trojan insertion ======================
	
	} elseif {$trojan_name == "camellia_fault_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx
		
		set org_rand_node0 "ka\[90\]"
		set org_rand_node1 "ka\[91\]"
		set org_rand_node2 "ka\[92\]"
		set org_rand_node3 "ka\[93\]"
		set org_rand_node4 "ka\[94\]"
		
		for {set m $start_idx} {$m < $end_idx} {incr m} {
			set cur_line [lindex $lines $m]
			if {[string first ".A($org_rand_node0)" $cur_line ] != -1 || [string first ".A1($org_rand_node0)" $cur_line ] != -1 || [string first ".A2($org_rand_node0)" $cur_line ] != -1 || [string first ".B($org_rand_node0)" $cur_line ] != -1 || [string first ".B1($org_rand_node0)" $cur_line ] != -1 || [string first ".B2($org_rand_node0)" $cur_line ] != -1 || [string first ".C($org_rand_node0)" $cur_line ] != -1 || [string first ".CI($org_rand_node0)" $cur_line ] != -1 || [string first ".C1($org_rand_node0)" $cur_line ] != -1 || [string first ".C2($org_rand_node0)" $cur_line ] != -1 || [string first ".D($org_rand_node0)" $cur_line ] != -1 || [string first ".D1($org_rand_node0)" $cur_line ] != -1 || [string first ".D2($org_rand_node0)" $cur_line ] != -1} {
			# puts $cur_line 
			set lines [lreplace $lines $m $m [regsub -all {ka\[90\]} [lindex $lines $m] htnet0 ] ]
			# puts [lindex $lines $m]
			} elseif {[string first ".A($org_rand_node1)" $cur_line] != -1 || [string first ".A1($org_rand_node1)" $cur_line] != -1 || [string first ".A2($org_rand_node1)" $cur_line] != -1 || [string first ".B($org_rand_node1)" $cur_line] != -1 || [string first ".B1($org_rand_node1)" $cur_line ] != -1 || [string first ".B2($org_rand_node1)" $cur_line ] != -1 || [string first ".C($org_rand_node1)" $cur_line ] != -1 || [string first ".CI($org_rand_node1)" $cur_line ] != -1|| [string first ".C1($org_rand_node1)" $cur_line ] != -1 || [string first ".C2($org_rand_node1)" $cur_line ] != -1 || [string first ".D($org_rand_node1)" $cur_line ] != -1 || [string first ".D1($org_rand_node1)" $cur_line ] != -1 || [string first ".D2($org_rand_node1)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {ka\[91\]} [lindex $lines $m] htnet1 ] ]
			
			} elseif {[string first ".A($org_rand_node2)" $cur_line] != -1 || [string first ".A1($org_rand_node2)" $cur_line] != -1 || [string first ".A2($org_rand_node2)" $cur_line] != -1 || [string first ".B($org_rand_node2)" $cur_line ] != -1 || [string first ".B1($org_rand_node2)" $cur_line ] != -1 || [string first ".B2($org_rand_node2)" $cur_line ] != -1 || [string first ".C($org_rand_node2)" $cur_line ] != -1 || [string first ".CI($org_rand_node2)" $cur_line ] != -1 || [string first ".C1($org_rand_node2)" $cur_line ] != -1 || [string first ".C2($org_rand_node2)" $cur_line ] != -1 || [string first ".D($org_rand_node2)" $cur_line ] != -1 || [string first ".D1($org_rand_node2)" $cur_line ] != -1 || [string first ".D2($org_rand_node2)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {ka\[92\]} [lindex $lines $m] htnet2 ] ]
			
			} elseif {[string first ".A($org_rand_node3)" $cur_line] != -1 || [string first ".A1($org_rand_node3)" $cur_line] != -1 || [string first ".A2($org_rand_node3)" $cur_line] != -1 || [string first ".B($org_rand_node3)" $cur_line ] != -1 || [string first ".B1($org_rand_node3)" $cur_line ] != -1 || [string first ".B2($org_rand_node3)" $cur_line ] != -1 || [string first ".C($org_rand_node3)" $cur_line ] != -1 || [string first ".CI($org_rand_node3)" $cur_line ] != -1 || [string first ".C1($org_rand_node3)" $cur_line ] != -1 || [string first ".C2($org_rand_node3)" $cur_line ] != -1 || [string first ".D($org_rand_node3)" $cur_line ] != -1 || [string first ".D1($org_rand_node3)" $cur_line ] != -1 || [string first ".D2($org_rand_node3)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {ka\[93\]} [lindex $lines $m] htnet3 ] ]
			
			} elseif {[string first ".A($org_rand_node4)" $cur_line] != -1 || [string first ".A1($org_rand_node4)" $cur_line] != -1 || [string first ".A2($org_rand_node4)" $cur_line] != -1 || [string first ".B($org_rand_node4)" $cur_line ] != -1 || [string first ".B1($org_rand_node4)" $cur_line ] != -1 || [string first ".B2($org_rand_node4)" $cur_line ] != -1 || [string first ".C($org_rand_node4)" $cur_line ] != -1 || [string first ".CI($org_rand_node4)" $cur_line ] != -1 || [string first ".C1($org_rand_node4)" $cur_line ] != -1 || [string first ".C2($org_rand_node4)" $cur_line ] != -1 || [string first ".D($org_rand_node4)" $cur_line ] != -1 || [string first ".D1($org_rand_node4)" $cur_line ] != -1 || [string first ".D2($org_rand_node4)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {ka\[94\]} [lindex $lines $m] htnet4 ] ]
			}
		}
		
			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
		set lines [linsert $lines $wire_idx "wire htnet4;" ]
		set lines [linsert $lines $wire_idx "wire htnet3;" ]
		set lines [linsert $lines $wire_idx "wire htnet2;" ]
		set lines [linsert $lines $wire_idx "wire htnet1;" ]		
		set lines [linsert $lines $wire_idx "wire htnet0;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
		
#================Process starts for leak_random Trojan insertion ======================
	
	} elseif {$trojan_name == "camellia_leak_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx


			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
				
		set lines [linsert $lines $wire_idx "wire htnet1;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
	}

#============================================================================================
#=========================================== CAST ===========================================
#============================================================================================

	
#================Process starts for burn_targeted Trojan insertion ======================
	
	if {$trojan_name == "cast_burn_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx

			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
	
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 

#================Process starts for fault_targeted Trojan insertion ======================
	
	} elseif {$trojan_name == "cast_fault_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx
		
		set org_targ_node0 "zE\[7\]"
		set org_targ_node1 "zE\[6\]"
		set org_targ_node2 "zF\[7\]"
		set org_targ_node3 "zF\[6\]"
		set org_targ_node4 "zC\[7\]"
		
		for {set m $start_idx} {$m < $end_idx} {incr m} {
			set cur_line [lindex $lines $m]
			if {[string first ".A($org_targ_node0)" $cur_line ] != -1 || [string first ".A1($org_targ_node0)" $cur_line ] != -1 || [string first ".A2($org_targ_node0)" $cur_line ] != -1 || [string first ".B($org_targ_node0)" $cur_line ] != -1 || [string first ".B1($org_targ_node0)" $cur_line ] != -1 || [string first ".B2($org_targ_node0)" $cur_line ] != -1 || [string first ".C($org_targ_node0)" $cur_line ] != -1 || [string first ".CI($org_targ_node0)" $cur_line ] != -1 || [string first ".C1($org_targ_node0)" $cur_line ] != -1 || [string first ".C2($org_targ_node0)" $cur_line ] != -1 || [string first ".D($org_targ_node0)" $cur_line ] != -1 || [string first ".D1($org_targ_node0)" $cur_line ] != -1 || [string first ".D2($org_targ_node0)" $cur_line ] != -1} {
			# puts $cur_line 
			set lines [lreplace $lines $m $m [regsub -all {zE\[7\]} [lindex $lines $m] htnet0 ] ]
			# puts [lindex $lines $m]
			} elseif {[string first ".A($org_targ_node1)" $cur_line ] != -1 || [string first ".A1($org_targ_node1)" $cur_line ] != -1 || [string first ".A2($org_targ_node1)" $cur_line ] != -1 || [string first ".B($org_targ_node1)" $cur_line ] != -1 || [string first ".B1($org_targ_node1)" $cur_line ] != -1 || [string first ".B2($org_targ_node1)" $cur_line ] != -1 || [string first ".C($org_targ_node1)" $cur_line ] != -1 || [string first ".CI($org_targ_node1)" $cur_line ] != -1 || [string first ".C1($org_targ_node1)" $cur_line ] != -1 || [string first ".C2($org_targ_node1)" $cur_line ] != -1 || [string first ".D($org_targ_node1)" $cur_line ] != -1 || [string first ".D1($org_targ_node1)" $cur_line ] != -1 || [string first ".D2($org_targ_node1)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {zE\[6\]} [lindex $lines $m] htnet1 ] ]
			
			} elseif {[string first ".A($org_targ_node2)" $cur_line] != -1 || [string first ".A1($org_targ_node2)" $cur_line] != -1 || [string first ".A2($org_targ_node2)" $cur_line] != -1 || [string first ".B($org_targ_node2)" $cur_line ] != -1 || [string first ".B1($org_targ_node2)" $cur_line ] != -1 || [string first ".B2($org_targ_node2)" $cur_line ] != -1 || [string first ".C($org_targ_node2)" $cur_line ] != -1 || [string first ".CI($org_targ_node2)" $cur_line ] != -1 || [string first ".C1($org_targ_node2)" $cur_line ] != -1 || [string first ".C2($org_targ_node2)" $cur_line ] != -1 || [string first ".D($org_targ_node2)" $cur_line ] != -1 || [string first ".D1($org_targ_node2)" $cur_line ] != -1 || [string first ".D2($org_targ_node2)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {zF\[7\]} [lindex $lines $m] htnet2 ] ]
			
			} elseif {[string first ".A($org_targ_node3)" $cur_line] != -1 || [string first ".A1($org_targ_node3)" $cur_line] != -1 || [string first ".A2($org_targ_node3)" $cur_line] != -1 || [string first ".B($org_targ_node3)" $cur_line ] != -1 || [string first ".B1($org_targ_node3)" $cur_line ] != -1 || [string first ".B2($org_targ_node3)" $cur_line ] != -1 || [string first ".C($org_targ_node3)" $cur_line ] != -1 || [string first ".CI($org_targ_node3)" $cur_line ] != -1 || [string first ".C1($org_targ_node3)" $cur_line ] != -1 || [string first ".C2($org_targ_node3)" $cur_line ] != -1 || [string first ".D($org_targ_node3)" $cur_line ] != -1 || [string first ".D1($org_targ_node3)" $cur_line ] != -1 || [string first ".D2($org_targ_node3)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {zF\[6\]} [lindex $lines $m] htnet3 ] ]
			
			} elseif {[string first ".A($org_targ_node4)" $cur_line] != -1 || [string first ".A1($org_targ_node4)" $cur_line] != -1 || [string first ".A2($org_targ_node4)" $cur_line] != -1 || [string first ".B($org_targ_node4)" $cur_line ] != -1 || [string first ".B1($org_targ_node4)" $cur_line ] != -1 || [string first ".B2($org_targ_node4)" $cur_line ] != -1 || [string first ".C($org_targ_node4)" $cur_line ] != -1 || [string first ".CI($org_targ_node4)" $cur_line ] != -1 || [string first ".C1($org_targ_node4)" $cur_line ] != -1 || [string first ".C2($org_targ_node4)" $cur_line ] != -1 || [string first ".D($org_targ_node4)" $cur_line ] != -1 || [string first ".D1($org_targ_node4)" $cur_line ] != -1 || [string first ".D2($org_targ_node4)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {zC\[7\]} [lindex $lines $m] htnet4 ] ]
			}
		}
		
			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
		set lines [linsert $lines $wire_idx "wire htnet4;" ]
		set lines [linsert $lines $wire_idx "wire htnet3;" ]
		set lines [linsert $lines $wire_idx "wire htnet2;" ]
		set lines [linsert $lines $wire_idx "wire htnet1;" ]		
		set lines [linsert $lines $wire_idx "wire htnet0;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
		
#================Process starts for leak_targeted Trojan insertion ======================
	
	} elseif {$trojan_name == "cast_leak_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx


			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
				
		set lines [linsert $lines $wire_idx "wire htnet1;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
#================Process starts for burn_random Trojan insertion ======================
	
	} elseif {$trojan_name == "cast_burn_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx

			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
	
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 

#================Process starts for fault_random Trojan insertion ======================
	
	} elseif {$trojan_name == "cast_fault_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx
		
		set org_rand_node0 "z0\[0\]"
		set org_rand_node1 "z0\[1\]"
		set org_rand_node2 "z0\[2\]"
		set org_rand_node3 "z0\[3\]"
		set org_rand_node4 "z0\[4\]"
		
		for {set m $start_idx} {$m < $end_idx} {incr m} {
			set cur_line [lindex $lines $m]
			if {[string first ".A($org_rand_node0)" $cur_line ] != -1 || [string first ".A1($org_rand_node0)" $cur_line ] != -1 || [string first ".A2($org_rand_node0)" $cur_line ] != -1 || [string first ".B($org_rand_node0)" $cur_line ] != -1 || [string first ".B1($org_rand_node0)" $cur_line ] != -1 || [string first ".B2($org_rand_node0)" $cur_line ] != -1 || [string first ".C($org_rand_node0)" $cur_line ] != -1 || [string first ".CI($org_rand_node0)" $cur_line ] != -1 || [string first ".C1($org_rand_node0)" $cur_line ] != -1 || [string first ".C2($org_rand_node0)" $cur_line ] != -1 || [string first ".D($org_rand_node0)" $cur_line ] != -1 || [string first ".D1($org_rand_node0)" $cur_line ] != -1 || [string first ".D2($org_rand_node0)" $cur_line ] != -1} {
			# puts $cur_line 
			set lines [lreplace $lines $m $m [regsub -all {z0\[0\]} [lindex $lines $m] htnet0 ] ]
			# puts [lindex $lines $m]
			} elseif {[string first ".A($org_rand_node1)" $cur_line] != -1 || [string first ".A1($org_rand_node1)" $cur_line] != -1 || [string first ".A2($org_rand_node1)" $cur_line] != -1 || [string first ".B($org_rand_node1)" $cur_line] != -1 || [string first ".B1($org_rand_node1)" $cur_line ] != -1 || [string first ".B2($org_rand_node1)" $cur_line ] != -1 || [string first ".C($org_rand_node1)" $cur_line ] != -1 || [string first ".CI($org_rand_node1)" $cur_line ] != -1|| [string first ".C1($org_rand_node1)" $cur_line ] != -1 || [string first ".C2($org_rand_node1)" $cur_line ] != -1 || [string first ".D($org_rand_node1)" $cur_line ] != -1 || [string first ".D1($org_rand_node1)" $cur_line ] != -1 || [string first ".D2($org_rand_node1)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {z0\[1\]} [lindex $lines $m] htnet1 ] ]
			
			} elseif {[string first ".A($org_rand_node2)" $cur_line] != -1 || [string first ".A1($org_rand_node2)" $cur_line] != -1 || [string first ".A2($org_rand_node2)" $cur_line] != -1 || [string first ".B($org_rand_node2)" $cur_line ] != -1 || [string first ".B1($org_rand_node2)" $cur_line ] != -1 || [string first ".B2($org_rand_node2)" $cur_line ] != -1 || [string first ".C($org_rand_node2)" $cur_line ] != -1 || [string first ".CI($org_rand_node2)" $cur_line ] != -1 || [string first ".C1($org_rand_node2)" $cur_line ] != -1 || [string first ".C2($org_rand_node2)" $cur_line ] != -1 || [string first ".D($org_rand_node2)" $cur_line ] != -1 || [string first ".D1($org_rand_node2)" $cur_line ] != -1 || [string first ".D2($org_rand_node2)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {z0\[2\]} [lindex $lines $m] htnet2 ] ]
			
			} elseif {[string first ".A($org_rand_node3)" $cur_line] != -1 || [string first ".A1($org_rand_node3)" $cur_line] != -1 || [string first ".A2($org_rand_node3)" $cur_line] != -1 || [string first ".B($org_rand_node3)" $cur_line ] != -1 || [string first ".B1($org_rand_node3)" $cur_line ] != -1 || [string first ".B2($org_rand_node3)" $cur_line ] != -1 || [string first ".C($org_rand_node3)" $cur_line ] != -1 || [string first ".CI($org_rand_node3)" $cur_line ] != -1 || [string first ".C1($org_rand_node3)" $cur_line ] != -1 || [string first ".C2($org_rand_node3)" $cur_line ] != -1 || [string first ".D($org_rand_node3)" $cur_line ] != -1 || [string first ".D1($org_rand_node3)" $cur_line ] != -1 || [string first ".D2($org_rand_node3)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {z0\[3\]} [lindex $lines $m] htnet3 ] ]
			
			} elseif {[string first ".A($org_rand_node4)" $cur_line] != -1 || [string first ".A1($org_rand_node4)" $cur_line] != -1 || [string first ".A2($org_rand_node4)" $cur_line] != -1 || [string first ".B($org_rand_node4)" $cur_line ] != -1 || [string first ".B1($org_rand_node4)" $cur_line ] != -1 || [string first ".B2($org_rand_node4)" $cur_line ] != -1 || [string first ".C($org_rand_node4)" $cur_line ] != -1 || [string first ".CI($org_rand_node4)" $cur_line ] != -1 || [string first ".C1($org_rand_node4)" $cur_line ] != -1 || [string first ".C2($org_rand_node4)" $cur_line ] != -1 || [string first ".D($org_rand_node4)" $cur_line ] != -1 || [string first ".D1($org_rand_node4)" $cur_line ] != -1 || [string first ".D2($org_rand_node4)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {z0\[4\]} [lindex $lines $m] htnet4 ] ]
			}
		}
		
			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
		set lines [linsert $lines $wire_idx "wire htnet4;" ]
		set lines [linsert $lines $wire_idx "wire htnet3;" ]
		set lines [linsert $lines $wire_idx "wire htnet2;" ]
		set lines [linsert $lines $wire_idx "wire htnet1;" ]		
		set lines [linsert $lines $wire_idx "wire htnet0;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
		
#================Process starts for leak_random Trojan insertion ======================
	
	} elseif {$trojan_name == "cast_leak_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx


			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
				
		set lines [linsert $lines $wire_idx "wire htnet1;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
	}

#=============================================================================================
#=========================================== MISTY ===========================================
#=============================================================================================

	
#================Process starts for burn_targeted Trojan insertion ======================
	
	if {$trojan_name == "misty_burn_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx

			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
	
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 

#================Process starts for fault_targeted Trojan insertion ======================
	
	} elseif {$trojan_name == "misty_fault_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx
		
		set org_targ_node0 "key_sched_K_reg\[109\]"
		set org_targ_node1 "key_sched_K_reg\[116\]"
		set org_targ_node2 "key_sched_K_reg\[115\]"
		set org_targ_node3 "key_sched_K_reg\[108\]"
		set org_targ_node4 "key_sched_K_reg\[114\]"
		
		for {set m $start_idx} {$m < $end_idx} {incr m} {
			set cur_line [lindex $lines $m]
			if {[string first ".A($org_targ_node0)" $cur_line ] != -1 || [string first ".A1($org_targ_node0)" $cur_line ] != -1 || [string first ".A2($org_targ_node0)" $cur_line ] != -1 || [string first ".B($org_targ_node0)" $cur_line ] != -1 || [string first ".B1($org_targ_node0)" $cur_line ] != -1 || [string first ".B2($org_targ_node0)" $cur_line ] != -1 || [string first ".C($org_targ_node0)" $cur_line ] != -1 || [string first ".CI($org_targ_node0)" $cur_line ] != -1 || [string first ".C1($org_targ_node0)" $cur_line ] != -1 || [string first ".C2($org_targ_node0)" $cur_line ] != -1 || [string first ".D($org_targ_node0)" $cur_line ] != -1 || [string first ".D1($org_targ_node0)" $cur_line ] != -1 || [string first ".D2($org_targ_node0)" $cur_line ] != -1} {
			# puts $cur_line 
			set lines [lreplace $lines $m $m [regsub -all {key_sched_K_reg\[109\]} [lindex $lines $m] htnet0 ] ]
			# puts [lindex $lines $m]
			} elseif {[string first ".A($org_targ_node1)" $cur_line ] != -1 || [string first ".A1($org_targ_node1)" $cur_line ] != -1 || [string first ".A2($org_targ_node1)" $cur_line ] != -1 || [string first ".B($org_targ_node1)" $cur_line ] != -1 || [string first ".B1($org_targ_node1)" $cur_line ] != -1 || [string first ".B2($org_targ_node1)" $cur_line ] != -1 || [string first ".C($org_targ_node1)" $cur_line ] != -1 || [string first ".CI($org_targ_node1)" $cur_line ] != -1 || [string first ".C1($org_targ_node1)" $cur_line ] != -1 || [string first ".C2($org_targ_node1)" $cur_line ] != -1 || [string first ".D($org_targ_node1)" $cur_line ] != -1 || [string first ".D1($org_targ_node1)" $cur_line ] != -1 || [string first ".D2($org_targ_node1)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {key_sched_K_reg\[116\]} [lindex $lines $m] htnet1 ] ]
			
			} elseif {[string first ".A($org_targ_node2)" $cur_line] != -1 || [string first ".A1($org_targ_node2)" $cur_line] != -1 || [string first ".A2($org_targ_node2)" $cur_line] != -1 || [string first ".B($org_targ_node2)" $cur_line ] != -1 || [string first ".B1($org_targ_node2)" $cur_line ] != -1 || [string first ".B2($org_targ_node2)" $cur_line ] != -1 || [string first ".C($org_targ_node2)" $cur_line ] != -1 || [string first ".CI($org_targ_node2)" $cur_line ] != -1 || [string first ".C1($org_targ_node2)" $cur_line ] != -1 || [string first ".C2($org_targ_node2)" $cur_line ] != -1 || [string first ".D($org_targ_node2)" $cur_line ] != -1 || [string first ".D1($org_targ_node2)" $cur_line ] != -1 || [string first ".D2($org_targ_node2)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {key_sched_K_reg\[115\]} [lindex $lines $m] htnet2 ] ]
			
			} elseif {[string first ".A($org_targ_node3)" $cur_line] != -1 || [string first ".A1($org_targ_node3)" $cur_line] != -1 || [string first ".A2($org_targ_node3)" $cur_line] != -1 || [string first ".B($org_targ_node3)" $cur_line ] != -1 || [string first ".B1($org_targ_node3)" $cur_line ] != -1 || [string first ".B2($org_targ_node3)" $cur_line ] != -1 || [string first ".C($org_targ_node3)" $cur_line ] != -1 || [string first ".CI($org_targ_node3)" $cur_line ] != -1 || [string first ".C1($org_targ_node3)" $cur_line ] != -1 || [string first ".C2($org_targ_node3)" $cur_line ] != -1 || [string first ".D($org_targ_node3)" $cur_line ] != -1 || [string first ".D1($org_targ_node3)" $cur_line ] != -1 || [string first ".D2($org_targ_node3)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {key_sched_K_reg\[108\]} [lindex $lines $m] htnet3 ] ]
			
			} elseif {[string first ".A($org_targ_node4)" $cur_line] != -1 || [string first ".A1($org_targ_node4)" $cur_line] != -1 || [string first ".A2($org_targ_node4)" $cur_line] != -1 || [string first ".B($org_targ_node4)" $cur_line ] != -1 || [string first ".B1($org_targ_node4)" $cur_line ] != -1 || [string first ".B2($org_targ_node4)" $cur_line ] != -1 || [string first ".C($org_targ_node4)" $cur_line ] != -1 || [string first ".CI($org_targ_node4)" $cur_line ] != -1 || [string first ".C1($org_targ_node4)" $cur_line ] != -1 || [string first ".C2($org_targ_node4)" $cur_line ] != -1 || [string first ".D($org_targ_node4)" $cur_line ] != -1 || [string first ".D1($org_targ_node4)" $cur_line ] != -1 || [string first ".D2($org_targ_node4)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {key_sched_K_reg\[114\]} [lindex $lines $m] htnet4 ] ]
			}
		}
		
			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
		set lines [linsert $lines $wire_idx "wire htnet4;" ]
		set lines [linsert $lines $wire_idx "wire htnet3;" ]
		set lines [linsert $lines $wire_idx "wire htnet2;" ]
		set lines [linsert $lines $wire_idx "wire htnet1;" ]		
		set lines [linsert $lines $wire_idx "wire htnet0;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
		
#================Process starts for leak_targeted Trojan insertion ======================
	
	} elseif {$trojan_name == "misty_leak_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx


			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
				
		set lines [linsert $lines $wire_idx "wire htnet1;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
#================Process starts for burn_random Trojan insertion ======================
	
	} elseif {$trojan_name == "misty_burn_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx

			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
	
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 

#================Process starts for fault_random Trojan insertion ======================
	
	} elseif {$trojan_name == "misty_fault_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx
		
		set org_rand_node0 "randomize_data_reg\[40\]"
		set org_rand_node1 "randomize_data_reg\[41\]"
		set org_rand_node2 "randomize_data_reg\[42\]"
		set org_rand_node3 "randomize_data_reg\[43\]"
		set org_rand_node4 "randomize_data_reg\[44\]"
		
		for {set m $start_idx} {$m < $end_idx} {incr m} {
			set cur_line [lindex $lines $m]
			if {[string first ".A($org_rand_node0)" $cur_line ] != -1 || [string first ".A1($org_rand_node0)" $cur_line ] != -1 || [string first ".A2($org_rand_node0)" $cur_line ] != -1 || [string first ".B($org_rand_node0)" $cur_line ] != -1 || [string first ".B1($org_rand_node0)" $cur_line ] != -1 || [string first ".B2($org_rand_node0)" $cur_line ] != -1 || [string first ".C($org_rand_node0)" $cur_line ] != -1 || [string first ".CI($org_rand_node0)" $cur_line ] != -1 || [string first ".C1($org_rand_node0)" $cur_line ] != -1 || [string first ".C2($org_rand_node0)" $cur_line ] != -1 || [string first ".D($org_rand_node0)" $cur_line ] != -1 || [string first ".D1($org_rand_node0)" $cur_line ] != -1 || [string first ".D2($org_rand_node0)" $cur_line ] != -1} {
			# puts $cur_line 
			set lines [lreplace $lines $m $m [regsub -all {randomize_data_reg\[40\]} [lindex $lines $m] htnet0 ] ]
			# puts [lindex $lines $m]
			} elseif {[string first ".A($org_rand_node1)" $cur_line] != -1 || [string first ".A1($org_rand_node1)" $cur_line] != -1 || [string first ".A2($org_rand_node1)" $cur_line] != -1 || [string first ".B($org_rand_node1)" $cur_line] != -1 || [string first ".B1($org_rand_node1)" $cur_line ] != -1 || [string first ".B2($org_rand_node1)" $cur_line ] != -1 || [string first ".C($org_rand_node1)" $cur_line ] != -1 || [string first ".CI($org_rand_node1)" $cur_line ] != -1|| [string first ".C1($org_rand_node1)" $cur_line ] != -1 || [string first ".C2($org_rand_node1)" $cur_line ] != -1 || [string first ".D($org_rand_node1)" $cur_line ] != -1 || [string first ".D1($org_rand_node1)" $cur_line ] != -1 || [string first ".D2($org_rand_node1)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {randomize_data_reg\[41\]} [lindex $lines $m] htnet1 ] ]
			
			} elseif {[string first ".A($org_rand_node2)" $cur_line] != -1 || [string first ".A1($org_rand_node2)" $cur_line] != -1 || [string first ".A2($org_rand_node2)" $cur_line] != -1 || [string first ".B($org_rand_node2)" $cur_line ] != -1 || [string first ".B1($org_rand_node2)" $cur_line ] != -1 || [string first ".B2($org_rand_node2)" $cur_line ] != -1 || [string first ".C($org_rand_node2)" $cur_line ] != -1 || [string first ".CI($org_rand_node2)" $cur_line ] != -1 || [string first ".C1($org_rand_node2)" $cur_line ] != -1 || [string first ".C2($org_rand_node2)" $cur_line ] != -1 || [string first ".D($org_rand_node2)" $cur_line ] != -1 || [string first ".D1($org_rand_node2)" $cur_line ] != -1 || [string first ".D2($org_rand_node2)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {randomize_data_reg\[42\]} [lindex $lines $m] htnet2 ] ]
			
			} elseif {[string first ".A($org_rand_node3)" $cur_line] != -1 || [string first ".A1($org_rand_node3)" $cur_line] != -1 || [string first ".A2($org_rand_node3)" $cur_line] != -1 || [string first ".B($org_rand_node3)" $cur_line ] != -1 || [string first ".B1($org_rand_node3)" $cur_line ] != -1 || [string first ".B2($org_rand_node3)" $cur_line ] != -1 || [string first ".C($org_rand_node3)" $cur_line ] != -1 || [string first ".CI($org_rand_node3)" $cur_line ] != -1 || [string first ".C1($org_rand_node3)" $cur_line ] != -1 || [string first ".C2($org_rand_node3)" $cur_line ] != -1 || [string first ".D($org_rand_node3)" $cur_line ] != -1 || [string first ".D1($org_rand_node3)" $cur_line ] != -1 || [string first ".D2($org_rand_node3)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {randomize_data_reg\[43\]} [lindex $lines $m] htnet3 ] ]
			
			} elseif {[string first ".A($org_rand_node4)" $cur_line] != -1 || [string first ".A1($org_rand_node4)" $cur_line] != -1 || [string first ".A2($org_rand_node4)" $cur_line] != -1 || [string first ".B($org_rand_node4)" $cur_line ] != -1 || [string first ".B1($org_rand_node4)" $cur_line ] != -1 || [string first ".B2($org_rand_node4)" $cur_line ] != -1 || [string first ".C($org_rand_node4)" $cur_line ] != -1 || [string first ".CI($org_rand_node4)" $cur_line ] != -1 || [string first ".C1($org_rand_node4)" $cur_line ] != -1 || [string first ".C2($org_rand_node4)" $cur_line ] != -1 || [string first ".D($org_rand_node4)" $cur_line ] != -1 || [string first ".D1($org_rand_node4)" $cur_line ] != -1 || [string first ".D2($org_rand_node4)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {randomize_data_reg\[44\]} [lindex $lines $m] htnet4 ] ]
			}
		}
		
			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
		set lines [linsert $lines $wire_idx "wire htnet4;" ]
		set lines [linsert $lines $wire_idx "wire htnet3;" ]
		set lines [linsert $lines $wire_idx "wire htnet2;" ]
		set lines [linsert $lines $wire_idx "wire htnet1;" ]		
		set lines [linsert $lines $wire_idx "wire htnet0;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
		
#================Process starts for leak_random Trojan insertion ======================
	
	} elseif {$trojan_name == "misty_leak_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx


			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
				
		set lines [linsert $lines $wire_idx "wire htnet1;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
	}


#=============================================================================================
#=========================================== SHA256 ===========================================
#=============================================================================================

	
#================Process starts for burn_targeted Trojan insertion ======================
	
	if {$trojan_name == "sha256_burn_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx

			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
	
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 

#================Process starts for fault_targeted Trojan insertion ======================
	
	} elseif {$trojan_name == "sha256_fault_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx
		
		set org_targ_node0 "\\block_reg\[4\] \[4\]"
		set org_targ_node1 "\\block_reg\[4\] \[5\]"
		set org_targ_node2 "\\block_reg\[4\] \[7\]"
		set org_targ_node3 "\\block_reg\[4\] \[2\]"
		set org_targ_node4 "\\block_reg\[4\] \[1\]"
		
		for {set m $start_idx} {$m < $end_idx} {incr m} {
			set cur_line [lindex $lines $m]
			if {[string first ".A($org_targ_node0)" $cur_line ] != -1 || [string first ".A1($org_targ_node0)" $cur_line ] != -1 || [string first ".A2($org_targ_node0)" $cur_line ] != -1 || [string first ".B($org_targ_node0)" $cur_line ] != -1 || [string first ".B1($org_targ_node0)" $cur_line ] != -1 || [string first ".B2($org_targ_node0)" $cur_line ] != -1 || [string first ".C($org_targ_node0)" $cur_line ] != -1 || [string first ".CI($org_targ_node0)" $cur_line ] != -1 || [string first ".C1($org_targ_node0)" $cur_line ] != -1 || [string first ".C2($org_targ_node0)" $cur_line ] != -1 || [string first ".D($org_targ_node0)" $cur_line ] != -1 || [string first ".D1($org_targ_node0)" $cur_line ] != -1 || [string first ".D2($org_targ_node0)" $cur_line ] != -1} {
			# puts $cur_line 
			set lines [lreplace $lines $m $m [regsub -all {\\block_reg\[4\] \[4\]} [lindex $lines $m] htnet0 ] ]
			# puts [lindex $lines $m]
			} elseif {[string first ".A($org_targ_node1)" $cur_line ] != -1 || [string first ".A1($org_targ_node1)" $cur_line ] != -1 || [string first ".A2($org_targ_node1)" $cur_line ] != -1 || [string first ".B($org_targ_node1)" $cur_line ] != -1 || [string first ".B1($org_targ_node1)" $cur_line ] != -1 || [string first ".B2($org_targ_node1)" $cur_line ] != -1 || [string first ".C($org_targ_node1)" $cur_line ] != -1 || [string first ".CI($org_targ_node1)" $cur_line ] != -1 || [string first ".C1($org_targ_node1)" $cur_line ] != -1 || [string first ".C2($org_targ_node1)" $cur_line ] != -1 || [string first ".D($org_targ_node1)" $cur_line ] != -1 || [string first ".D1($org_targ_node1)" $cur_line ] != -1 || [string first ".D2($org_targ_node1)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {\\block_reg\[4\] \[5\]} [lindex $lines $m] htnet1 ] ]
			
			} elseif {[string first ".A($org_targ_node2)" $cur_line] != -1 || [string first ".A1($org_targ_node2)" $cur_line] != -1 || [string first ".A2($org_targ_node2)" $cur_line] != -1 || [string first ".B($org_targ_node2)" $cur_line ] != -1 || [string first ".B1($org_targ_node2)" $cur_line ] != -1 || [string first ".B2($org_targ_node2)" $cur_line ] != -1 || [string first ".C($org_targ_node2)" $cur_line ] != -1 || [string first ".CI($org_targ_node2)" $cur_line ] != -1 || [string first ".C1($org_targ_node2)" $cur_line ] != -1 || [string first ".C2($org_targ_node2)" $cur_line ] != -1 || [string first ".D($org_targ_node2)" $cur_line ] != -1 || [string first ".D1($org_targ_node2)" $cur_line ] != -1 || [string first ".D2($org_targ_node2)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {\\block_reg\[4\] \[7\]} [lindex $lines $m] htnet2 ] ]
			
			} elseif {[string first ".A($org_targ_node3)" $cur_line] != -1 || [string first ".A1($org_targ_node3)" $cur_line] != -1 || [string first ".A2($org_targ_node3)" $cur_line] != -1 || [string first ".B($org_targ_node3)" $cur_line ] != -1 || [string first ".B1($org_targ_node3)" $cur_line ] != -1 || [string first ".B2($org_targ_node3)" $cur_line ] != -1 || [string first ".C($org_targ_node3)" $cur_line ] != -1 || [string first ".CI($org_targ_node3)" $cur_line ] != -1 || [string first ".C1($org_targ_node3)" $cur_line ] != -1 || [string first ".C2($org_targ_node3)" $cur_line ] != -1 || [string first ".D($org_targ_node3)" $cur_line ] != -1 || [string first ".D1($org_targ_node3)" $cur_line ] != -1 || [string first ".D2($org_targ_node3)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {\\block_reg\[4\] \[2\]} [lindex $lines $m] htnet3 ] ]
			
			} elseif {[string first ".A($org_targ_node4)" $cur_line] != -1 || [string first ".A1($org_targ_node4)" $cur_line] != -1 || [string first ".A2($org_targ_node4)" $cur_line] != -1 || [string first ".B($org_targ_node4)" $cur_line ] != -1 || [string first ".B1($org_targ_node4)" $cur_line ] != -1 || [string first ".B2($org_targ_node4)" $cur_line ] != -1 || [string first ".C($org_targ_node4)" $cur_line ] != -1 || [string first ".CI($org_targ_node4)" $cur_line ] != -1 || [string first ".C1($org_targ_node4)" $cur_line ] != -1 || [string first ".C2($org_targ_node4)" $cur_line ] != -1 || [string first ".D($org_targ_node4)" $cur_line ] != -1 || [string first ".D1($org_targ_node4)" $cur_line ] != -1 || [string first ".D2($org_targ_node4)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {\\block_reg\[4\] \[1\]} [lindex $lines $m] htnet4 ] ]
			}
		}
		
			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
		set lines [linsert $lines $wire_idx "wire htnet4;" ]
		set lines [linsert $lines $wire_idx "wire htnet3;" ]
		set lines [linsert $lines $wire_idx "wire htnet2;" ]
		set lines [linsert $lines $wire_idx "wire htnet1;" ]		
		set lines [linsert $lines $wire_idx "wire htnet0;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
		
#================Process starts for leak_targeted Trojan insertion ======================
	
	} elseif {$trojan_name == "sha256_leak_targeted"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx


			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
				
		set lines [linsert $lines $wire_idx "wire htnet1;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
#================Process starts for burn_random Trojan insertion ======================
	
	} elseif {$trojan_name == "sha256_burn_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx

			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
	
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 

#================Process starts for fault_random Trojan insertion ======================
	
	} elseif {$trojan_name == "sha256_fault_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx
		
		set org_rand_node0 "digest_reg\[40\]"
		set org_rand_node1 "digest_reg\[41\]"
		set org_rand_node2 "digest_reg\[42\]"
		set org_rand_node3 "digest_reg\[43\]"
		set org_rand_node4 "digest_reg\[44\]"
		
		for {set m $start_idx} {$m < $end_idx} {incr m} {
			set cur_line [lindex $lines $m]
			if {[string first ".A($org_rand_node0)" $cur_line ] != -1 || [string first ".A1($org_rand_node0)" $cur_line ] != -1 || [string first ".A2($org_rand_node0)" $cur_line ] != -1 || [string first ".B($org_rand_node0)" $cur_line ] != -1 || [string first ".B1($org_rand_node0)" $cur_line ] != -1 || [string first ".B2($org_rand_node0)" $cur_line ] != -1 || [string first ".C($org_rand_node0)" $cur_line ] != -1 || [string first ".CI($org_rand_node0)" $cur_line ] != -1 || [string first ".C1($org_rand_node0)" $cur_line ] != -1 || [string first ".C2($org_rand_node0)" $cur_line ] != -1 || [string first ".D($org_rand_node0)" $cur_line ] != -1 || [string first ".D1($org_rand_node0)" $cur_line ] != -1 || [string first ".D2($org_rand_node0)" $cur_line ] != -1} {
			# puts $cur_line 
			set lines [lreplace $lines $m $m [regsub -all {digest_reg\[40\]} [lindex $lines $m] htnet0 ] ]
			# puts [lindex $lines $m]
			} elseif {[string first ".A($org_rand_node1)" $cur_line] != -1 || [string first ".A1($org_rand_node1)" $cur_line] != -1 || [string first ".A2($org_rand_node1)" $cur_line] != -1 || [string first ".B($org_rand_node1)" $cur_line] != -1 || [string first ".B1($org_rand_node1)" $cur_line ] != -1 || [string first ".B2($org_rand_node1)" $cur_line ] != -1 || [string first ".C($org_rand_node1)" $cur_line ] != -1 || [string first ".CI($org_rand_node1)" $cur_line ] != -1|| [string first ".C1($org_rand_node1)" $cur_line ] != -1 || [string first ".C2($org_rand_node1)" $cur_line ] != -1 || [string first ".D($org_rand_node1)" $cur_line ] != -1 || [string first ".D1($org_rand_node1)" $cur_line ] != -1 || [string first ".D2($org_rand_node1)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {digest_reg\[41\]} [lindex $lines $m] htnet1 ] ]
			
			} elseif {[string first ".A($org_rand_node2)" $cur_line] != -1 || [string first ".A1($org_rand_node2)" $cur_line] != -1 || [string first ".A2($org_rand_node2)" $cur_line] != -1 || [string first ".B($org_rand_node2)" $cur_line ] != -1 || [string first ".B1($org_rand_node2)" $cur_line ] != -1 || [string first ".B2($org_rand_node2)" $cur_line ] != -1 || [string first ".C($org_rand_node2)" $cur_line ] != -1 || [string first ".CI($org_rand_node2)" $cur_line ] != -1 || [string first ".C1($org_rand_node2)" $cur_line ] != -1 || [string first ".C2($org_rand_node2)" $cur_line ] != -1 || [string first ".D($org_rand_node2)" $cur_line ] != -1 || [string first ".D1($org_rand_node2)" $cur_line ] != -1 || [string first ".D2($org_rand_node2)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {digest_reg\[42\]} [lindex $lines $m] htnet2 ] ]
			
			} elseif {[string first ".A($org_rand_node3)" $cur_line] != -1 || [string first ".A1($org_rand_node3)" $cur_line] != -1 || [string first ".A2($org_rand_node3)" $cur_line] != -1 || [string first ".B($org_rand_node3)" $cur_line ] != -1 || [string first ".B1($org_rand_node3)" $cur_line ] != -1 || [string first ".B2($org_rand_node3)" $cur_line ] != -1 || [string first ".C($org_rand_node3)" $cur_line ] != -1 || [string first ".CI($org_rand_node3)" $cur_line ] != -1 || [string first ".C1($org_rand_node3)" $cur_line ] != -1 || [string first ".C2($org_rand_node3)" $cur_line ] != -1 || [string first ".D($org_rand_node3)" $cur_line ] != -1 || [string first ".D1($org_rand_node3)" $cur_line ] != -1 || [string first ".D2($org_rand_node3)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {digest_reg\[43\]} [lindex $lines $m] htnet3 ] ]
			
			} elseif {[string first ".A($org_rand_node4)" $cur_line] != -1 || [string first ".A1($org_rand_node4)" $cur_line] != -1 || [string first ".A2($org_rand_node4)" $cur_line] != -1 || [string first ".B($org_rand_node4)" $cur_line ] != -1 || [string first ".B1($org_rand_node4)" $cur_line ] != -1 || [string first ".B2($org_rand_node4)" $cur_line ] != -1 || [string first ".C($org_rand_node4)" $cur_line ] != -1 || [string first ".CI($org_rand_node4)" $cur_line ] != -1 || [string first ".C1($org_rand_node4)" $cur_line ] != -1 || [string first ".C2($org_rand_node4)" $cur_line ] != -1 || [string first ".D($org_rand_node4)" $cur_line ] != -1 || [string first ".D1($org_rand_node4)" $cur_line ] != -1 || [string first ".D2($org_rand_node4)" $cur_line ] != -1} {
			set lines [lreplace $lines $m $m [regsub -all {digest_reg\[44\]} [lindex $lines $m] htnet4 ] ]
			}
		}
		
			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
		set lines [linsert $lines $wire_idx "wire htnet4;" ]
		set lines [linsert $lines $wire_idx "wire htnet3;" ]
		set lines [linsert $lines $wire_idx "wire htnet2;" ]
		set lines [linsert $lines $wire_idx "wire htnet1;" ]		
		set lines [linsert $lines $wire_idx "wire htnet0;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
		
#================Process starts for leak_random Trojan insertion ======================
	
	} elseif {$trojan_name == "sha256_leak_random"} {
		set fp [open $netlist_for_trojan_insertion]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile TI/${trojan_name}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx


			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
				
		set lines [linsert $lines $wire_idx "wire htnet1;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open $netlist_w_trojan_inserted w]
		puts $fp [join $lines "\n"]
		close $fp 
		
	}
