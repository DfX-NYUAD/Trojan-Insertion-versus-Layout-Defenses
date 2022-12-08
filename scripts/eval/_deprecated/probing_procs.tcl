proc Sinsts { count } {
	set i 0
	dbForEachCellInst [dbgTopCell] inst {
		set instName [dbInstName $inst ]
		if { $i < $count } { 
			selectInst $instName 
		        incr i 1 
		} else {break }
	}
}
 proc parea { poly } {
     set xprev [lindex $poly end-1]
     set yprev [lindex $poly end]
     set area 0
     foreach { x y } $poly {
         set area [expr { $area + ( ($x - $xprev) * ( $y + $yprev) ) }]
         set xprev $x; set yprev $y
     }
     return [expr { abs( $area / 2. ) }]
 }

proc least {ll} {

	set list_uniq [lsort -u $ll ]

	set el1 [lindex $list_uniq 0]
	set el2 [lindex $list_uniq 1]
	
	if {$el1 > $el2 } {return $el2 } else {return $el1}
}

proc max {ll} {

	set list_uniq [lsort -u $ll ]

	set el1 [lindex $list_uniq 0]
	set el2 [lindex $list_uniq 1]
	
	if {$el1 < $el2 } {return $el2 } else {return $el1}
}

proc convert_poly_to_box { poly } {

set x0 [lindex $poly 0 0]
set x2 [lindex $poly 0 2]
set x4 [lindex $poly 0 4]
set x6 [lindex $poly 0 6]

set y1 [lindex $poly 0 1]
set y3 [lindex $poly 0 3]
set y5 [lindex $poly 0 5]
set y7 [lindex $poly 0 7]

set xlist "$x0 $x2 $x4 $x6"
set ylist "$y1 $y3 $y5 $y7"

set xmin [least $xlist]
set xmax [max $xlist]
set ymin [least $ylist]
set ymax [max $ylist]

set box "$xmin $ymin $xmax $ymax"
return $box

}

proc convert_box_to_poly  { box } {

	set llx [lindex $box  0]
	set lly [lindex $box  1]
	set urx [lindex $box  2]
	set ury [lindex $box  3]

	set poly "$llx $lly $urx $lly $urx $ury $llx $ury $llx $lly"

	return $poly	
}


proc showWirePoly { all } {
        clearDrc
	alias cm createMarker -poly
	set all_poly_uniq [lindex $all 0]
        foreach t $all_poly_uniq {
		set tt [regsub "{" $t ""] 
		set t [regsub "}" $tt ""] 
                cm $t 
        }
}

proc showAndPoly {all } {
        clearDrc 
	alias cm createMarker -poly
	set and_poly [lindex $all 1]
        foreach t $and_poly {
		set tt [regsub "{" $t ""] 
		set t [regsub "}" $tt ""] 
                cm $t 
        }
}

