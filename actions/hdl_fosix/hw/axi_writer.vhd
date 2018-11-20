library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity AxiWriter is
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

    -- input stream of data to write
    pi_stream_ms : in  t_AxiStream_ms;
    po_stream_sm : out t_AxiStream_sm;

    -- memory interface data will be written to
    po_mem_ms : out t_AxiWr_ms;
    pi_mem_sm : in  t_AxiWr_sm);
end AxiWriter;

architecture AxiWriter of AxiWriter is

  type t_State is (Idle, Init, WaitBurst, WaitAThruW, DoneAThruW, WaitADoneW, WaitAFillW, DoneAFillW, WaitAEndW, Done);
  signal s_state : t_State;

  signal s_address : t_AxiWordAddr;
  signal s_count   : t_RegData;
  signal s_maxLen  : t_AxiBurstLen; -- maximum burst length - 1 (range 1 to 64)
  signal s_burstCount : t_AxiBurstLen;
  signal s_nextBurstCount : t_AxiBurstLen;

  signal s_memAwAddr   : t_AxiAddr;
  signal s_memAwLen    : t_AxiLen;
  signal s_memAwValid  : std_logic;
  signal s_memAwReady  : std_logic;
  signal s_memWValid   : std_logic;
  signal s_memWReady   : std_logic;
  signal s_streamValid : std_logic;
  signal s_streamLast  : std_logic;
  signal s_streamReady : std_logic;

  constant c_AddrRegALo : t_RegAddr := to_unsigned(0, C_CTRL_SPACE_W);
  constant c_AddrRegAHi : t_RegAddr := to_unsigned(1, C_CTRL_SPACE_W);
  constant c_AddrRegCnt : t_RegAddr := to_unsigned(2, C_CTRL_SPACE_W);
  constant c_AddrRegBst : t_RegAddr := to_unsigned(3, C_CTRL_SPACE_W);

  signal s_regAdr : unsigned(2*C_CTRL_ADDR_W-1 downto 0);
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
    if s_nextBurstCount > s_count then
      s_nextBurstCount <= s_count(C_AXI_BURST_LEN_W-1 downto 0) - to_unsigned(1, C_AXI_BURST_LEN_W);
    end if;
    if s_nextBurstCount > s_maxLen then
      s_nextBurstCount <= s_maxLen;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  po_mem_ms.awsize <= c_AxiSize;
  po_mem_ms.awburst <= c_AxiBurstIncr;
  po_mem_ms.awuser  <= pi_context;
  -- bind p_stream to p_mem.w
  with s_state select po_mem_ms.wdata <=
    (others => '0') when WaitAFillW,
    (others => '0') when DoneAFillW,
    pi_stream_ms.tdata when others;
  with s_state select po_mem_ms.wstrb <=
    (others => '0') when WaitAFillW,
    (others => '0') when DoneAFillW,
    pi_stream_ms.tstrb when others;
  po_mem_ms.wlast <= '1' when s_burstCount = 0 else '0';
  with s_state select s_memWValid <=
    s_streamValid when WaitAThruW,
    s_streamValid when DoneAThruW,
    '1' when WaitAFillW,
    '1' when DoneAFillW,
    '0' when others;
  with s_state select s_streamReady <=
    s_memWReady when WaitAThruW,
    s_memWReady when DoneAThruW,
    '0' when others;
  -- always accept and ignore responses (TODO-lw: handle bresp /= OKAY)
  po_mem_ms.bready <= '1';

  -- handshake signals
  po_ready <= '1' when s_state = Idle else '0';
  po_done <= '1' when s_state = Done else '0';

  -- port buffer signals
  po_mem_ms.awaddr    <= s_memAwAddr;
  po_mem_ms.awlen     <= s_memAwLen;
  po_mem_ms.awvalid   <= s_memAwValid;
  s_memAwReady        <= pi_mem_sm.awready;
  po_mem_ms.wvalid    <= s_memWValid;
  s_memWReady         <= pi_mem_sm.wready;
  s_streamValid       <= pi_stream_ms.tvalid;
  s_streamLast        <= pi_stream_ms.tlast;
  po_stream_sm.tready <= s_streamReady;

  -----------------------------------------------------------------------------
  -- Main State Machine
  -----------------------------------------------------------------------------
  process (pi_clk)
    variable v_start : std_logic; -- start signal
    variable v_hold  : std_logic; -- hold signal
    variable v_awrdy : std_logic; -- Write Address Channel Ready
    variable v_bend  : std_logic; -- Burst End
    variable v_wbeat : std_logic; -- Write Data Channel Handshake Occurred
    variable v_send  : std_logic; -- Stream End
    variable v_comp  : std_logic; -- Transfer Complete
  begin
    if pi_clk'event and pi_clk = '1' then
      v_start := pi_start;
      v_hold := pi_hold;
      v_awrdy := pi_mem_sm.awready;
      v_bend := f_logic(s_burstCount = to_unsigned(0, C_AXI_BURST_LEN_W));
      v_wbeat := s_memWValid and s_memWReady;
      v_send := s_streamValid and s_streamReady and s_streamLast;
      v_comp := f_logic(s_count = to_unsigned(0, C_CTRL_DATA_W));

      if pi_rst_n = '0' then
        s_state <= Idle;
        s_address <= (others => '0');
        s_count <= (others => '0');
        s_maxLen <= (others => '0');
        s_burstCount <= (others => '0');
        s_memAwAddr <= (others => '0');
        s_memAwLen <= (others => '0');
        s_memAwValid <= '0';
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
              s_memAwAddr  <= s_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
              s_memAwLen   <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_nextBurstCount;
              s_memAwValid <= '1';
              s_burstCount <= s_nextBurstCount;
              s_address <= s_address + s_nextBurstCount + to_unsigned(1, C_AXI_WORDADDR_W);
              s_count <= s_count - s_nextBurstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
              s_state <= WaitAThruW;
            end if;

          when WaitBurst =>
          -- Wait for release of hold signal after burst parameters are prepared
            if pi_hold = '0' then
              s_memAwAddr <= s_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
              s_memAwLen <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_nextBurstCount;
              s_memAwValid <= '1';
              s_burstCount <= s_nextBurstCount;
              s_address <= s_address + s_nextBurstCount + to_unsigned(1, C_AXI_WORDADDR_W);
              s_count <= s_count - s_nextBurstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
              s_state <= WaitAThruW;
            else
              s_state <= WaitBurst;
            end if;

          when WaitAThruW =>
            -- decrement s_burstCount if data transfer happened
            if v_wbeat = '1' then
              s_burstCount <= s_burstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
            end if;
            -- react to awready
            if v_awrdy = '1' then
              s_memAwValid <= '0';
            end if;
            -- Determine next state
            if    v_awrdy = '1' and v_bend = '1' and v_send = '1' then
              s_state <= Done;
            elsif v_awrdy = '1' and v_bend = '1' and v_send = '0' then
              if v_comp = '1' then
                s_state <= Done;
              elsif pi_hold = '1' then
                s_state <= WaitBurst;
              else
                s_memAwAddr <= s_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
                s_memAwLen <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_nextBurstCount;
                s_memAwValid <= '1';
                s_burstCount <= s_nextBurstCount;
                s_address <= s_address + s_nextBurstCount + to_unsigned(1, C_AXI_WORDADDR_W);
                s_count <= s_count - s_nextBurstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
                s_state <= WaitAThruW;
              end if;
            elsif v_awrdy = '1' and v_bend = '0' and v_send = '1' then
              s_state <= DoneAFillW;
            elsif v_awrdy = '1' and v_bend = '0' and v_send = '0' then
              s_state <= DoneAThruW;
            elsif v_awrdy = '0' and v_bend = '1' and v_send = '1' then
              s_state <= WaitAEndW;
            elsif v_awrdy = '0' and v_bend = '1' and v_send = '0' then
              s_state <= WaitADoneW;
            elsif v_awrdy = '0' and v_bend = '0' and v_send = '1' then
              s_state <= WaitAFillW;
            else
              s_state <= WaitAThruW;
            end if;

          when DoneAThruW =>
            -- decrement s_burstCount if data transfer happened
            if v_wbeat = '1' then
              s_burstCount <= s_burstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
            end if;
            -- Determine next state
            if    v_bend = '1' and v_send = '1' then
              s_state <= Done;
            elsif v_bend = '1' and v_send = '0' then
              if v_comp = '1' then
                s_state <= Done;
              elsif v_hold = '1' then
                s_state <= WaitBurst;
              else
                s_memAwAddr <= s_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
                s_memAwLen <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_nextBurstCount;
                s_memAwValid <= '1';
                s_burstCount <= s_nextBurstCount;
                s_address <= s_address + s_nextBurstCount + to_unsigned(1, C_AXI_WORDADDR_W);
                s_count <= s_count - s_nextBurstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
                s_state <= WaitAThruW;
              end if;
            elsif v_bend = '0' and v_send = '1' then
              s_state <= DoneAFillW;
            else
              s_state <= DoneAThruW;
            end if;

          when WaitADoneW =>
            -- react to awready
            if v_awrdy = '1' then
              s_memAwValid <= '0';
            end if;
            -- Determine next state
            if v_awrdy = '1' then
              if v_comp = '1' then
                s_state <= Done;
              elsif v_hold = '1' then
                s_state <= WaitBurst;
              else
                s_memAwAddr <= s_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
                s_memAwLen <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_nextBurstCount;
                s_memAwValid <= '1';
                s_burstCount <= s_nextBurstCount;
                s_address <= s_address + s_nextBurstCount + to_unsigned(1, C_AXI_WORDADDR_W);
                s_count <= s_count - s_nextBurstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
                s_state <= WaitAThruW;
              end if;
            end if;

          when WaitAFillW =>
            -- decrement s_burstCount if data transfer happened
            if v_wbeat = '1' then
              s_burstCount <= s_burstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
            end if;
            -- react to awready
            if v_awrdy = '1' then
              s_memAwValid <= '0';
            end if;
            -- Determine next state
            if    v_awrdy = '1' and v_bend = '1' then
              s_state <= Done;
            elsif v_awrdy = '1' and v_bend = '0' then
              s_state <= DoneAFillW;
            elsif v_awrdy = '0' and v_bend = '1' then
              s_state <= WaitAEndW;
            else
              s_state <= WaitAFillW;
            end if;

          when DoneAFillW =>
            -- decrement s_burstCount if data transfer happened
            if v_wbeat = '1' then
              s_burstCount <= s_burstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
            end if;
            -- Determine next state
            if v_bend = '1' then
              s_state <= Done;
            else
              s_state <= DoneAFillW;
            end if;

          when WaitAEndW =>
            -- Determine next state
            if v_awrdy = '1' then
              s_state <= Done;
            else
              s_state <= WaitAEndW;
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

end AxiWriter;
