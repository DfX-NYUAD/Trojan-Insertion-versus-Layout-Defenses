setMultiCpuUsage -localCpu 1

loadLefFile NangateOpenCellLibrary.lef
loadDefFile design.def

source probing_procs.tcl
source probing.tcl

set fl [open cells.assets r]
set instList [split [read $fl] '\n']
close $fl
## trim last dummy entry which is empty, arising from split '\n'
# would make scripts fail otherwise
set instList [lrange $instList 0 end-1]

## controls accuracy and speed; the smaller the numbers, the more accurate, but the more slow
set xstep 0.0501
set ystep 0.0501
#set xstep 0.1501
#set ystep 0.1501

splitPolygonAngledProbe $instList 0 $xstep $ystep cells_ea.rpt

exit
