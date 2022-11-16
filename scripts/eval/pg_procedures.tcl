proc userGetPGBoxesOnLayer {layerNumber} {
  set pgBoxList {}
  dbForEachFPlanStrip [dbHeadFPlan] strip {
    dbForEachStripBox $strip stripBox {
      if {[dbStripBoxZ $stripBox] == $layerNumber} {
        set box [dbStripBoxBox $stripBox]
        set net [dbStripBoxNet $stripBox]
        if {$net} {
          set netName [dbNetName $net]
          lappend pgBoxList [list $netName $box]
        }
      }
    }
  }
  return $pgBoxList
}

proc userGetPGBoxesOnLayerAndNet {layerNumber netName} {
  set pgBoxList {}
  dbForEachFPlanStrip [dbHeadFPlan] strip {
    dbForEachStripBox $strip stripBox {
      if {[dbStripBoxZ $stripBox] == $layerNumber} {
        if {[dbNetName [dbStripBoxNet $stripBox]] == $netName} {
          set box [dbStripBoxBox $stripBox]
          lappend pgBoxList $box
        }
      }
    }
  }
  return $pgBoxList
}


proc lcount list {
    set count {}
    foreach element $list {dict incr count $element}
    set count
 }

proc genListWidthLength { bbox_list d } {
	set wl_pair ""
	foreach el $bbox_list { 
		set llx [dbDBUToMicrons [lindex $el 0 ] ]
		set lly [dbDBUToMicrons [lindex $el 1 ] ]
		set urx [dbDBUToMicrons [lindex $el 2 ] ]
		set ury [dbDBUToMicrons [lindex $el 3 ] ]
		
		if {$d == "v"} {
			set width  [expr $urx - $llx ]
			set length [expr $ury - $lly ]
		} else {
			set length  [expr $urx - $llx ]
			set width [expr $ury - $lly ]
		}
		set pair "$width $length"
		lappend wl_pair $pair

}
	return $wl_pair
}




proc pg_mesh_details { } {

set of [open ./pg_metals.rpt w ]

set layers  "{1 h} {2 v} {3 h} {4 v} {5 h} {6 v} {7 h} {8 v} {9 h} {10 v}"
set nets    "VDD VSS"
	foreach net $nets {
		foreach layer_pair $layers {
			set layer [lindex $layer_pair 0 ]
			set direction [lindex $layer_pair 1]
			puts $of "NET : $net LAYER : metal$layer"
			puts $of "WL PAIR : COUNT"
			set bbox_list [ userGetPGBoxesOnLayerAndNet $layer $net ]
#			puts $bbox_list
			set wl_list [genListWidthLength $bbox_list $direction]
			#puts $wl_list
			set len [llength $wl_list]
			#puts $len
			set count_list [lcount $wl_list]	
			#puts $count_list
			for {set i 0 } { $i < $len } { incr i 2 } { 
	#			puts $i
				set p [lindex $count_list $i]
				set c [lindex $count_list [expr $i + 1]]
				if { $p != ""} {	
					puts $of "$p : $c " 
				}
			}
			
		}
	}
close $of

}












##proc genListWidthLength { bbox_list } {
##set wl_pair ""
##set wlist ""
##set llist ""
##
##	foreach el $bbox_list { 
##
##		set llx [dbDBUToMicrons [lindex $el 0 ] ]
##		set lly [dbDBUToMicrons [lindex $el 1 ] ]
##		set urx [dbDBUToMicrons [lindex $el 2 ] ]
##		set ury [dbDBUToMicrons [lindex $el 3 ] ]
##
##		set width  [expr $urx - $llx ]
##		set length [expr $ury - $lly ]
##		lappend wlist $width
##		lappend llist $length
##		set p "$width $length"
##		lappend wl_pair $p
##	  }
##		
##		
##		set wl_pair_uniq [lsort -u $wl_pair]
##
##		set wuniq [lsort -u $wlist]
##		set luniq [lsort -u $llist]
##
##		
##	}
##	
##	
##	
