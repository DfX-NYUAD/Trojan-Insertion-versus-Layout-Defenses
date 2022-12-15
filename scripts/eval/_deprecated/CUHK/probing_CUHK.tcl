namespace eval CUHK {
    # create variable inside the namespace   
    variable foo
}; # create namespace to avoid conflict with innovus' original commands

proc CUHK::load_net_assets {} {
    # read nets.assets and return a list

    set infile [open "nets.assets" r]
    set net_assets {}
    while { [gets $infile line] >= 0} {
        lappend net_assets $line
    }
    # puts $net_assets
    close $infile
    return $net_assets
}

proc CUHK::load_cell_assets {} {
    # read nets.assets and return a list

    set infile [open "cells.assets" r]
    set cell_assets {}
    while { [gets $infile line] >= 0} {
        lappend cell_assets $line
    }
    # puts $cell_assets
    close $infile
    return $cell_assets
}
# Notes: to highligh/dehighlight cell/net assets, can use gui_highlight/gui_clear_highlight command 
# e.g., set ca [loadCellAssets]; set na [loadNetAssets]; gui_highlight $ca -auto_color ; gui_clear_highlight $ca

proc CUHK::summarize_assets {} {
    upvar net_assets net_assets
    upvar cell_assets cell_assets
    
    # 1. write cell assets
    set fp_cells [open "cells_summary.rpt" w+]
    foreach ca $cell_assets {
        set cell_name [get_db $ca .name]
        set ca_box [get_db $ca .bbox]
        set ca_box [lindex $ca_box 0]
        puts $fp_cells "( $cell_name $ca_box )"
    }
    close $fp_cells
    
    # 2. write nets
    set fp_nets [open "nets_summary.rpt" w+]

    # 2.1 write net asssets
    foreach net $net_assets {
        set net_name [get_db $net .name]
        set is_asset 1
        
        # regular wires
        foreach wire [get_db $net .wires] {
            set wire_rect [get_db $wire .rect]
            set wire_rect [lindex $wire_rect 0]
            puts $fp_nets "( $wire $net_name $wire_rect [get_db $wire .layer] $is_asset )"
        }

        # regular vias
        foreach via [get_db $net .vias] {
            set via_bottom_metal [get_db $via .bottom_rects]
            set via_bottom_metal [lindex $via_bottom_metal 0]
            set via_top_metal [get_db $via .top_rects]
            set via_top_metal [lindex $via_top_metal 0]
            puts $fp_nets "( ${via}_bottom $net_name $via_bottom_metal [get_db $via .via_def.bottom_layer] $is_asset )"; 
            puts $fp_nets "( ${via}_top $net_name $via_top_metal [get_db $via .via_def.top_layer] $is_asset )"
        }

        # special wires
        foreach wire [get_db $net .special_wires] {
            set wire_rect [get_db $wire .rect]
            set wire_rect [lindex $wire_rect 0]
            puts $fp_nets "( $wire $net_name $wire_rect [get_db $wire .layer] $is_asset )"
        }

        # special vias
        foreach via [get_db $net .special_vias] {
            set via_bottom_metal [get_db $via .bottom_rects]
            set via_bottom_metal [lindex $via_bottom_metal 0]
            set via_top_metal [get_db $via .top_rects]
            set via_top_metal [lindex $via_top_metal 0]
            puts $fp_nets "( ${via}_bottom $net_name $via_bottom_metal [get_db $via .via_def.bottom_layer] $is_asset )"; 
            puts $fp_nets "( ${via}_top $net_name $via_top_metal [get_db $via .via_def.top_layer] $is_asset )"
        }
    }

    # 2.2 write non-asset and non-power nets
    set pg_nets [get_db pg_nets]
    foreach net [get_db nets] {

        # skip assets and pg nets
        if { $net in $net_assets || $net in $pg_nets} {
            continue
        }

        set net_name [get_db $net .name]
        set is_asset 0
        
        # regular wires
        foreach wire [get_db $net .wires] {
            set wire_rect [get_db $wire .rect]
            set wire_rect [lindex $wire_rect 0]
            puts $fp_nets "( $wire $net_name $wire_rect [get_db $wire .layer] $is_asset )"
        }

        # regular vias
        foreach via [get_db $net .vias] {
            set via_bottom_metal [get_db $via .bottom_rects]
            set via_bottom_metal [lindex $via_bottom_metal 0]
            set via_top_metal [get_db $via .top_rects]
            set via_top_metal [lindex $via_top_metal 0]
            puts $fp_nets "( ${via}_bottom $net_name $via_bottom_metal [get_db $via .via_def.bottom_layer] $is_asset )"; 
            puts $fp_nets "( ${via}_top $net_name $via_top_metal [get_db $via .via_def.top_layer] $is_asset )"
        }

        # special wires
        foreach wire [get_db $net .special_wires] {
            set wire_rect [get_db $wire .rect]
            set wire_rect [lindex $wire_rect 0]
            puts $fp_nets "( $wire $net_name $wire_rect [get_db $wire .layer] $is_asset )"
        }

        # special vias
        foreach via [get_db $net .special_vias] {
            set via_bottom_metal [get_db $via .bottom_rects]
            set via_bottom_metal [lindex $via_bottom_metal 0]
            set via_top_metal [get_db $via .top_rects]
            set via_top_metal [lindex $via_top_metal 0]
            puts $fp_nets "( ${via}_bottom $net_name $via_bottom_metal [get_db $via .via_def.bottom_layer] $is_asset )"; 
            puts $fp_nets "( ${via}_top $net_name $via_top_metal [get_db $via .via_def.top_layer] $is_asset )"
        }
    }

    # 2.3 write pg nets
    foreach net $pg_nets {

        set net_name [get_db $net .name]
        set is_asset 0
        
        # regular wires
        foreach wire [get_db $net .wires] {
            set wire_rect [get_db $wire .rect]
            set wire_rect [lindex $wire_rect 0]
            puts $fp_nets "( $wire $net_name $wire_rect [get_db $wire .layer] $is_asset )"
        }

        # regular vias
        foreach via [get_db $net .vias] {
            set via_bottom_metal [get_db $via .bottom_rects]
            set via_bottom_metal [lindex $via_bottom_metal 0]
            set via_top_metal [get_db $via .top_rects]
            set via_top_metal [lindex $via_top_metal 0]
            puts $fp_nets "( ${via}_bottom $net_name $via_bottom_metal [get_db $via .via_def.bottom_layer] $is_asset )"; 
            puts $fp_nets "( ${via}_top $net_name $via_top_metal [get_db $via .via_def.top_layer] $is_asset )"
        }

        # special wires
        foreach wire [get_db $net .special_wires] {
            set wire_rect [get_db $wire .rect]
            set wire_rect [lindex $wire_rect 0]
            puts $fp_nets "( $wire $net_name $wire_rect [get_db $wire .layer] $is_asset )"
        }

        # special vias
        foreach via [get_db $net .special_vias] {
            set via_bottom_metal [get_db $via .bottom_rects]
            set via_bottom_metal [lindex $via_bottom_metal 0]
            set via_top_metal [get_db $via .top_rects]
            set via_top_metal [lindex $via_top_metal 0]
            puts $fp_nets "( ${via}_bottom $net_name $via_bottom_metal [get_db $via .via_def.bottom_layer] $is_asset )"; 
            puts $fp_nets "( ${via}_top $net_name $via_top_metal [get_db $via .via_def.top_layer] $is_asset )"
        }
    }

    close $fp_nets
}
