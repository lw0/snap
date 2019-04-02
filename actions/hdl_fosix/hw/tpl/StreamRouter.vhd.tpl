-->{{name}}StreamRouter.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_ctrl.all;
use work.fosix_stream.all;
use work.fosix_util.all;


entity {{name}}StreamRouter is
  generic (
    g_InPorts      : integer range 1 to 15;
    g_OutPorts     : integer range 1 to 16);
  port (
    pi_clk         : in std_logic;
    pi_rst_n       : in std_logic;

    -- OutPort n is mapped to InPort pi_mapping(4n+3..4n)
    --  InPort 15 is an infinite Null Byte Stream
    pi_mapping     : in  unsigned(g_OutPorts*4-1 downto 0);

    pi_inPorts_ms  : in  t_{{name}}_v_ms(0 to g_InPorts-1);
    po_inPorts_sm  : out t_{{name}}_v_sm(0 to g_InPorts-1);

    po_outPorts_ms : out t_{{name}}_v_ms(0 to g_OutPorts-1);
    pi_outPorts_sm : in  t_{{name}}_v_sm(0 to g_OutPorts-1));
end StreamRouter;

architecture {{name}}StreamRouter of {{name}}StreamRouter is

  subtype t_PortIndex is integer range 0 to 15;

  type t_InOutBits is array (g_InPorts-1 downto 0)
                    of unsigned (g_OutPorts-1 downto 0);

  signal s_inPorts_ms     : t_{{name}}_v_ms(0 to g_InPorts-1);
  signal s_inPorts_sm     : t_{{name}}_v_sm(0 to g_InPorts-1);
  signal s_outPorts_ms    : t_{{name}}_v_ms(0 to g_OutPorts-1);
  signal s_outPorts_sm    : t_{{name}}_v_sm(0 to g_OutPorts-1);

  signal s_validLines     : t_SrcDstBits;
  signal s_readyLines     : t_SrcDstBits;


begin

  s_inPorts_ms   <= pi_inPorts_ms;
  po_inPorts_sm  <= s_inPorts_sm;
  po_outPorts_ms <= s_outPorts_ms;
  s_outPorts_sm  <= pi_outPorts_sm;

  -----------------------------------------------------------------------------
  -- Port Multiplier
  -----------------------------------------------------------------------------
  i_multipliers:
  for v_idx in 0 to g_InPorts-1 generate
    signal s_readyMask : unsigned (g_OutPorts-1 downto 0);
  begin
    i_barrier : entity work.UtilBarrier
      generic map (
        g_Count => g_OutPorts)
      port map (
        pi_clk      => pi_clk,
        pi_rst_n    => pi_rst_n,
        pi_signal   => s_readyLines(v_idx),
        po_mask     => s_readyMask,
        po_continue => s_inPorts_sm(v_idx).tready);
     s_validLines <= (others => s_inPorts_ms(v_idx).tvalid) and not s_readyMask;
  end generate i_multipliers;

  -----------------------------------------------------------------------------
  -- Stream Switch
  -----------------------------------------------------------------------------
  process(pi_mapping, s_inPorts_ms, s_outPorts_sm)
    variable v_srcPort : t_PortIndex;
    variable v_dstPort : t_PortIndex;
  begin
    s_readyLines <= (others => (others => '1'));
    for v_dstPort in 0 to g_OutPorts-1 loop
      v_srcPort := to_integer(pi_mapping(4*v_dstPort+3 downto 4*v_dstPort));
      if v_srcPort < g_InPorts then
        s_outPorts_ms(v_dstPort).tdata <= s_inPorts_ms(v_srcPort).tdata;
        s_outPorts_ms(v_dstPort).tstrb <= s_inPorts_ms(v_srcPort).tstrb;
        s_outPorts_ms(v_dstPort).tkeep <= s_inPorts_ms(v_srcPort).tkeep;
        s_outPorts_ms(v_dstPort).tlast <= s_inPorts_ms(v_srcPort).tlast;
        s_outPorts_ms(v_dstPort).tvalid <= s_validLines(v_srcPort)(v_dstPort);
        s_readyLines(v_srcPort)(v_dstPort) <= s_outPorts_sm(v_dstPort).tready;
      else
        s_outPorts_ms(v_dstPort) <= c_Stm{{name}}Safe_ms;
      end if;
    end loop;
  end process;

end {{name}}StreamRouter;
