library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;
use work.fosix_blockmap.all;


entity ExtentStore_MatchPipeline is
  generic (
    g_PortAddrWidth : integer);
  port (
    pi_clk          : in  std_logic;
    pi_rst_n        : in  std_logic;

    -- Match Pipeline 4 clock delay
    pi_reqEn        : in  std_logic;
    pi_reqPort      : in  unsigned(g_PortAddrWidth-1 downto 0);
    pi_reqData      : in  t_MapReq;

    po_resEn        : out std_logic;
    po_resPort      : out unsigned(g_PortAddrWidth-1 downto 0);
    po_resData      : out t_MapRes;

    -- Write Ports
    pi_storeWrite   : in  t_StoreWrite);
end ExtentStore_MatchPipeline;

architecture ExtentStore_MatchPipeline of ExtentStore_MatchPipeline is

  signal s_lstoreWrEn_v   : t_BRAMw256x32r16x512_WrEn;
  signal s_lstoreWrAddr_v : t_BRAMw256x32r16x512_WrAddr;
  signal s_lstoreWrData_v : t_BRAMw256x32r16x512_WrData;
  signal s_lstoreRdAddr_v : t_BRAMw256x32r16x512_RdAddr;
  signal s_lstoreRdData_v : t_BRAMw256x32r16x512_RdData;

  signal s_pstoreWrEn_v   : t_BRAMw256x64r256x64_WrEn;
  signal s_pstoreWrAddr_v : t_BRAMw256x64r256x64_WrAddr;
  signal s_pstoreWrData_v : t_BRAMw256x64r256x64_WrData;
  signal s_pstoreRdAddr_v : t_BRAMw256x64r256x64_RdAddr;
  signal s_pstoreRdData_v : t_BRAMw256x64r256x64_RdData;

  subtype t_PortAddr is unsigned (g_PortAddrWidth-1 downto 0);

  signal s_port_0         : t_PortAddr;
  signal s_enable_0       : std_logic;
  signal s_lrowAddr_0     : t_LRowAddr;
  signal s_lblk_0         : t_LBlk;

  signal s_port_1         : t_PortAddr;
  signal s_enable_1       : std_logic;
  signal s_lrowAddr_1     : t_LRowAddr;
  signal s_lblk_1         : t_LBlk;

  signal s_port_2         : t_PortAddr;
  signal s_enable_2       : std_logic;
  signal s_lrowAddr_2     : t_LRowAddr;
  signal s_lblk_2         : t_LBlk;
  signal s_lrow_2         : t_LRow;
  signal s_lcolAddr_2     : t_LRowAddr;
  signal s_lbase_2        : t_LBlk;
  signal s_llimit_2       : t_LBlk;
  signal s_valid_2        : std_logic;
  signal s_pBlkAddr_2     : t_EntryAddr;

  signal s_port_3         : t_PortAddr;
  signal s_enable_3       : std_logic;
  signal s_lbase_3        : t_LBlk;
  signal s_llimit_3       : t_LBlk;
  signal s_valid_3        : std_logic;

  signal s_port_4         : t_PortAddr;
  signal s_enable_4       : std_logic;
  signal s_lbase_4        : t_LBlk;
  signal s_llimit_4       : t_LBlk;
  signal s_pbase_4        : t_PBlk;
  signal s_valid_4        : std_logic;

