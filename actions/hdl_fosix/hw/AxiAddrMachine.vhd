library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity AxiAddrMachine is
  port (
    pi_clk             : in  std_logic;
    pi_rst_n           : in  std_logic;

    -- operation is started when both start and ready are asserted
    pi_start           : in  std_logic;
    po_ready           : out std_logic;
    -- while asserted, no new burst will be started
    pi_hold            : in  std_logic := '0';
    -- if asserted, no new burst will be inserted into the queue
    pi_abort           : in  std_logic := '0';

    pi_address         : in  t_AxiWordAddr;
    pi_count           : in  t_RegData;
    pi_maxLen          : in  t_AxiBurstLen;

    po_axiAAddr        : out t_AxiAddr;
    po_axiALen         : out t_AxiLen;
    po_axiAValid       : out std_logic;
    pi_axiAReady       : in  std_logic;

    po_queueBurstCount : out t_AxiBurstLen;
    po_queueBurstLast  : out std_logic;
    po_queueValid      : out std_logic;
    pi_queueReady      : in  std_logic);
end AxiAddrMachine;

architecture AxiAddrMachine of AxiAddrMachine is

  signal so_ready         : std_logic;

  subtype t_BurstParam is unsigned(C_AXI_BURST_LEN_W downto 0);
  signal s_nextBurstCount : t_AxiBurstLen;
  signal s_nextBurstLast  : std_logic;
  signal s_nextBurstParam : t_BurstParam;
  signal s_nextAddress    : t_AxiWordAddr;
  signal s_nextCount      : t_RegData;
  signal s_nextBurstReq   : std_logic;

  -- Address State Machine
  type t_State is (Idle, ReqInit, Init, WaitBurst, ReqWaitAWaitF, WaitAWaitF, DoneAWaitF, WaitADoneF, WaitAWaitFLast, DoneAWaitFLast, WaitADoneFLast);
  signal s_state         : t_State;
  signal s_address           : t_AxiWordAddr;
  signal s_count             : t_RegData;
  signal s_maxLen            : t_AxiBurstLen; -- maximum burst length - 1 (range 1 to 64)

  -- Burst Length Queue
  signal s_qWrBurstParam     : t_BurstParam;
  signal s_qWrValid          : std_logic;
  signal s_qWrReady          : std_logic;
  signal s_qRdBurstParam     : t_BurstParam;

