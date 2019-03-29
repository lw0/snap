library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_axi.all;
use work.fosix_ctrl.all;
use work.fosix_stream.all;
use work.fosix_util.all;


entity AxiMonitor is
  port (
    pi_clk         : in  std_logic;
    pi_rst_n       : in  std_logic;

    pi_regs_ms     : in  t_RegPort_ms;
    po_regs_sm     : out t_RegPort_sm;

    pi_start       : in  std_logic;

    pi_axiRd0Stop  : in  std_logic;
    pi_axiRd0_ms   : in  t_NativeAxiRd_ms;
    pi_axiRd0_sm   : in  t_NativeAxiRd_sm;
    pi_axiWr0Stop  : in  std_logic;
    pi_axiWr0_ms   : in  t_NativeAxiWr_ms;
    pi_axiWr0_sm   : in  t_NativeAxiWr_sm;

    pi_axiRd1Stop  : in  std_logic;
    pi_axiRd1_ms   : in  t_NativeAxiRd_ms;
    pi_axiRd1_sm   : in  t_NativeAxiRd_sm;
    pi_axiWr1Stop  : in  std_logic;
    pi_axiWr1_ms   : in  t_NativeAxiWr_ms;
    pi_axiWr1_sm   : in  t_NativeAxiWr_sm;

    pi_stream_ms   : in  t_NativeStream_ms;
    pi_stream_sm   : in  t_NativeStream_sm);
end AxiMonitor;

architecture AxiMonitor of AxiMonitor is

  signal s_readMap        : unsigned(0 downto 0);
  signal s_axiRdStop      : std_logic;
  signal s_axiRd_ms       : t_NativeAxiRd_ms;
  signal s_axiRd_sm       : t_NativeAxiRd_sm;

  signal s_writeMap       : unsigned(0 downto 0);
  signal s_axiWrStop      : std_logic;
  signal s_axiWr_ms       : t_NativeAxiWr_ms;
  signal s_axiWr_sm       : t_NativeAxiWr_sm;

  constant c_CounterWidth : integer := 48;
  subtype t_Counter is unsigned (c_CounterWidth-1 downto 0);
  signal s_rtrnCounter    : t_Counter;
  signal s_rlatCounter    : t_Counter;
  signal s_rsstCounter    : t_Counter;
  signal s_rmstCounter    : t_Counter;
  signal s_ractCounter    : t_Counter;
  signal s_ridlCounter    : t_Counter;
  signal s_rbytCounter    : t_Counter;

  signal s_wtrnCounter    : t_Counter;
  signal s_wlatCounter    : t_Counter;
  signal s_wsstCounter    : t_Counter;
  signal s_wmstCounter    : t_Counter;
  signal s_wactCounter    : t_Counter;
  signal s_widlCounter    : t_Counter;
  signal s_wbytCounter    : t_Counter;

  signal s_ssstCounter    : t_Counter;
  signal s_smstCounter    : t_Counter;
  signal s_sactCounter    : t_Counter;
  signal s_sidlCounter    : t_Counter;
  signal s_sbytCounter    : t_Counter;

  -- Control Registers
  signal so_regs_sm_ready : std_logic;
  signal s_regFileRd : t_RegFile(0 to 39);

