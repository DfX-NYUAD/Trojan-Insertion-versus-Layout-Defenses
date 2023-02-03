####
#
# Script for ISPD'23 contest. Johann Knechtel, NYUAD, in collaboration with Mohammad Eslami and Samuel Pagliarini, TalTech
#
####

## library_sets
create_library_set -name TT_library_set \
    -timing {ASAP7/asap7sc7p5t_AO_LVT_TT_nldm_211120.lib ASAP7/asap7sc7p5t_AO_SLVT_TT_nldm_211120.lib ASAP7/asap7sc7p5t_INVBUF_LVT_TT_nldm_220122.lib ASAP7/asap7sc7p5t_INVBUF_SLVT_TT_nldm_220122.lib ASAP7/asap7sc7p5t_OA_LVT_TT_nldm_211120.lib ASAP7/asap7sc7p5t_OA_SLVT_TT_nldm_211120.lib ASAP7/asap7sc7p5t_SEQ_LVT_TT_nldm_220123.lib ASAP7/asap7sc7p5t_SEQ_SLVT_TT_nldm_220123.lib ASAP7/asap7sc7p5t_SIMPLE_LVT_TT_nldm_211120.lib ASAP7/asap7sc7p5t_SIMPLE_SLVT_TT_nldm_211120.lib}

### opcond
## NOTE opcond is optional; useful for setting different conditions w/o changing library itself; not needed here
#create_opcond -name TT_opcond -process 1.0 -voltage 0.7 -temperature 25.0

## timing_condition
create_timing_condition -name TT_timing_cond \
    -library_sets { TT_library_set }
#    -opcond TT_opcond

## rc_corner
create_rc_corner -name TT_rc_corner \
    -T 25 \
    -qrc_tech ASAP7/qrcTechFile_typ03_scaled4xV06

## delay_corner
create_delay_corner -name TT_delay_corner \
    -early_timing_condition { TT_timing_cond } \
    -late_timing_condition { TT_timing_cond } \
    -early_rc_corner TT_rc_corner \
    -late_rc_corner TT_rc_corner

## constraint_mode
# NOTE the files must also contain clock propagation constraints
create_constraint_mode -name TT_constraints \
    -sdc_files { design.sdc latency.sdc }

## analysis_view
create_analysis_view -name TT_view \
    -constraint_mode TT_constraints \
    -delay_corner TT_delay_corner

## set_analysis_view
set_analysis_view \
    -setup { TT_view } \
    -hold { TT_view }
