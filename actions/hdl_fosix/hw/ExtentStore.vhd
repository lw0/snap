library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity ExtentStore is
  generic (
    g_Ports     : integer);
  port (
    pi_clk      : in  std_logic;
    pi_rst_n    : in  std_logic;

    po_intReq   : out std_logic;
    pi_intAck   : in  std_logic;

    pi_regs_ms  : in  t_RegPort_ms;
    po_regs_sm  : out t_RegPort_sm;

    pi_ports_ms : in  t_BlkMaps_ms(0 to g_Ports-1);
    po_ports_sm : out t_BlkMaps_sm(0 to g_Ports-1)
);
end ExtentStore;

architecture ExtentStore of ExtentStore is

  component bram_w256x32r16x512 is
    port (
      clka  : in  std_logic;
      wea   : in  std_logic_vector(  0 downto 0);
      addra : in  std_logic_vector(  7 downto 0);
      dina  : in  std_logic_vector( 31 downto 0);
      clkb  : in  std_logic;
      addrb : in  std_logic_vector(  3 downto 0);
      doutb : out std_logic_vector(511 downto 0));
  end component;
  signal s_lstoreWrAddr_v : std_logic_vector(  7 downto 0);
  signal s_lstoreWrData_v : std_logic_vector( 31 downto 0);
  signal s_lstoreWrEn_v   : std_logic_vector(  0 downto 0);
  signal s_lstoreRdAddr_v : std_logic_vector(  3 downto 0);
  signal s_lstoreRdData_v : std_logic_vector(511 downto 0));

  component bram_w256x64r256x64 is
    port (
      clka  : in  std_logic;
      wea   : in  std_logic_vector(  0 downto 0);
      addra : in  std_logic_vector(  7 downto 0);
      dina  : in  std_logic_vector( 63 downto 0);
      clkb  : in  std_logic;
      addrb : in  std_logic_vector(  7 downto 0);
      doutb : out std_logic_vector( 63 downto 0));
  end component;
  signal s_pstoreWrAddr_v : std_logic_vector(  7 downto 0);
  signal s_pstoreWrData_v : std_logic_vector( 63 downto 0);
  signal s_pstoreWrEn_v   : std_logic_vector(  0 downto 0);
  signal s_pstoreRdAddr_v : std_logic_vector(  7 downto 0);
  signal s_pstoreRdData_v : std_logic_vector( 63 downto 0));

  constant c_LRowAddrWidth : integer := 4;
  subtype t_LRowAddr is unsigned (c_LRowAddrWidth-1 downto 0);

  constant c_LColAddrWidth : integer := 4;
  constant c_LColCount : integer := 2**c_LColAddrWidth;
  subtype t_LColAddr is unsigned (c_LColAddrWidth-1 downto 0);

  constant c_PBlkAddrWidth : integer := c_LRowAddrWidth + c_LColAddrWidth;
  subtype t_PBlkAddr is unsigned (c_PBlkAddrWidth-1 downto 0);

  constant c_LRowWidth : integer := c_LColCount * c_LBlkWidth;
  subtype t_LRow is unsigned (c_LRowWidth-1 downto 0);

  signal s_lstoreWrAddr : t_EntryAddr;
  signal s_lstoreWrData : t_LBlk;
  signal s_lstoreWrEn   : std_logic;
  signal s_pstoreWrAddr : t_EntryAddr;
  signal s_pstoreWrData : t_PBlk;
  signal s_pstoreWrEn   : std_logic;

  signal s_lrowAddr_0   : t_LRowAddr;
  signal s_reqLblk_0   : t_LRowAddr;
  signal s_reqPort_0   : t_LRowAddr;
  signal s_enable_0   : t_LRowAddr;

  signal s_lrowAddr_1   : t_LRowAddr;
  signal s_reqLblk_1   : t_LRowAddr;
  signal s_reqPort_1   : t_LRowAddr;
  signal s_enable_1   : t_LRowAddr;

  signal s_lrowAddr_2   : t_LRowAddr;
  signal s_lrow_2       : t_LRow;
  signal s_reqLBlk_2   : t_LRowAddr;

  type t_RowLBlks is array (integer range <>) of t_LBlk;
  signal s_extLBlks_2 : t_RowLBlks(c_LColCount-2 downto 0);
  signal s_extLCnts_2 : t_RowLBlks(c_LColCount-2 downto 0);
  signal s_extValids_2 : unsigned(c_LColCount-2 downto 0);

  signal s_lcolAddr_2   : t_LRowAddr;
  signal s_extLBlk_2   : t_LRowAddr;
  signal s_extLCnt_2   : t_LRowAddr;
  signal s_extValid_2   : t_LRowAddr;
  signal s_reqPort_2   : t_LRowAddr;
  signal s_enable_2   : t_LRowAddr;
  signal s_pblkAddr_2   : t_PBlkAddr;

  signal s_extLBlk_3   : t_LRowAddr;
  signal s_extLCnt_3   : t_LRowAddr;
  signal s_extValid_3   : t_LRowAddr;
  signal s_reqPort_3   : t_LRowAddr;
  signal s_enable_3   : t_LRowAddr;

  signal s_pblk_4       : t_PBlk;
  signal s_extLBlk_4   : t_LRowAddr;
  signal s_extLCnt_4   : t_LRowAddr;
  signal s_extValid_4   : t_LRowAddr;
  signal s_reqPort_4   : t_LRowAddr;
  signal s_enable_4   : t_LRowAddr;

