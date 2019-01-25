library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;
use work.fosix_blockmap.all;


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

    pi_ports_ms : in  t_BlkMaps_ms(g_Ports-1 downto 0);
    po_ports_sm : out t_BlkMaps_sm(g_Ports-1 downto 0);

    po_status   : out t_RegData);
end ExtentStore;

architecture ExtentStore of ExtentStore is

  constant c_PortAddrWidth : integer := f_clog2(g_Ports);
  subtype t_PortAddr is unsigned (c_PortAddrWidth-1 downto 0);
  subtype t_PortVector is unsigned (g_Ports-1 downto 0);

  signal so_regs_sm_ready : std_logic;
  signal s_regIntEn       : t_PortVector;
  signal s_regHalt        : t_PortVector;
  signal s_regFlush       : t_PortVector;
  signal s_regsRowConfig  : t_RegFile (g_Ports-1 downto 0);
  signal s_regLBlk        : t_RegData;
  signal s_regPBlk        : unsigned (2*C_CTRL_DATA_W-1 downto 0);
  alias  a_regPBlkLo is s_regPBlk(C_CTRL_DATA_W-1 downto 0);
  alias  a_regPBlkHi is s_regPBlk(2*C_CTRL_DATA_W-1 downto C_CTRL_DATA_W);

  signal s_storeAddr      : t_EntryAddr;
  signal s_storeEn        : std_logic;
  signal s_storeWrite     : t_StoreWrite;

  signal s_portsLBlk       : t_LBlks(g_Ports-1 downto 0);
  signal s_portsBlocked    : t_PortVector;

  signal s_reqEn          : t_PortVector;
  signal s_reqData        : t_MapReqs(g_Ports-1 downto 0);
  signal s_reqAck         : t_PortVector;

  signal s_arbEn          : std_logic;
  signal s_arbPort        : t_PortAddr;
  signal s_arbData        : t_MapReq;

  signal s_resEn          : std_logic;
  signal s_resPort        : t_PortAddr;
  signal s_resData        : t_MapRes;

  signal s_status         : unsigned(g_Ports*4-1 downto 0);