proc FindExposedAreaSplitPolygon { select threshold} {
	set xstep 0.05
	set ystep 0.05

	if { $select } {
		set instList ""
		foreach inst [get_db selected ] {
			set instName [get_db $inst .name]
			lappend instList $instName
		}
	
	} else {
		source newInstList.tcl
		}


	set of [open ./inst_exposed_split_polygon.tcl w ]
	puts $of "INSTANCE\t\tAREA\t\tEXPOSED AREA\t\tPERC EXPOSED"

	set all_exposed_perc 0
	set count_instance 0
	set a [expr $xstep * $ystep ]
	set nano_xstep [expr $xstep/10]
	set nano_ystep [expr $ystep/10]
	set nano_area [expr $nano_xstep * $nano_ystep]
	foreach inst_name $instList {
		set inst_bbox [dbInstBox [dbGetInstByName $inst_name]]
		set illx [dbDBUToMicrons [dbBoxLLX  $inst_bbox  ] ]
		set illy [dbDBUToMicrons [dbBoxLLY  $inst_bbox  ] ]
		set iurx [dbDBUToMicrons [dbBoxURX  $inst_bbox  ] ]
		set iury [dbDBUToMicrons [dbBoxURY  $inst_bbox  ] ] 

		set inst_box "$illx $illy $iurx $iury"
		set width  [expr $iurx - $illx]
		set height [expr $iury - $illy ]
		set all_boxes [splitPolygon $inst_box $xstep $ystep] 
		set count 0
		set nano_count 0
		foreach el $all_boxes {
			set n [llength [dbQuery -area $el -objType {wire special via}]]
			if {$n==0} { 
					incr count 1 
					add_gui_shape  -layer my_layer_1 -rect $el
				} else {
			
					##set w [expr [lindex $el 2] - [lindex $el 0]]	
					##set h [expr [lindex $el 3] - [lindex $el 1]]	
					##if { $w !=0 && $h != 0} {
					####puts "In the nano section"
					####puts "The polygon is $el"
					##set nano_polygons [splitPolygon $el $nano_xstep $nano_ystep]
					####puts "The nano polygons are $nano_polygons"
					##foreach pp $nano_polygons {
					##	set nano_n [llength [dbQuery -area $pp -objType {wire special via}]]
					##	if  { $nano_n == 0 } { 
					##		incr nano_count 1
					##		add_gui_shape  -layer my_layer_1 -rect $pp
					##		}
					##}
					##
					##}
					}	

		}

		
	set tot_area [expr ($count * $a) + ($nano_count * $nano_area)]
	set instArea [expr $width * $height]

	set perc_exposed [expr $tot_area / $instArea * 100]

	set all_exposed_perc [expr $all_exposed_perc + $perc_exposed ]

	##puts "Details for instance $inst_name"
	##puts "Total inst area is $instArea"
	##puts "Total exposed area is $tot_area"
	##puts "Total exposed percentage of area is $perc_exposed"

	incr count_instance 1 

	puts "Completed $count_instance"
	##puts $of "$inst_name $instArea $tot_area $perc_exposed"

	if { $perc_exposed > $threshold } {
	
	        add_gui_shape -layer my_layer_1 -rect $inst_box
	}

	}

set average_perc [expr $all_exposed_perc / $count_instance]
##puts "Average perc exposed $average_perc"		
##puts $of "Average perc exposed $average_perc"		
	close $of
}
proc splitPolygon {box xstep ystep } {

	#puts "The box input to split polygon is $box"
	set llx [lindex $box 0 ]
	set lly [lindex $box 1 ]
	set urx [lindex $box 2 ]
	set ury [lindex $box 3 ]
	
	set instWidth  [expr $urx - $llx]
	set instHeight [expr $ury - $lly]

	set no_x_steps [ expr floor ($instWidth / $xstep) ]
	set no_y_steps [ expr floor ($instHeight / $ystep) ]

	set finalStepSizeX [expr $instWidth - $no_x_steps * $xstep]
	set finalStepSizeY [expr $instHeight - $no_y_steps * $ystep]

	set y $lly
	set x $llx

	set all_box ""

	##puts "The polygon under split is $box"
	##puts "Polygon width is $instWidth"
	##puts "Polygon Height is $instHeight"

	##puts "The x and y final remaining step sizes are $finalStepSizeX and $finalStepSizeY"

	for { set ynext [expr $lly + $ystep] } {$ynext <= $ury } {set ynext [expr $ynext + $ystep] }	 {
		

		for { set xnext [expr $llx + $xstep] } { $xnext <= $urx } { set xnext [expr $xnext + $xstep] } {


			set pbox "$x $y $xnext $ynext"	

			lappend all_box $pbox

			set x $xnext

	
		}


##		puts "Completed the array of polygon for $y $ynext"

			if {$finalStepSizeX != 0 } {
				set xnext [expr $x + $finalStepSizeX ]	
				set pbox "$x $y $xnext $ynext" 
				lappend all_box $pbox
			}

			set x $llx
			set y $ynext
	}

##	puts "Completed the array of Y polygons. remaining the finalStepSize array"
	
	if { $finalStepSizeY != 0 } {
	
		set ynext [expr $ynext + $finalStepSizeY - $ystep]

		for { set xnext [expr $llx + $xstep] } { $xnext < $urx } { set xnext [expr $xnext + $xstep] } {

			set pbox "$x $y $xnext $ynext"	

			lappend all_box $pbox

			set x $xnext

	
		}

	}
	
	set xnext [expr $xnext - $xstep]
	set pbox "$xnext $y $urx $ury"
	lappend all_box $pbox

##return $all_box
}	


