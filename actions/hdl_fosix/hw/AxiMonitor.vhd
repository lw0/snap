library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_axi.all;
use work.fosix_ctrl.all;
use work.fosix_stream.all;
use work.fosix_util.all;


entity AxiMonitor is
  generic (
    g_RdPortCount  : integer range 1 to 16;
    g_WrPortCount  : integer range 1 to 16;
    g_StmPortCount : integer range 1 to 16);
  port (
    pi_clk         : in  std_logic;
    pi_rst_n       : in  std_logic;

    pi_regs_ms     : in  t_RegPort_ms;
    po_regs_sm     : out t_RegPort_sm;

    pi_start       : in  std_logic;

    pi_axiRdStop   : in  unsigned(g_RdPortCount-1 downto 0) := (others => '0');
    pi_axiRd_ms    : in  t_NativeAxiRd_v_ms(g_RdPortCount-1 downto 0);
    pi_axiRd_sm    : in  t_NativeAxiRd_v_sm(g_RdPortCount-1 downto 0);

    pi_axiWrStop   : in  unsigned(g_WrPortCount-1 downto 0) := (others => '0');
    pi_axiWr_ms    : in  t_NativeAxiWr_v_ms(g_WrPortCount-1 downto 0);
    pi_axiWr_sm    : in  t_NativeAxiWr_v_sm(g_WrPortCount-1 downto 0);

    pi_stream_ms   : in  t_NativeStream_v_ms(g_StmPortCount-1 downto 0);
    pi_stream_sm   : in  t_NativeStream_v_sm(g_StmPortCount-1 downto 0));
end AxiMonitor;

architecture AxiMonitor of AxiMonitor is

  constant c_CounterCount : integer := 19;
  constant c_CounterWidth : integer := 48;

  subtype t_Counter is unsigned(c_CounterWidth-1 downto 0);
  type t_Counters is array (0 to c_CounterCount-1) of t_Counter;

  constant c_IncWidth : integer := c_NativeAxiByteAddrWidth+1;
  subtype t_Increment is unsigned(c_IncWidth-1 downto 0);
  constant c_IncrementOne : t_Increment := to_unsigned(1, c_IncWidth);

  type t_CounterControl is record
    enable : std_logic;
    increment : t_Increment;
  end record;
  type t_CounterControls is array (0 to c_CounterCount-1) of t_CounterControl;

  -- Axi Read Half Switch and Monitor
  signal s_readMap     : unsigned(3 downto 0);
  signal s_axiRdStop   : std_logic;
  signal s_axiRd_ms    : t_NativeAxiRd_ms;
  signal s_axiRd_sm    : t_NativeAxiRd_sm;
  signal s_axiRdBytes  : unsigned(c_IncWidth-1 downto 0);
  signal s_axiRdTrn    : std_logic;
  signal s_axiRdLat    : std_logic;
  signal s_axiRdAct    : std_logic;
  signal s_axiRdMSt    : std_logic;
  signal s_axiRdSSt    : std_logic;
  signal s_axiRdIdl    : std_logic;

  -- Axi Write Half Switch and Monitor
  signal s_writeMap    : unsigned(3 downto 0);
  signal s_axiWrStop   : std_logic;
  signal s_axiWr_ms    : t_NativeAxiWr_ms;
  signal s_axiWr_sm    : t_NativeAxiWr_sm;
  signal s_axiWrBytes  : unsigned(c_IncWidth-1 downto 0);
  signal s_axiWrTrn    : std_logic;
  signal s_axiWrLat    : std_logic;
  signal s_axiWrAct    : std_logic;
  signal s_axiWrMSt    : std_logic;
  signal s_axiWrSSt    : std_logic;
  signal s_axiWrIdl    : std_logic;

  -- Stream Switch and Monitor
  signal s_streamMap   : unsigned(3 downto 0);
  signal s_stream_ms   : t_NativeStream_ms;
  signal s_stream_sm   : t_NativeStream_sm;
  signal s_streamBytes : unsigned(c_IncWidth-1 downto 0);
  signal s_streamTrn   : std_logic;
  signal s_streamLat   : std_logic;
  signal s_streamAct   : std_logic;
  signal s_streamMSt   : std_logic;
  signal s_streamSSt   : std_logic;
  signal s_streamIdl   : std_logic;

  -- Counter Block
  signal s_counterControls : t_CounterControls;
  signal s_counters : t_Counters;

  -- Control Registers
  -- 2 Mapping Registers and 2 Registers per Counter
  constant c_RegCount : integer := 2*c_CounterCount + 2;
  signal s_regFileRd : t_RegFile(0 to c_RegCount-1);
  signal s_reg0 : t_RegData;
  signal so_regs_sm_ready : std_logic;

