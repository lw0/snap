library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosi_ctrl.all;
use work.fosi_stream.all;
use work.fosi_user.all;
use work.fosi_util.all;


entity NativeStreamInfiniteSource is
  generic (
    g_SendData : boolean := true;
    g_AssertLast : boolean := false;
    g_Enabled : boolean := true);
  port (
    pi_clk     : in std_logic;
    pi_rst_n   : in std_logic;

    po_stm_ms  : out t_NativeStream_ms;
    pi_stm_sm  : in  t_NativeStream_sm);
end NativeStreamInfiniteSource;

architecture NativeStreamInfiniteSource of NativeStreamInfiniteSource is

begin

  po_stm_ms.tdata <= (others => '1');
  po_stm_ms.tkeep <= (others => f_logic(g_SendData));
  po_stm_ms.tlast <= f_logic(g_AssertLast);
  po_stm_ms.tvalid <= f_logic(g_Enabled);

end NativeStreamInfiniteSource;
