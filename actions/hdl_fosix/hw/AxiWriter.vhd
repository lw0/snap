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
    -- while asserted, no new burst will be started
    pi_hold    : in  std_logic := '0';

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

  signal so_ready         : std_logic;
  signal s_addrStart : std_logic;
  signal s_addrReady : std_logic;

  -- Address State Machine
  signal s_address           : t_AxiWordAddr;
  signal s_count             : t_RegData;
  signal s_maxLen            : t_AxiBurstLen;

  -- Burst Count Queue
  signal s_queueBurstCount     : t_AxiBurstLen;
  signal s_queueBurstLast      : std_logic;
  signal s_queueValid          : std_logic;
  signal s_queueReady          : std_logic;

  -- Data State Machine
  type t_DataState is (Idle, Thru, ThruWait, Fill, FillWait);
  signal s_state         : t_DataState;

  signal s_burstCount        : t_AxiBurstLen;
  signal s_abort             : std_logic;

  signal so_mem_ms_wvalid    : std_logic;
  signal so_stream_sm_tready : std_logic;

  -- Control Registers
  signal s_regAdr            : unsigned(2*C_CTRL_ADDR_W-1 downto 0);
  alias  a_regALo is s_regAdr(C_CTRL_DATA_W-1 downto 0);
  alias  a_regAHi is s_regAdr(2*C_CTRL_DATA_W-1 downto C_CTRL_DATA_W);
  signal s_regCnt            : t_RegData;
  signal s_regBst            : t_RegData;