proc FindExposedAreaNet { netList xstep ystep of_name } {

	set a [expr $xstep * $ystep ]

	set of [open ./${of_name} w ]

	puts $of "NET_NAME\tTOT_NET_AREA\tTOT_EXPOSED_PERC"
	set nets_finished 0

	foreach net $netList {
		
		puts "Working on net $net"

		set net_area_exposed 0
		set net_area 0
		dbForEachNetWire [dbGetNetByName $net] w {
			set wb [dbWireBox $w]
##			puts $wb
			set wllx [dbDBUToMicrons [dbBoxLLX  $wb] ]
			set wlly [dbDBUToMicrons [dbBoxLLY  $wb] ]		
			set wurx [dbDBUToMicrons [dbBoxURX  $wb] ]		
			set wury [dbDBUToMicrons [dbBoxURY  $wb] ]		
		
			set wbox "$wllx $wlly $wurx $wury"	
		##	puts "Working on segment $wbox"
			set wireLayer [dbWireZ $w]
		##	puts "Wire layer is $wireLayer"

			set box_width [expr $wurx - $wllx]
			set box_height [expr $wury - $wlly]
			set box_area [expr $box_width * $box_height]

		##	puts "The current box area is $box_area"

			set net_area [expr $net_area + $box_area]
			if { $box_width != 0 && $box_height != 0 } {
##				puts "The box_width is $box_width"
##				puts "The box_height is $box_height"
##				puts "About to split segment to polygons"
				set all_boxes [splitPolygon $wbox $xstep $ystep]
##				createMarker -bbox $wbox
##				puts "$all_boxes"
				
		 		set count 0
				foreach el $all_boxes  {
					set n [llength [dbQuery -area $el -objType {wire special}]]
					set n_above 0
					foreach queryObj [dbQuery -area $el -objType {wire special}] {
						if { [dbIsObjWire $queryObj]} { 
							set queryObj_layer [dbWireZ $queryObj]	
						} else {
							set queryObj_layer [dbStripBoxZ $queryObj]	
						}
						if { $queryObj_layer > $wireLayer } { 
							incr n_above 1
						}
					} 
					if {$n_above==0}  {
						incr count 1
						##add_gui_shape  -layer my_layer_1 -rect $el
							}
				}	
		##		puts "Total exposed split polygon is $count"
				set segment_area_exposed [expr $count * $a]
		##		puts "Total exposed area of the segment is $segment_area_exposed"
				set net_area_exposed [expr $net_area_exposed + $segment_area_exposed]

				}
			}		
		incr nets_finished 1
		puts "Total net area is $net_area"
		puts "Total exposed area is $net_area_exposed"
		set perc_net_exposed [expr $net_area_exposed / $net_area * 100]
		puts $of "$net\t\t$net_area\t\t$perc_net_exposed"	
		puts "$net\t\t$net_area\t\t$perc_net_exposed"	
		puts "Completed $nets_finished nets"

	}	
	
	close $of
}


proc GetCrossPoly { inst_name } {
	set and_poly ""
##	puts "Working on instance $inst_name"
	set inst_bbox  [dbInstBox [dbGetInstByName $inst_name]]
	set illx [dbDBUToMicrons [dbBoxLLX  $inst_bbox  ] ]
	set illy [dbDBUToMicrons [dbBoxLLY  $inst_bbox  ] ]
	set iurx [dbDBUToMicrons [dbBoxURX  $inst_bbox  ] ]
	set iury [dbDBUToMicrons [dbBoxURY  $inst_bbox  ] ] 
	set inst_box "$illx $illy $iurx $iury"
	##puts "The instance box is $inst_box"
	set inst_bbox [regsub "{" $inst_box "" ]
	set inst_bbox [regsub "}" $inst_bbox "" ]
	set inst_poly [convert_box_to_poly $inst_bbox]
##	puts "The polygon of instance is $inst_poly"
	set cross_poly_area 0
	set area 0
	foreach w [dbQuery -area $inst_box -objType {wire special }] {
		if {[dbIsObjWire $w]} {
			set nname [dbNetName [dbWireNet  $w]]
			set llx [dbDBUToMicrons [dbBoxLLX [dbWireBox $w ] ] ]
			set lly [dbDBUToMicrons [dbBoxLLY [dbWireBox $w ] ] ]
			set urx [dbDBUToMicrons [dbBoxURX [dbWireBox $w ] ] ]
			set ury [dbDBUToMicrons [dbBoxURY [dbWireBox $w ] ] ] 
		} elseif {[dbIsObjStripBox $w] } {
			set llx [dbDBUToMicrons [dbBoxLLX [dbStripBoxBox $w ] ] ]
			set lly [dbDBUToMicrons [dbBoxLLY [dbStripBoxBox $w ] ] ]
			set urx [dbDBUToMicrons [dbBoxURX [dbStripBoxBox $w ] ] ]
			set ury [dbDBUToMicrons [dbBoxURY [dbStripBoxBox $w ] ] ] 
		}
		
		##puts "Start of if statments"
		if { $illx == $llx} {
			set llx [expr $llx - 0.04 ]
		}
		if { $illy == $lly} {
			set lly [expr $lly - 0.04 ]
		}
		if { $iurx == $urx} {
			set urx [expr $urx + 0.04 ]
		}
		if { $iury == $ury} {
		##puts "The above polygon shares its lower edge with instance top edge "
		##puts "The top edge of polygon is $ury"
			set ury [expr $ury + 0.04 ]
		}
		if { $iury == $lly} {
		##puts "The above polygon share edge with instance. hence modifying the coordinate"
		##puts "The bottom edge of the polygon is $lly"
			set lly [expr $lly + 0.04 ]
		}
		if { $iurx == $llx} {
			set llx [expr $llx + 0.04 ]
		}
		if { $illx == $urx} {
			set urx [expr $urx - 0.04 ]
		}
		if { $illy == $ury} {
			set ury [expr $ury - 0.04 ]
		}
		##puts "End of if statments"
		set wlist "$llx $lly $urx $lly $urx $ury $llx $ury $llx $lly"
##		puts $wlist
		##puts "Start of clipping"
		set poly [ghclip::clip $inst_poly AND $wlist]
		##puts "End of clipping"
##		puts "AND poly is $poly"
		foreach element $poly {
			set ppoly [regsub "{" $element ""]
			set ppoly [regsub "}" $ppoly ""]
			set area [parea $element]
			##puts "poly area is $area"
			set cross_poly_area [expr $cross_poly_area + $area ]
		}
		lappend and_poly $poly
}
set result "$and_poly $cross_poly_area "
return $result
}



