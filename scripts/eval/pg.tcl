####
# settings
####
setMultiCpuUsage -localCpu 1

####
# init
####
loadLefFile NangateOpenCellLibrary.lef
loadDefFile design.def

####
# execute
####
source pg_procedures.tcl
pg_mesh_details

####
# mark done; exit
####
date > DONE.pg
exit