begin

  -----------------------------------------------------------------------------
  -- Axi Read Half Switch and Monitor
  -----------------------------------------------------------------------------
  s_readMap     <= f_resize(s_reg0, 4, 0);
  s_axiRdStop   <= pi_axiRdStop(to_integer(s_readMap));
  s_axiRd_ms    <= pi_axiRd_ms (to_integer(s_readMap));
  s_axiRd_sm    <= pi_axiRd_sm (to_integer(s_readMap));
  s_axiRdBytes  <= to_unsigned(64, s_axiRdBytes'length);
  i_axiRdMon : entity work.AxiChannelMonitor
    generic map (
      g_SingleShot => false,
      g_InvertHandshake => true)
    port map (
      pi_clk      => pi_clk,
      pi_rst_n    => pi_rst_n,
      pi_start    => pi_start,
      pi_stop     => s_axiRdStop,
      pi_last     => s_axiRd_sm.rlast,
      pi_valid    => s_axiRd_sm.rvalid,
      pi_ready    => s_axiRd_ms.rready,
      po_trnCycle => s_axiRdTrn,
      po_latCycle => s_axiRdLat,
      po_actCycle => s_axiRdAct,
      po_mstCycle => s_axiRdMSt,
      po_sstCycle => s_axiRdSSt,
      po_idlCycle => s_axiRdIdl);

  -----------------------------------------------------------------------------
  -- Axi Write Half Switch and Monitor
  -----------------------------------------------------------------------------
  s_writeMap    <= f_resize(s_reg0, 4, 4);
  s_axiWrStop   <= pi_axiWrStop(to_integer(s_writeMap));
  s_axiWr_ms    <= pi_axiWr_ms (to_integer(s_writeMap));
  s_axiWr_sm    <= pi_axiWr_sm (to_integer(s_writeMap));
  s_axiWrBytes  <= to_unsigned(f_bitCount(s_axiWr_ms.wstrb), s_axiWrBytes'length);
  i_axiWrMon : entity work.AxiChannelMonitor
    generic map (
      g_SingleShot => false,
      g_InvertHandshake => false)
    port map (
      pi_clk      => pi_clk,
      pi_rst_n    => pi_rst_n,
      pi_start    => pi_start,
      pi_stop     => s_axiWrStop,
      pi_last     => s_axiWr_ms.wlast,
      pi_valid    => s_axiWr_ms.wvalid,
      pi_ready    => s_axiWr_sm.wready,
      po_trnCycle => s_axiWrTrn,
      po_latCycle => s_axiWrLat,
      po_actCycle => s_axiWrAct,
      po_mstCycle => s_axiWrMSt,
      po_sstCycle => s_axiWrSSt,
      po_idlCycle => s_axiWrIdl);

  -----------------------------------------------------------------------------
  -- Stream Switch and Monitor
  -----------------------------------------------------------------------------
  s_streamMap   <= f_resize(s_reg0, 4, 8);
  s_stream_ms   <= pi_stream_ms (to_integer(s_streamMap));
  s_stream_sm   <= pi_stream_sm (to_integer(s_streamMap));
  s_streamBytes <= to_unsigned(f_bitCount(s_stream_ms.tkeep), s_streamBytes'length);
  i_streamMon : entity work.AxiChannelMonitor
    generic map (
      g_SingleShot => true,
      g_InvertHandshake => false)
    port map (
      pi_clk      => pi_clk,
      pi_rst_n    => pi_rst_n,
      pi_start    => pi_start,
      pi_stop     => '0',
      pi_last     => s_stream_ms.tlast,
      pi_valid    => s_stream_ms.tvalid,
      pi_ready    => s_stream_sm.tready,
      po_trnCycle => s_streamTrn,
      po_latCycle => s_streamLat,
      po_actCycle => s_streamAct,
      po_mstCycle => s_streamMSt,
      po_sstCycle => s_streamSSt,
      po_idlCycle => s_streamIdl);

  -----------------------------------------------------------------------------
  -- Counter Block
  -----------------------------------------------------------------------------
  s_counterControls <= (
  -- Transaction Counters
    (enable => s_axiRdTrn,  increment => c_IncrementOne),
    (enable => s_axiWrTrn,  increment => c_IncrementOne),
  -- Latency Counters
    (enable => s_axiRdLat,  increment => c_IncrementOne),
    (enable => s_axiWrLat,  increment => c_IncrementOne),
  -- Active Counters
    (enable => s_axiRdAct,  increment => c_IncrementOne),
    (enable => s_axiWrAct,  increment => c_IncrementOne),
    (enable => s_streamAct, increment => c_IncrementOne),
  -- Master Stall Counters
    (enable => s_axiRdMSt,  increment => c_IncrementOne),
    (enable => s_axiWrMSt,  increment => c_IncrementOne),
    (enable => s_streamMSt, increment => c_IncrementOne),
  -- Slave Stall Counters
    (enable => s_axiRdSSt,  increment => c_IncrementOne),
    (enable => s_axiWrSSt,  increment => c_IncrementOne),
    (enable => s_streamSSt, increment => c_IncrementOne),
  -- Idle Counters
    (enable => s_axiRdIdl,  increment => c_IncrementOne),
    (enable => s_axiWrIdl,  increment => c_IncrementOne),
    (enable => s_streamIdl, increment => c_IncrementOne),
  -- Byte Counters
    (enable => s_axiRdAct,  increment => s_axiRdBytes),
    (enable => s_axiWrAct,  increment => s_axiWrBytes),
    (enable => s_streamAct, increment => s_streamBytes));

  i_counterBlock: for v_idx in 0 to c_CounterCount-1 generate
    i_counter : entity work.UtilCounter
      generic map (
        g_CounterWidth => c_CounterWidth,
        g_IncrementWidth => c_IncWidth)
      port map (
        pi_clk => pi_clk,
        pi_rst_n => pi_rst_n,
        pi_reset => pi_start,
        pi_enable => s_counterControls(v_idx).enable,
        pi_increment => s_counterControls(v_idx).increment,
        po_count => s_counters(v_idx));
    s_regFileRd(2*v_idx+2)  <= f_resize(s_counters(v_idx), t_RegData'length, 0);
    s_regFileRd(2*v_idx+3)  <= f_resize(s_counters(v_idx), t_RegData'length, t_RegData'length);
  end generate;

  -----------------------------------------------------------------------------
  -- Register Interface
  -----------------------------------------------------------------------------
  s_regFileRd(0)  <= f_resize(s_reg0,     t_RegData'length);
  s_regFileRd(1)  <= (others => '0');

  process (pi_clk)
    variable v_portAddr : integer range 0 to 2**pi_regs_ms.addr'length-1;
  begin
    if pi_clk'event and pi_clk = '1' then
      v_portAddr := to_integer(pi_regs_ms.addr);
      if pi_rst_n = '0' then
        po_regs_sm.rddata <= (others => '0');
        so_regs_sm_ready <= '0';
        s_reg0 <= (others => '0');
      else
        if pi_regs_ms.valid = '1' and so_regs_sm_ready = '0' then
          so_regs_sm_ready <= '1';
          if pi_regs_ms.wrnotrd = '1' and
                pi_regs_ms.wrstrb(0) = '1' and
                v_portAddr = 0 then
              s_reg0 <= f_byteMux(pi_regs_ms.wrstrb, pi_regs_ms.wrdata, s_reg0);
          end if;
          if v_portAddr >= s_regFileRd'low and
              v_portAddr <= s_regFileRd'high then
            po_regs_sm.rddata <= s_regFileRd(v_portAddr);
          else
            po_regs_sm.rddata <= (others => '0');
          end if;
        else
          so_regs_sm_ready <= '0';
        end if;
      end if;
    end if;
  end process;
  po_regs_sm.ready <= so_regs_sm_ready;

end AxiMonitor;