#package require ghclip

##source GetCrossPoly.tcl
##source useful_procs.tcl

proc FindExposedArea { select thresh } {

	if { $select } {
		set instList ""
		foreach inst [get_db selected ] {
			set instName [get_db $inst .name]
			lappend instList $instName
		}
	
	} else {
		source newInstList.tcl
		}

	set j 0 
	set of [open ./inst_exposed.tcl w ]
	set tot_exposed_perc 0
	puts $of "INSTANCE\t\tAREA\t\tEXPOSED AREA\t\tPERC EXPOSED"

	foreach el $instList {
		set inst_name $el
		set result [GetCrossPoly $inst_name]
		set cross_poly_area [lindex $result end]
		##set all_poly [lsort -u [lreplace [lreplace $result end end] 0 0 ] ]
		set all_poly [lsort -u [lreplace $result end end] ]
	
	set all_poly_uniq ""
	foreach el $all_poly {
	        if {$el != "" } {
	                lappend all_poly_uniq $el }
	        }
	
##	puts "All poly uniq is $all_poly_uniq"


	incr j 1
	
	set i 0
	set and_area 0
	set and_poly ""
##	puts "Entering the AND product calculation within the list of polygons"
	set temp $all_poly_uniq
##       puts ""
##	puts "all poly is $all_poly"
	foreach el $all_poly_uniq {
##		puts "The el is $el"
		set el_box [convert_poly_to_box $el]
##		puts "The el_box is $el_box"
	        set illx [lindex $el_box 0 ] 
	        set illy [lindex $el_box 1 ] 
	        set iurx [lindex $el_box 2 ] 
	        set iury [lindex $el_box 3 ] 
		set el "$illx $illy $iurx $illy $iurx $iury $illx $iury $illx $illy"
##	        puts "Working on poly $el"
	        set temp [lreplace $temp 0 0 ]
	        incr i 1
##	        puts "The poly list after replacing the current poly is $temp"
	        foreach e $temp {
			set e_box [convert_poly_to_box $e]
	                set llx [lindex  $e_box 0 ] 
	                set lly [lindex  $e_box 1 ] 
	                set urx [lindex  $e_box 2 ] 
	                set ury [lindex  $e_box 3 ] 
	                if { $illx == $llx} {
	                        set llx [expr $llx - 0.02 ]
	                }
	                if { $illy == $lly} {
	                        set lly [expr $lly - 0.02 ]
	                }
	                if { $iurx == $urx} {
	                        set urx [expr $urx + 0.02 ]
	                }
	                if { $iury == $ury} {
	                        set ury [expr $ury + 0.02 ]
	                }
	                set e "$llx $lly $urx $lly $urx $ury $llx $ury $llx $lly"
	                set e [regsub "{" [regsub "}" $e ""] "" ]
#	                puts "Working on the element $e of the temp poly"
	                set and [ghclip::clip $el AND $e]
			lappend and_poly $and
	                ##puts "The AND product is "
	                ##puts $and
	                set a 0
			if { $and != ""} {
	                foreach element $and {
	                set a [expr $a + [parea $element] ]
	                }
	                ##puts "The area pf AND product poly is"
	                ##puts $a
##	                puts "Current and area is $a"
	                set and_area [expr $and_area + $a]
			}
	        }
	 }
	
	##puts "Total cross poly area is $cross_poly_area"
	##puts "Total and poly area is $and_area"
	
	puts "Working on instance $inst_name"	
set inst_bbox  [dbInstBox [dbGetInstByName $inst_name]]
        set illx [dbDBUToMicrons [dbBoxLLX  $inst_bbox  ] ]
        set illy [dbDBUToMicrons [dbBoxLLY  $inst_bbox  ] ]
        set iurx [dbDBUToMicrons [dbBoxURX  $inst_bbox  ] ]
        set iury [dbDBUToMicrons [dbBoxURY  $inst_bbox  ] ]
        set inst_box "$illx $illy $iurx $iury"
        set inst_bbox [regsub "{" $inst_box "" ]
        set inst_bbox [regsub "}" $inst_bbox "" ]
        set inst_poly [convert_box_to_poly $inst_bbox]
	set inst_area [parea $inst_poly]
	puts "Total Inst area is $inst_area"
	
		set exposed_area [expr $inst_area - $cross_poly_area + $and_area]
		puts "Exposed area is $exposed_area"
		
		set perc_exposed [ expr ($exposed_area / $inst_area ) * 100 ]
		puts "Percentage of std cell exposed is $perc_exposed"
		
		set tot_exposed_perc [expr $tot_exposed_perc + $perc_exposed ]
		puts $of "$inst_name\t\t$inst_area\t\t$exposed_area\t\t$perc_exposed"
		puts  "$inst_name\t\t$inst_area\t\t$exposed_area\t\t$perc_exposed"

if { $exposed_area > $thresh } {

	add_gui_shape -layer my_layer_1 -rect $inst_box
}
	}



set average_perc [expr $tot_exposed_perc/$j]
puts $of " AVERAGE EXPOSED PERC : $average_perc"
puts  " AVERAGE EXPOSED PERC : $average_perc"
close $of

set and_poly_uniq ""
        foreach el $and_poly {
                if {$el != "" } {
                        lappend and_poly_uniq $el }
                }

set all "{$all_poly_uniq} {$and_poly_uniq}"
return $all

}


