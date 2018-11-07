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
use work.action_ctrl_types.all;

entity action_example is
  port (
    pi_clk     : in  std_logic;
    pi_rst_n   : in  std_logic;
    po_intReq  : out std_logic;
    po_intSrc  : out t_InterruptSrc;
    po_intCtx  : out t_Context;
    pi_intAck  : in  std_logic;

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
end action_example;

architecture action_example of action_example is

  -----------------------------------------------------------------------------
  -- Register Port Map Configuration
  -----------------------------------------------------------------------------
  constant c_PortCount : positive := 2;
  constant c_Ports : t_RegMap(0 to c_PortCount-1) := (
    -- Port 0: Control Registers                         (0x000 - 0x02C)
    (to_unsigned(0,   C_CTRL_SPACE_W), to_unsigned(12,  C_CTRL_SPACE_W)),
    -- Port 1: Host Memory Reader                        (0x040 - 0x04C)
    (to_unsigned(16,  C_CTRL_SPACE_W), to_unsigned(4,  C_CTRL_SPACE_W)),
    -- Port 2: Host Memory Writer                        (0x050 - 0x05C)
    (to_unsigned(20,  C_CTRL_SPACE_W), to_unsigned(4,  C_CTRL_SPACE_W))
    -- -- Port 3: Card Memory Reader                        (0x060 - 0x06C)
    -- (to_unsigned(24,  C_CTRL_SPACE_W), to_unsigned(4,  C_CTRL_SPACE_W)),
    -- -- Port 4: Card Memory Writer                        (0x070 - 0x07C)
    -- (to_unsigned(28,  C_CTRL_SPACE_W), to_unsigned(4,  C_CTRL_SPACE_W)),
  );
  -----------------------------------------------------------------------------

  signal s_ports_ms : array(c_Ports'range) of t_RegPort_ms;
  signal s_ports_sm : array(c_Ports'range) of t_RegPort_sm;
  signal s_ctrlRegs_ms : t_RegPort_ms;
  signal s_ctrlRegs_sm : t_RegPort_sm;
  signal s_hmRdRegs_ms : t_RegPort_ms;
  signal s_hmRdRegs_sm : t_RegPort_sm;
  signal s_hmWrRegs_ms : t_RegPort_ms;
  signal s_hmWrRegs_sm : t_RegPort_sm;
  -- signal s_cmRdRegs_ms : t_RegPort_ms;
  -- signal s_cmRdRegs_sm : t_RegPort_sm;
  -- signal s_cmWrRegs_ms : t_RegPort_ms;
  -- signal s_cmWrRegs_sm : t_RegPort_sm;

  signal s_hmemRd_ms : t_AxiRd_ms;
  signal s_hmemRd_sm : t_AxiRd_sm;
  signal s_hmemWr_ms : t_AxiWr_ms;
  signal s_hmemWr_sm : t_AxiWr_sm;
  signal s_cmemRd_ms : t_AxiRd_ms;
  signal s_cmemRd_sm : t_AxiRd_sm;
  signal s_cmemWr_ms : t_AxiWr_ms;
  signal s_cmemWr_sm : t_AxiWr_sm;

  signal s_stream_ms : t_AxiStream_ms;
  signal s_stream_sm : t_AxiStream_sm;

  signal s_context : t_Context;

  signal s_appStart : std_logic;
  signal s_appDone : std_logic;
  signal s_appReady : std_logic;
  signal s_appIdle : std_logic;

  signal s_hmWrReady : std_logic;
  signal s_hmWrDone : std_logic;
  signal s_hmRdReady : std_logic;
  signal s_hmRdDone : std_logic;

begin

  -- Split Memory Ports into Separate Read and Write Portions
  po_hmem_ms <= f_axiJoin_ms(s_hmemRd_ms, s_hmemWr_ms);
  s_hmemRd_sm <= f_axiSplitRd_sm(pi_hmem_sm);
  s_hmemWr_sm <= f_axiSplitWr_sm(pi_hmem_sm);
  po_cmem_ms <= f_axiJoin_ms(s_cmemRd_ms, s_cmemWr_ms);
  s_cmemRd_sm <= f_axiSplitRd_sm(pi_cmem_sm);
  s_cmemWr_sm <= f_axiSplitWr_sm(pi_cmem_sm);

  -- Demultiplex and Simplify Control Register Ports
  i_ctrlDemux : entity work.CtrlRegDemux
    generic map (
      g_PortCount => c_PortCount,
      g_Ports => c_Ports)
    port map ( 
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_ctrl_ms => pi_ctrl_ms,
      po_ctrl_sm => po_ctrl_sm,
      po_ports_ms => s_ports_ms,
      pi_ports_sm => s_ports_sm);
  s_ctrlRegs_ms <= s_ports_ms(0);
  s_ports_sm(0) <= s_ctrlRegs_ms;
  s_hmRdRegs_ms <= s_ports_ms(1);
  s_ports_sm(1) <= s_hmRdRegs_sm;
  s_hmWrRegs_ms <= s_ports_ms(2);
  s_ports_sm(2) <= s_hmWrRegs_sm;


  i_actionControl : entity work.ActionControl
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      po_intReq       => po_intReq,
      po_intSrc       => po_intSrc,
      po_intCtx       => po_intCtx,
      pi_intAck       => pi_intAck,
      pi_ctrlRegs_ms  => s_ctrlRegs_ms,
      po_ctrlRegs_sm  => s_ctrlRegs_sm,
      pi_type         => x"1014_0000",
      pi_version      => x"0000_0000",
      po_context      => s_context,
      po_start        => s_appStart,
      pi_done         => s_appDone,
      pi_ready        => s_appReady,
      pi_idle         => s_appIdle,
      pi_userInt1Req  => s_bmapIntReq,
      po_userInt1Ack  => s_bmapIntAck);

  s_appDone <= (s_hmRdDone  and s_hmWrDone)  or
               (s_hmRdDone  and s_hmWrReady) or
               (s_hmRdReady and s_hmWrDone);
  s_appReady<= (s_hmRdDone  and s_hmWrDone)  or
               (s_hmRdDone  and s_hmWrReady) or
               (s_hmRdReady and s_hmWrDone);
  s_appIdle <= s_hmRdReady and s_hmWrReady;

  i_hmemReader : entity work.AxiReader
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_start        => s_appStart,
      po_ready        => s_hmRdReady,
      po_done         => s_hmRdDone,
      pi_hold         => '0',
      pi_context      => s_context,
      pi_regs_ms      => s_hmRdRegs_ms,
      po_regs_sm      => s_hmRdRegs_sm,
      po_mem_ms       => s_hmemWr_ms,
      pi_mem_sm       => s_hmemWr_sm,
      pi_stream_ms    => s_stream_ms,
      po_stream_sm    => s_stream_sm);

  i_hmemWriter : entity work.AxiWriter
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_start        => s_appStart,
      po_ready        => s_hmWrReady,
      po_done         => s_hmWrDone,
      pi_hold         => '0',
      pi_context      => s_context,
      pi_regs_ms      => s_hmWrRegs_ms,
      po_regs_sm      => s_hmWrRegs_sm,
      po_mem_ms       => s_hmemRd_ms,
      pi_mem_sm       => s_hmemRd_sm,
      po_stream_ms    => s_stream_ms,
      pi_stream_sm    => s_stream_sm);

  po_cmemRd_ms <= c_AxiRdNull_ms;
  po_cmemWr_ms <= c_AxiWrNull_ms;
  po_nvmeRd_ms <= c_AxiRdNull_ms;
  po_nvmeWr_ms <= c_AxiWrNull_ms;

end action_example;