begin

  s_addrStart <= so_ready and pi_start;
  so_ready <= s_addrReady and f_logic(s_state = Idle);
  po_ready <= so_ready;

  -----------------------------------------------------------------------------
  -- Address State Machine
  -----------------------------------------------------------------------------
  po_mem_ms.arsize <= c_AxiSize;
  po_mem_ms.arburst <= c_AxiBurstIncr;

  s_address <= f_resizeLeft(s_regAdr, C_AXI_WORDADDR_W);
  s_count   <= s_regCnt;
  s_maxLen  <= f_resize(s_regBst, C_AXI_BURST_LEN_W);
  i_addrMachine : entity work.AxiAddrMachine
    port map (
    pi_clk             => pi_clk,
    pi_rst_n           => pi_rst_n,
    pi_start           => s_addrStart,
    po_ready           => s_addrReady,
    pi_hold            => pi_hold,
    pi_abort           => s_abort,
    pi_address         => s_address,
    pi_count           => s_count,
    pi_maxLen          => s_maxLen,
    po_axiAAddr        => po_mem_ms.araddr,
    po_axiALen         => po_mem_ms.arlen,
    po_axiAValid       => po_mem_ms.arvalid,
    pi_axiAReady       => pi_mem_sm.arready,
    po_queueBurstCount => s_queueBurstCount,
    po_queueBurstLast  => s_queueBurstLast,
    po_queueValid      => s_queueValid,
    pi_queueReady      => s_queueReady);

  -----------------------------------------------------------------------------
  -- Data State Machine
  -----------------------------------------------------------------------------
  with s_state select po_mem_ms.wdata <=
    pi_stream_ms.tdata  when Thru,
    (others => '0')     when Fill,
    (others => '0')     when others;
  with s_state select po_mem_ms.wstrb <=
    pi_stream_ms.tstrb  when Thru,
    (others => '0')     when Fill,
    (others => '0')     when others;
  po_mem_ms.wlast <= f_logic(s_burstCount = 0);
  with s_state select so_mem_ms_wvalid <=
    pi_stream_ms.tvalid when Thru,
    '1'                 when Fill,
    '0'                 when others;
  po_mem_ms.wvalid <= so_mem_ms_wvalid;
  with s_state select so_stream_sm_tready <=
    pi_mem_sm.wready    when Thru,
    '0'                 when others;
  po_stream_sm.tready <= so_stream_sm_tready;
  with s_state select s_abort <=
    '1'                 when Fill,
    '1'                 when FillLast,
    '1'                 when FillWait,
    '0'                 when others;
  -- always accept and ignore responses (TODO-lw: handle bresp /= OKAY)
  po_mem_ms.bready <= '1';

  process (pi_clk)
    variable v_beat : std_logic; -- Data Channel Handshake
    variable v_bend : std_logic; -- Last Data Channel Handshake
    variable v_send : std_logic; -- Stream End
    variable v_qval : std_logic; -- Queue Valid
    variable v_qlst : std_logic; -- Queue Last
  begin
    if pi_clk'event and pi_clk = '1' then
      v_beat := so_mem_ms_wvalid = '1' and
                pi_mem_sm.wready = '1';
      v_bend := (s_burstCount = to_unsigned(0, C_AXI_BURST_LEN_W)) and
                so_mem_ms_wvalid = '1' and
                pi_mem_sm.wready = '1';
      v_send := pi_stream_ms.tlast = '1' and
                pi_stream_ms.tvalid = '1' and
                so_stream_sm_tready = '1';
      v_qval := s_qRdValid = '1';
      v_qfin := s_qRdBurstFinal = '1';

      if pi_rst_n = '0' then
        s_burstCount <= (others => '0');
        s_queueReady <= '0';
        s_state <= Idle;
      else
        s_queueReady <= '0';
        case s_state is

          when Idle =>
            if v_qval then
              s_queueReady <= '1';
              s_burstCount <= s_queueBurstCount;
              if v_qlst then
                s_state <= ThruLast;
              else
                s_state <= Thru;
              end if;
            end if;

          when Thru =>
            if v_beat then
              s_burstCount <= s_burstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
            end if;
            if v_bend then
              if v_qval then
                s_queueReady <= '1';
                s_burstCount <= s_queueBurstCount;
                if v_qlst and v_send then
                  s_state <= FillLast;
                elsif v_qlst and not v_send then
                  s_state <= ThruLast;
                elsif not v_qlst and v_send then
                  s_state <= Fill;
                else
                  s_state <= Thru;
                end if;
              else
                if v_send then
                  s_state <= FillWait;
                else
                  s_state <= ThruWait;
                end if;
              end if;
            elsif v_send then
              s_state <= Fill;
            end if;

          when ThruLast =>
            if v_beat then
              s_burstCount <= s_burstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
            end if;
            if v_bend then
              if v_send then
                s_state <= Idle;
              else
                -- TODO-lw add unfinished Stream Signaling or consume until v_send
                s_state <= Idle;
              end if;
            elsif v_send then
              s_state <= FillLast;
            end if;

          when ThruWait =>
            if v_qval then
              s_queueReady <= '1';
              s_burstCount <= s_queueBurstCount;
              if v_qlst then
                s_state <= ThruLast;
              else
                s_state <= Thru;
              end if;
            end if;

          when Fill =>
            if v_beat then
              s_burstCount <= s_burstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
            end if;
            if v_bend then
              if v_qval then
                s_queueReady <= '1';
                s_burstCount <= s_queueBurstCount;
                if v_qlst then
                  s_state <= FillLast;
                else
                  s_state <= Fill;
                end if;
              else
                s_state <= FillWait;
              end if;
            end if;

          when FillLast =>
            if v_beat then
              s_burstCount <= s_burstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
            end if;
            if v_bend then
              s_state <= Idle;
            end if;

          when FillWait =>
            if v_qval then
              s_queueReady <= '1';
              s_burstCount <= s_queueBurstCount;
              if v_qlst then
                s_state <= FillLast;
              else
                s_state <= Fill;
              end if;
            end if;

        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Register Access
  -----------------------------------------------------------------------------
  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_regAdr <= (others => '0');
        s_regCnt <= (others => '0');
        s_regBst <= (others => '0');
        po_regs_sm.ready <= '0';
      else
        if pi_regs_ms.valid = '1' and po_regs_sm.ready = '0' then
          po_regs_sm.ready <= '1';
          case pi_regs_ms.addr is
            when to_unsigned(0, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= a_regALo;
              if pi_regs_ms.wrnotrd = '1' then
                a_regALo <= f_byteMux(pi_regs_ms.wrstrb, a_regALo, pi_regs_ms.wrdata);
              end if;
            when to_unsigned(1, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= a_regAHi;
              if pi_regs_ms.wrnotrd = '1' then
                a_regAHi <= f_byteMux(pi_regs_ms.wrstrb, a_regAHi, pi_regs_ms.wrdata);
              end if;
            when to_unsigned(2, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= s_regCnt;
              if pi_regs_ms.wrnotrd = '1' then
                s_regCnt <= f_byteMux(pi_regs_ms.wrstrb, s_regCnt, pi_regs_ms.wrdata);
              end if;
            when to_unsigned(3, C_CTRL_SPACE_W) =>
              po_regs_sm.rddata <= s_regBst;
              if pi_regs_ms.wrnotrd = '1' then
                s_regBst <= f_byteMux(pi_regs_ms.wrstrb, s_regBst, pi_regs_ms.wrdata);
              end if;
            when others =>
              po_regs_sm.rddata <= (others => '0');
          end case;
        else
          po_regs_sm.ready <= '0';
        end if;
      end if;
    end if;
  end process;

end AxiWriter;
