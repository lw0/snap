library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_axi.all;
use work.fosix_blockmap.all;
use work.fosix_ctrl.all;
use work.fosix_user.all;
use work.fosix_util.all;

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
  constant c_Ports : t_RegMap(0 to 3-1) := (
    (to_unsigned(0, c_RegAddrWidth), to_unsigned(16, c_RegAddrWidth)),
    (to_unsigned(16, c_RegAddrWidth), to_unsigned(4, c_RegAddrWidth)),
    (to_unsigned(20, c_RegAddrWidth), to_unsigned(4, c_RegAddrWidth))
  );
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Signal Declaration
  -----------------------------------------------------------------------------
  signal s_ctrlRegs_ms : t_RegPort_ms;
  signal s_ctrlRegs_sm : t_RegPort_sm;
  signal s_ENV_ready_v0 : t_Logic(4-1 downto 0);
  signal s_ENV_regPorts_v0_ms : t_RegPort_ms(3-1 downto 0);
  signal s_ENV_regPorts_v0_sm : t_RegPort_sm(3-1 downto 0);
  signal s_regExtStore_ms : t_RegPort_ms;
  signal s_regExtStore_sm : t_RegPort_sm;
  signal s_regSwitch_ms : t_RegPort_ms;
  signal s_regSwitch_sm : t_RegPort_sm;
  signal s_start : t_Logic;
  signal s_readyHRd : t_Logic;
  signal s_readyHWr : t_Logic;
  signal s_readyCRd : t_Logic;
  signal s_readyCWr : t_Logic;
  signal s_hmem_ms : t_NativeAxi_ms;
  signal s_hmem_sm : t_NativeAxi_sm;
  signal s_hmemWr_ms : t_NativeAxiWr_ms;
  signal s_hmemWr_sm : t_NativeAxiWr_sm;
  signal s_hmemRd_ms : t_NativeAxiRd_ms;
  signal s_hmemRd_sm : t_NativeAxiRd_sm;
  signal s_cmemWr_ms : t_NativeAxiWr_ms;
  signal s_cmemWr_sm : t_NativeAxiWr_sm;
  signal s_cmem_ms : t_NativeAxi_ms;
  signal s_cmem_sm : t_NativeAxi_sm;
  signal s_cmemRd_ms : t_NativeAxiRd_ms;
  signal s_cmemRd_sm : t_NativeAxiRd_sm;
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
  signal s_ExtentStore0_ports_v0_ms : t_BlkMap_ms(4-1 downto 0);
  signal s_ExtentStore0_ports_v0_sm : t_BlkMap_sm(4-1 downto 0);
  signal s_stmHRd_ms : t_NativeStream_ms;
  signal s_stmHRd_sm : t_NativeStream_sm;
  signal s_stmHWr_ms : t_NativeStream_ms;
  signal s_stmHWr_sm : t_NativeStream_sm;
  signal s_stmCRd_ms : t_NativeStream_ms;
  signal s_stmCRd_sm : t_NativeStream_sm;
  signal s_stmCWr_ms : t_NativeStream_ms;
  signal s_stmCWr_sm : t_NativeStream_sm;
  signal s_NativeStreamSwitch0_stmOut_v0_ms : t_NativeStream_ms(2-1 downto 0);
  signal s_NativeStreamSwitch0_stmOut_v0_sm : t_NativeStream_sm(2-1 downto 0);
  signal s_NativeStreamSwitch0_stmIn_v0_ms : t_NativeStream_ms(2-1 downto 0);
  signal s_NativeStreamSwitch0_stmIn_v0_sm : t_NativeStream_sm(2-1 downto 0);
  -----------------------------------------------------------------------------

