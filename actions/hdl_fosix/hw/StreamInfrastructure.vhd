library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
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

    pi_inPorts_ms  : in  t_AxiStreams_ms(0 to g_InPorts-1);
    po_inPorts_sm  : out t_AxiStreams_sm(0 to g_InPorts-1);

    po_outPorts_ms : out t_AxiStreams_ms(0 to g_OutPorts-1);
    pi_outPorts_sm : in  t_AxiStreams_sm(0 to g_OutPorts-1);

    po_monPort_ms  : out t_AxiStream_ms;
    po_monPort_sm  : out t_AxiStream_sm);
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

  type t_DummyState is (Done, Counting);
  signal s_dummyState     : t_DummyState;
  signal s_dummyCountdown : t_RegData;

  signal s_monitorMap     : unsigned(3 downto 0);

  -- Control Registers
  signal s_portReady      : std_logic;
  signal s_portValid      : std_logic;
  signal s_portWrNotRd    : std_logic;
  signal s_portWrData     : t_RegData;
  signal s_portWrStrb     : t_RegStrb;
  signal s_portRdData     : t_RegData;
  signal s_portAddr       : t_RegAddr;

  signal s_reg3WrEvent    : std_logic;
  signal s_reg1reg0       : unsigned(2*C_CTRL_DATA_W-1 downto 0);
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
    variable v_srcPort : integer range 0 to 15;
    variable v_dstPort : integer range 0 to 15;
    variable v_guards : t_BoolArray(0 to 15);
  begin
    v_guards := (others=>false);
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
        s_inPorts_sm(v_srcPort) <= (tready => '1');
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
      po_monPort_ms <= c_AxiStreamNull_ms;
      po_monPort_sm <= c_AxiStreamNull_sm;
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
          if s_dummyCount = to_unsigned(0, C_CTRL_DATA_W) then
            s_dummyState <= Done;
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

  s_portAddr <= pi_regs_ms.addr;
  s_portWrData <= pi_regs_ms.wrdata;
  s_portWrStrb <= pi_regs_ms.wrstrb;
  s_portWrNotRd <= pi_regs_ms.wrnotrd;
  s_portValid <= pi_regs_ms.valid;
  po_regs_sm.rddata <= s_portRdData;
  po_regs_sm.ready <= s_portReady;
  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_portRdData <= (others => '0');
        s_portReady <= '0';
        s_reg0 <= (others => '0');
        s_reg1 <= (others => '0');
        s_reg2 <= (others => '0');
        s_reg3 <= (others => '0');
        s_reg3WrEvent <= '0';
      else
        s_reg3WrEvent <= '0';
        if s_portValid = '1' and s_portReady = '0' then
          s_portReady <= '1';
          case s_portAddr is
            when to_unsigned(0, C_CTRL_SPACE_W) =>
              s_portRdData <= s_reg0;
              if s_portWrNotRd = '1' then
                s_reg0 <= f_byteMux(s_portWrStrb, s_reg0, s_portWrData);
              end if;
            when to_unsigned(1, C_CTRL_SPACE_W) =>
              s_portRdData <= s_reg1;
              if s_portWrNotRd = '1' then
                s_reg1 <= f_byteMux(s_portWrStrb, s_reg1, s_portWrData);
              end if;
            when to_unsigned(2, C_CTRL_SPACE_W) =>
              s_portRdData <= s_reg2;
              if s_portWrNotRd = '1' then
                s_reg2 <= f_byteMux(s_portWrStrb, s_reg2, s_portWrData);
              end if;
            when to_unsigned(3, C_CTRL_SPACE_W) =>
              s_portRdData <= s_reg3;
              s_reg3WrEvent <= s_portWrNotRd;
              if s_portWrNotRd = '1' then
                s_reg3 <= f_byteMux(s_portWrStrb, s_reg3, s_portWrData);
              end if;
            when others =>
              s_portRdData <= (others => '0');
          end case;
        else
          s_portReady <= '0';
        end if;
      end if;
    end if;
  end process;

end StreamInfrastructure;
