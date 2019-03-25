--?AXIChannelTypes
-->{{name_ch}}N1.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity {{name_ch}}N1 is
  generic (
    g_Count : positive);
  port (
    pi_clk         : in  std_logic;
    pi_rst_n       : in  std_logic;

    pi_enable      : in  std_logic;
    pi_select      : in  unsigned(f_clog2(g_Count)-1 downto 0);

    pi_inputs_od   : in  t_{{name_ch}}_v_od(g_Count-1 downto 0);
    po_inputs_do   : out t_{{name_ch}}_v_do(g_Count-1 downto 0);

    po_output_od   : out t_{{name_ch}}_od;
    pi_output_do   : in  t_{{name_ch}}_do;

    po_inputsValid : out unsigned(g_Count-1 downto 0);
    po_inputsReady : out unsigned(g_Count-1 downto 0);
    po_outputValid : out std_logic;
    po_outputReady : out std_logic;
    po_beat        : out std_logic);
end {{name_ch}}N1;

architecture {{name_ch}}N1 of {{name_ch}}N1 is

begin

  process (pi_enable, pi_select, pi_inputs_od, pi_output_do)
    variable v_idx : integer range 0 to g_Count-1;
    variable v_sel : integer range 0 to 2**f_clog2(g_PortCount)-1;
  begin
    v_sel := to_integer(pi_select);
    po_outputReady <= pi_output_do.ready;
    po_output_od <= c_{{name_ch}}Null_od;
    po_outputValid <= '0';
    po_beat <= '0';
    for v_idx in 0 to g_Count-1 loop
      po_inputsValid(v_idx) <= pi_inputs_od(v_idx).valid;
      po_inputs_do(v_idx) <= c_{{name_ch}}Null_do;
      po_inputsReady(v_idx) <= '0';
      if pi_enable = '1' and v_idx = v_sel then
        po_output_od <= pi_inputs_od(v_idx);
        po_outputValid <= pi_inputs_od(v_idx).valid;
        po_inputs_do(v_idx) <= pi_output_do;
        po_inputsReady(v_idx) <= pi_output_do.ready;
        po_beat <= pi_inputs_od(v_idx).valid and pi_output_do.ready;
      end if;
    end if;
  end process;

end {{name_ch}}N1;