begin

  -----------------------------------------------------------------------------
  -- FOSIX Environment
  -----------------------------------------------------------------------------
  -- Handle Axi Ports
  po_hmem_ms <= s_hmem_ms;
  s_hmem_sm <= pi_hmem_sm;

  po_cmem_ms <= c_NativeAxiNull_ms;

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
      po_ports_ms => s_ENV_regPorts_v0_ms,
      pi_ports_sm => s_ENV_regPorts_v0_sm);
  s_ctrlRegs_ms <= s_ENV_regPorts_v0_ms(0);
  s_ENV_regPorts_v0_sm(0) <= s_ctrlRegs_sm;
  s_regExtStore_ms <= s_ENV_regPorts_v0_ms(1);
  s_ENV_regPorts_v0_sm(1) <= s_regExtStore_sm;
  s_regSwitch_ms <= s_ENV_regPorts_v0_ms(2);
  s_ENV_regPorts_v0_sm(2) <= s_regSwitch_sm;

  -- Action Status and Interrupt Logic:
  i_actionControl : entity work.ActionControl
    generic map (
      g_ReadyCount => 4,
      g_ActionType => 264,
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
      po_start        => s_start,
      pi_ready        => s_ENV_ready_v0);
  s_ENV_ready_v0(0) <= s_readyHRd;
  s_ENV_ready_v0(1) <= s_readyHWr;
  s_ENV_ready_v0(2) <= s_readyCRd;
  s_ENV_ready_v0(3) <= s_readyCWr;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- User Instances
  -----------------------------------------------------------------------------
  AxiSplitter0 : entity work.AxiSplitter
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      po_axi_ms => s_hmem_ms,
      pi_axi_sm => s_hmem_sm,
      pi_axiRd_ms => s_hmemRd_ms,
      po_axiRd_sm => s_hmemRd_sm,
      pi_axiWr_ms => s_hmemWr_ms,
      po_axiWr_sm => s_hmemWr_sm);

  AxiSplitter1 : entity work.AxiSplitter
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      po_axi_ms => s_cmem_ms,
      pi_axi_sm => s_cmem_sm,
      pi_axiRd_ms => s_cmemRd_ms,
      po_axiRd_sm => s_cmemRd_sm,
      pi_axiWr_ms => s_cmemWr_ms,
      po_axiWr_sm => s_cmemWr_sm);

  AxiRdBlockMapper0 : entity work.AxiRdBlockMapper
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      po_map_ms => s_extmapHRd_ms,
      pi_map_sm => s_extmapHRd_sm,
      po_axiPhy_ms => s_hmemRd_ms,
      pi_axiPhy_sm => s_hmemRd_sm,
      pi_axiLog_ms => s_hmemRdLog_ms,
      po_axiLog_sm => s_hmemRdLog_sm);

  AxiWrBlockMapper0 : entity work.AxiWrBlockMapper
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      po_map_ms => s_extmapHWr_ms,
      pi_map_sm => s_extmapHWr_sm,
      po_axiPhy_ms => s_hmemWr_ms,
      pi_axiPhy_sm => s_hmemWr_sm,
      pi_axiLog_ms => s_hmemWrLog_ms,
      po_axiLog_sm => s_hmemWrLog_sm);

  AxiRdBlockMapper1 : entity work.AxiRdBlockMapper
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      po_map_ms => s_extmapCRd_ms,
      pi_map_sm => s_extmapCRd_sm,
      po_axiPhy_ms => s_cmemRd_ms,
      pi_axiPhy_sm => s_cmemRd_sm,
      pi_axiLog_ms => s_cmemRdLog_ms,
      po_axiLog_sm => s_cmemRdLog_sm);

  AxiWrBlockMapper1 : entity work.AxiWrBlockMapper
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      po_map_ms => s_extmapCWr_ms,
      pi_map_sm => s_extmapCWr_sm,
      po_axiPhy_ms => s_cmemWr_ms,
      pi_axiPhy_sm => s_cmemWr_sm,
      pi_axiLog_ms => s_cmemWrLog_ms,
      po_axiLog_sm => s_cmemWrLog_sm);

  ExtentStore0 : entity work.ExtentStore
    generic map (
      g_PortCount => 4)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_reg_ms => s_regExtStore_ms,
      po_reg_sm => s_regExtStore_sm,
      pi_ports_ms => s_ExtentStore0_ports_v0_ms,
      po_ports_sm => s_ExtentStore0_ports_v0_sm);
  -- Unpack ports:
  s_ExtentStore0_ports_v0_ms(0) <= s_extmapHRd_ms;
  s_extmapHRd_sm <= s_ExtentStore0_ports_v0_sm(0);
  s_ExtentStore0_ports_v0_ms(1) <= s_extmapHWr_ms;
  s_extmapHWr_sm <= s_ExtentStore0_ports_v0_sm(1);
  s_ExtentStore0_ports_v0_ms(2) <= s_extmapCRd_ms;
  s_extmapCRd_sm <= s_ExtentStore0_ports_v0_sm(2);
  s_ExtentStore0_ports_v0_ms(3) <= s_extmapCWr_ms;
  s_extmapCWr_sm <= s_ExtentStore0_ports_v0_sm(3);

  AxiReader0 : entity work.AxiReader
    generic map (
      g_FIFODepth => 3)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      po_axiRd_ms => s_hmemRdLog_ms,
      pi_axiRd_sm => s_hmemRdLog_sm,
      po_ready => s_readyHRd,
      pi_start => s_start,
      po_stm_ms => s_stmHRd_ms,
      pi_stm_sm => s_stmHRd_sm);

  AxiWriter0 : entity work.AxiWriter
    generic map (
      g_FIFODepth => 1)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_stm_ms => s_stmHWr_ms,
      po_stm_sm => s_stmHWr_sm,
      po_axiWr_ms => s_hmemWrLog_ms,
      pi_axiWr_sm => s_hmemWrLog_sm,
      po_ready => s_readyHWr,
      pi_start => s_start);

  AxiReader1 : entity work.AxiReader
    generic map (
      g_FIFODepth => 8)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      po_axiRd_ms => s_cmemRdLog_ms,
      pi_axiRd_sm => s_cmemRdLog_sm,
      po_ready => s_readyCRd,
      pi_start => s_start,
      po_stm_ms => s_stmCRd_ms,
      pi_stm_sm => s_stmCRd_sm);

  AxiWriter1 : entity work.AxiWriter
    generic map (
      g_FIFODepth => 1)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_stm_ms => s_stmCWr_ms,
      po_stm_sm => s_stmCWr_sm,
      po_axiWr_ms => s_cmemWrLog_ms,
      pi_axiWr_sm => s_cmemWrLog_sm,
      po_ready => s_readyCWr,
      pi_start => s_start);

  NativeStreamSwitch0 : entity work.NativeStreamSwitch
    generic map (
      g_OutPortCount => 2,
      g_InPortCount => 2)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      po_stmOut_ms => s_NativeStreamSwitch0_stmOut_v0_ms,
      pi_stmOut_sm => s_NativeStreamSwitch0_stmOut_v0_sm,
      pi_reg_ms => s_regSwitch_ms,
      po_reg_sm => s_regSwitch_sm,
      pi_stmIn_ms => s_NativeStreamSwitch0_stmIn_v0_ms,
      po_stmIn_sm => s_NativeStreamSwitch0_stmIn_v0_sm);
  -- Unpack stmOut:
  s_stmHWr_ms <= s_NativeStreamSwitch0_stmOut_v0_ms(0);
  s_NativeStreamSwitch0_stmOut_v0_sm(0) <= s_stmHWr_sm;
  s_stmCWr_ms <= s_NativeStreamSwitch0_stmOut_v0_ms(1);
  s_NativeStreamSwitch0_stmOut_v0_sm(1) <= s_stmCWr_sm;
  -- Unpack stmIn:
  s_NativeStreamSwitch0_stmIn_v0_ms(0) <= s_stmHRd_ms;
  s_stmHRd_sm <= s_NativeStreamSwitch0_stmIn_v0_sm(0);
  s_NativeStreamSwitch0_stmIn_v0_ms(1) <= s_stmCRd_ms;
  s_stmCRd_sm <= s_NativeStreamSwitch0_stmIn_v0_sm(1);

  -----------------------------------------------------------------------------

end Action;