begin

  so_ready <= f_logic(s_state = Idle);
  po_ready <= so_ready;

  -----------------------------------------------------------------------------
  -- Next Burst Parameter Generator
  -----------------------------------------------------------------------------
  process (pi_clk)
    constant c_MaxBurstLen : t_AxiBurstLen := to_unsigned(2**C_AXI_BURST_LEN_W-1, C_AXI_BURST_LEN_W);
    variable v_addrFill : t_AxiBurstLen;
    variable v_countDec : t_RegData;
    variable v_countFill : t_AxiBurstLen;
    variable v_nextBurstCount : t_AxiBurstLen;
    variable v_nextBurstLast : std_logic;
  begin
    if pi_clk'event and pi_clk = '1' then
      if s_nextBurstReq = '1' then
        v_nextBurstCount := s_maxLen;
        v_nextBurstLast := pi_abort;

        -- inversion of address bits within boundary range
        -- equals remaining words but one until boundary would be crossed
        v_addrFill := f_resize(not s_address, C_AXI_BURST_LEN_W);
        if v_nextBurstCount > v_addrFill then
          v_nextBurstCount := v_addrFill;
        end if;

        v_countDec := s_count - to_unsigned(1, C_CTRL_DATA_W);
        if v_countDec > c_MaxBurstLen then
          v_countFill := c_MaxBurstLen;
        else
          v_countFill := f_resize(v_countDec, C_AXI_BURST_LEN_W);
        end if;
        if v_nextBurstCount >= v_countFill then
          v_nextBurstCount := v_countFill;
          v_nextBurstLast := '1';
        end if;

        s_nextBurstCount <= v_nextBurstCount;
        s_nextBurstLast <= v_nextBurstLast;
      end if;
    end if;
  end process;
  s_nextBurstParam <= s_nextBurstLast & s_nextBurstCount;
  s_nextAddress <= s_address + f_resize(s_nextBurstCount, C_AXI_WORDADDR_W) +
                    to_unsigned(1, C_AXI_WORDADDR_W);
  s_nextCount <= s_count - f_resize(s_nextBurstCount, C_CTRL_DATA_W) -
                    to_unsigned(1, C_CTRL_DATA_W);

  -----------------------------------------------------------------------------
  -- Address State Machine
  -----------------------------------------------------------------------------
  with s_state select s_nextBurstReq <=
    '1' when ReqInit,
    '1' when ReqWaitAWaitF,
    '0' when others;

  process (pi_clk)
    variable v_strt : boolean; -- Start Condition
    variable v_hold : boolean; -- Hold Signal
    variable v_ardy : boolean; -- Write Address Channel Ready
    variable v_qrdy : boolean; -- Burst Length Queue Ready
    variable v_last : boolean; -- Next is the last Burst
  begin
    if pi_clk'event and pi_clk = '1' then
      v_strt := pi_start = '1' and so_ready = '1';
      v_hold := pi_hold = '1';
      v_ardy := pi_axiAReady = '1';
      v_qrdy := s_qWrReady = '1';
      v_last := s_nextBurstLast = '1';

      if pi_rst_n = '0' then
        po_axiAAddr       <= (others => '0');
        po_axiALen        <= (others => '0');
        po_axiAValid      <= '0';
        s_qWrBurstParam   <= (others => '0');
        s_qWrValid        <= '0';
        s_address         <= (others => '0');
        s_count           <= (others => '0');
        s_maxLen          <= (others => '0');
        s_state           <= Idle;
      else
        case s_state is

          when Idle =>
            if v_strt then
              s_maxLen  <= pi_maxLen;
              s_address <= pi_address;
              s_count   <= pi_count;
              s_state   <= ReqInit;
            end if;

          when ReqInit =>
            if s_count = to_unsigned(0, C_CTRL_DATA_W) then
              s_state   <= Idle;
            else
              s_state   <= Init;
            end if;

          when Init =>
            if v_hold then
              s_state         <= WaitBurst;
            else
              po_axiAAddr     <= f_resizeLeft(s_address, C_AXI_ADDR_W);
              po_axiALen      <= f_resize(s_nextBurstCount, C_AXI_LEN_W);
              po_axiAValid    <= '1';

              s_qWrBurstParam <= s_nextBurstParam;
              s_qWrValid      <= '1';

              s_address       <= s_nextAddress;
              s_count         <= s_nextCount;
              if v_last then
                s_state       <= WaitAWaitFLast;
              else
                s_state       <= ReqWaitAWaitF;
              end if;
            end if;

          when WaitBurst =>
            if not v_hold then
              po_axiAAddr     <= f_resizeLeft(s_address, C_AXI_ADDR_W);
              po_axiALen      <= f_resize(s_nextBurstCount, C_AXI_LEN_W);
              po_axiAValid    <= '1';

              s_qWrBurstParam <= s_nextBurstParam;
              s_qWrValid      <= '1';

              s_address       <= s_nextAddress;
              s_count         <= s_nextCount;
              if v_last then
                s_state       <= WaitAWaitFLast;
              else
                s_state       <= ReqWaitAWaitF;
              end if;
            end if;

          when ReqWaitAWaitF =>
            if v_ardy and v_qrdy then
              po_axiAValid      <= '0';
              s_qWrValid        <= '0';
              s_state <= WaitBurst;
            elsif v_ardy then
              po_axiAValid      <= '0';
              s_state           <= DoneAWaitF;
            elsif v_qrdy then
              s_qWrValid        <= '0';
              s_state           <= WaitADoneF;
            else
              s_state           <= WaitAWaitF;
            end if;

          when WaitAWaitF =>
            if v_ardy and v_qrdy then
              po_axiAValid      <= '0';
              s_qWrValid        <= '0';
              if v_hold then
                s_state         <= WaitBurst;
              else
                po_axiAAddr     <= f_resizeLeft(s_address, C_AXI_ADDR_W);
                po_axiALen      <= f_resize(s_nextBurstCount, C_AXI_LEN_W);
                po_axiAValid    <= '1';

                s_qWrBurstParam <= s_nextBurstParam;
                s_qWrValid      <= '1';

                s_address       <= s_nextAddress;
                s_count         <= s_nextCount;
                if v_last then
                  s_state       <= WaitAWaitFLast;
                else
                  s_state       <= ReqWaitAWaitF;
                end if;
              end if;
            elsif v_ardy then
              po_axiAValid      <= '0';
              s_state           <= DoneAWaitF;
            elsif v_qrdy then
              s_qWrValid        <= '0';
              s_state           <= WaitADoneF;
            end if;

          when WaitADoneF =>
            if v_ardy then
              po_axiAValid      <= '0';
              if v_hold then
                s_state         <= WaitBurst;
              else
                po_axiAAddr     <= f_resizeLeft(s_address, C_AXI_ADDR_W);
                po_axiALen      <= f_resize(s_nextBurstCount, C_AXI_LEN_W);
                po_axiAValid    <= '1';

                s_qWrBurstParam <= s_nextBurstParam;
                s_qWrValid      <= '1';

                s_address       <= s_nextAddress;
                s_count         <= s_nextCount;
                if v_last then
                  s_state       <= WaitAWaitFLast;
                else
                  s_state       <= ReqWaitAWaitF;
                end if;
              end if;
            end if;

          when DoneAWaitF =>
            if v_qrdy then
              s_qWrValid        <= '0';
              if v_hold then
                s_state         <= WaitBurst;
              else
                po_axiAAddr     <= f_resizeLeft(s_address, C_AXI_ADDR_W);
                po_axiALen      <= f_resize(s_nextBurstCount, C_AXI_LEN_W);
                po_axiAValid    <= '1';

                s_qWrBurstParam <= s_nextBurstParam;
                s_qWrValid      <= '1';

                s_address       <= s_nextAddress;
                s_count         <= s_nextCount;
                if v_last then
                  s_state       <= WaitAWaitFLast;
                else
                  s_state       <= ReqWaitAWaitF;
                end if;
              end if;
            end if;

          when WaitAWaitFLast =>
            if v_ardy and v_qrdy then
              po_axiAValid      <= '0';
              s_qWrValid        <= '0';
              s_state           <= Idle;
            elsif v_ardy then
              po_axiAValid      <= '0';
              s_state           <= DoneAWaitFLast;
            elsif v_qrdy then
              s_qWrValid        <= '0';
              s_state           <= WaitADoneFLast;
            end if;

          when WaitADoneFLast =>
            if v_ardy then
              po_axiAValid      <= '0';
              s_state           <= Idle;
            end if;

          when DoneAWaitFLast =>
            if v_qrdy then
              s_qWrValid        <= '0';
              s_state           <= Idle;
            end if;

        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Burst Lenght Queue
  -----------------------------------------------------------------------------
  i_blenFIFO : entity work.FIFO
    generic map (
      g_DataWidth => C_AXI_BURST_LEN_W + 1,
      g_CntWidth => 3) -- FIFO depth = 8
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_inData => s_qWrBurstParam,
      pi_inValid => s_qWrValid,
      po_inReady => s_qWrReady,
      po_outData => s_qRdBurstParam,
      po_outValid => po_queueValid,
      pi_outReady => pi_queueReady);
  po_queueBurstCount <= s_qRdBurstParam(C_AXI_BURST_LEN_W-1 downto 0);
  po_queueBurstLast  <= s_qRdBurstParam(C_AXI_BURST_LEN_W);

end AxiAddrMachine;
