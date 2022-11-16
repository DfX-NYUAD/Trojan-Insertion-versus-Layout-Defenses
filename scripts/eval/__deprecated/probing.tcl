#package require ghclip

#source scripts/GetCrossPoly.tcl

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

proc getSelect { } {

	set instList ""
	foreach inst [get_db selected ] { 
		set instName [get_db $inst .name]
		lappend instList $instName
	}
	
	return $instList
}

proc genInstList { } {

	set selCount [llength [get_db selected ] ]

	if { $selCount == 0 } {
		##puts "No selected Instances. Hence using InstList.tcl in the work directory"
		if { [file exists InstList.tcl] } {
			source InstList.tcl
		} else {
			##puts "Neither any selected instances nor InstList.tcl present."
			##puts " Please make sure to choose an instance or create this file with instance lists"
		}
	} else {
		##puts "Total $selCount instances are selected for Analysis"
		set instList [getSelect]
		}

return $instList
}


proc getInstBox { inst_name } {

	set ibox [dbInstBox [dbGetInstByName $inst_name ] ]
        set illx [dbDBUToMicrons [dbBoxLLX  $ibox  ] ]
        set illy [dbDBUToMicrons [dbBoxLLY  $ibox  ] ]
        set iurx [dbDBUToMicrons [dbBoxURX  $ibox  ] ]
        set iury [dbDBUToMicrons [dbBoxURY  $ibox  ] ]

        set inst_box "$illx $illy $iurx $iury"

return $inst_box

}

proc convert_box_to_poly  { box } {

        set llx [lindex $box  0]
        set lly [lindex $box  1]
        set urx [lindex $box  2]
        set ury [lindex $box  3]

        set poly "$llx $lly $urx $lly $urx $ury $llx $ury $llx $lly"

        return $poly
}

proc shiftBox { box d side } {

	set llx [lindex $box 0]	
	set lly [lindex $box 1]	
	set urx [lindex $box 2]	
	set ury [lindex $box 3]	

	##puts "Shifting the box $box for offset $d and for side $side"

	switch $side {
		
		E {
			set newllx [expr $llx + $d ]
			set newlly $lly
			set newurx [expr $urx + $d ] 
			set newury $ury
			set shift_box "$newllx $newlly $newurx $newury"
		}

		W {
			set newllx [expr $llx - $d ]
			set newlly $lly
			set newurx [expr $urx - $d ] 
			set newury $ury
			set shift_box "$newllx $newlly $newurx $newury"
		}

		N {
			set newllx $llx
			set newlly [expr $lly + $d]
			set newurx $urx
			set newury [expr $ury + $d]
			set shift_box "$newllx $newlly $newurx $newury"
		}

		S {
			set newllx $llx
			set newlly [expr $lly - $d]
			set newurx $urx
			set newury [expr $ury - $d]
			set shift_box "$newllx $newlly $newurx $newury"
		}
		
		NA {

			set newllx $llx
			set newlly $lly
			set newurx $urx
			set newury $ury 
			set shift_box "$newllx $newlly $newurx $newury"
		}
		

	}

return $shift_box

}

proc reOrderPoly { poly } {
	set box [convert_poly_to_box $poly]
	set llx [lindex $box 0 ]
	set lly [lindex $box 1 ]
	set urx [lindex $box 2 ]
	set ury [lindex $box 3 ]
	set OrderPoly "$llx $lly $urx $lly $urx $ury $llx $ury $llx $lly"

return $OrderPoly
}

proc filterPoly { poly_list } {

	set filteredPoly ""
	foreach poly $poly_list {
		if {$poly != "" } {
			lappend filteredPoly $poly
		}
	}
return $filteredPoly
}

proc adjustBoxforAnd { poly1 poly2 } {
	set box1 [convert_poly_to_box $poly1]
	set llx1 [lindex  $box1 0 ]
        set lly1 [lindex  $box1 1 ]
        set urx1 [lindex  $box1 2 ]
        set ury1 [lindex  $box1 3 ]

	set box2 [convert_poly_to_box $poly2]
	set llx2 [lindex  $box2 0 ]
        set lly2 [lindex  $box2 1 ]
        set urx2 [lindex  $box2 2 ]
        set ury2 [lindex  $box2 3 ]
	
	if { $llx1 == $llx2 } {
		set llx2 [expr $llx2 - 0.02 ]
	}
	if { $llx1 == $urx2 } {
		set urx2 [expr $urx2 - 0.02 ]
	}
	if { $lly1 == $lly2 } {
	        set lly2 [expr $lly2 - 0.02 ]
	}
	if { $lly1 == $ury2 } {
	        set ury2 [expr $ury2 - 0.02 ]
	}
	if { $urx1 == $urx2 } {
	        set urx2 [expr $urx2 + 0.02 ]
	}
	if { $urx1 == $llx2 } {
	        set llx2 [expr $llx2 + 0.02 ]
	}
	if { $ury1 == $ury2} {
	        set ury2 [expr $ury2 + 0.02 ]
	}
	if { $ury1 == $lly2} {
	        set lly2 [expr $lly2 + 0.02 ]
	}
	set out "$llx2 $lly2 $urx2 $lly2 $urx2 $ury2 $llx2 $ury2 $llx2 $lly2"
	set outPoly [regsub "{" [regsub "}" $out ""] "" ]

return $outPoly

}


