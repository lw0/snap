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
    po_stream_ms : out t_NativeStream_ms;
    pi_stream_sm : in  t_NativeStream_sm;

    -- memory interface data will be read from
    po_mem_ms : out t_AxiWr_ms;
    pi_mem_sm : in  t_AxiWr_sm);
end AxiReader;

architecture AxiReader of AxiReader is

  constant c_AddrRegALo : t_RegAddr := to_unsigned(0, C_CTRL_SPACE_W);
  constant c_AddrRegAHi : t_RegAddr := to_unsigned(1, C_CTRL_SPACE_W);
  constant c_AddrRegCnt : t_RegAddr := to_unsigned(2, C_CTRL_SPACE_W);
  constant c_AddrRegBst : t_RegAddr := to_unsigned(3, C_CTRL_SPACE_W);

  signal s_regALo : t_RegData;
  signal s_regAHi : t_RegData;
  signal s_regCnt : t_RegData;
  signal s_regBst : t_RegData;

begin

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  -- p_mem signals
  -- select burst parameters
  po_mem_ms.awsize <= c_AxiSize;
  po_mem_ms.awburst <= c_AxiBurstIncr;
  -- memory access context
  po_mem_ms.awuser  <= pi_context;
  -- bind p_stream to p_hmem.w
  po_mem_ms.wdata <= pi_stream_ms.tdata;
  po_mem_ms.wstrb <= pi_stream_ms.tstrb;
  po_mem_ms.wlast <= '1' when s_burstCounter = 0 else '0';
  with s_state select po_mem_ms.wvalid <=
    pi_stream_ms.tvalid when WaitAThruW,
    pi_stream_ms.tvalid when DoneAThruW,
    '0' when others;
  -- always accept and ignore responses (TODO-lw: handle bresp /= OKAY)
  po_mem_ms.bready <= '1';

  -- p_stream signals
  with s_state select po_stream_sm.tready <=
    pi_mem_sm.wready when WaitAThruW,
    pi_mem_sm.wready when DoneAThruW,
    '0' when others;

  -- handshake signals
  po_ready <= '1' when s_state = Idle else '0';
  po_done <= '1' when s_state = Done else '0';

  -----------------------------------------------------------------------------
  -- Main State Machine
  -----------------------------------------------------------------------------
  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_state <= Idle;
        s_address <= (others => '0');
        s_count <= (others => '0');
        s_maxLen <= (others => '0');
        s_burstCount <= (others => '0');
        s_lastBurstCount <= (others => '0');
        po_mem_ms.awaddr <= (others => '0');
        po_mem_ms.awlen <= (others => '0');
        po_mem_ms.awvalid <= '0';
      else
        case s_state is
          when Idle =>
          -- Wait for start signal and save register contents
            if pi_start = '1' then
              s_address <= (s_regAHi & s_regALo)(C_AXI_ADDR_W-1 downto C_AXI_DATA_BYTES_W);
              s_count <= s_regCnt;
              s_maxLen <= s_regBst(C_AXI_BURST_LEN_W-1 downto 0);
              s_state <= Init;
            end if;
          when Init =>
          -- calculate burst parameters and start burst
            s_burstCount <= f_burstCount(s_address, s_count, s_maxLen);
            s_address <= s_address + s_burstCount;
            s_count <= s_count - s_burstCount;
            if s_burstCount = to_unsigned(0, C_AXI_BURST_LEN_W) then
              s_state <= Done;
            elsif pi_hold = '0' then
              s_state <= WaitBurst;
            else
              s_state <= WaitAThruW;
              po_mem_ms.awaddr <= a_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
              po_mem_ms.awlen <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_burstCount;
              po_mem_ms.awvalid <= '1';
            end if;
          when WaitBurst =>
          -- Wait for release of hold signal after burst parameters are prepared
            if pi_hold = '0' then
              s_state <= WaitAThruW;
              po_mem_ms.awaddr <= a_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
              po_mem_ms.awlen <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_burstCount;
              po_mem_ms.awvalid <= '1';
            end if;
          when WaitAThruW =>
          -- Wait for awready to terminate aw-channel transfer
          -- Monitor t-w-channel
            -- decrement s_burstCount if data transfer happened
            s_lastBurstCount <= s_burstCount;
            if pi_stream_ms.tvalid = '1' and pi_mem_sm.wready = '1' then
              s_burstCount <= s_burstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
            end if;
            -- if burst ended, update address counters
            if s_lastBurstCount = to_unsigned(0, C_AXI_BURST_LEN_W) then
              s_burstCount <= f_burstCount(s_address, s_count, s_maxLen);
              s_address <= s_address + s_burstCount;
              s_count <= s_count - s_burstCount;
            end if;
            -- react to awready
            if pi_mem_sm.awready = '1' then
              po_mem_ms.awvalid <= '0';
            end if;
            -- determine next state
            if pi_mem_sm.awready = '1' and s_lastBurstCount = to_unsigned(0, C_AXI_BURST_LEN_W) then
              if s_burstCount = to_unsigned(0, C_AXI_BURST_LEN_W) then
                s_state <= Done;
              elsif pi_hold = '0' then
                s_state <= WaitBurst;
              else
                s_state <= WaitAThruW;
                po_mem_ms.awaddr <= a_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
                po_mem_ms.awlen <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_burstCount;
                po_mem_ms.awvalid <= '1';
              end if;
            elsif pi_mem_sm.awready = '1' then
              state <= DoneAThruW;
            elsif s_lastBurstCount = to_unsigned(0, C_AXI_BURST_LEN_W) then
              state <= WaitADoneW;
            end if;
          when DoneAThruW =>
          -- aw-channel transfer completed
          -- Monitor t-w-channel
            -- decrement s_burstCount if data transfer happened
            s_lastBurstCount <= s_burstCount;
            if pi_stream_ms.tvalid = '1' and pi_mem_sm.wready = '1' then
              s_burstCount <= s_burstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
            end if;
            if s_lastBurstCount = to_unsigned(0, C_AXI_BURST_LEN_W) then
              s_burstCount <= f_burstCount(s_address, s_count, s_maxLen);
              s_address <= s_address + s_burstCount;
              s_count <= s_count - s_burstCount;
              if s_burstCount = to_unsigned(0, C_AXI_BURST_LEN_W) then
                s_state <= Done;
              elsif pi_hold = '0' then
                s_state <= WaitBurst;
              else
                s_state <= WaitAThruW;
                po_mem_ms.awaddr <= a_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
                po_mem_ms.awlen <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_burstCount;
                po_mem_ms.awvalid <= '1';
              end if;
            end if;
          when WaitADoneW =>
          -- Wait for awready to terminate aw-channel transfer
          -- t-w-channel transfers completed
            if pi_mem_sm.awready = '1' then
              po_mem_ms.awvalid <= '0';
              if s_burstCount = to_unsigned(0, C_AXI_BURST_LEN_W) then
                s_state <= Done;
              elsif pi_hold = '0' then
                s_state <= WaitBurst;
              else
                s_state <= WaitAThruW;
                po_mem_ms.awaddr <= a_address & to_unsigned(0, C_AXI_DATA_BYTES_W);
                po_mem_ms.awlen <= to_unsigned(0, C_AXI_LEN_W-C_AXI_BURST_LEN_W) & s_burstCount;
                po_mem_ms.awvalid <= '1';
              end if;
            end if;
          when Done =>
          -- Assert po_done for one cycle before entering Idle
            state <= Idle;
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
        s_regAdrLo <= (others => '0');
        s_regAdrHi <= (others => '0');
        s_regCount <= (others => '0');
        s_regBurst <= (others => '0');
        po_regs_sm.rddata <= (others => '0');
      else
        if pi_regs_ms.valid = '1' then
          case pi_regs_ms.addr is
            when c_AddrRegALo =>
              po_regs_sm.rddata <= s_regALo;
              if pi_regs_ms.wrnotrd = '1' then
                s_regALo <= f_byteMux(pi_regs_ms.wrstrb, s_regALo, pi_regs_ms.wrdata);
              end if;
            when c_AddrRegAHi =>
              po_regs_sm.rddata <= s_regAHi;
              if pi_regs_ms.wrnotrd = '1' then
                s_regAHi <= f_byteMux(pi_regs_ms.wrstrb, s_regAHi, pi_regs_ms.wrdata);
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
