--?StreamTypes
-->StreamRouter{{name}}.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity StreamRouter{{name}} is
  generic (
    g_InPorts      : integer range 1 to 15;
    g_OutPorts     : integer range 1 to 16);
  port (
    pi_clk         : in std_logic;
    pi_rst_n       : in std_logic;

    -- OutPort n is mapped to InPort pi_mapping(4n+3..4n)
    --  InPort 15 is an infinite Null Byte Stream
    pi_mapping     : in  unsigned(g_OutPorts*4-1 downto 0);

    pi_inPorts_ms  : in  t_Stm{{name}}_ms_v(0 to g_InPorts-1);
    po_inPorts_sm  : out t_Stm{{name}}_sm_v(0 to g_InPorts-1);

    po_outPorts_ms : out t_Stm{{name}}_ms_v(0 to g_OutPorts-1);
    pi_outPorts_sm : in  t_Stm{{name}}_sm_v(0 to g_OutPorts-1));
end StreamRouter;

architecture StreamRouter{{name}} of StreamRouter{{name}} is

  subtype t_PortIndex is integer range 0 to 15;

  type t_InOutBits is array (g_InPorts-1 downto 0)
                    of unsigned (g_OutPorts-1 downto 0);

  signal s_inPorts_ms     : t_AxiStreams_ms_v(0 to g_InPorts-1);
  signal s_inPorts_sm     : t_AxiStreams_sm_v(0 to g_InPorts-1);
  signal s_outPorts_ms    : t_AxiStreams_ms_v(0 to g_OutPorts-1);
  signal s_outPorts_sm    : t_AxiStreams_sm_v(0 to g_OutPorts-1);

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
    -- i_multiplier : entity work.ChannelMultiplier
    --   generic map (
    --     g_OutPorts => g_OutPorts )
    --   port map (
    --     pi_clk   => pi_clk,
    --     pi_rst_n => pi_rst_n,
    --     pi_valid => s_inPorts_ms(v_idx).tvalid,
    --     po_ready => s_inPorts_sm(v_idx).tready,
    --     po_valid => s_validLines(v_idx),
    --     pi_ready => s_readyLines(v_idx) );
  end generate i_multipliers;

  -----------------------------------------------------------------------------
  -- Stream Switch
  -----------------------------------------------------------------------------
  process(all)
    variable v_srcPort : t_PortIndex;
    variable v_dstPort : t_PortIndex;
  begin
    for v_dstPort in 0 to g_OutPorts-1 loop
      for v_srcPort in 0 to g_InPorts-1 loop
        -- unused ready lines are asserted to avoid deadlocking the ChannelMultiplier
        s_readyLines(v_srcPort)(v_dstPort) <= '1';
      end loop;
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

end StreamRouter{{name}};
