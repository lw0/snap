--?AXIChannelTypes
-->{{name_ch}}Switch1N.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity {{name_ch}}Switch1N is
  generic (
    g_Count : positive);
  port (
    pi_enable       : in  std_logic;
    pi_select       : in  unsigned(f_clog2(g_Count)-1 downto 0);

    pi_input_od     : in  t_{{name_ch}}_od;
    po_input_do     : out t_{{name_ch}}_do;

    po_outputs_od   : out t_{{name_ch}}_v_od(g_Count-1 downto 0);
    pi_outputs_do   : in  t_{{name_ch}}_v_do(g_Count-1 downto 0);

    po_inputValid   : out std_logic;
    po_inputReady   : out std_logic;
    po_outputsValid : out unsigned(g_Count-1 downto 0);
    po_outputsReady : out unsigned(g_Count-1 downto 0);
    po_beat         : out std_logic);
end {{name_ch}}Switch1N;

architecture {{name_ch}}Switch1N of {{name_ch}}Switch1N is

begin

  process (pi_enable, pi_select, pi_input_od, pi_outputs_do)
    variable v_idx : integer range 0 to g_Count-1;
    variable v_sel : integer range 0 to 2**f_clog2(g_PortCount)-1;
  begin
    v_sel := to_integer(pi_select);
    po_inputValid <= pi_input_od.valid
    po_input_do <= c_{{name_ch}}Null_do;
    po_inputReady <= '0';
    po_beat <= '0';
    for v_idx in 0 to g_Count-1 loop
      po_outputsReady(v_idx) <= pi_outputs_do(v_idx).ready;
      po_outputs_od(v_idx) <= c_{{name_ch}}Null_od;
      po_outputsValid(v_idx) <= '0';
      if pi_enable = '1' and v_idx = v_sel then
        po_input_do <= pi_outputs_do(v_idx);
        po_inputReady <= pi_outputs_do(v_idx).ready;
        po_outputs_od(v_idx) <= pi_input_od;
        po_outputsValid(v_idx) <= pi_input_od.valid;
        po_beat <= pi_outputs_do(v_idx).ready and pi_input_od.valid;
      end if;
    end if;
  end process;

end {{name_ch}}Switch1N;
