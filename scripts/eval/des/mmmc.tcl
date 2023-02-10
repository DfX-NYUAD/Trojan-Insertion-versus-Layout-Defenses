####
#
# Script for ISPD'23 contest. Mohammad Eslami and Samuel Pagliarini, TalTech, in collaboration with Johann Knechtel, NYUAD
#
####

create_library_set -name tc -timing {ASAP7/asap7sc7p5t_AO_LVT_TT_nldm_211120.lib   ASAP7/asap7sc7p5t_INVBUF_LVT_TT_nldm_220122.lib   ASAP7/asap7sc7p5t_OA_LVT_TT_nldm_211120.lib   ASAP7/asap7sc7p5t_SEQ_LVT_TT_nldm_220123.lib   ASAP7/asap7sc7p5t_SIMPLE_LVT_TT_nldm_211120.lib \
        ASAP7/asap7sc7p5t_AO_SLVT_TT_nldm_211120.lib  ASAP7/asap7sc7p5t_INVBUF_SLVT_TT_nldm_220122.lib  ASAP7/asap7sc7p5t_OA_SLVT_TT_nldm_211120.lib  ASAP7/asap7sc7p5t_SEQ_SLVT_TT_nldm_220123.lib  ASAP7/asap7sc7p5t_SIMPLE_SLVT_TT_nldm_211120.lib}

create_constraint_mode -name sdc -sdc_files {design.sdc}

create_rc_corner -name rc_typ_25 -qx_tech_file ASAP7/qrcTechFile_typ03_scaled4xV06 -T 25

create_delay_corner -name delay_tc -library_set {tc} -rc_corner {rc_typ_25}
create_analysis_view -name view_tc -constraint_mode {sdc} -delay_corner {delay_tc}
set_analysis_view -setup {view_tc} -hold {view_tc}
