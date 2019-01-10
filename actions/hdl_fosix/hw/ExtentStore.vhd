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

  constant c_LRowEntryAddrWidth : integer := 4;
  subtype t_LRowEntryAddr is unsigned (c_LRowEntryAddrWidth-1 downto 0);

  constant c_EntryAddrWidth : integer := c_RowAddrWidth + c_RowEntryAddrWidth;
  subtype t_EntryAddr is unsigned (c_EntryAddrWidth-1 downto 0);

  constant c_LRowWidth : integer := (2**c_LRowEntryAddrWidth) * c_LBlkWidth;
  subtype t_LRow is unsigned (c_LRowWidth-1 downto 0);

  signal s_lstoreWrAddr : t_EntryAddr;
  signal s_lstoreWrData : t_LBlk;
  signal s_lstoreWrEn   : std_logic;
  signal s_lstoreRdAddr : t_LRowAddr;
  signal s_lstoreRdData : t_LRow;

  signal s_pstoreWrAddr : t_EntryAddr;
  signal s_pstoreWrData : t_PBlk;
  signal s_pstoreWrEn   : std_logic;
  signal s_pstoreRdAddr : t_EntryAddr;
  signal s_pstoreRdData : t_PBlk;

begin


  -- Logical Block Offset Store Instantiation
  s_lstoreWrAddr_v <= std_logic_vector(s_lstoreWrAddr);
  s_lstoreWrData_v <= std_logic_vector(s_lstoreWrData);
  s_lstoreWrEn_v   <= std_logic_vector(s_lstoreWrEn);
  s_lstoreRdAddr_v <= std_logic_vector(s_lstoreRdAddr);
  s_lstoreRdData   <= t_LRow(s_lstoreRdData_v);
  i_lstore : bram_w256x32r16x512
    port map(
      clka  => pi_clk,
      wea   => s_lstoreWrEn_v,
      addra => s_lstoreWrAddr_v,
      dina  => s_lstoreWrData_v,
      clkb  => pi_clk,
      addrb => s_lstoreRdAddr_v,
      doutb => s_lstoreRdData_v);

  -- Physical Block Store Instantiation
  s_pstoreWrAddr_v <= std_logic_vector(s_pstoreWrAddr);
  s_pstoreWrData_v <= std_logic_vector(s_pstoreWrData);
  s_pstoreWrEn_v   <= std_logic_vector(s_pstoreWrEn);
  s_pstoreRdAddr_v <= std_logic_vector(s_pstoreRdAddr);
  s_pstoreRdData   <= t_LRow(s_pstoreRdData_v);
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
