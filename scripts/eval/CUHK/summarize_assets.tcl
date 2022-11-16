set_multi_cpu_usage -local_cpu 1

set lef_path NangateOpenCellLibrary.lef
set def_path design.def
set netlist_path design.v

read_physical -lefs $lef_path
read_netlist $netlist_path
read_def $def_path -preserve_shape

init_design

source probing_CUHK.tcl

# load assets
set cell_asset_names [ CUHK::load_cell_assets ]
set net_asset_names [ CUHK::load_net_assets ]

# mark assets as dont touch; procedures are based on that property
set_dont_touch $cell_asset_names true
set_dont_touch $net_asset_names true

set cell_assets [get_db insts -if {.dont_touch == true} ]
set net_assets [get_db nets -if {.dont_touch == true} ]

# run reporting of nets and cells assets from layout db
CUHK::summarize_assets

date > DONE.assets
exit
