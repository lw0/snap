open_project "hls_operator_sln_xcku060-ffva1156-2-e"

set_top hls_filter

# Can that be a list?
foreach file [ list hls_filter.cpp ] {
  add_files ${file} -cflags " -I/home/lwenzel/sync/study/18ma/snap_fosix/actions/include -I/home/lwenzel/sync/study/18ma/snap_fosix/software/include -I../../../software/examples -I../include"
  add_files -tb ${file} -cflags " -DNO_SYNTH -I/home/lwenzel/sync/study/18ma/snap_fosix/actions/include -I/home/lwenzel/sync/study/18ma/snap_fosix/software/include -I../../../software/examples -I../include"
}

open_solution "hls_operator_sln"
set_part xcku060-ffva1156-2-e

create_clock -period 4 -name default
config_interface -m_axi_addr64=true
#config_rtl -reset all -reset_level low

csynth_design
#export_design -format ip_catalog -rtl vhdl
exit
