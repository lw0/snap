library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;
use work.fosix_blockmap.all;


entity ExtentStore_Arbiter is
  generic (
    g_Ports     : integer);
  port (
    pi_clk      : in  std_logic;
    pi_rst_n    : in  std_logic;

    pi_reqEn    : in  unsigned(g_Ports-1 downto 0);
    pi_reqData  : in  t_MapReqs(g_Ports-1 downto 0);
    po_reqAck   : out unsigned(g_Ports-1 downto 0);

    po_reqEn    : out std_logic;
    po_reqPort  : out std_logic;
    po_reqData  : out t_MapReq);
end ExtentStore_Arbiter;

architecture ExtentStore_Arbiter of ExtentStore_Arbiter is

  constant c_PortAddrWidth : integer := f_clog2(g_Ports);
  subtype t_PortAddr is unsigned (c_PortAddrWidth-1 downto 0);

  subtype t_PortVector is unsigned (g_Ports-1 downto 0);
  constant c_PVZero : t_PortVector := to_unsigned(0, g_Ports);
  constant c_PVOne : t_PortVector := to_unsigned(1, g_Ports);

  signal s_mask_q : t_PortVector;
  signal s_ureq : t_PortVector;
  signal s_mreq : t_PortVector;
  signal s_ugnt : t_PortVector;
  signal s_mgnt : t_PortVector;
  signal s_gnt  : t_PortVector;
  signal s_mask : t_PortVector;
  signal s_port : t_PortAddr;
  signal s_enable : std_logic;

begin

  -- unmasked and masked request vector (mask is necessary for round robin behavior)
  s_ureq <= pi_reqEn;
  s_mreq <= pi_reqEn and s_mask_q;
  -- produce grant vector: isolate the lowest set request bit (e.g. 110100 -> 000100)
  s_ugnt <= s_ureq and ((not s_ureq) + c_PVOne);
  s_mgnt <= s_mreq and ((not s_mreq) + c_PVOne);
  -- select unmasked grant vector if no masked request bits remain to implement wrap
  s_gnt <= s_ugnt when s_mreq = c_PVZero else s_mgnt;
  -- produce new mask: set all bits left of the granted bit (e.g. 000100 -> 111000)
  s_mask <= not ((s_gnt - c_PVOne) or s_gnt);
  -- encode grant vector into port address
  s_port <= f_encode(s_gnt, c_PortAddrWidth);

  -- Outputs
  po_reqEn <= f_or(s_gnt);
  po_reqAck <= s_gnt;
  po_reqPort <= s_port;
  po_reqData <= pi_reqData(to_integer(s_port));

  -- register to maintain round robin mask
  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_mask_q <= (others => '0');
      else
        s_mask_q <= s_mask;
      end if;
    end if;
  end process;

end ExtentStore_Arbiter;
