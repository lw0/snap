library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;

package fosix_axi_util is

  -- returns nextBurstCount in (C_AXI_BURST_LEN_W-1 downto 0) and
  -- nextBurstLast in (C_AXI_BURST_LEN_W)
  function f_nextBurstParam(v_address : t_AxiWordAddr; v_count : t_RegData; v_maxLen : t_AxiBurstLen) return unsigned(C_AXI_BURST_LEN_W downto 0);


end fosix_axi_util;

package body fosix_axi_util is


end fosix_axi_util;
