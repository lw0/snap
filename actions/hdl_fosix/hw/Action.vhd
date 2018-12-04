----------------------------------------------------------------------------
----------------------------------------------------------------------------
--
-- Copyright 2016 International Business Machines
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions AND
-- limitations under the License.
--
-- change log:
-- 12/20/2016 R. Rieke fixed case statement issue
----------------------------------------------------------------------------
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.fosix_types.all;

entity Action is
  port (
    pi_clk     : in  std_logic;
    pi_rst_n   : in  std_logic;
    po_intReq  : out std_logic;
    po_intSrc  : out t_InterruptSrc;
    pi_intAck  : in  std_logic;
    po_context : out t_Context;

    -- Ports of Axi Slave Bus Interface AXI_CTRL_REG
    pi_ctrl_ms : in  t_Ctrl_ms;
    po_ctrl_sm : out t_Ctrl_sm;

    -- Ports of Axi Master Bus Interface AXI_HOST_MEM
    po_hmem_ms : out t_Axi_ms;
    pi_hmem_sm : in  t_Axi_sm;

    -- Ports of Axi Master Bus Interface AXI_CARD_MEM0
    po_cmem_ms : out t_Axi_ms;
    pi_cmem_sm : in  t_Axi_sm;

    -- Ports of Axi Master Bus Interface AXI_NVME
    po_nvme_ms : out t_Nvme_ms;
    pi_nvme_sm : in  t_Nvme_sm);
end Action;

