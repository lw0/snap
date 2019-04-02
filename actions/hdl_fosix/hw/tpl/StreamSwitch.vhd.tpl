-->{{name}}StreamSwitch.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_ctrl.all;
use work.fosix_stream.all;
use work.fosix_util.all;


entity {{name}}StreamSwitch is
  generic (
    g_InPorts      : integer range 1 to 15;
    g_OutPorts     : integer range 1 to 16);
  port (
    pi_clk         : in std_logic;
    pi_rst_n       : in std_logic;

    -- OutPort n is mapped to InPort pi_mapping(4n+3..4n)
    --  InPort 15 is an infinite Null Byte Stream
    pi_regMapLo    : in  t_RegData;
    pi_regMapHi    : in  t_RegData;

    pi_inPorts_ms  : in  t_{{name}}_v_ms(0 to g_InPorts-1);
    po_inPorts_sm  : out t_{{name}}_v_sm(0 to g_InPorts-1);

    po_outPorts_ms : out t_{{name}}_v_ms(0 to g_OutPorts-1);
    pi_outPorts_sm : in  t_{{name}}_v_sm(0 to g_OutPorts-1));
end {{name}}StreamSwitch;

architecture {{name}}StreamSwitch of {{name}}StreamSwitch is

  signal s_regMap         : unsigned(2*c_RegDataWidth-1 downto 0);

  signal s_mapping        : unsigned(g_InPorts*4-1 downto 0);
  signal s_inPorts_ms     : t_{{name}}_v_ms(0 to g_InPorts-1);
  signal s_inPorts_sm     : t_{{name}}_v_sm(0 to g_InPorts-1);
  signal s_outPorts_ms    : t_{{name}}_v_ms(0 to g_OutPorts-1);
  signal s_outPorts_sm    : t_{{name}}_v_sm(0 to g_OutPorts-1);

begin

  s_regMap <= pi_regMapHi & pi_regMapLo;
  s_mapping <= f_resize(s_regMap, 4*g_InPorts, 0);

  -----------------------------------------------------------------------------
  -- Stream Switch
  -----------------------------------------------------------------------------
  s_inPorts_ms   <= pi_inPorts_ms;
  po_inPorts_sm  <= s_inPorts_sm;
  po_outPorts_ms <= s_outPorts_ms;
  s_outPorts_sm  <= pi_outPorts_sm;
  process(s_mapping, s_dummyMap, s_inPorts_ms, s_outPorts_sm)
    type t_BoolArray is array (integer range<>) of boolean;
    variable v_guards : t_BoolArray(0 to 15);
    variable v_srcPort : integer range 0 to 15;
    variable v_dstPort : integer range 0 to 15;
  begin
    v_guards := (others => false);
    s_inPorts_sm <= (others => c_{{name}}Safe_sm);
    for v_dstPort in 0 to g_OutPorts-1 loop
      v_srcPort := to_integer(pi_mapping(4*v_dstPort+3 downto 4*v_dstPort));
      if v_srcPort < g_InPorts and not v_guards(v_srcPort) then
        v_guards(v_srcPort) <= true;
        s_outPorts_ms(v_srcPort) <= s_inPorts_ms(v_srcPort);
        s_inPorts_sm(v_srcPort) <= s_outPorts_sm(v_srcPort);
      else
        s_outPorts_ms(v_srcPort) <= c_{{name}}Safe_ms;
      end if;
    end loop;
  end process;

end {{name}}StreamSwitch;
