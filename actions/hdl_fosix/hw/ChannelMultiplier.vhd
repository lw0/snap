library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity ChannelMultiplier is
  generic (
    g_OutPorts     : integer range 1 to 15);
  port (
    pi_clk         : in std_logic;
    pi_rst_n       : in std_logic;

    pi_valid       : in std_logic;
    po_ready       : out std_logic;

    po_valid       : in unsigned(g_OutPorts-1 downto 0);
    pi_ready       : out unsigned(g_OutPorts-1 downto 0));
end ChannelMultiplier;

architecture ChannelMultiplier of ChannelMultiplier is

  signal s_ready : std_logic;
  signal s_readyMask : unsigned(g_OutPorts-1 downto 0);

begin

  s_ready <= f_and(s_readyMask or pi_ready);
  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' or s_ready = '1' then
        s_readyMask <= (others => '0');
      else
        s_readyMask <= s_readyMask or pi_ready;
      end if;
    end if;
  end process;

  po_ready <= s_ready;
  po_valid <= (others => pi_valid) and not s_readyMask;

end ChannelMultiplier;
