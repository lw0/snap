library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_util.all;

entity FIFO is
  generic (
    g_DataWidth : integer;
    g_CntWidth  : integer);
  port (
    pi_clk      : in  std_logic;
    pi_rst_n    : in  std_logic;

    pi_inData   : in  unsigned(g_DataWidth-1 downto 0);
    pi_inValid  : in  std_logic;
    po_inReady  : out std_logic;

    po_outData  : out unsigned(g_DataWidth-1 downto 0);
    po_outValid : out std_logic;
    pi_outReady : in  std_logic);
end FIFO;

architecture FIFO of FIFO is

  constant c_Depth : integer := 2**g_CntWidth;
  subtype t_Cnt is unsigned(g_CntWidth-1 downto 0);
  constant c_CntOne : t_Cnt := to_unsigned(1, g_CntWidth);

  subtype t_Data is unsigned(g_DataWidth-1 downto 0);
  type t_Buffer is array(0 to c_Depth-1) of t_Data;
  signal s_buffer : t_Buffer;
  signal s_rdCnt : t_Cnt;
  signal s_wrCnt : t_Cnt;
  signal s_inReady : std_logic;
  signal s_outValid : std_logic;

begin

  s_inReady <= f_logic(s_wrCnt /= (s_rdCnt - c_CntOne));
  s_outValid <= f_logic(s_rdCnt /= s_wrCnt);
  po_outData <= s_buffer(to_integer(s_rdCnt));

  process(pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_rdCnt <= (others => '0');
        s_wrCnt <= (others => '0');
      else
        if pi_inValid = '1' and s_inReady = '1' then
          s_buffer(to_integer(s_wrCnt)) <= pi_inData;
          s_wrCnt <= s_wrCnt + to_unsigned(1, g_CntWidth);
        end if;
        if s_outValid = '1' and pi_outReady = '1' then
          s_rdCnt <= s_rdCnt + to_unsigned(1, g_CntWidth);
        end if;
      end if;
    end if;
  end process;

  po_inReady <= s_inReady;
  po_outValid <= s_outValid;

end FIFO;
