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
    -- while asserted, no new burst will be started
    pi_hold    : in  std_logic := '0';

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
  type t_State is (Idle, Thru, ThruLast, ThruWait);
  signal s_state         : t_State;
  signal s_burstCount        : t_AxiBurstLen;
  signal so_mem_ms_rready    : std_logic;
  signal so_stream_ms_tvalid : std_logic;

  -- Control Registers
  signal s_regAdr         : unsigned(2*C_CTRL_DATA_W-1 downto 0);
  alias  a_regALo is s_regAdr(C_CTRL_DATA_W-1 downto 0);
  alias  a_regAHi is s_regAdr(2*C_CTRL_DATA_W-1 downto C_CTRL_DATA_W);
  signal s_regCnt         : t_RegData;
  signal s_regBst         : t_RegData;

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
  with s_state select po_stream_ms.tdata <=
    pi_mem_sm.rdata     when Thru,
    (others => '0')     when others;
  with s_state select po_mem_ms.tstrb <=
    (others => '1')     when Thru,
    (others => '0')     when others;
  with s_state select po_mem_ms.tkeep <=
    (others => '1')     when Thru,
    (others => '0')     when others;
  po_stream_ms.tlast <= f_logic(s_burstCount = to_unsigned(0, C_AXI_BURST_LEN_W) and s_state = ThruLast);
  with s_state select so_stream_ms_tvalid <=
    pi_mem_sm.rvalid    when Thru,
    '0'                 when others;
  po_stream_ms.tvalid <= so_stream_ms_tvalid;
  with s_state select so_mem_ms_wready <=
    pi_stream_sm.tready when Thru,
    '0'                 when others;
  -- TODO-lw: handle rresp /= OKAY

  process (pi_clk)
    variable v_beat : std_logic; -- Data Channel Handshake
    variable v_bend : std_logic; -- Last Data Channel Handshake
    variable v_qval : std_logic; -- Queue Valid
    variable v_qlst : std_logic; -- Queue Last
  begin
    if pi_clk'event and pi_clk = '1' then
      v_beat := so_mem_ms_wvalid = '1' and
                pi_mem_sm.wready = '1';
      v_bend := (s_burstCount = to_unsigned(0, C_AXI_BURST_LEN_W)) and
                so_mem_ms_wvalid = '1' and
                pi_mem_sm.wready = '1';
      v_qval := s_queueValid = '1';
      v_qlst := s_queueBurstLast = '1';

      if pi_rst_n = '0' then
        s_burstCount <= (others => '0');
        s_queueReady <= '0';
        s_state  <= Idle;
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
                if v_qlst then
                  s_state <= ThruLast;
                else
                  s_state <= Thru;
                end if;
              else
                s_state <= ThruWait;
              end if;
            end if;

          when ThruLast =>
            if v_beat then
              s_burstCount <= s_burstCount - to_unsigned(1, C_AXI_BURST_LEN_W);
            end if;
            if v_bend then
              s_state <= Idle;
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

end AxiReader;
