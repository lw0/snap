--?AXITypes
-->{{name}}RdMultiplexer.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity {{name}}RdMultiplexer is
  generic (
    g_PortCount : positive,
    g_FIFOCntWidth : natural );
  port (
    pi_clk     : in  std_logic;
    pi_rst_n   : in  std_logic;

    po_master_ms : out t_AxiRd_ms;
    pi_master_sm : in  t_AxiRd_sm;

    pi_slaves_ms : out t_AxiRd_v_ms(g_PortCount-1 downto 0);
    po_slaves_sm : in  t_AxiRd_v_sm(g_PortCount-1 downto 0) );
end {{name}}RdMultiplexer;

architecture {{name}}RdMultiplexer of {{name}}RdMultiplexer is

  subtype t_PortVector is unsigned (g_PortCount-1 downto 0);
  constant c_PortNumberWidth : natural := f_clog2(g_PortCount);
  subtype t_PortNumber is unsigned (c_PortNumberWidth-1 downto 0);

  -- Individual {{name}}Rd Address and Read Channels:
  signal so_masterA_od : t_AxiA_od;
  signal si_masterA_do : t_AxiA_do;
  signal so_masterR_do : t_AxiR_do;
  signal si_masterR_od : t_AxiR_od;

  signal si_slavesA_od : t_AxiA_v_od;
  signal so_slavesA_do : t_AxiA_v_do;
  signal si_slavesR_do : t_AxiR_v_do;
  signal so_slavesR_od : t_AxiR_v_od;

  -- Address Channel Arbiter and Switch:
  signal s_arbitRequest : t_PortVector;
  signal s_arbitPort    : t_PortNumber;
  signal s_arbitActive  : std_logic;
  signal s_arbitNext    : std_logic;

  signal s_barDone : unsigned(1 downto 0);
  alias a_barDoneA is s_barDone(0);
  alias a_barDoneF is s_barDone(1);
  signal s_barMask : unsigned(1 downto 0);
  alias a_barMaskA is s_barMask(0);
  alias a_barMaskF is s_barMask(1);
  signal s_barContinue : std_logic;

  signal s_switchAEnable : std_logic;
  signal s_slavesAValid : t_PortVector;

  -- Read Channel FIFO and Switch:
  signal s_fifoInReady : std_logic;
  signal s_fifoInValid : std_logic;

  signal s_fifoOutPort : t_PortNumber;
  signal s_fifoOutReady : std_logic;
  signal s_fifoOutValid : std_logic;

begin

  -- Individual {{name}}Rd Address and Read Channels:
  process (pi_master_sm, so_masterA_od, so_masterR_do,
           pi_slaves_ms, so_slavesA_do, so_slavesR_od)
    variable v_idx : integer range 0 to g_PortCount-1;
  begin
    po_master_ms <= f_axiRdJoin_ms(so_masterA_od, so_masterR_do);
    si_masterA_do <= f_axiRdSplitA_sm(pi_master_sm);
    si_masterR_od <= f_axiRdSplitR_sm(pi_master_sm);
    for v_idx in 0 to g_PortCount-1 loop
      po_slaves_sm(v_idx) <= f_axiRdJoin_sm(so_slavesA_do(v_idx), so_slavesR_od(v_idx));
      si_slavesA_od(v_idx) <= f_axiRdSplitA_ms(pi_slaves_ms(v_idx));
      si_slavesR_do(v_idx) <= f_axiRdSplitR_ms(pi_slaves_ms(v_idx));
    end loop;
  end process;

  -- Address Channel Arbiter:
  s_arbitRequest <= s_slavesAValid;
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
      g_Count => 2)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_signal => s_barDone,
      po_mask => s_barMask,
      po_continue => s_barContinue);


  -- Address Channel Switch:
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

  -- Read Channel FIFO:
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

  -- Read Channel Switch:
  i_switchR : entity work.{{name}}RSwitch1N
    generic map (
      g_Count => g_PortCount)
    port map (
      pi_enable => s_fifoOutValid,
      pi_select => s_fifoOutPort,
      pi_input_od => si_masterR_od,
      po_input_do => so_masterR_do,
      po_outputs_od => so_slavesR_od,
      pi_outputs_do => si_slavesR_do,
      po_beat => s_readBeat);
  s_fifoOutReady <= si_masterR_od.valid and si_masterR_od.last and so_masterR_do.ready;

end {{name}}RdMultiplexer;
