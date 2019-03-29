library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_ctrl.all;
use work.fosix_stream.all;
use work.fosix_util.all;


entity StreamInfrastructure is
  generic (
    g_InPorts      : integer range 1 to 15;
    g_OutPorts     : integer range 1 to 15);
  port (
    pi_clk         : in std_logic;
    pi_rst_n       : in std_logic;

    -- Config register port (12 Registers):
    -- Switch
    --   InPort 15 is a dummy stream source that generates a configurable
    --   number of transfers (see Reg3)
    --   OutPort 15 is a dummy stream sink that consumes an indefinite
    --   umber of transfers
    --  Reg0: [RW] Destination Ports 0 to 7
    --    Bits(4n+3..4n): OutPort number for InPort n   (0<=n<8)
    --    OutPort number 15 disables routing of respective InPort
    --  Reg1: [RW] Destination Ports 8 to 15
    --    Bits(4n+3..4n): OutPort number for InPort n+8 (0<=n<8)
    --  Reg2: [RW] Monitor Source Port
    --    Bits(3..0): InPort number to attach the stream monitor to
    -- Dummy Source
    --  Reg3: [RW] Dummy Transfer Count
    pi_regs_ms     : in  t_RegPort_ms;
    po_regs_sm     : out t_RegPort_sm;

    pi_inPorts_ms  : in  t_NativeStream_v_ms(0 to g_InPorts-1);
    po_inPorts_sm  : out t_NativeStream_v_sm(0 to g_InPorts-1);

    po_outPorts_ms : out t_NativeStream_v_ms(0 to g_OutPorts-1);
    pi_outPorts_sm : in  t_NativeStream_v_sm(0 to g_OutPorts-1);

    po_monPort_ms  : out t_NativeStream_ms;
    po_monPort_sm  : out t_NativeStream_sm);
end StreamInfrastructure;

architecture StreamInfrastructure of StreamInfrastructure is

  signal s_streamMap      : unsigned(g_InPorts*4-1 downto 0);
  signal s_inPorts_ms     : t_NativeStream_v_ms(0 to g_InPorts-1);
  signal s_inPorts_sm     : t_NativeStream_v_sm(0 to g_InPorts-1);
  signal s_outPorts_ms    : t_NativeStream_v_ms(0 to g_OutPorts-1);
  signal s_outPorts_sm    : t_NativeStream_v_sm(0 to g_OutPorts-1);

  signal s_dummyMap       : unsigned(3 downto 0);
  signal s_dummyPort_ms   : t_NativeStream_ms;
  signal s_dummyPort_sm   : t_NativeStream_sm;
  signal s_dummyCount     : t_RegData;
  signal s_dummyCountSet  : std_logic;

  type t_DummyState is (Done, Counting);
  signal s_dummyState     : t_DummyState;
  signal s_dummyCountdown : t_RegData;

  signal s_monitorMap     : unsigned(3 downto 0);

  -- Control Registers
  signal so_regs_sm_ready : std_logic;
  signal s_reg3WrEvent    : std_logic;
  signal s_reg1reg0       : unsigned(2*c_RegDataWidth-1 downto 0);
  signal s_reg0           : t_RegData;
  signal s_reg1           : t_RegData;
  signal s_reg2           : t_RegData;
  signal s_reg3           : t_RegData;

