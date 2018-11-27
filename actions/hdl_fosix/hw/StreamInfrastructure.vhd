library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity StreamInfrastructure is
  generic (
    g_InPorts : integer range 1 to 15;
    g_OutPorts : integer range 1 to 15);
  port (
    pi_clk          : in std_logic;
    pi_rst_n        : in std_logic;

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
    --    0 means an indefinite number of transfers (tlast never generated)
    -- Monitor
    --   Reset on Write to any of Reg4 to RegB
    --   Start on first (tvalid or tready) Cycle
    --   Stop on (tvalid and tready and tlast) Cycle
    --  Reg4: [RC] (Low  Half) Total Cycle Counter
    --  Reg5: [RC] (High Half) Total Cycle Counter
    --  Reg6: [RC] (Low  Half) Active Cycle Counter (tvalid and tready)
    --  Reg7: [RC] (High Half) Active Cycle Counter (tvalid and tready)
    --  Reg8: [RC] (Low  Half) Slave Stall Cycle Counter (tvalid and not tready)
    --  Reg9: [RC] (High Half) Slave Stall Cycle Counter (tvalid and not tready)
    --  RegA: [RC] (Low  Half) Master Stall Cycle Counter (not tvalid and tready)
    --  RegB: [RC] (High Half) Master Stall Cycle Counter (not tvalid and tready)
    pi_regs_ms : in  t_RegPort_ms;
    po_regs_sm : out t_RegPort_sm;

    pi_inPorts_ms     : in  t_AxiStreams_ms(0 to g_InPorts-1);
    po_inPorts_sm     : out t_AxiStreams_sm(0 to g_InPorts-1);

    po_outPorts_ms    : out t_AxiStreams_ms(0 to g_OutPorts-1);
    pi_outPorts_sm    : in  t_AxiStreams_sm(0 to g_OutPorts-1));
end StreamInfrastructure;

architecture StreamInfrastructure of StreamInfrastructure is

  signal s_streamMap      : unsigned(g_InPorts*4-1 downto 0);
  signal s_inPorts_ms     : t_AxiStreams_ms(0 to g_InPorts-1);
  signal s_inPorts_sm     : t_AxiStreams_sm(0 to g_InPorts-1);
  signal s_outPorts_ms    : t_AxiStreams_ms(0 to g_OutPorts-1);
  signal s_outPorts_sm    : t_AxiStreams_sm(0 to g_OutPorts-1);

  signal s_dummyMap       : unsigned(3 downto 0);
  signal s_dummyPort_ms   : t_AxiStream_ms;
  signal s_dummyPort_sm   : t_AxiStream_sm;
  signal s_dummyCount     : t_RegData;
  signal s_dummyCountSet  : std_logic;

  type t_DummyState is (Done, Counting, Indefinite);
  signal s_dummyState     : t_DummyState;
  signal s_dummyCountdown : t_RegData;

  signal s_monitorMap     : unsigned(3 downto 0);
  signal s_monitorPort_ms : t_AxiStream_ms;
  signal s_monitorPort_sm : t_AxiStream_sm;

  type t_MonitorState is (Idle, Running, Done);
  signal s_monitorState   : t_MonitorState;

  constant c_CounterWidth : integer := 48;
  constant c_CounterZero  : unsigned(c_CounterWidth-1 downto 0) :=
                              to_unsigned(0, c_CounterWidth);
  constant c_CounterOne   : unsigned(c_CounterWidth-1 downto 0) :=
                              to_unsigned(1, c_CounterWidth);
  signal s_totalCounter   : unsigned(c_CounterWidth-1 downto 0);
  signal s_activeCounter  : unsigned(c_CounterWidth-1 downto 0);
  signal s_mstallCounter  : unsigned(c_CounterWidth-1 downto 0);
  signal s_sstallCounter  : unsigned(c_CounterWidth-1 downto 0);

  signal s_reg3WrEvent    : std_logic;
  signal s_reg0           : t_RegData;
  signal s_reg1           : t_RegData;
  signal s_reg2           : t_RegData;
  signal s_reg3           : t_RegData;
  signal s_reg4Rd         : t_RegData;
  signal s_reg5Rd         : t_RegData;
  signal s_reg6Rd         : t_RegData;
  signal s_reg7Rd         : t_RegData;
  signal s_reg8Rd         : t_RegData;
  signal s_reg9Rd         : t_RegData;
  signal s_regARd         : t_RegData;
  signal s_regBRd         : t_RegData;