proc genAndPoly { poly_collection } {
	
	set temp $poly_collection
	set allAndPoly ""
	set andArea 0

	##puts "Inside genAndPoly procedure"
	##puts "The poly collection is $poly_collection"
	
	foreach poly_list $poly_collection {
		set temp [lreplace $temp 0 0 ]
		foreach poly $poly_list {
			##puts "Working on poly $poly"
			set OrderPoly [reOrderPoly $poly ]
			##puts "The Ordered poly is $OrderPoly"
			foreach temp_poly $temp {
				foreach temp_sub_poly $temp_poly {
					##puts "The sub poly of temp is $temp_sub_poly"
					set OrderNextPoly [reOrderPoly $temp_sub_poly]
					set adjustedPoly [ adjustBoxforAnd $OrderPoly $OrderNextPoly ]
					##puts "The OrderPoly is $OrderPoly"
					##puts "The OrderNextPoly is $OrderNextPoly"
					set AndPoly [ghclip::clip $OrderPoly AND $adjustedPoly]
					##puts "The AndPoly is $AndPoly"
					lappend allAndPoly $AndPoly
					set nano_area  0
                        		if { $AndPoly != ""} {
                        			foreach element $AndPoly {
							#set element_box [convert_poly_to_box $element ]
							###puts "The element box inside the And poly is $element_box"
							set box_area [parea $element]
							##puts "The box Area is $box_area"
                        				set nano_area [expr $nano_area + $box_area]
                        			}

					set andArea [expr $andArea + $nano_area]

                        		} 
					
				}
			}
		}
	}

return $andArea

}
proc shiftPolyListOpp { polyList offset side } {

	##puts "Inside the procedure to shiftPoly back"
	set shiftedPolyList ""

	foreach poly $polyList {

		set box [convert_poly_to_box $poly ]	
		##puts "Converting box $box"
		
		switch $side {

			E {
				set shiftedBox [shiftBox $box $offset W]
			}

			W {
				set shiftedBox [shiftBox $box $offset E]
			}

			N {
				set shiftedBox [shiftBox $box $offset S]
			}

			S {
				set shiftedBox [shiftBox $box $offset N]
			}
		}

		set shiftedPoly [convert_box_to_poly $shiftedBox ]
		lappend shiftedPolyList $shiftedPoly
	}	

		
	##puts "The shifted poly list is $shiftedPolyList"

return $shiftedPolyList

}

proc FindTan { height angle } {

	switch $angle {

		30 {
			set d [expr $height*0.5774]
		}

		45 {
			set d $height
		}

		60 {
			set d [expr $height*1.732]
		}

		0 {
			set d 0
		}
	}

return $d

}

proc Probe { angle } {


	set of [open ./Analysis.rpt w]

	puts $of "INSTANCE_NAME \t PERC_EXPOSED"

	##puts "Starting the probing analysis for angle $angle"	
	set instList  [genInstList]	

	##puts "The Instance list chosen for analysis is $instList"
	
	#Below is the pair list of metal layer and its corresponding height from base layers. Obtained from tech lef"
	set MH_pair "{1 0.37} {2 0.62} {3 0.88} {4 1.14} {5 1.71} {6 2.28} {7 2.85} {8 4.47} {9 6.09} {10 10.09}"

	#Various sides analysed for probing.
	if { $angle != 0 } {
		set sides "E W N S"
	} else {
		set sides "N"
	}

	foreach inst $instList {
		
		##puts "Working on instance $inst"	

		set inst_box [getInstBox $inst]

	 	##puts "The instance box is $inst_box"

		set instArea [boxArea $inst_box ]
		##puts "Instance area is $instArea"

		foreach side $sides {

			##puts "Working for side $side"

			set mergedPolygonList ""
			set preShiftmergedPolygonList ""
			set AllCrossPolyforInstSide ""
			set AllCrossPolypreShift ""
			set AllCrossPolyArea 0

			foreach pair $MH_pair {
				set layer  [lindex $pair 0]
				set height [lindex $pair 1]
				##puts "Looking in to layer $layer. Its height is $height"
				set d [FindTan $height $angle]
				##puts "The offset drift for angle $angle for layer $layer is $d"
				set shifted_inst_box [shiftBox $inst_box $d $side]
				##puts "Shifted inst box is $shifted_inst_box"
				set result [GetCrossPoly $shifted_inst_box $layer ]	
				set CrossPoly [lsort -u [lreplace $result end end] ]
				set cross_poly_area [lindex $result end]
				##puts "The CrossPoly is $CrossPoly and area is $cross_poly_area"
				if { [llength $CrossPoly ] != 0 } {
					##puts "The CrossPoly is not empty"
					set AllCrossPolyArea [expr $AllCrossPolyArea + $cross_poly_area]
					set filteredPoly [filterPoly $CrossPoly ]
					set shiftedCrossPoly [ shiftPolyListOpp $filteredPoly $d $side]	
					set AllCrossPolypreShift [ lappend AllCrossPolypreShift $filteredPoly]
					set AllCrossPolyforInstSide [lappend AllCrossPolyforInstSide $shiftedCrossPoly]
				}
			
			}
				##puts "All Cross polygons pre shift are $AllCrossPolypreShift"
				##puts "All Cross polygons post shift are $AllCrossPolyforInstSide"
				set andArea [genAndPoly $AllCrossPolyforInstSide]
				##puts "And area for side $side is $andArea"	
				set exposedArea [expr $instArea - $AllCrossPolyArea + $andArea ]

				set perc_exposed [expr $exposedArea / $instArea * 100]
				puts "Exposed percentage for angle $angle for side $side is $perc_exposed"

				set mergedPolygonList [ lappend mergedPolygonList $AllCrossPolyforInstSide ]
				set preShiftmergedPolygonList [ lappend preShiftmergedPolygonList $AllCrossPolypreShift]
			
				puts $of "$inst $side $perc_exposed"
		}

	}

#return $mergedPolygonList
#return $preShiftmergedPolygonList
close $of
}



