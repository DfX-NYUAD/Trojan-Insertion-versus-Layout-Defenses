#!/usr/bin/tclsh

# Set the local dir for the netlist
set netlist_org "design.v"

# Choose the benchmark from this list ONLY: aes | camellia | cast | misty | seed | sha256
set target_netlist "seed"



if {$target_netlist == "aes"} {
set mod_keyword "module aes_128 ("
} elseif { $target_netlist == "camellia" } {
set mod_keyword "module Camellia ("
} elseif { $target_netlist == "cast" } {
set mod_keyword "module CAST128 ("
} elseif { $target_netlist == "misty" } {
set mod_keyword "module top ("
} elseif { $target_netlist == "seed" } {
set mod_keyword "module SEED ("
} elseif { $target_netlist == "sha256" } {
set mod_keyword "module sha256 ("
} else {
puts "ERROR! Please set the target_netlist variable from the list"
}


 proc listFromFile {filename} {
     set read_text [open $filename r]
     set data [split [string trim [read $read_text]] "\n" ]
     close $read_text
     return $data
 }
set list_of_nets [listFromFile $netlist_org]

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
	

set trj_files {burn_targeted fault_targeted leak_targeted burn_random fault_random leak_random}

for {set k 0} {$k < 6} {incr k} {

	set target [lindex $trj_files $k]
	#puts $target
	
#================Process starts for burn_targeted Trojan insertion ======================
	
	if {$target == "burn_targeted"} {
		set fp [open $netlist_org]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile ${target_netlist}_${target}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx

			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
	
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open ${target}_${target_netlist}.v w]
		puts $fp [join $lines "\n"]
		close $fp 

#================Process starts for fault_targeted Trojan insertion ======================
	
	} elseif {$target == "fault_targeted"} {
		set fp [open $netlist_org]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile ${target_netlist}_${target}.trj]
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

		set fp [open ${target}_${target_netlist}.v w]
		puts $fp [join $lines "\n"]
		close $fp 
		
		
#================Process starts for leak_targeted Trojan insertion ======================
	
	} elseif {$target == "leak_targeted"} {
		set fp [open $netlist_org]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile ${target_netlist}_${target}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx


			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
				
		set lines [linsert $lines $wire_idx "wire htnet1;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open ${target}_${target_netlist}.v w]
		puts $fp [join $lines "\n"]
		close $fp 
		
#================Process starts for burn_random Trojan insertion ======================
	
	} elseif {$target == "burn_random"} {
		set fp [open $netlist_org]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile ${target_netlist}_${target}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx

			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
	
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open ${target}_${target_netlist}.v w]
		puts $fp [join $lines "\n"]
		close $fp 

#================Process starts for fault_random Trojan insertion ======================
	
	} elseif {$target == "fault_random"} {
		set fp [open $netlist_org]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile ${target_netlist}_${target}.trj]
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

		set fp [open ${target}_${target_netlist}.v w]
		puts $fp [join $lines "\n"]
		close $fp 
		
		
#================Process starts for leak_random Trojan insertion ======================
	
	} elseif {$target == "leak_random"} {
		set fp [open $netlist_org]
		set lines [split [read $fp] \n]
		close $fp

		set list_of_trj [listFromFile ${target_netlist}_${target}.trj]
		set trj_len [llength $list_of_trj]
		set end_index $end_idx


			for {set j 0} {$j < $trj_len} {incr j} {
			set lines [linsert $lines $end_index [lindex $list_of_trj $j] ]
			incr end_index
			}
				
		set lines [linsert $lines $wire_idx "wire htnet1;" ]
		set lines [linsert $lines $wire_idx "wire clk_trojan;" ]

		set fp [open ${target}_${target_netlist}.v w]
		puts $fp [join $lines "\n"]
		close $fp 
		
	}
	
}