begin

  -----------------------------------------------------------------------------
  -- Stream Switch
  -----------------------------------------------------------------------------
  s_inPorts_ms   <= pi_inPorts_ms;
  po_inPorts_sm  <= s_inPorts_sm;
  po_outPorts_ms <= s_outPorts_ms;
  s_outPorts_sm  <= pi_outPorts_sm;
  process(s_streamMap, s_inPorts_ms, s_outPorts_sm)
    type t_BoolArray is array (integer range<>) of boolean;
    variable v_srcPort : integer range 0 to 15;
    variable v_dstPort : integer range 0 to 15;
    variable v_guards : t_BoolArray(0 to 15) := (others=>false);
  begin
    for v_dstPort in 0 to g_OutPorts-1 loop
      s_outPorts_ms(v_dstPort) <= c_AxiStreamNull_ms;
    end loop;
    for v_srcPort in 0 to g_InPorts-1 loop
      s_inPorts_sm(v_srcPort) <= c_AxiStreamNull_sm;
      v_dstPort := to_integer(s_streamMap(4*v_srcPort+3 downto 4*v_srcPort));
      if v_dstPort < g_OutPorts and not v_guards(v_dstPort) then
        v_guards(v_dstPort) := true;
        s_outPorts_ms(v_dstPort) <= s_inPorts_ms(v_srcPort);
        s_inPorts_sm(v_srcPort) <= s_outPorts_sm(v_dstPort);
      elsif v_dstPort = 15 then
        -- this implements the dummy stream sink
        s_inPorts_sm(v_srcPort).tready <= '1';
      end if;
    end loop;
    -- map the dummy stream source
    s_dummyPort_sm <= c_AxiStreamNull_sm;
    v_dstPort := to_integer(s_dummyMap);
    if v_dstPort < g_OutPorts and not v_guards(v_dstPort) then
      s_outPorts_ms(v_dstPort) <= s_dummyPort_ms;
      s_dummyPort_sm <= s_outPorts_sm(v_dstPort);
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Monitor Switch
  -----------------------------------------------------------------------------
  process(s_monitorMap, s_inPorts_ms, s_inPorts_sm)
    variable v_monPort : integer range 0 to 15;
  begin
    v_monPort := to_integer(s_monitorMap);
    if v_monPort < g_InPorts then
      s_monitorPort_ms <= s_inPorts_ms(v_monPort);
      s_monitorPort_sm <= s_inPorts_sm(v_monPort);
    elsif v_monPort = 15 then
      s_monitorPort_ms <= s_dummyPort_ms;
      s_monitorPort_sm <= s_dummyPort_sm;
    else
      s_monitorPort_ms <= c_AxiStreamNull_ms;
      s_monitorPort_sm <= c_AxiStreamNull_sm;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Dummy Source
  -----------------------------------------------------------------------------
  process(pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '1' then
        s_dummyState <= Done;
        s_dummyCountdown <= (others => '0');
      else
        if s_dummyCountSet = '1' then
          s_dummyCountdown <= s_dummyCount;
          if s_dummyCount = to_unsigned(0, C_CTRL_DATA_W) then
            s_dummyState <= Indefinite;
          else
            s_dummyState <= Counting;
          end if;
        elsif s_dummyState = Counting and s_dummyPort_sm.tready = '1' then
          s_dummyCountdown <= s_dummyCountdown - to_unsigned(1, C_CTRL_DATA_W);
          if s_dummyCountdown = to_unsigned(0, C_CTRL_DATA_W) then
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
    f_logic(s_dummyCountdown = to_unsigned(1, C_CTRL_DATA_W)) when Counting,
    '0' when others;
  with s_dummyState select s_dummyPort_ms.tvalid <=
    '1' when Counting,
    '1' when Indefinite,
    '0' when others;

  -----------------------------------------------------------------------------
  -- Monitor Counters
  -----------------------------------------------------------------------------
  process(pi_clk)
    variable v_reset : boolean;
    variable v_lst : boolean;
    variable v_vld : boolean;
    variable v_rdy : boolean;
  begin
    v_reset := pi_regs_ms.wrnotrd = '1' and
               pi_regs_ms.valid = '1' and
               pi_regs_ms.addr >= to_unsigned(4, C_CTRL_SPACE_W);
    v_lst := s_monitorPort_ms.tlast = '1';
    v_vld := s_monitorPort_ms.tvalid = '1';
    v_rdy := s_monitorPort_sm.tready = '1';
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_monitorState  <= Idle;
        s_mstallCounter <= c_CounterZero;
        s_sstallCounter <= c_CounterZero;
        s_activeCounter <= c_CounterZero;
        s_totalCounter  <= c_CounterZero;
      else
        case s_monitorState is

          when Idle =>
            if v_reset then
              s_monitorState  <= Idle;
              s_mstallCounter <= c_CounterZero;
              s_sstallCounter <= c_CounterZero;
              s_activeCounter <= c_CounterZero;
              s_totalCounter  <= c_CounterZero;
            else
              if v_vld and v_rdy and v_lst then
                s_monitorState  <= Done;
                s_totalCounter <= s_totalCounter + c_CounterOne;
                s_activeCounter <= s_activeCounter + c_CounterOne;
              elsif v_vld and v_rdy then
                s_monitorState  <= Running;
                s_totalCounter <= s_totalCounter + c_CounterOne;
                s_activeCounter <= s_activeCounter + c_CounterOne;
              elsif v_vld then
                s_monitorState  <= Running;
                s_totalCounter <= s_totalCounter + c_CounterOne;
                s_sstallCounter <= s_sstallCounter + c_CounterOne;
              elsif v_rdy then
                s_monitorState  <= Running;
                s_totalCounter <= s_totalCounter + c_CounterOne;
                s_mstallCounter <= s_mstallCounter + c_CounterOne;
              end if;
            end if;

          when Running =>
            if v_reset then
              s_monitorState  <= Idle;
              s_mstallCounter <= c_CounterZero;
              s_sstallCounter <= c_CounterZero;
              s_activeCounter <= c_CounterZero;
              s_totalCounter  <= c_CounterZero;
            else
              s_totalCounter <= s_totalCounter + c_CounterOne;
              if v_vld and v_rdy and v_lst then
                s_monitorState  <= Done;
                s_activeCounter <= s_activeCounter + c_CounterOne;
              elsif v_vld and v_rdy then
                s_activeCounter <= s_activeCounter + c_CounterOne;
              elsif v_vld then
                s_sstallCounter <= s_sstallCounter + c_CounterOne;
              elsif v_rdy then
                s_mstallCounter <= s_mstallCounter + c_CounterOne;
              end if;
            end if;

          when Done =>
            if v_reset then
              s_monitorState  <= Idle;
              s_mstallCounter <= c_CounterZero;
              s_sstallCounter <= c_CounterZero;
              s_activeCounter <= c_CounterZero;
              s_totalCounter  <= c_CounterZero;
            end if;

        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Register Interface
  -----------------------------------------------------------------------------
  s_streamMap <= f_resize(s_reg1 & s_reg0, 4*g_InPorts, 0);
  s_dummyMap <= s_reg1(31 downto 28);
  s_monitorMap <= f_resize(s_reg2, 4, 0);
  s_dummyCount <= s_reg3;
  s_dummyCountSet <= s_reg3WrEvent;
  s_reg4Rd <= f_resize(s_totalCounter, C_CTRL_DATA_W, 0);
  s_reg5Rd <= f_resize(s_totalCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
  s_reg6Rd <= f_resize(s_activeCounter, C_CTRL_DATA_W, 0);
  s_reg7Rd <= f_resize(s_activeCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
  s_reg8Rd <= f_resize(s_sstallCounter, C_CTRL_DATA_W, 0);
  s_reg9Rd <= f_resize(s_sstallCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
  s_regARd <= f_resize(s_mstallCounter, C_CTRL_DATA_W, 0);
  s_regBRd <= f_resize(s_mstallCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);

  po_regs_sm.ready <= '1';
  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        po_regs_sm.rddata <= (others => '0');
        s_reg0 <= (others => '0');
        s_reg1 <= (others => '0');
        s_reg2 <= (others => '0');
        s_reg3 <= (others => '0');
        s_reg3WrEvent <= '0';
      else
        s_reg3WrEvent <= '0';
        if pi_regs_ms.valid = '1' then
          case pi_regs_ms.addr is
            when to_unsigned(0, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= s_reg0;
              if pi_regs_ms.wrnotrd = '1' then
                s_reg0 <= f_byteMux(pi_regs_ms.wrstrb, s_reg0, pi_regs_ms.wrdata);
              end if;
            when to_unsigned(1, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= s_reg1;
              if pi_regs_ms.wrnotrd = '1' then
                s_reg1 <= f_byteMux(pi_regs_ms.wrstrb, s_reg1, pi_regs_ms.wrdata);
              end if;
            when to_unsigned(2, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= s_reg2;
              if pi_regs_ms.wrnotrd = '1' then
                s_reg2 <= f_byteMux(pi_regs_ms.wrstrb, s_reg2, pi_regs_ms.wrdata);
              end if;
            when to_unsigned(3, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= s_reg3;
              if pi_regs_ms.wrnotrd = '1' then
                s_reg3WrEvent <= '1';
                s_reg3 <= f_byteMux(pi_regs_ms.wrstrb, s_reg3, pi_regs_ms.wrdata);
              end if;
            when to_unsigned(4, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= s_reg4Rd;
            when to_unsigned(5, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= s_reg5Rd;
            when to_unsigned(6, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= s_reg6Rd;
            when to_unsigned(7, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= s_reg7Rd;
            when to_unsigned(8, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= s_reg8Rd;
            when to_unsigned(9, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= s_reg9Rd;
            when to_unsigned(10, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= s_regARd;
            when to_unsigned(11, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= s_regBRd;
            when others =>
              po_regs_sm.rddata <= (others => '0');
          end case;
        end if;
      end if;
    end if;
  end process;

end StreamInfrastructure;