begin

  po_intReq <= f_or(s_portsBlocked and s_regIntEn);
  -- TODO-lw pi_intAck can be ignored due to edge detecting int logic,
  --   but multiple interrupts are thus not handled correctly

  s_storeWrite.laddr <= s_storeAddr;
  s_storeWrite.ldata <= f_resize(s_regLBlk, c_LBlkWidth);
  s_storeWrite.len <= s_storeEn;
  s_storeWrite.paddr <= s_storeAddr;
  s_storeWrite.pdata <= f_resize(s_regPBlk, c_PBlkWidth);
  s_storeWrite.pen <= s_storeEn;

  -----------------------------------------------------------------------------
  -- Register Access
  -----------------------------------------------------------------------------
  po_regs_sm.ready <= so_regs_sm_ready;
  process (pi_clk)
    variable v_addr : integer range 0 to 2**C_CTRL_SPACE_W;
  begin
    v_addr := to_integer(pi_regs_ms.addr);
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        so_regs_sm_ready <= '0';
        s_regIntEn <= (others => '0');
        s_regHalt <= (others => '0');
        s_regFlush <= (others => '0');
        s_regsRowConfig <= (others => (others => '0'));
        s_regLBlk <= (others => '0');
        s_regPBlk <= (others => '0');
        s_storeAddr <= (others => '0');
        s_storeEn <= '0';
      else
        s_regFlush <= (others => '0');
        s_storeEn <= '0';
        if pi_regs_ms.valid = '1' and so_regs_sm_ready = '0' then
          so_regs_sm_ready <= '1';
          po_regs_sm.rddata <= (others => '0');
          if v_addr >= 8 and v_addr < (g_Ports + 8) then
            po_regs_sm.rddata <= s_portsLBlk(v_addr-8);
            if pi_regs_ms.wrnotrd = '1' then
              s_regsRowConfig(v_addr-8) <=  pi_regs_ms.wrdata;
              -- TODO-lw use wrstb?
            end if;
          else
            case v_addr is
              when 0 =>
                po_regs_sm.rddata <= f_resize(s_regHalt, C_CTRL_DATA_W);
                if pi_regs_ms.wrnotrd = '1' then
                  s_regHalt <= s_regHalt or f_resize(pi_regs_ms.wrdata, g_Ports);
                  -- TODO-lw use wrstb?
                end if;
              when 1 =>
                po_regs_sm.rddata <= f_resize(s_regFlush, C_CTRL_DATA_W);
                if pi_regs_ms.wrnotrd = '1' then
                  s_regFlush <= f_resize(pi_regs_ms.wrdata, g_Ports);
                  s_regHalt <= s_regHalt and not f_resize(pi_regs_ms.wrdata, g_Ports);
                  -- TODO-lw use wrstb?
                end if;
              when 2 =>
                po_regs_sm.rddata <= f_resize(s_regIntEn, C_CTRL_DATA_W);
                if pi_regs_ms.wrnotrd = '1' then
                  s_regIntEn <= f_resize(pi_regs_ms.wrdata, g_Ports);
                  -- TODO-lw use wrstb?
                end if;
              when 3 =>
                po_regs_sm.rddata <= f_resize(s_portsBlocked, C_CTRL_DATA_W);
              when 4 =>
                if pi_regs_ms.wrnotrd = '1' then
                  -- TODO-lw use wrstb?
                  s_storeAddr <= f_resize(pi_regs_ms.wrdata, c_EntryAddrWidth);
                  s_storeEn <= '1';
                end if;
              when 5 =>
                po_regs_sm.rddata <= s_regLBlk;
                if pi_regs_ms.wrnotrd = '1' then
                  s_regLBlk <= f_byteMux(pi_regs_ms.wrstrb, s_regLBlk, pi_regs_ms.wrdata);
                end if;
              when 6 =>
                po_regs_sm.rddata <= a_regPBlkLo;
                if pi_regs_ms.wrnotrd = '1' then
                  a_regPBlkLo <= f_byteMux(pi_regs_ms.wrstrb, a_regPBlkLo, pi_regs_ms.wrdata);
                end if;
              when 7 =>
                po_regs_sm.rddata <= a_regPBlkHi;
                if pi_regs_ms.wrnotrd = '1' then
                  a_regPBlkHi <= f_byteMux(pi_regs_ms.wrstrb, a_regPBlkHi, pi_regs_ms.wrdata);
                end if;
              when others =>
                po_regs_sm.rddata <= (others => '0');
            end case;
          end if;
        else
          so_regs_sm_ready <= '0';
        end if;
      end if;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- Port Machines
  -----------------------------------------------------------------------------
  i_PortMachines: for I in g_Ports-1 downto 0 generate
    i_PortMachine : entity work.ExtentStore_PortMachine
      generic map (
        g_Ports        => g_Ports,
        g_PortNumber   => I)
      port map (
        pi_clk         => pi_clk,
        pi_rst_n       => pi_rst_n,
        pi_halt        => s_regHalt(I),
        pi_flush       => s_regFlush(I),
        pi_rowConfig   => s_regsRowConfig(I),
        po_currentLBlk => s_portsLBlk(I),
        po_blocked     => s_portsBlocked(I),
        pi_port_ms     => pi_ports_ms(I),
        po_port_sm     => po_ports_sm(I),
        po_reqEn       => s_reqEn(I),
        po_reqData     => s_reqData(I),
        pi_reqAck      => s_reqAck(I),
        pi_resEn       => s_resEn,
        pi_resPort     => s_resPort,
        pi_resData     => s_resData,
        po_status      => s_status(I*4+3 downto I*4));
  end generate;


  -----------------------------------------------------------------------------
  -- Mapping Pipeline
  -----------------------------------------------------------------------------

  i_Arbiter : entity work.ExtentStore_Arbiter
    generic map (
      g_Ports     => g_Ports)
    port map (
      pi_clk      => pi_clk,
      pi_rst_n    => pi_rst_n,
      pi_reqEn    => s_reqEn,
      pi_reqData  => s_reqData,
      po_reqAck   => s_reqAck,
      po_reqEn    => s_arbEn,
      po_reqPort  => s_arbPort,
      po_reqData  => s_arbData);

  i_MatchPipeline : entity work.ExtentStore_MatchPipeline
    generic map (
      g_PortAddrWidth => c_PortAddrWidth)
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_reqEn        => s_arbEn,
      pi_reqPort      => s_arbPort,
      pi_reqData      => s_arbData,
      po_resEn        => s_resEn,
      po_resPort      => s_resPort,
      po_resData      => s_resData,
      pi_storeWrite   => s_storeWrite);

  -----------------------------------------------------------------------------
  -- Status Output
  -----------------------------------------------------------------------------
  po_status <= f_resize(s_status, t_RegData'length);

end ExtentStore;