begin

  s_port_0          <= pi_reqPort;
  s_enable_0        <= pi_reqEn;
  s_lrowAddr_0      <= pi_reqData.rowAddr;
  s_lblk_0          <= pi_reqData.lblock;

  po_resPort        <= s_port_4;
  po_resEn          <= s_enable_4;
  po_resData.lbase  <= s_lbase_4;
  po_resData.llimit <= s_llimit_4;
  po_resData.pbase  <= s_pbase_4;
  po_resData.valid  <= s_valid_4;


  -----------------------------------------------------------------------------
  -- Matching Logic and Priority Encoder (Lower Entries Win)
  -----------------------------------------------------------------------------

  process(s_lrow_2, s_lblk_2)
    variable v_thisLCol : t_LBlk;
    variable v_nextLCol : t_LBlk;
    variable v_guard : boolean;
  begin
    v_guard := false;
    s_valid_2 <= '0';
    for v_index in 0 to c_LColCount-2 loop
      v_thisLCol := f_resize(s_lrow_2, c_LBlkWidth, v_index * c_LBlkWidth);
      v_nextLCol := f_resize(s_lrow_2, c_LBlkWidth, (v_index+1) * c_LBlkWidth);
      if v_thisLCol <= s_lblk_2 and s_lblk_2 < v_nextLCol and not v_guard then
        v_guard := true;
        s_lbase_2 <= v_thisLCol;
        s_llimit_2 <= v_nextLCol;
        s_lcolAddr_2 <= to_unsigned(v_index, c_LColAddrWidth);
        s_valid_2 <= '1';
      end if;
    end loop;
  end process;
  s_pblkAddr_2 <= s_lrowAddr_2 & s_lcolAddr_2;

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
        s_valid_3    <= '0';
        s_enable_4   <= '0';
        s_valid_4    <= '0';
      else
        s_lrowAddr_1 <= s_lrowAddr_0;
        s_lblk_1     <= s_lblk_0;
        s_port_1     <= s_port_0;
        s_enable_1   <= s_enable_0;

        s_lrowAddr_2 <= s_lrowAddr_1;
        s_lblk_2     <= s_lblk_1;
        s_port_2     <= s_port_1;
        s_enable_2   <= s_enable_1;

        s_lbase_3    <= s_lbase_2;
        s_llimit_3   <= s_llimit_2;
        s_valid_3    <= s_valid_2;
        s_port_3     <= s_port_2;
        s_enable_3   <= s_enable_2;

        s_lbase_4    <= s_lbase_3;
        s_llimit_4   <= s_llimit_3;
        s_valid_4    <= s_valid_3;
        s_port_4     <= s_port_3;
        s_enable_4   <= s_enable_3;
      end if;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- BRAM Instatiations
  -----------------------------------------------------------------------------

  -- Logical Block Store
  s_lstoreWrAddr_v  <= std_logic_vector(pi_storeWrite.laddr);
  s_lstoreWrData_v  <= std_logic_vector(pi_storeWrite.ldata);
  s_lstoreWrEn_v(0) <= pi_storeWrite.len;
  s_lstoreRdAddr_v  <= std_logic_vector(s_lrowAddr_0);
  s_lrow_2          <= t_LRow(s_lstoreRdData_v);
  i_lstore : BRAMw256x32r16x512
    port map(
      clka  => pi_clk,
      wea   => s_lstoreWrEn_v,
      addra => s_lstoreWrAddr_v,
      dina  => s_lstoreWrData_v,
      clkb  => pi_clk,
      addrb => s_lstoreRdAddr_v,
      doutb => s_lstoreRdData_v);

  -- Physical Block Store
  s_pstoreWrAddr_v  <= std_logic_vector(pi_storeWrite.paddr);
  s_pstoreWrData_v  <= std_logic_vector(pi_storeWrite.pdata);
  s_pstoreWrEn_v(0) <= pi_storeWrite.pen;
  s_pstoreRdAddr_v  <= std_logic_vector(s_pblkAddr_2);
  s_pbase_4         <= t_PBlk(s_pstoreRdData_v);
  i_pstore : BRAMw256x64r256x64
    port map(
      clka  => pi_clk,
      wea   => s_pstoreWrEn_v,
      addra => s_pstoreWrAddr_v,
      dina  => s_pstoreWrData_v,
      clkb  => pi_clk,
      addrb => s_pstoreRdAddr_v,
      doutb => s_pstoreRdData_v);

end ExtentStore_MatchPipeline;
