library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosi_ctrl.all;
use work.fosi_stream.all;
use work.fosi_user.all;
use work.fosi_util.all;


entity NativeStreamInfiniteSink is
  generic (
    g_Enabled : boolean := true);
  port (
    pi_clk     : in  std_logic;
    pi_rst_n   : in  std_logic;

    pi_stm_ms  : in  t_NativeStream_ms;
    po_stm_sm  : out t_NativeStream_sm);
end NativeStreamInfiniteSink;

architecture NativeStreamInfiniteSink of NativeStreamInfiniteSink is

begin

  po_stm_sm.ready <= f_logic(g_Enabled);

end NativeStreamInfiniteSink;
