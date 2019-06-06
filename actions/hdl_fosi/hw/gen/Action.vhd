library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosi_axi.all;
use work.fosi_blockmap.all;
use work.fosi_ctrl.all;
use work.fosi_stream.all;
use work.fosi_user.all;
use work.fosi_util.all;

entity Action is
  port (
    pi_clk     : in  std_logic;
    pi_rst_n   : in  std_logic;
    po_intReq  : out std_logic;
    po_intSrc  : out t_InterruptSrc;
    pi_intAck  : in  std_logic;

    -- Ports of Axi Slave Bus Interface AXI_CTRL_REG
    pi_ctrl_ms : in  t_Ctrl_ms;
    po_ctrl_sm : out t_Ctrl_sm;

    -- Ports of Axi Master Bus Interface AXI_HOST_MEM
    po_hmem_ms : out t_NativeAxi_ms;
    pi_hmem_sm : in  t_NativeAxi_sm;

    -- Ports of Axi Master Bus Interface AXI_CARD_MEM0
    po_cmem_ms : out t_NativeAxi_ms;
    pi_cmem_sm : in  t_NativeAxi_sm;

    -- Ports of Axi Master Bus Interface AXI_NVME
    po_nvme_ms : out t_Ctrl_ms;
    pi_nvme_sm : in  t_Ctrl_sm;

    po_context : out t_Context);
end Action;

