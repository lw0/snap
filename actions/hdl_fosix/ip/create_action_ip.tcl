
## Env Variables

set action_root [lindex $argv 0]
set fpga_part  	[lindex $argv 1]
#set fpga_part    xcvu9p-flgb2104-2l-e
#set action_root ../

set aip_dir 	$action_root/ip
set log_dir     $action_root/../../hardware/logs
set log_file    $log_dir/create_action_ip.log
set src_dir 	$aip_dir/action_ip_prj/action_ip_prj.srcs/sources_1/ip

## Create a new Vivado IP Project
puts "\[CREATE_ACTION_IPs..........\] start [clock format [clock seconds] -format {%T %a %b %d/ %Y}]"
puts "                        FPGACHIP = $fpga_part"
puts "                        ACTION_ROOT = $action_root"
puts "                        Creating IP in $src_dir"
create_project action_ip_prj $aip_dir/action_ip_prj -force -part $fpga_part -ip >> $log_file

# Project IP Settings
# General

puts "                        Generating BRAMw256x32r16x512 ......"
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name \
  BRAMw256x32r16x512 >> $log_file
set_property -dict [list \
    CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
    CONFIG.Assume_Synchronous_Clk {true} \
    CONFIG.Write_Width_A {32} \
    CONFIG.Write_Depth_A {256} \
    CONFIG.Read_Width_A {32} \
    CONFIG.Operating_Mode_A {NO_CHANGE} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Write_Width_B {512} \
    CONFIG.Read_Width_B {512} \
    CONFIG.Operating_Mode_B {READ_FIRST} \
    CONFIG.Enable_B {Always_Enabled} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {true}] \
  [get_ips BRAMw256x32r16x512] >> $log_file
set_property generate_synth_checkpoint false \
  [get_files $src_dir/BRAMw256x32r16x512/BRAMw256x32r16x512.xci] >> $log_file
generate_target {instantiation_template} \
  [get_files $src_dir/BRAMw256x32r16x512/BRAMw256x32r16x512.xci] >> $log_file

puts "                        Generating BRAMw256x64r256x64 ......"
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name \
  BRAMw256x64r256x64 >> $log_file
set_property -dict [list \
    CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
    CONFIG.Assume_Synchronous_Clk {true} \
    CONFIG.Write_Width_A {64} \
    CONFIG.Read_Width_A {64} \
    CONFIG.Write_Depth_A {256} \
    CONFIG.Operating_Mode_A {NO_CHANGE} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Write_Width_B {64} \
    CONFIG.Read_Width_B {64} \
    CONFIG.Operating_Mode_B {READ_FIRST} \
    CONFIG.Enable_B {Always_Enabled} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {true}] \
  [get_ips BRAMw256x64r256x64] >> $log_file
set_property generate_synth_checkpoint false \
  [get_files $src_dir/BRAMw256x64r256x64/BRAMw256x64r256x64.xci] >> $log_file
generate_target {instantiation_template} \
  [get_files $src_dir/BRAMw256x64r256x64/BRAMw256x64r256x64.xci] >> $log_file

close_project
puts "\[CREATE_ACTION_IPs..........\] done  [clock format [clock seconds] -format {%T %a %b %d %Y}]"