begin

  s_axiRdStop  <= pi_axiRd1Stop  when (s_readMap = "1") else pi_axiRd0Stop;
  s_axiRd_ms   <= pi_axiRd1_ms   when (s_readMap = "1") else pi_axiRd0_ms;
  s_axiRd_sm   <= pi_axiRd1_sm   when (s_readMap = "1") else pi_axiRd0_sm;

  i_axiRdMonitor : entity work.MonChannelMulti
    generic map (
      g_CounterWidth => c_CounterWidth,
      g_ByteMaskWidth => c_NativeAxiStrbWidth)
    port map(
      pi_clk       => pi_clk,
      pi_rst_n     => pi_rst_n,
      pi_start     => pi_start,
      pi_stop      => s_axiRdStop,
      pi_last      => s_axiRd_sm.rlast,
      pi_masterHS  => s_axiRd_ms.rready,
      pi_slaveHS   => s_axiRd_sm.rvalid,
      po_trnCount  => s_rtrnCounter,
      po_latCount  => s_rlatCounter,
      po_actCount  => s_ractCounter,
      po_mstCount  => s_rmstCounter,
      po_sstCount  => s_rsstCounter,
      po_idlCount  => s_ridlCounter,
      po_bytCount  => s_rbytCounter);

  s_axiWrStop  <= pi_axiWr1Stop  when (s_writeMap = "1") else pi_axiWr0Stop;
  s_axiWr_ms   <= pi_axiWr1_ms   when (s_writeMap = "1") else pi_axiWr0_ms;
  s_axiWr_sm   <= pi_axiWr1_sm   when (s_writeMap = "1") else pi_axiWr0_sm;

  i_axiWrMonitor : entity work.MonChannelMulti
    generic map (
      g_CounterWidth => c_CounterWidth,
      g_ByteMaskWidth => c_NativeAxiStrbWidth)
    port map(
      pi_clk       => pi_clk,
      pi_rst_n     => pi_rst_n,
      pi_start     => pi_start,
      pi_stop      => s_axiWrStop,
      pi_strb      => s_axiWr_ms.wstrb,
      pi_last      => s_axiWr_ms.wlast,
      pi_masterHS  => s_axiWr_ms.wvalid,
      pi_slaveHS   => s_axiWr_sm.wready,
      po_trnCount  => s_wtrnCounter,
      po_latCount  => s_wlatCounter,
      po_actCount  => s_wactCounter,
      po_mstCount  => s_wmstCounter,
      po_sstCount  => s_wsstCounter,
      po_idlCount  => s_widlCounter,
      po_bytCount  => s_wbytCounter);

  i_streamMonitor : entity work.MonChannelSingle
    generic map (
      g_CounterWidth => c_CounterWidth,
      g_ByteMaskWidth => c_NativeStreamStrbWidth)
    port map(
      pi_clk       => pi_clk,
      pi_rst_n     => pi_rst_n,
      pi_start     => pi_start,
      pi_strb      => pi_stream_ms.tstrb,
      pi_last      => pi_stream_ms.tlast,
      pi_masterHS  => pi_stream_ms.tvalid,
      pi_slaveHS   => pi_stream_sm.tready,
      po_actCount  => s_sactCounter,
      po_mstCount  => s_smstCounter,
      po_sstCount  => s_ssstCounter,
      po_idlCount  => s_sidlCounter,
      po_bytCount  => s_sbytCounter);

  -----------------------------------------------------------------------------
  -- Register Interface
  -----------------------------------------------------------------------------
  s_regFileRd(0)  <= f_resize(s_readMap,     t_RegData'length);
  s_regFileRd(1)  <= f_resize(s_writeMap,    t_RegData'length);
  s_regFileRd(2)  <= f_resize(s_rtrnCounter, t_RegData'length, 0);
  s_regFileRd(3)  <= f_resize(s_rtrnCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(4)  <= f_resize(s_wtrnCounter, t_RegData'length, 0);
  s_regFileRd(5)  <= f_resize(s_wtrnCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(6)  <= f_resize(s_rlatCounter, t_RegData'length, 0);
  s_regFileRd(7)  <= f_resize(s_rlatCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(8)  <= f_resize(s_wlatCounter, t_RegData'length, 0);
  s_regFileRd(9)  <= f_resize(s_wlatCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(10) <= f_resize(s_rsstCounter, t_RegData'length, 0);
  s_regFileRd(11) <= f_resize(s_rsstCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(12) <= f_resize(s_wsstCounter, t_RegData'length, 0);
  s_regFileRd(13) <= f_resize(s_wsstCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(14) <= f_resize(s_ssstCounter, t_RegData'length, 0);
  s_regFileRd(15) <= f_resize(s_ssstCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(16) <= f_resize(s_rmstCounter, t_RegData'length, 0);
  s_regFileRd(17) <= f_resize(s_rmstCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(18) <= f_resize(s_wmstCounter, t_RegData'length, 0);
  s_regFileRd(19) <= f_resize(s_wmstCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(20) <= f_resize(s_smstCounter, t_RegData'length, 0);
  s_regFileRd(21) <= f_resize(s_smstCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(22) <= f_resize(s_ractCounter, t_RegData'length, 0);
  s_regFileRd(23) <= f_resize(s_ractCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(24) <= f_resize(s_wactCounter, t_RegData'length, 0);
  s_regFileRd(25) <= f_resize(s_wactCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(26) <= f_resize(s_sactCounter, t_RegData'length, 0);
  s_regFileRd(27) <= f_resize(s_sactCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(28) <= f_resize(s_ridlCounter, t_RegData'length, 0);
  s_regFileRd(29) <= f_resize(s_ridlCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(30) <= f_resize(s_widlCounter, t_RegData'length, 0);
  s_regFileRd(31) <= f_resize(s_widlCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(32) <= f_resize(s_sidlCounter, t_RegData'length, 0);
  s_regFileRd(33) <= f_resize(s_sidlCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(34) <= f_resize(s_rbytCounter, t_RegData'length, 0);
  s_regFileRd(35) <= f_resize(s_rbytCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(36) <= f_resize(s_wbytCounter, t_RegData'length, 0);
  s_regFileRd(37) <= f_resize(s_wbytCounter, t_RegData'length, t_RegData'length);
  s_regFileRd(38) <= f_resize(s_sbytCounter, t_RegData'length, 0);
  s_regFileRd(39) <= f_resize(s_sbytCounter, t_RegData'length, t_RegData'length);

  process (pi_clk)
    variable v_portAddr : integer range 0 to 2**pi_regs_ms.addr'length-1;
  begin
    if pi_clk'event and pi_clk = '1' then
      v_portAddr := to_integer(pi_regs_ms.addr);

      if pi_rst_n = '0' then
        s_readMap <= "0";
        s_writeMap <= "0";
        po_regs_sm.rddata <= (others => '0');
        so_regs_sm_ready <= '0';
      else
        if pi_regs_ms.valid = '1' and so_regs_sm_ready = '0' then
          so_regs_sm_ready <= '1';
          if pi_regs_ms.wrnotrd = '1' and
              pi_regs_ms.wrstrb(0) = '1' then
            if v_portAddr = 0 then
              s_readMap <= pi_regs_ms.wrdata(0 downto 0);
            elsif v_portAddr = 1 then
              s_writeMap <= pi_regs_ms.wrdata(0 downto 0);
            end if;
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