architecture Action of Action is

  -----------------------------------------------------------------------------
  -- Register Port Map Configuration
  -----------------------------------------------------------------------------
  constant c_Ports : t_RegMap(0 to 7) := (
    -- Port 0: Control Registers                         (0x000 - 0x02C)
    (to_unsigned(0,   C_CTRL_SPACE_W), to_unsigned(12,  C_CTRL_SPACE_W)),
    -- Port 1: Stream Infrastructure                     (0x040 - 0x06C)
    (to_unsigned(16,  C_CTRL_SPACE_W), to_unsigned(12,  C_CTRL_SPACE_W)),
    -- Port 2: Host Memory Reader                        (0x080 - 0x08C)
    (to_unsigned(32,  C_CTRL_SPACE_W), to_unsigned(4,   C_CTRL_SPACE_W)),
    -- Port 3: Host Memory Writer                        (0x090 - 0x09C)
    (to_unsigned(36,  C_CTRL_SPACE_W), to_unsigned(4,   C_CTRL_SPACE_W)),
    -- Port 4: Card Memory Reader                        (0x0A0 - 0x0AC)
    (to_unsigned(40,  C_CTRL_SPACE_W), to_unsigned(4,   C_CTRL_SPACE_W)),
    -- Port 5: Card Memory Writer                        (0x0B0 - 0x0BC)
    (to_unsigned(44,  C_CTRL_SPACE_W), to_unsigned(4,   C_CTRL_SPACE_W)),
    -- Port 6: Host Memory Monitor                       (0x100 - 0x14C)
    (to_unsigned(64,  C_CTRL_SPACE_W), to_unsigned(24,  C_CTRL_SPACE_W)),
    -- Port 7: Card Memory Monitor                       (0x180 - 0x1DC)
    (to_unsigned(96,  C_CTRL_SPACE_W), to_unsigned(24,  C_CTRL_SPACE_W))
  );
  -----------------------------------------------------------------------------
  signal s_ports_ms : t_RegPorts_ms(c_Ports'range);
  signal s_ports_sm : t_RegPorts_sm(c_Ports'range);

  signal s_ctrlRegs_ms : t_RegPort_ms;
  signal s_ctrlRegs_sm : t_RegPort_sm;
  signal s_appStart : std_logic;
  signal s_appReady : std_logic;

  constant c_SwitchInStreams : integer := 2;
  constant c_SwitchOutStreams : integer := 2;
  signal s_switchRegs_ms : t_RegPort_ms;
  signal s_switchRegs_sm : t_RegPort_sm;
  signal s_switchIn_ms  : t_AxiStreams_ms(0 to c_SwitchInStreams-1);
  signal s_switchIn_sm  : t_AxiStreams_sm(0 to c_SwitchInStreams-1);
  signal s_switchOut_ms : t_AxiStreams_ms(0 to c_SwitchOutStreams-1);
  signal s_switchOut_sm : t_AxiStreams_sm(0 to c_SwitchOutStreams-1);

  signal s_hwReady : std_logic;
  signal s_hwDone : std_logic;
  signal s_hmemRdRegs_ms : t_RegPort_ms;
  signal s_hmemRdRegs_sm : t_RegPort_sm;
  signal s_hmemRd_ms : t_AxiRd_ms;
  signal s_hmemRd_sm : t_AxiRd_sm;
  signal s_hmemRdStream_ms : t_AxiStream_ms;
  signal s_hmemRdStream_sm : t_AxiStream_sm;

  signal s_hrReady : std_logic;
  signal s_hrDone : std_logic;
  signal s_hmemWrRegs_ms : t_RegPort_ms;
  signal s_hmemWrRegs_sm : t_RegPort_sm;
  signal s_hmemWr_ms : t_AxiWr_ms;
  signal s_hmemWr_sm : t_AxiWr_sm;
  signal s_hmemWrStream_ms : t_AxiStream_ms;
  signal s_hmemWrStream_sm : t_AxiStream_sm;

  signal s_cwReady : std_logic;
  signal s_cwDone : std_logic;
  signal s_cmemRdRegs_ms : t_RegPort_ms;
  signal s_cmemRdRegs_sm : t_RegPort_sm;
  signal s_cmemRd_ms : t_AxiRd_ms;
  signal s_cmemRd_sm : t_AxiRd_sm;
  signal s_cmemRdStream_ms : t_AxiStream_ms;
  signal s_cmemRdStream_sm : t_AxiStream_sm;

  signal s_crReady : std_logic;
  signal s_crDone : std_logic;
  signal s_cmemWrRegs_ms : t_RegPort_ms;
  signal s_cmemWrRegs_sm : t_RegPort_sm;
  signal s_cmemWr_ms : t_AxiWr_ms;
  signal s_cmemWr_sm : t_AxiWr_sm;
  signal s_cmemWrStream_ms : t_AxiStream_ms;
  signal s_cmemWrStream_sm : t_AxiStream_sm;

  signal s_hmemMonRegs_ms : t_RegPort_ms;
  signal s_hmemMonRegs_sm : t_RegPort_sm;
  signal s_hmemMon_ms : t_Axi_ms;
  signal s_hmemMon_sm : t_Axi_sm;

  signal s_cmemMonRegs_ms : t_RegPort_ms;
  signal s_cmemMonRegs_sm : t_RegPort_sm;
  signal s_cmemMon_ms : t_Axi_ms;
  signal s_cmemMon_sm : t_Axi_sm;

begin

  -- Split Memory Ports into Separate Read and Write Portions
  po_hmem_ms <= f_axiJoin_ms(s_hmemRd_ms, s_hmemWr_ms);
  s_hmemRd_sm <= f_axiSplitRd_sm(pi_hmem_sm);
  s_hmemWr_sm <= f_axiSplitWr_sm(pi_hmem_sm);
  po_cmem_ms <= f_axiJoin_ms(s_cmemRd_ms, s_cmemWr_ms);
  s_cmemRd_sm <= f_axiSplitRd_sm(pi_cmem_sm);
  s_cmemWr_sm <= f_axiSplitWr_sm(pi_cmem_sm);

  s_hmemMon_ms <= f_axiJoin_ms(s_hmemRd_ms, s_hmemWr_ms);
  s_hmemMon_sm <= f_axiJoin_sm(s_hmemRd_sm, s_hmemWr_sm);
  s_cmemMon_ms <= f_axiJoin_ms(s_cmemRd_ms, s_cmemWr_ms);
  s_cmemMon_sm <= f_axiJoin_sm(s_cmemRd_sm, s_cmemWr_sm);

  -- Demultiplex and Simplify Control Register Ports
  i_ctrlDemux : entity work.CtrlRegDemux
    generic map (
      g_Ports => c_Ports)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_ctrl_ms => pi_ctrl_ms,
      po_ctrl_sm => po_ctrl_sm,
      po_ports_ms => s_ports_ms,
      pi_ports_sm => s_ports_sm);
  s_ctrlRegs_ms <= s_ports_ms(0);
  s_ports_sm(0) <= s_ctrlRegs_sm;
  s_switchRegs_ms <= s_ports_ms(1);
  s_ports_sm(1) <= s_switchRegs_sm;
  s_hmemRdRegs_ms <= s_ports_ms(2);
  s_ports_sm(2) <= s_hmemRdRegs_sm;
  s_hmemWrRegs_ms <= s_ports_ms(3);
  s_ports_sm(3) <= s_hmemWrRegs_sm;
  s_cmemRdRegs_ms <= s_ports_ms(4);
  s_ports_sm(4) <= s_cmemRdRegs_sm;
  s_cmemWrRegs_ms <= s_ports_ms(5);
  s_ports_sm(5) <= s_cmemWrRegs_sm;
  s_hmemMonRegs_ms <= s_ports_ms(6);
  s_ports_sm(6) <= s_hmemMonRegs_sm;
  s_cmemMonRegs_ms <= s_ports_ms(7);
  s_ports_sm(7) <= s_cmemMonRegs_sm;

  i_actionControl : entity work.ActionControl
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      po_intReq       => po_intReq,
      po_intSrc       => po_intSrc,
      pi_intAck       => pi_intAck,
      pi_ctrlRegs_ms  => s_ctrlRegs_ms,
      po_ctrlRegs_sm  => s_ctrlRegs_sm,
      pi_type         => x"0000_006c",
      pi_version      => x"0000_0000",
      po_context      => po_context,
      po_start        => s_appStart,
      pi_ready        => s_appReady);

  s_appReady <= s_hrReady and s_hwReady and s_crReady and s_cwReady;

  i_infrastructure : entity work.StreamInfrastructure
    generic map (
      g_InPorts => c_SwitchInStreams,
      g_OutPorts => c_SwitchOutStreams)
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_regs_ms      => s_switchRegs_ms,
      po_regs_sm      => s_switchRegs_sm,
      pi_inPorts_ms   => s_switchIn_ms,
      po_inPorts_sm   => s_switchIn_sm,
      po_outPorts_ms  => s_switchOut_ms,
      pi_outPorts_sm  => s_switchOut_sm);

  s_switchIn_ms(0) <= s_hmemRdStream_ms;
  s_hmemRdStream_sm <= s_switchIn_sm(0);
  s_hmemWrStream_ms <= s_switchOut_ms(0);
  s_switchOut_sm(0) <= s_hmemWrStream_sm;

  s_switchIn_ms(1) <= s_cmemRdStream_ms;
  s_cmemRdStream_sm <= s_switchIn_sm(1);
  s_cmemWrStream_ms <= s_switchOut_ms(1);
  s_switchOut_sm(1) <= s_cmemWrStream_sm;

  i_hmemReader : entity work.AxiReader
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_start        => s_appStart,
      po_ready        => s_hrReady,
      po_done         => s_hrDone,
      pi_hold         => '0',
      pi_regs_ms      => s_hmemRdRegs_ms,
      po_regs_sm      => s_hmemRdRegs_sm,
      po_mem_ms       => s_hmemRd_ms,
      pi_mem_sm       => s_hmemRd_sm,
      po_stream_ms    => s_hmemRdStream_ms,
      pi_stream_sm    => s_hmemRdStream_sm);

  i_hmemWriter : entity work.AxiWriter
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_start        => s_appStart,
      po_ready        => s_hwReady,
      po_done         => s_hwDone,
      pi_hold         => '0',
      pi_regs_ms      => s_hmemWrRegs_ms,
      po_regs_sm      => s_hmemWrRegs_sm,
      po_mem_ms       => s_hmemWr_ms,
      pi_mem_sm       => s_hmemWr_sm,
      pi_stream_ms    => s_hmemWrStream_ms,
      po_stream_sm    => s_hmemWrStream_sm);

  i_cmemReader : entity work.AxiReader
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_start        => s_appStart,
      po_ready        => s_crReady,
      po_done         => s_crDone,
      pi_hold         => '0',
      pi_regs_ms      => s_cmemRdRegs_ms,
      po_regs_sm      => s_cmemRdRegs_sm,
      po_mem_ms       => s_cmemRd_ms,
      pi_mem_sm       => s_cmemRd_sm,
      po_stream_ms    => s_cmemRdStream_ms,
      pi_stream_sm    => s_cmemRdStream_sm);

  i_cmemWriter : entity work.AxiWriter
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_start        => s_appStart,
      po_ready        => s_cwReady,
      po_done         => s_cwDone,
      pi_hold         => '0',
      pi_regs_ms      => s_cmemWrRegs_ms,
      po_regs_sm      => s_cmemWrRegs_sm,
      po_mem_ms       => s_cmemWr_ms,
      pi_mem_sm       => s_cmemWr_sm,
      pi_stream_ms    => s_cmemWrStream_ms,
      po_stream_sm    => s_cmemWrStream_sm);

  i_hmemMonitor : entity work.AxiMonitor
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_regs_ms      => s_hmemMonRegs_ms,
      po_regs_sm      => s_hmemMonRegs_sm,
      pi_axi_ms       => s_hmemMon_ms,
      pi_axi_sm       => s_hmemMon_sm);

  i_cmemMonitor : entity work.AxiMonitor
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_regs_ms      => s_cmemMonRegs_ms,
      po_regs_sm      => s_cmemMonRegs_sm,
      pi_axi_ms       => s_cmemMon_ms,
      pi_axi_sm       => s_cmemMon_sm);

  po_nvme_ms <= c_NvmeNull_ms;

end Action;