proc clear { } {

dbDeleteObj [dbGet top.fplan.guiRects.guiLayerName my_layer_1 -p]

}



proc expandPoly {inst_box stretch } { 

	set llx [dbDBUToMicrons [dbBoxLLX  $inst_bbox  ] ]
        set lly [dbDBUToMicrons [dbBoxLLY  $inst_bbox  ] ]
        set urx [dbDBUToMicrons [dbBoxURX  $inst_bbox  ] ]
        set ury [dbDBUToMicrons [dbBoxURY  $inst_bbox  ] ]
	
	set newllx [expr $llx + $stretch]
	set newlly [expr $lly + $stretch]
	set newurx [expr $urx + $stretch]
	set newury [expr $ury + $stretch]

	set expand_poly "$newllx $newlly $newurx $newury"

	return $expand_poly
}


proc shadowPoly { box angle height side } {

	set llx [dbDBUToMicrons [dbBoxLLX  $box  ] ]
        set lly [dbDBUToMicrons [dbBoxLLY  $box  ] ]
        set urx [dbDBUToMicrons [dbBoxURX  $box  ] ]
        set ury [dbDBUToMicrons [dbBoxURY  $box  ] ]

	set d [expr $height*tan($angle)]	

	switch $side {

		E {
			set newllx [expr $llx - $d]
			set newlly $lly
			set newurx [expr $urx - $d]
			set newury $ury
	           }

		W {
			set newllx [expr $llx + $d]
			set newlly $lly
			set newurx [expr $urx + $d]
			set newury $ury
			}
		N {
			set newllx $llx
			set newlly [expr $lly - $d]
			set newurx $urx
			set newury [expr $ury - $d]
			}
		S  {
			set newllx $llx
			set newlly [expr $lly + $d]
			set newurx $urx
			set newury [expr $ury + $d]
			}
	}	

	set shadowPoly "$newllx $newlly $newurx $newury"

	return $shadowPoly
}




