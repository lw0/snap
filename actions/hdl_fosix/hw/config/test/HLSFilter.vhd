-->HLSFilterStreamRouter.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_user.all;


entity HLSFilter is
  port (
    pi_start : in  std_logic;
    po_ready : out std_logic;

    pi_rst_n : in  std_logic;
    pi_clk : in  std_logic);
end HLSFilter;

architecture HLSFilter of HLSFilter is

  signal s_ap_start : std_logic;
  signal s_ap_done : std_logic;

begin

  -- Protocol State Machine
  process(pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_ap_start <= '0';
      elsif s_ap_start = '0' and pi_start = '1' then
        s_ap_start <= '1';
      elsif s_ap_start = '1' and s_ap_done = '1' then
        s_ap_start <= '0';
      end if;
    end if;
  end process;
  po_ready <= not s_ap_start;

  -- Instantiation
  i_hls : entity work.hls_filter
    port map (
      ap_start => s_ap_start,
      ap_done => s_ap_done,
      ap_rst_n => pi_rst_n,
      ap_clk => pi_clk);

  -- Signal conversion
end HLSFilter;
