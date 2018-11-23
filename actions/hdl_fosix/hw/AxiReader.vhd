library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity AxiReader is
	port (
    pi_clk     : in  std_logic;
    pi_rst_n   : in  std_logic;

    -- operation is started when both start and ready are asserted
    pi_start   : in  std_logic;
    po_ready   : out std_logic;
    -- assertion of done signals that ready will be asserted in next cycle
    po_done    : out std_logic;
    -- while asserted, no new burst will be started
    pi_hold    : in  std_logic := '0';
    -- context id used for memory accesses
    pi_context : in  t_Context;

    -- Config register port:
    --  Reg0: Start address low word
    --  Reg1: Start address high word
    --  Reg2: Transfer count
    --  Reg3: Maximum Burst length
    pi_regs_ms : in  t_RegPort_ms;
    po_regs_sm : out t_RegPort_sm;

    -- output stream of read data
    po_stream_ms : out t_AxiStream_ms;
    pi_stream_sm : in  t_AxiStream_sm;

    -- memory interface data will be read from
    po_mem_ms : out t_AxiRd_ms;
    pi_mem_sm : in  t_AxiRd_sm);
end AxiReader;

architecture AxiReader of AxiReader is

  type t_State is (Idle, Init, WaitBurst, WaitAThruR, DoneAThruR, WaitADoneR, Done);
  signal s_state : t_State;

  signal s_address : t_AxiWordAddr;
  signal s_count   : t_RegData;
  signal s_maxLen  : t_AxiBurstLen; -- maximum burst length - 1 (range 1 to 64)
  signal s_burstCount : t_AxiBurstLen;
  signal s_nextBurstCount : t_AxiBurstLen;

  signal s_memArAddr  : t_AxiAddr;
  signal s_memArLen   : t_AxiLen;
  signal s_memArValid : std_logic;
  signal s_memArReady : std_logic;
  signal s_memRValid  : std_logic;
  signal s_memRReady  : std_logic;

  constant c_AddrRegALo : t_RegAddr := to_unsigned(0, C_CTRL_SPACE_W);
  constant c_AddrRegAHi : t_RegAddr := to_unsigned(1, C_CTRL_SPACE_W);
  constant c_AddrRegCnt : t_RegAddr := to_unsigned(2, C_CTRL_SPACE_W);
  constant c_AddrRegBst : t_RegAddr := to_unsigned(3, C_CTRL_SPACE_W);

  signal s_regAdr : unsigned(2*C_CTRL_DATA_W-1 downto 0);
  alias  a_regALo is s_regAdr(C_CTRL_DATA_W-1 downto 0);
  alias  a_regAHi is s_regAdr(2*C_CTRL_DATA_W-1 downto C_CTRL_DATA_W);
  signal s_regCnt : t_RegData;
  signal s_regBst : t_RegData;

