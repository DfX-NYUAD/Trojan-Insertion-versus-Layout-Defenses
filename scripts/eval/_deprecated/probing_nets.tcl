setMultiCpuUsage -localCpu 1

loadLefFile NangateOpenCellLibrary.lef
loadDefFile design.def

source probing_procs.tcl
source probing.tcl

set fl [open nets.assets r]
set netList [split [read $fl] '\n']
close $fl
## trim last dummy entry which is empty, arising from split '\n'
# would make scripts fail otherwise
set netList [lrange $netList 0 end-1]

## controls accuracy and speed; the smaller the numbers, the more accurate, but the more slow
## orig values; too slow
#set xstep 0.0101
#set ystep 0.0101
## prior values; accuracy probably not good
#set xstep 0.1001
#set ystep 0.1001
set xstep 0.0501
set ystep 0.0501

FindExposedAreaNet $netList $xstep $ystep nets_ea.rpt

exit
