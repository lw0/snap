--?AXITypes
-->{{name}}WrMultiplexer.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity {{name}}WrMultiplexer is
  generic (
    g_PortCount : positive,
    g_FIFOCntWidth : natural );
  port (
    pi_clk     : in  std_logic;
    pi_rst_n   : in  std_logic;

    po_master_ms : out t_AxiWr_ms;
    pi_master_sm : in  t_AxiWr_sm;

    pi_slaves_ms : out t_AxiWr_v_ms(g_PortCount-1 downto 0);
    po_slaves_sm : in  t_AxiWr_v_sm(g_PortCount-1 downto 0) );
end {{name}}WrMultiplexer;

architecture {{name}}WrMultiplexer of {{name}}WrMultiplexer is

  subtype t_PortVector is unsigned (g_PortCount-1 downto 0);
  constant c_PortNumberWidth : natural := f_clog2(g_PortCount);
  subtype t_PortNumber is unsigned (c_PortNumberWidth-1 downto 0);

  -- Individual {{name}}Wr Address, Write and Response Channels:
  signal so_masterA_od : t_AxiA_od;
  signal si_masterA_do : t_AxiA_do;
  signal so_masterW_od : t_AxiW_od;
  signal si_masterW_do : t_AxiW_do;
  signal so_masterB_do : t_AxiW_do;
  signal si_masterB_od : t_AxiW_od;

  signal si_slavesA_od : t_AxiA_v_od;
  signal so_slavesA_do : t_AxiA_v_do;
  signal si_slavesW_od : t_AxiW_v_od;
  signal so_slavesW_do : t_AxiW_v_do;
  signal si_slavesB_do : t_AxiB_v_do;
  signal so_slavesB_od : t_AxiB_v_od;

  -- Address/Write Channel Arbiter and Switches:
  signal s_arbitRequest : t_PortVector;
  signal s_arbitPort : t_PortNumber;
  signal s_arbitActive : std_logic;
  signal s_arbitNext : std_logic;

  signal s_barDone : unsigned(2 downto 0);
  alias a_barDoneA is s_barDone(0);
  alias a_barDoneW is s_barDone(1);
  alias a_barDoneF is s_barDone(2);
  signal s_barMask : unsigned(2 downto 0);
  alias a_barMaskA is s_barMask(0);
  alias a_barMaskW is s_barMask(1);
  alias a_barMaskF is s_barMask(2);
  signal s_barContinue : std_logic;

  signal s_switchAEnable : std_logic;
  signal s_slavesAValid : t_PortVector;

  signal s_switchWEnable : std_logic;
  signal s_slavesWValid : t_PortVector;

  -- Response Channel FIFO and Switch:
  signal s_fifoInReady : std_logic;
  signal s_fifoInValid : std_logic;

  signal s_fifoOutPort : t_PortNumber;
  signal s_fifoOutReady : std_logic;
  signal s_fifoOutValid : std_logic;

begin

  -- Individual {{name}}Wr Address, Write and Response Channels:
  process (pi_master_sm, so_masterA_od, so_masterW_od, so_masterB_do,
           pi_slaves_ms, so_slavesA_do, so_slavesW_do, so_slavesB_od)
    variable v_idx : integer range 0 to g_PortCount-1;
  begin
    po_master_ms <= f_axiWrJoin_ms(so_masterA_od, so_masterW_od, so_masterB_do);
    si_masterA_do <= f_axiWrSplitA_sm(pi_master_sm);
    si_masterW_do <= f_axiWrSplitW_sm(pi_master_sm);
    si_masterB_od <= f_axiWrSplitB_sm(pi_master_sm);
    for v_idx in 0 to g_PortCount-1 loop
      po_slaves_sm(v_idx) <= f_axiWrJoin_sm(so_slavesA_do(v_idx), so_slavesW_do(v_idx), so_slavesR_od(v_idx));
      si_slavesA_od(v_idx) <= f_axiWrSplitA_ms(pi_slaves_ms(v_idx));
      si_slavesW_od(v_idx) <= f_axiWrSplitW_ms(pi_slaves_ms(v_idx));
      si_slavesB_do(v_idx) <= f_axiWrSplitB_ms(pi_slaves_ms(v_idx));
    end loop;
  end process;

  -- Address/Write Channel Arbiter:
  s_arbitRequest <= s_slavesAValid or s_slavesWValid;
  s_arbitNext <= s_barContinue;
  i_arbiter : entity work.Arbiter
    generic map (
      g_PortCount => g_PortCount)
    port map (
      pi_clk      => pi_clk,
      pi_rst_n    => pi_rst_n,
      pi_request  => s_arbitRequest,
      po_port     => s_arbitPort,
      po_active   => s_arbitActive,
      pi_next     => s_arbitNext);

  i_barrier : entity work.Barrier
    generic map (
      g_Count => 3)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_signal => s_barDone,
      po_mask => s_barMask,
      po_continue => s_barContinue);

  -- Address Channel Switch
  s_switchAEnable <= s_arbitActive and not a_barMaskA;
  i_switchA : entity work.{{name}}ASwitchN1
    generic map (
      g_Count => g_PortCount)
    port map (
      pi_select => s_arbitPort,
      pi_enable => s_switchAEnable,
      pi_inputs_od => si_slavesA_od,
      po_inputs_do => so_slavesA_do,
      po_output_od => so_masterA_od,
      pi_output_do => si_masterA_do,
      po_inputsValid => s_slavesAValid);
  a_barDoneA <= so_masterA_od.valid and si_masterA_do.ready;

  -- Write Channel Switch
  s_switchWEnable <= s_arbitActive and not a_barMaskW;
  i_switchW : entity work.{{name}}ASwitchN1
    generic map (
      g_Count => g_PortCount)
    port map (
      pi_select => s_arbitPort,
      pi_enable => s_switchWEnable,
      pi_inputs_od => si_slavesW_od,
      po_inputs_do => so_slavesW_do,
      po_output_od => so_masterW_od,
      pi_output_do => si_masterW_do,
      po_inputsValid => s_slavesWValid);
  a_barDoneW <= so_masterW_od.valid and so_masterW_od.last and si_masterW_do.ready;

  -- Response Channel FIFO:
  s_fifoInValid <= s_arbitActive and not a_barMaskF;
  i_portFIFO : entity work.FIFO
    generic map (
      g_DataWidth => c_PortNumberWidth,
      g_CntWidth  => g_FIFOCntWidth)
    port map (
      pi_clk      => pi_clk,
      pi_rst_n    => pi_rst_n,
      pi_inData   => s_arbitPort,
      pi_inValid  => s_fifoInValid,
      po_inReady  => s_fifoInReady,
      po_outData  => s_fifoOutPort,
      po_outValid => s_fifoOutValid,
      pi_outReady => s_fifoOutReady);
  a_barDoneF <= s_fifoInValid and s_fifoInReady;

  -- Response Channel Switch
  i_switchB : entity work.{{name}}RSwitch1N
    generic map (
      g_Count => g_PortCount)
    port map (
      pi_enable => s_fifoOutValid,
      pi_select => s_fifoOutPort,
      pi_input_od => si_masterB_od,
      po_input_do => so_masterB_do,
      po_outputs_od => so_slavesB_od,
      pi_outputs_do => si_slavesB_do);
  s_fifoOutReady <= si_masterB_od.valid and so_masterB_do.ready;

end {{name}}WrMultiplexer;