proc splitPolygonAngledProbe { instList angle xstep ystep of_name } {
	dbDeleteObj [dbGet top.fplan.guiRects]
	set MH_pair "{1 0.37} {2 0.62} {3 0.88} {4 1.14} {5 1.71} {6 2.28} {7 2.85} {8 4.47} {9 6.09} {10 10.09}"
	if { $angle != 0 } {
                set sides "E W N S"
        } else {
                set sides "N"
        }

	set of [open ./${of_name} w ]
	puts $of "INSTANCE\t\tAREA\t\tEXPOSED AREA\t\tPERC EXPOSED"

	set all_exposed_perc 0
	set count_instance 0
	set a [expr $xstep * $ystep ]
	set nano_xstep [expr $xstep/10]
	set nano_ystep [expr $ystep/10]
	set nano_area [expr $nano_xstep * $nano_ystep]
	foreach inst_name $instList {
		set inst_bbox [dbInstBox [dbGetInstByName $inst_name]]
		set illx [dbDBUToMicrons [dbBoxLLX  $inst_bbox  ] ]
		set illy [dbDBUToMicrons [dbBoxLLY  $inst_bbox  ] ]
		set iurx [dbDBUToMicrons [dbBoxURX  $inst_bbox  ] ]
		set iury [dbDBUToMicrons [dbBoxURY  $inst_bbox  ] ] 

		set inst_box "$illx $illy $iurx $iury"
		set instwidth  [expr $iurx - $illx]
		set instheight [expr $iury - $illy ]
		set all_boxes [splitPolygon $inst_box $xstep $ystep] 
		foreach side $sides { 
			puts "Working on side $side"
			set count 0
			set nano_count 0
			foreach el $all_boxes {
				set flag 0
				##puts "Working on element $el"
				foreach pair $MH_pair {
					##puts "Working on pair $pair"
					set layer  [lindex $pair 0]
                                	set height [lindex $pair 1]
					set d [FindTan $height $angle]

					set tllx [lindex $el 0]
					set tlly [lindex $el 1]
					set turx [lindex $el 2]
					set tury [lindex $el 3]

					if {$angle != 0 } {
					switch $side {
						E {
							set newllx [expr $tllx + $d]
							set newlly $tlly
							set newurx [expr $turx + $d]
							set newury $tury
						}

						W {
							set newllx [expr $tllx - $d]
							set newlly $tlly
							set newurx [expr $turx - $d]
							set newury $tury
						}

						N {
						##	puts "Inside north"
							set newllx $tllx
							set newlly [expr $tlly + $d]
							set newurx $turx
							set newury [expr $tury + $d]
						}

						S {
							set newllx $tllx
							set newlly [expr $tlly - $d]
							set newurx $turx
							set newury [expr $tury - $d]
						}
					}
					} else {
							set newllx $tllx
							set newlly $tlly
							set newurx $turx
							set newury $tury
					}
					set new_el_box "$newllx $newlly $newurx $newury"
					##puts "The el box is $el"
					##puts "The modified el box is $new_el_box"
					foreach queryObj [dbQuery -area $new_el_box -objType {wire special}] {
                                                if { [dbIsObjWire $queryObj]} {
                                                        set queryObj_layer [dbWireZ $queryObj]
                                                } else {
                                                        set queryObj_layer [dbStripBoxZ $queryObj]
                                                }
                                                if { $queryObj_layer == $layer } {
							set flag 1
                                                }
					}
					
				}
				if {$flag == 0} {
					add_gui_shape -layer my_layer_1 -rect $new_el_box
					incr count 1 
				}
			}
		set tot_area [expr ($count * $a) + ($nano_count * $nano_area)]
		set instArea [expr $instwidth * $instheight]
		set perc_exposed [expr $tot_area / $instArea * 100]
		puts "Total area is $tot_area"
		puts "Instance area is $instArea"
		puts "Instance: $inst_name  angle  : $angle  side : $side  Exposed: $perc_exposed"
		puts $of "Instance: $inst_name  angle  : $angle  side : $side  Exposed: $perc_exposed"
		}

		

	incr count_instance 1 

	puts "Completed $count_instance"

	}

##set average_perc [expr $all_exposed_perc / $count_instance]
####puts "Average perc exposed $average_perc"		
##puts $of "Average perc exposed $average_perc"		
	close $of
}