begin

  -----------------------------------------------------------------------------
  -- Stream Switch
  -----------------------------------------------------------------------------
  s_inPorts_ms   <= pi_inPorts_ms;
  po_inPorts_sm  <= s_inPorts_sm;
  po_outPorts_ms <= s_outPorts_ms;
  s_outPorts_sm  <= pi_outPorts_sm;
  process(s_streamMap, s_dummyMap, s_inPorts_ms, s_outPorts_sm, s_dummyPort_ms)
    type t_BoolArray is array (integer range<>) of boolean;
    variable v_guards : t_BoolArray(0 to 15);
    variable v_srcPort : integer range 0 to 15;
    variable v_dstPort : integer range 0 to 15;
  begin
    v_guards := (others=>false);
    s_outPorts_ms <= (others => c_NativeStreamNull_ms);
    s_inPorts_sm <= (others => c_NativeStreamNull_sm);
    for v_srcPort in 0 to g_InPorts-1 loop
      s_inPorts_sm(v_srcPort) <= c_NativeStreamNull_sm;
      v_dstPort := to_integer(s_streamMap(4*v_srcPort+3 downto 4*v_srcPort));
      if v_dstPort < g_OutPorts and not v_guards(v_dstPort) then
        v_guards(v_dstPort) := true;
        s_outPorts_ms(v_dstPort) <= s_inPorts_ms(v_srcPort);
        s_inPorts_sm(v_srcPort) <= s_outPorts_sm(v_dstPort);
      elsif v_dstPort = 15 then
        -- this implements the dummy stream sink
        s_inPorts_sm(v_srcPort) <= (tready => '1');
      end if;
    end loop;
    -- map the dummy stream source
    s_dummyPort_sm <= c_NativeStreamNull_sm;
    v_dstPort := to_integer(s_dummyMap);
    if v_dstPort < g_OutPorts and not v_guards(v_dstPort) then
      s_outPorts_ms(v_dstPort) <= s_dummyPort_ms;
      s_dummyPort_sm <= s_outPorts_sm(v_dstPort);
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Monitor Switch
  -----------------------------------------------------------------------------
  process(s_monitorMap, s_inPorts_ms, s_inPorts_sm, s_dummyPort_ms, s_dummyPort_sm)
    variable v_monPort : integer range 0 to 15;
  begin
    v_monPort := to_integer(s_monitorMap);
    if v_monPort < g_InPorts then
      po_monPort_ms <= s_inPorts_ms(v_monPort);
      po_monPort_sm <= s_inPorts_sm(v_monPort);
    elsif v_monPort = 15 then
      po_monPort_ms <= s_dummyPort_ms;
      po_monPort_sm <= s_dummyPort_sm;
    else
      po_monPort_ms <= c_NativeStreamNull_ms;
      po_monPort_sm <= c_NativeStreamNull_sm;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Dummy Source
  -----------------------------------------------------------------------------
  process(pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_dummyState <= Done;
        s_dummyCountdown <= (others => '0');
      else
        if s_dummyCountSet = '1' then
          s_dummyCountdown <= s_dummyCount;
          if s_dummyCount = to_unsigned(0, s_dummyCount'length) then
            s_dummyState <= Done;
          else
            s_dummyState <= Counting;
          end if;
        elsif s_dummyState = Counting and s_dummyPort_sm.tready = '1' then
          s_dummyCountdown <= s_dummyCountdown - to_unsigned(1, s_dummyCountdown'length);
          if s_dummyCountdown = to_unsigned(0, s_dummyCountdown'length) then
            s_dummyState <= Done;
          end if;
        end if;
      end if;
    end if;
  end process;
  -- TODO-lw: implement data pattern generator
  s_dummyPort_ms.tdata <= (others => '1');
  s_dummyPort_ms.tstrb <= (others => '1');
  s_dummyPort_ms.tkeep <= (others => '1');
  with s_dummyState select s_dummyPort_ms.tlast <=
    f_logic(s_dummyCountdown = to_unsigned(1, s_dummyCountdown'length)) when Counting,
    '0' when others;
  with s_dummyState select s_dummyPort_ms.tvalid <=
    '1' when Counting,
    '0' when others;

  -----------------------------------------------------------------------------
  -- Register Interface
  -----------------------------------------------------------------------------
  s_reg1reg0 <= s_reg1 & s_reg0;
  s_streamMap <= f_resize(s_reg1reg0, 4*g_InPorts, 0);
  s_dummyMap <= s_reg1(31 downto 28);
  s_monitorMap <= f_resize(s_reg2, 4, 0);
  s_dummyCount <= s_reg3;
  s_dummyCountSet <= s_reg3WrEvent;

  process (pi_clk)
    variable v_addr : integer range 0 to 2**c_RegAddrWidth := 0;
  begin
    if pi_clk'event and pi_clk = '1' then
      v_addr := to_integer(pi_regs_ms.addr);

      if pi_rst_n = '0' then
        po_regs_sm.rddata <= (others => '0');
        so_regs_sm_ready <= '0';
        s_reg0 <= (others => '0');
        s_reg1 <= (others => '0');
        s_reg2 <= (others => '0');
        s_reg3 <= (others => '0');
        s_reg3WrEvent <= '0';
      else
        s_reg3WrEvent <= '0';
        if pi_regs_ms.valid = '1' and so_regs_sm_ready = '0' then
          so_regs_sm_ready <= '1';
          case v_addr is
            when 0 =>
              po_regs_sm.rddata <= s_reg0;
              if pi_regs_ms.wrnotrd = '1' then
                s_reg0 <= f_byteMux(pi_regs_ms.wrstrb, s_reg0, pi_regs_ms.wrdata);
              end if;
            when 1 =>
              po_regs_sm.rddata <= s_reg1;
              if pi_regs_ms.wrnotrd = '1' then
                s_reg1 <= f_byteMux(pi_regs_ms.wrstrb, s_reg1, pi_regs_ms.wrdata);
              end if;
            when 2 =>
              po_regs_sm.rddata <= s_reg2;
              if pi_regs_ms.wrnotrd = '1' then
                s_reg2 <= f_byteMux(pi_regs_ms.wrstrb, s_reg2, pi_regs_ms.wrdata);
              end if;
            when 3 =>
              po_regs_sm.rddata <= s_reg3;
              s_reg3WrEvent <= pi_regs_ms.wrnotrd;
              if pi_regs_ms.wrnotrd = '1' then
                s_reg3 <= f_byteMux(pi_regs_ms.wrstrb, s_reg3, pi_regs_ms.wrdata);
              end if;
            when others =>
              po_regs_sm.rddata <= (others => '0');
          end case;
        else
          so_regs_sm_ready <= '0';
        end if;
      end if;
    end if;
  end process;
  po_regs_sm.ready <= so_regs_sm_ready;

end StreamInfrastructure;