begin

  -----------------------------------------------------------------------------
  -- Burst Length Calculation
  -----------------------------------------------------------------------------
  process (s_address, s_count, s_maxLen)
  begin
    -- inversion of address bits within boundary range = remaining words but one until boundary would be crossed
    s_nextBurstCount <= not s_address(C_AXI_BURST_LEN_W-1 downto 0);
    if s_nextBurstCount >= s_count then
      s_nextBurstCount <= s_count(C_AXI_BURST_LEN_W-1 downto 0) - to_unsigned(1,C_AXI_BURST_LEN_W);
    end if;
    if s_nextBurstCount > s_maxLen then
      s_nextBurstCount <= s_maxLen;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  po_mem_ms.arsize <= c_AxiSize;
  po_mem_ms.arburst <= c_AxiBurstIncr;
  po_mem_ms.aruser  <= pi_context;
  -- bind p_mem.r to p_stream
  po_stream_ms.tdata <= pi_mem_sm.rdata;
  po_stream_ms.tstrb <= (others => '1');
  po_stream_ms.tkeep <= (others => '1');
  po_stream_ms.tlast <= f_logic(s_burstCount = 0 and s_count = 0);
  with s_state select po_stream_ms.tvalid <=
    s_memRValid when WaitAThruR,
    s_memRValid when DoneAThruR,
    '0' when others;
  with s_state select s_memRReady <=
    pi_stream_sm.tready when WaitAThruR,
    pi_stream_sm.tready when DoneAThruR,
    '0' when others;
  -- TODO-lw: handle rresp /= OKAY

  -- handshake signals
  po_ready <= '1' when s_state = Idle else '0';
  po_done <= '1' when s_state = Done else '0';

  po_mem_ms.araddr  <= s_memArAddr;
  po_mem_ms.arlen   <= s_memArLen;
  po_mem_ms.arvalid <= s_memArValid;
  s_memArReady      <= pi_mem_sm.arready;
  s_memRValid       <= pi_mem_sm.rvalid;
  po_mem_ms.rready  <= s_memRReady;
  -----------------------------------------------------------------------------
  -- Main State Machine
  -----------------------------------------------------------------------------
  process (pi_clk)
    variable v_start : std_logic; -- start signal
    variable v_hold  : std_logic; -- hold signal
    variable v_arrdy : std_logic; -- Read Address Channel Ready
    variable v_bend  : std_logic; -- Burst End
    variable v_rbeat : std_logic; -- Read Data Channel Handshake Occurred
    variable v_comp  : std_logic; -- Transfer Complete
  begin
    if pi_clk'event and pi_clk = '1' then
      v_start := pi_start;
      v_hold  := pi_hold;
      v_arrdy := s_memArReady;
      v_bend  := f_logic(s_burstCount = to_unsigned(0, C_AXI_BURST_LEN_W));
      v_rbeat := s_memRValid and s_memRReady; --TODO-lw declare buffers
      v_comp  := f_logic(s_count = to_unsigned(0, C_CTRL_DATA_W));

      if pi_rst_n = '0' then
        s_state <= Idle;
        s_address <= (others => '0');
        s_count <= (others => '0');
        s_maxLen <= (others => '0');
        s_burstCount <= (others => '0');
        s_memArAddr <= (others => '0');
        s_memArLen <= (others => '0');
        s_memArValid <= '0';
      else
        case s_state is

          when Idle =>
            if v_start = '1' then
              s_address <= s_regAdr(C_AXI_ADDR_W-1 downto C_AXI_DATA_BYTES_W);
              s_count   <= s_regCnt;
              s_maxLen  <= s_regBst(C_AXI_BURST_LEN_W-1 downto 0);
              s_state   <= Init;
            else
              s_state <= Idle;
            end if;

          when Init =>
            if v_comp = '1' then -- transaction is empty
              s_state <= Done;
            elsif v_hold = '1' then -- wait for hold release
              s_state <= WaitBurst;
            else -- start burst
              s_memArAddr  <= s_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
              s_memArLen   <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_nextBurstCount;
              s_memArValid <= '1';
              s_burstCount <= s_nextBurstCount;
              s_address <= s_address + s_nextBurstCount + to_unsigned(1, C_AXI_WORDADDR_W);
              s_count <= s_count - s_nextBurstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
              s_state <= WaitAThruR;
            end if;

          when WaitBurst =>
          -- Wait for release of hold signal after burst parameters are prepared
            if pi_hold = '0' then
              s_memArAddr <= s_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
              s_memArLen <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_nextBurstCount;
              s_memArValid <= '1';
              s_burstCount <= s_nextBurstCount;
              s_address <= s_address + s_nextBurstCount + to_unsigned(1, C_AXI_WORDADDR_W);
              s_count <= s_count - s_nextBurstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
              s_state <= WaitAThruR;
            else
              s_state <= WaitBurst;
            end if;

          when WaitAThruR =>
            -- decrement s_burstCount if data transfer happened
            if v_rbeat = '1' then
              s_burstCount <= s_burstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
            end if;
            -- react to arready
            if v_arrdy = '1' then
              s_memArValid <= '0';
            end if;
            -- Determine next state
            if v_arrdy = '1' and v_bend = '1' then
              if v_comp = '1' then
                s_state <= Done;
              elsif pi_hold = '1' then
                s_state <= WaitBurst;
              else
                s_memArAddr <= s_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
                s_memArLen <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_nextBurstCount;
                s_memArValid <= '1';
                s_burstCount <= s_nextBurstCount;
                s_address <= s_address + s_nextBurstCount + to_unsigned(1, C_AXI_WORDADDR_W);
                s_count <= s_count - s_nextBurstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
                s_state <= WaitAThruR;
              end if;
            elsif v_arrdy = '1' and v_bend = '0' then
              s_state <= DoneAThruR;
            elsif v_arrdy = '0' and v_bend = '1' then
              s_state <= WaitADoneR;
            else
              s_state <= WaitAThruR;
            end if;

          when DoneAThruR =>
            -- decrement s_burstCount if data transfer happened
            if v_rbeat = '1' then
              s_burstCount <= s_burstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
            end if;
            -- Determine next state
            if v_bend = '1' then
              if v_comp = '1' then
                s_state <= Done;
              elsif v_hold = '1' then
                s_state <= WaitBurst;
              else
                s_memArAddr <= s_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
                s_memArLen <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_nextBurstCount;
                s_memArValid <= '1';
                s_burstCount <= s_nextBurstCount;
                s_address <= s_address + s_nextBurstCount + to_unsigned(1, C_AXI_WORDADDR_W);
                s_count <= s_count - s_nextBurstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
                s_state <= WaitAThruR;
              end if;
            else
              s_state <= DoneAThruR;
            end if;

          when WaitADoneR =>
            -- react to arready
            if v_arrdy = '1' then
              s_memArValid <= '0';
            end if;
            -- Determine next state
            if v_arrdy = '1' then
              if v_comp = '1' then
                s_state <= Done;
              elsif v_hold = '1' then
                s_state <= WaitBurst;
              else
                s_memArAddr <= s_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
                s_memArLen <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_nextBurstCount;
                s_memArValid <= '1';
                s_burstCount <= s_nextBurstCount;
                s_address <= s_address + s_nextBurstCount + to_unsigned(1, C_AXI_WORDADDR_W);
                s_count <= s_count - s_nextBurstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
                s_state <= WaitAThruR;
              end if;
            else
              s_state <= WaitADoneR;
            end if;

          when Done =>
            s_state <= Idle;
        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Register Access
  -----------------------------------------------------------------------------
  po_regs_sm.ready <= '1';
  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_regAdr <= (others => '0');
        s_regCnt <= (others => '0');
        s_regBst <= (others => '0');
        po_regs_sm.rddata <= (others => '0');
      else
        if pi_regs_ms.valid = '1' then
          case pi_regs_ms.addr is
            when c_AddrRegALo =>
              po_regs_sm.rddata <= a_regALo;
              if pi_regs_ms.wrnotrd = '1' then
                a_regALo <= f_byteMux(pi_regs_ms.wrstrb, a_regALo, pi_regs_ms.wrdata);
              end if;
            when c_AddrRegAHi =>
              po_regs_sm.rddata <= a_regAHi;
              if pi_regs_ms.wrnotrd = '1' then
                a_regAHi <= f_byteMux(pi_regs_ms.wrstrb, a_regAHi, pi_regs_ms.wrdata);
              end if;
            when c_AddrRegCnt =>
              po_regs_sm.rddata <= s_regCnt;
              if pi_regs_ms.wrnotrd = '1' then
                s_regCnt <= f_byteMux(pi_regs_ms.wrstrb, s_regCnt, pi_regs_ms.wrdata);
              end if;
            when c_AddrRegBst =>
              po_regs_sm.rddata <= s_regBst;
              if pi_regs_ms.wrnotrd = '1' then
                s_regBst <= f_byteMux(pi_regs_ms.wrstrb, s_regBst, pi_regs_ms.wrdata);
              end if;
            when others =>
              po_regs_sm.rddata <= (others => '0');
          end case;
        end if;
      end if;
    end if;
  end process;

end AxiReader;