begin

  -- Matching Logic (Stage 2)
  process(s_lrow_2, s_reqLBlk_2)
    variable v_thisCol : t_LBlk;
    variable v_nextCol : t_LBlk;
  begin
    for v_index in 0 to c_ColCount-2 loop
      v_thisLCol := f_resize(s_lrow_2, c_LBlkWidth, v_index * c_LBlkWidth);
      v_nextLCol := f_resize(s_lrow_2, c_LBlkWidth, (v_index+1) * c_LBlkWidth);
      s_extValids_2(v_index)
      if v_thisCol <= s_reqLBlk_2 and s_reqLBlk_2 < v_nextCol then
        --TODO-lw continue
      end if;
    end loop;
  end process;


  -----------------------------------------------------------------------------
  -- Pipeline Registers
  -----------------------------------------------------------------------------

  process(pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_enable_1   <= '0';
        s_enable_2   <= '0';
        s_enable_3   <= '0';
        s_extValid_3 <= '0';
        s_enable_4   <= '0';
        s_extValid_4 <= '0';
      else
        s_lrowAddr_1 <= s_lrowAddr_0;
        s_reqLblk_1  <= s_reqLblk_0;
        s_reqPort_1  <= s_reqPort_0;
        s_enable_1   <= s_enable_0;

        s_lrowAddr_2 <= s_lrowAddr_1;
        s_reqLBlk_2  <= s_reqLblk_1;
        s_reqPort_2  <= s_reqPort_1;
        s_enable_2   <= s_enable_1;

        s_extLBlk_3  <= s_extLBlk_2;
        s_extLCnt_3  <= s_extLCnt_2;
        s_extValid_3 <= s_extValid_2;
        s_reqPort_3  <= s_reqPort_2;
        s_enable_3   <= s_enable_2;

        s_extLBlk_4  <= s_extLBlk_3;
        s_extLCnt_4  <= s_extLCnt_3;
        s_extValid_4 <= s_extValid_3;
        s_reqPort_4  <= s_reqPort_3;
        s_enable_4   <= s_enable_3;
      end if;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- BRAM Instatiations
  -----------------------------------------------------------------------------

  -- Logical Block Store
  s_lstoreWrAddr_v <= std_logic_vector(s_lstoreWrAddr);
  s_lstoreWrData_v <= std_logic_vector(s_lstoreWrData);
  s_lstoreWrEn_v   <= std_logic_vector(s_lstoreWrEn);
  s_lstoreRdAddr_v <= std_logic_vector(s_lrowAddr_0);
  s_lrow_2 <= t_LRow(s_lstoreRdData_v);
  i_lstore : bram_w256x32r16x512
    port map(
      clka  => pi_clk,
      wea   => s_lstoreWrEn_v,
      addra => s_lstoreWrAddr_v,
      dina  => s_lstoreWrData_v,
      clkb  => pi_clk,
      addrb => s_lstoreRdAddr_v,
      doutb => s_lstoreRdData_v);

  -- Physical Block Store
  s_pstoreWrAddr_v <= std_logic_vector(s_pstoreWrAddr);
  s_pstoreWrData_v <= std_logic_vector(s_pstoreWrData);
  s_pstoreWrEn_v   <= std_logic_vector(s_pstoreWrEn);
  s_pstoreRdAddr_v <= std_logic_vector(s_pblkAddr_2);
  s_pblk_4 <= t_LRow(s_pstoreRdData_v);
  i_pstore : bram_w256x64r256x64
    port map(
      clka  => pi_clk,
      wea   => s_pstoreWrEn_v,
      addra => s_pstoreWrAddr_v,
      dina  => s_pstoreWrData_v,
      clkb  => pi_clk,
      addrb => s_pstoreRdAddr_v,
      doutb => s_pstoreRdData_v);

end ExtentStore;