architecture Action of Action is

  -----------------------------------------------------------------------------
  -- Register Port Map Configuration
  -----------------------------------------------------------------------------
  constant c_Ports : t_RegMap(0 to 10-1) := (
    (to_unsigned(0, c_RegAddrWidth), to_unsigned(16, c_RegAddrWidth)),
    (to_unsigned(16, c_RegAddrWidth), to_unsigned(2, c_RegAddrWidth)),
    (to_unsigned(20, c_RegAddrWidth), to_unsigned(1, c_RegAddrWidth)),
    (to_unsigned(24, c_RegAddrWidth), to_unsigned(1, c_RegAddrWidth)),
    (to_unsigned(32, c_RegAddrWidth), to_unsigned(4, c_RegAddrWidth)),
    (to_unsigned(36, c_RegAddrWidth), to_unsigned(4, c_RegAddrWidth)),
    (to_unsigned(40, c_RegAddrWidth), to_unsigned(4, c_RegAddrWidth)),
    (to_unsigned(44, c_RegAddrWidth), to_unsigned(4, c_RegAddrWidth)),
    (to_unsigned(48, c_RegAddrWidth), to_unsigned(16, c_RegAddrWidth)),
    (to_unsigned(64, c_RegAddrWidth), to_unsigned(40, c_RegAddrWidth)));
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Signal Declaration
  -----------------------------------------------------------------------------
  signal s_ctrlRegs_ms : t_RegPort_ms;
  signal s_ctrlRegs_sm : t_RegPort_sm;
  signal s_ENV_ready_v : t_Logic_v(6-1 downto 0);
  signal s_ENV_regPorts_v_ms : t_RegPort_v_ms(10-1 downto 0);
  signal s_ENV_regPorts_v_sm : t_RegPort_v_sm(10-1 downto 0);
  signal s_regsSwitch_ms : t_RegPort_ms;
  signal s_regsSwitch_sm : t_RegPort_sm;
  signal s_regsSource_ms : t_RegPort_ms;
  signal s_regsSource_sm : t_RegPort_sm;
  signal s_regsSink_ms : t_RegPort_ms;
  signal s_regsSink_sm : t_RegPort_sm;
  signal s_regsHRd_ms : t_RegPort_ms;
  signal s_regsHRd_sm : t_RegPort_sm;
  signal s_regsHWr_ms : t_RegPort_ms;
  signal s_regsHWr_sm : t_RegPort_sm;
  signal s_regsCRd_ms : t_RegPort_ms;
  signal s_regsCRd_sm : t_RegPort_sm;
  signal s_regsCWr_ms : t_RegPort_ms;
  signal s_regsCWr_sm : t_RegPort_sm;
  signal s_regsExtStore_ms : t_RegPort_ms;
  signal s_regsExtStore_sm : t_RegPort_sm;
  signal s_regsMon_ms : t_RegPort_ms;
  signal s_regsMon_sm : t_RegPort_sm;
  signal s_start : t_Logic;
  signal s_intExtStore_ms : t_Handshake_ms;
  signal s_intExtStore_sm : t_Handshake_sm;
  signal s_cmem_ms : t_NativeAxi_ms;
  signal s_cmem_sm : t_NativeAxi_sm;
  signal s_hmem_ms : t_NativeAxi_ms;
  signal s_hmem_sm : t_NativeAxi_sm;
  signal s_readyHRd : t_Logic;
  signal s_readyHWr : t_Logic;
  signal s_readyCRd : t_Logic;
  signal s_readyCWr : t_Logic;
  signal s_readySrc : t_Logic;
  signal s_readySnk : t_Logic;
  signal s_hmemRd_ms : t_NativeAxiRd_ms;
  signal s_hmemRd_sm : t_NativeAxiRd_sm;
  signal s_hmemWr_ms : t_NativeAxiWr_ms;
  signal s_hmemWr_sm : t_NativeAxiWr_sm;
  signal s_cmemRd_ms : t_NativeAxiRd_ms;
  signal s_cmemRd_sm : t_NativeAxiRd_sm;
  signal s_cmemWr_ms : t_NativeAxiWr_ms;
  signal s_cmemWr_sm : t_NativeAxiWr_sm;
  signal s_hmemRdLog_ms : t_NativeAxiRd_ms;
  signal s_hmemRdLog_sm : t_NativeAxiRd_sm;
  signal s_extmapHRd_ms : t_BlkMap_ms;
  signal s_extmapHRd_sm : t_BlkMap_sm;
  signal s_hmemWrLog_ms : t_NativeAxiWr_ms;
  signal s_hmemWrLog_sm : t_NativeAxiWr_sm;
  signal s_extmapHWr_ms : t_BlkMap_ms;
  signal s_extmapHWr_sm : t_BlkMap_sm;
  signal s_cmemRdLog_ms : t_NativeAxiRd_ms;
  signal s_cmemRdLog_sm : t_NativeAxiRd_sm;
  signal s_extmapCRd_ms : t_BlkMap_ms;
  signal s_extmapCRd_sm : t_BlkMap_sm;
  signal s_cmemWrLog_ms : t_NativeAxiWr_ms;
  signal s_cmemWrLog_sm : t_NativeAxiWr_sm;
  signal s_extmapCWr_ms : t_BlkMap_ms;
  signal s_extmapCWr_sm : t_BlkMap_sm;
  signal s_stmHRd_ms : t_NativeStream_ms;
  signal s_stmHRd_sm : t_NativeStream_sm;
  signal s_stmHWr_ms : t_NativeStream_ms;
  signal s_stmHWr_sm : t_NativeStream_sm;
  signal s_stmCRd_ms : t_NativeStream_ms;
  signal s_stmCRd_sm : t_NativeStream_sm;
  signal s_stmCWr_ms : t_NativeStream_ms;
  signal s_stmCWr_sm : t_NativeStream_sm;
  signal s_extentStore_ports_v_ms : t_BlkMap_v_ms(4-1 downto 0);
  signal s_extentStore_ports_v_sm : t_BlkMap_v_sm(4-1 downto 0);
  signal s_stmSrc_ms : t_NativeStream_ms;
  signal s_stmSrc_sm : t_NativeStream_sm;
  signal s_stmSnk_ms : t_NativeStream_ms;
  signal s_stmSnk_sm : t_NativeStream_sm;
  signal s_nativeStreamSwitch_stmOut_v_ms : t_NativeStream_v_ms(3-1 downto 0);
  signal s_nativeStreamSwitch_stmOut_v_sm : t_NativeStream_v_sm(3-1 downto 0);
  signal s_nativeStreamSwitch_stmIn_v_ms : t_NativeStream_v_ms(3-1 downto 0);
  signal s_nativeStreamSwitch_stmIn_v_sm : t_NativeStream_v_sm(3-1 downto 0);
  signal s_axiMonitor_stream_v_ms : t_NativeStream_v_ms(3-1 downto 0);
  signal s_axiMonitor_stream_v_sm : t_NativeStream_v_sm(3-1 downto 0);
  signal s_axiMonitor_axiWr_v_ms : t_NativeAxiWr_v_ms(2-1 downto 0);
  signal s_axiMonitor_axiWr_v_sm : t_NativeAxiWr_v_sm(2-1 downto 0);
  signal s_axiMonitor_axiRd_v_ms : t_NativeAxiRd_v_ms(2-1 downto 0);
  signal s_axiMonitor_axiRd_v_sm : t_NativeAxiRd_v_sm(2-1 downto 0);
  -----------------------------------------------------------------------------

begin

  -----------------------------------------------------------------------------
  -- FOSIX Environment
  -----------------------------------------------------------------------------
  -- Handle Axi Ports
  po_hmem_ms <= s_hmem_ms;
  s_hmem_sm <= pi_hmem_sm;

  po_cmem_ms <= s_cmem_ms;
  s_cmem_sm <= pi_cmem_sm;

  po_nvme_ms <= c_CtrlNull_ms;

  -- Demultiplex and Simplify Control Register Ports
  i_ctrlDemux : entity work.CtrlRegDemux
    generic map (
      g_Ports => c_Ports)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_ctrl_ms => pi_ctrl_ms,
      po_ctrl_sm => po_ctrl_sm,
      po_ports_ms => s_ENV_regPorts_v_ms,
      pi_ports_sm => s_ENV_regPorts_v_sm);
  s_ctrlRegs_ms <= s_ENV_regPorts_v_ms(0);
  s_ENV_regPorts_v_sm(0) <= s_ctrlRegs_sm;
  s_regsSwitch_ms <= s_ENV_regPorts_v_ms(1);
  s_ENV_regPorts_v_sm(1) <= s_regsSwitch_sm;
  s_regsSource_ms <= s_ENV_regPorts_v_ms(2);
  s_ENV_regPorts_v_sm(2) <= s_regsSource_sm;
  s_regsSink_ms <= s_ENV_regPorts_v_ms(3);
  s_ENV_regPorts_v_sm(3) <= s_regsSink_sm;
  s_regsHRd_ms <= s_ENV_regPorts_v_ms(4);
  s_ENV_regPorts_v_sm(4) <= s_regsHRd_sm;
  s_regsHWr_ms <= s_ENV_regPorts_v_ms(5);
  s_ENV_regPorts_v_sm(5) <= s_regsHWr_sm;
  s_regsCRd_ms <= s_ENV_regPorts_v_ms(6);
  s_ENV_regPorts_v_sm(6) <= s_regsCRd_sm;
  s_regsCWr_ms <= s_ENV_regPorts_v_ms(7);
  s_ENV_regPorts_v_sm(7) <= s_regsCWr_sm;
  s_regsExtStore_ms <= s_ENV_regPorts_v_ms(8);
  s_ENV_regPorts_v_sm(8) <= s_regsExtStore_sm;
  s_regsMon_ms <= s_ENV_regPorts_v_ms(9);
  s_ENV_regPorts_v_sm(9) <= s_regsMon_sm;

  -- Action Status and Interrupt Logic:
  i_actionControl : entity work.ActionControl
    generic map (
      g_ReadyCount => 6,
      g_ActionType => 108,
      g_ActionRev => 1)
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      po_intReq       => po_intReq,
      po_intSrc       => po_intSrc,
      pi_intAck       => pi_intAck,
      po_context      => po_context,
      pi_regs_ms      => s_ctrlRegs_ms,
      po_regs_sm      => s_ctrlRegs_sm,
      pi_irq1         => s_intExtStore_ms,
      po_iack1        => s_intExtStore_sm,
      po_start        => s_start,
      pi_ready        => s_ENV_ready_v);
  s_ENV_ready_v(0) <= s_readyHRd;
  s_ENV_ready_v(1) <= s_readyHWr;
  s_ENV_ready_v(2) <= s_readyCRd;
  s_ENV_ready_v(3) <= s_readyCWr;
  s_ENV_ready_v(4) <= s_readySrc;
  s_ENV_ready_v(5) <= s_readySnk;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- User Instances
  -----------------------------------------------------------------------------
  i_axiSplitter : entity work.AxiSplitter
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_axiWr_ms => s_hmemWr_ms,
      po_axiWr_sm => s_hmemWr_sm,
      po_axi_ms => s_hmem_ms,
      pi_axi_sm => s_hmem_sm,
      pi_axiRd_ms => s_hmemRd_ms,
      po_axiRd_sm => s_hmemRd_sm);

  i_axiSplitter_0 : entity work.AxiSplitter
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_axiWr_ms => s_cmemWr_ms,
      po_axiWr_sm => s_cmemWr_sm,
      po_axi_ms => s_cmem_ms,
      pi_axi_sm => s_cmem_sm,
      pi_axiRd_ms => s_cmemRd_ms,
      po_axiRd_sm => s_cmemRd_sm);

  i_axiRdBlockMapper : entity work.AxiRdBlockMapper
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_axiLog_ms => s_hmemRdLog_ms,
      po_axiLog_sm => s_hmemRdLog_sm,
      po_map_ms => s_extmapHRd_ms,
      pi_map_sm => s_extmapHRd_sm,
      po_axiPhy_ms => s_hmemRd_ms,
      pi_axiPhy_sm => s_hmemRd_sm);

  i_axiWrBlockMapper : entity work.AxiWrBlockMapper
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_axiLog_ms => s_hmemWrLog_ms,
      po_axiLog_sm => s_hmemWrLog_sm,
      po_map_ms => s_extmapHWr_ms,
      pi_map_sm => s_extmapHWr_sm,
      po_axiPhy_ms => s_hmemWr_ms,
      pi_axiPhy_sm => s_hmemWr_sm);

  i_axiRdBlockMapper_0 : entity work.AxiRdBlockMapper
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_axiLog_ms => s_cmemRdLog_ms,
      po_axiLog_sm => s_cmemRdLog_sm,
      po_map_ms => s_extmapCRd_ms,
      pi_map_sm => s_extmapCRd_sm,
      po_axiPhy_ms => s_cmemRd_ms,
      pi_axiPhy_sm => s_cmemRd_sm);

  i_axiWrBlockMapper_0 : entity work.AxiWrBlockMapper
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_axiLog_ms => s_cmemWrLog_ms,
      po_axiLog_sm => s_cmemWrLog_sm,
      po_map_ms => s_extmapCWr_ms,
      pi_map_sm => s_extmapCWr_sm,
      po_axiPhy_ms => s_cmemWr_ms,
      pi_axiPhy_sm => s_cmemWr_sm);

  i_axiReader : entity work.AxiReader
    generic map (
      g_FIFOLogDepth => 3)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      po_axiRd_ms => s_hmemRdLog_ms,
      pi_axiRd_sm => s_hmemRdLog_sm,
      pi_start => s_start,
      po_ready => s_readyHRd,
      pi_hold => open,
      po_stm_ms => s_stmHRd_ms,
      pi_stm_sm => s_stmHRd_sm,
      pi_regs_ms => s_regsHRd_ms,
      po_regs_sm => s_regsHRd_sm);

  i_axiWriter : entity work.AxiWriter
    generic map (
      g_FIFOLogDepth => 1)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_stm_ms => s_stmHWr_ms,
      po_stm_sm => s_stmHWr_sm,
      pi_start => s_start,
      po_ready => s_readyHWr,
      pi_hold => open,
      po_axiWr_ms => s_hmemWrLog_ms,
      pi_axiWr_sm => s_hmemWrLog_sm,
      pi_regs_ms => s_regsHWr_ms,
      po_regs_sm => s_regsHWr_sm);

  i_axiReader_0 : entity work.AxiReader
    generic map (
      g_FIFOLogDepth => 8)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      po_axiRd_ms => s_cmemRdLog_ms,
      pi_axiRd_sm => s_cmemRdLog_sm,
      pi_start => s_start,
      po_ready => s_readyCRd,
      pi_hold => open,
      po_stm_ms => s_stmCRd_ms,
      pi_stm_sm => s_stmCRd_sm,
      pi_regs_ms => s_regsCRd_ms,
      po_regs_sm => s_regsCRd_sm);

  i_axiWriter_0 : entity work.AxiWriter
    generic map (
      g_FIFOLogDepth => 1)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_stm_ms => s_stmCWr_ms,
      po_stm_sm => s_stmCWr_sm,
      pi_start => s_start,
      po_ready => s_readyCWr,
      pi_hold => open,
      po_axiWr_ms => s_cmemWrLog_ms,
      pi_axiWr_sm => s_cmemWrLog_sm,
      pi_regs_ms => s_regsCWr_ms,
      po_regs_sm => s_regsCWr_sm);

  i_extentStore : entity work.ExtentStore
    generic map (
      g_PortCount => 4)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      po_int_ms => s_intExtStore_ms,
      pi_int_sm => s_intExtStore_sm,
      pi_ports_ms => s_extentStore_ports_v_ms,
      po_ports_sm => s_extentStore_ports_v_sm,
      pi_regs_ms => s_regsExtStore_ms,
      po_regs_sm => s_regsExtStore_sm);
  -- Unpack ports:
  s_extentStore_ports_v_ms(0) <= s_extmapHRd_ms;
  s_extmapHRd_sm <= s_extentStore_ports_v_sm(0);
  s_extentStore_ports_v_ms(1) <= s_extmapHWr_ms;
  s_extmapHWr_sm <= s_extentStore_ports_v_sm(1);
  s_extentStore_ports_v_ms(2) <= s_extmapCRd_ms;
  s_extmapCRd_sm <= s_extentStore_ports_v_sm(2);
  s_extentStore_ports_v_ms(3) <= s_extmapCWr_ms;
  s_extmapCWr_sm <= s_extentStore_ports_v_sm(3);

  i_nativeStreamSource : entity work.NativeStreamSource
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_start => s_start,
      po_ready => s_readySrc,
      po_stm_ms => s_stmSrc_ms,
      pi_stm_sm => s_stmSrc_sm,
      pi_regs_ms => s_regsSource_ms,
      po_regs_sm => s_regsSource_sm);

  i_nativeStreamSink : entity work.NativeStreamSink
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_stm_ms => s_stmSnk_ms,
      po_stm_sm => s_stmSnk_sm,
      pi_start => s_start,
      po_ready => s_readySnk,
      pi_regs_ms => s_regsSink_ms,
      po_regs_sm => s_regsSink_sm);

  i_nativeStreamSwitch : entity work.NativeStreamSwitch
    generic map (
      g_OutPortCount => 3,
      g_InPortCount => 3)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      po_stmOut_ms => s_nativeStreamSwitch_stmOut_v_ms,
      pi_stmOut_sm => s_nativeStreamSwitch_stmOut_v_sm,
      pi_regs_ms => s_regsSwitch_ms,
      po_regs_sm => s_regsSwitch_sm,
      pi_stmIn_ms => s_nativeStreamSwitch_stmIn_v_ms,
      po_stmIn_sm => s_nativeStreamSwitch_stmIn_v_sm);
  -- Unpack stmOut:
  s_stmHWr_ms <= s_nativeStreamSwitch_stmOut_v_ms(0);
  s_nativeStreamSwitch_stmOut_v_sm(0) <= s_stmHWr_sm;
  s_stmCWr_ms <= s_nativeStreamSwitch_stmOut_v_ms(1);
  s_nativeStreamSwitch_stmOut_v_sm(1) <= s_stmCWr_sm;
  s_stmSnk_ms <= s_nativeStreamSwitch_stmOut_v_ms(2);
  s_nativeStreamSwitch_stmOut_v_sm(2) <= s_stmSnk_sm;
  -- Unpack stmIn:
  s_nativeStreamSwitch_stmIn_v_ms(0) <= s_stmHRd_ms;
  s_stmHRd_sm <= s_nativeStreamSwitch_stmIn_v_sm(0);
  s_nativeStreamSwitch_stmIn_v_ms(1) <= s_stmCRd_ms;
  s_stmCRd_sm <= s_nativeStreamSwitch_stmIn_v_sm(1);
  s_nativeStreamSwitch_stmIn_v_ms(2) <= s_stmSrc_ms;
  s_stmSrc_sm <= s_nativeStreamSwitch_stmIn_v_sm(2);

  i_axiMonitor : entity work.AxiMonitor
    generic map (
      g_WrPortCount => 2,
      g_StmPortCount => 3,
      g_RdPortCount => 2)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_stream_ms => s_axiMonitor_stream_v_ms,
      pi_stream_sm => s_axiMonitor_stream_v_sm,
      pi_start => s_start,
      pi_axiWr_ms => s_axiMonitor_axiWr_v_ms,
      pi_axiWr_sm => s_axiMonitor_axiWr_v_sm,
      pi_axiRd_ms => s_axiMonitor_axiRd_v_ms,
      pi_axiRd_sm => s_axiMonitor_axiRd_v_sm,
      pi_regs_ms => s_regsMon_ms,
      po_regs_sm => s_regsMon_sm);
  -- Unpack stream:
  s_axiMonitor_stream_v_ms(0) <= s_stmHWr_ms;
  s_axiMonitor_stream_v_sm(0) <= s_stmHWr_sm;
  s_axiMonitor_stream_v_ms(1) <= s_stmCWr_ms;
  s_axiMonitor_stream_v_sm(1) <= s_stmCWr_sm;
  s_axiMonitor_stream_v_ms(2) <= s_stmSnk_ms;
  s_axiMonitor_stream_v_sm(2) <= s_stmSnk_sm;
  -- Unpack axiWr:
  s_axiMonitor_axiWr_v_ms(0) <= s_hmemWr_ms;
  s_axiMonitor_axiWr_v_sm(0) <= s_hmemWr_sm;
  s_axiMonitor_axiWr_v_ms(1) <= s_cmemWr_ms;
  s_axiMonitor_axiWr_v_sm(1) <= s_cmemWr_sm;
  -- Unpack axiRd:
  s_axiMonitor_axiRd_v_ms(0) <= s_hmemRd_ms;
  s_axiMonitor_axiRd_v_sm(0) <= s_hmemRd_sm;
  s_axiMonitor_axiRd_v_ms(1) <= s_cmemRd_ms;
  s_axiMonitor_axiRd_v_sm(1) <= s_cmemRd_sm;

  -----------------------------------------------------------------------------

end Action;
