library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity ActionControl is
  port (
    pi_clk          : in  std_logic;
    pi_rst_n        : in  std_logic;

    po_intReq       : out std_logic;
    po_intSrc       : out t_InterruptSrc;
    pi_intAck       : in  std_logic;
    pi_ctrlRegs_ms  : in  t_RegPort_ms;
    po_ctrlRegs_sm  : out t_RegPort_sm;

    pi_type         : in  t_RegData;
    pi_version      : in  t_RegData;
    po_context      : out t_Context;
    po_start        : out std_logic;
    pi_ready        : in  std_logic;

    pi_irq1         : in  std_logic := '0';
    po_iack1        : out std_logic;
    pi_irq2         : in  std_logic := '0';
    po_iack2        : out std_logic;
    pi_irq3         : in  std_logic := '0';
    po_iack3        : out std_logic);
end ActionControl;

architecture ActionControl of ActionControl is

  -- Action Logic
  signal s_readyEvent : std_logic;
  signal s_readyLast : std_logic;
  signal s_startBit : std_logic;
  signal s_doneBit  : std_logic;
  signal s_irqDone : std_logic;

  -- Interrupt Logic
  signal s_irqActive : std_logic;
  signal s_irq0      : std_logic;
  signal s_irqState  : unsigned(3 downto 0);
  signal s_irqEvent  : unsigned(3 downto 0);
  signal s_irqLatch  : unsigned(3 downto 0);
  signal s_irqLast   : unsigned(3 downto 0);
  signal s_intReq    : std_logic;
  signal s_intSrc    : t_InterruptSrc;
  signal s_iackEvent : unsigned(3 downto 0);

  -- Control Registers
  signal s_portReady  : std_logic;
  signal s_portValid  : std_logic;
  signal s_portWrNotRd  : std_logic;
  signal s_portWrData  : t_RegData;
  signal s_portWrStrb  : t_RegStrb;
  signal s_portRdData  : t_RegData;
  signal s_portAddr  : t_RegAddr;
  signal s_reg8   : t_RegData;
  signal s_intEn : unsigned(3 downto 0);
  signal s_intDoneEn : std_logic;
  signal s_reg0ReadEvent : std_logic;
  signal s_startSetEvent : std_logic;
  signal s_reg3ReadEvent : std_logic;

begin

  po_context <= s_reg8(po_context'range);

  -- Action Handshake Logic
  po_start <= s_startBit;
  s_irq0 <= s_irqDone;
  process(pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_readyEvent <= '0';
        s_readyLast <= '0';

        s_startBit <= '0';
        s_doneBit  <= '0';
        s_irqDone <= '0';
      else
        s_readyEvent <= pi_ready and not s_readyLast;
        s_readyLast <= pi_ready;

        if s_startSetEvent = '1' then
          s_startBit <= '1';
        elsif pi_ready = '1' then
          s_startBit <= '0';
        end if;

        if s_readyEvent = '1' then
          s_doneBit <= '1';
        elsif s_reg0ReadEvent = '1' then
          s_doneBit <= '0';
        end if;

        if s_readyEvent = '1' and s_intDoneEn = '1' then
          s_irqDone <= '1';
        elsif s_reg3ReadEvent = '1' then
          s_irqDone <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Interrupt Logic
  s_irqState <= (pi_irq3 and s_intEn(3)) &
                (pi_irq2 and s_intEn(2)) &
                (pi_irq1 and s_intEn(1)) &
                ( s_irq0 and s_intEn(0));
  po_iack1   <= s_iackEvent(1);
  po_iack2   <= s_iackEvent(2);
  po_iack3   <= s_iackEvent(3);
  po_intReq  <= s_intReq;
  po_intSrc  <= s_intSrc;
  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_irqActive <= '0';
        s_irqEvent  <= (others => '0');
        s_irqLatch  <= (others => '0');
        s_irqLast   <= (others => '0');
        s_iackEvent <= (others => '0');
        s_intReq    <= '0';
        s_intSrc    <= to_unsigned(0, C_INT_W);
      else
        s_irqEvent  <= s_irqState and not s_irqLast;
        s_irqLatch  <= s_irqLatch or s_irqEvent;
        s_irqLast   <= s_irqState;
        s_iackEvent <= (others => '0');
        s_intReq    <= '0';
        if s_irqActive = '0' then
          if s_irqLatch(0) = '1' then
            s_irqActive <= '1';
            s_irqLatch(0) <= '0';
            s_intReq <= '1';
            s_intSrc <= to_unsigned(0, C_INT_W);
          elsif s_irqLatch(1) = '1' then
            s_irqActive <= '1';
            s_irqLatch(1) <= '0';
            s_intReq <= '1';
            s_intSrc <= to_unsigned(1, C_INT_W);
          elsif s_irqLatch(2) = '1' then
            s_irqActive <= '1';
            s_irqLatch(2) <= '0';
            s_intReq <= '1';
            s_intSrc <= to_unsigned(2, C_INT_W);
          elsif s_irqLatch(3) = '1' then
            s_irqActive <= '1';
            s_irqLatch(3) <= '0';
            s_intReq <= '1';
            s_intSrc <= to_unsigned(3, C_INT_W);
          end if;
        elsif pi_intAck = '1' then
          s_irqActive <= '0';
          s_iackEvent(to_integer(s_intSrc)) <= '1';
        end if;
      end if;
    end if;
  end process;

  -- Control Register Access Logic
  s_portAddr <= pi_ctrlRegs_ms.addr;
  s_portWrData <= pi_ctrlRegs_ms.wrdata;
  s_portWrStrb <= pi_ctrlRegs_ms.wrstrb;
  s_portWrNotRd <= pi_ctrlRegs_ms.wrnotrd;
  s_portValid <= pi_ctrlRegs_ms.valid;
  po_ctrlRegs_sm.rddata <= s_portRdData;
  po_ctrlRegs_sm.ready <= s_portReady;
  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_reg8 <= (others => '0');
        s_intEn <= (others => '0');
        s_intDoneEn <= '0';
        s_portRdData <= (others => '0');
        s_portReady <= '0';
        s_reg0ReadEvent <= '0';
        s_reg3ReadEvent <= '0';
        s_startSetEvent <= '0';
      else
        s_reg0ReadEvent <= '0';
        s_reg3ReadEvent <= '0';
        s_startSetEvent <= '0';
        if s_portValid = '1' and s_portReady = '0' then
          s_portReady <= '1';
          case s_portAddr is
            when to_unsigned(0, C_CTRL_SPACE_W) =>
              s_portRdData <= to_unsigned(0, C_CTRL_DATA_W-4) &
                                s_doneBit & pi_ready & s_doneBit & s_startBit;
              s_reg0ReadEvent <= not s_portWrNotRd;
              if s_portWrNotRd = '1' then
                s_startSetEvent <= s_portWrStrb(0) and s_portWrData(0);
              end if;
            when to_unsigned(1, C_CTRL_SPACE_W) =>
              s_portRdData <= to_unsigned(0, C_CTRL_DATA_W-4) &
                                s_intEn;
              if s_portWrNotRd = '1' and s_portWrStrb(0) = '1' then
                s_intEn <= s_portWrData(3 downto 0);
              end if;
            when to_unsigned(2, C_CTRL_SPACE_W) =>
              s_portRdData <= to_unsigned(0, C_CTRL_DATA_W-1) &
                                s_intDoneEn;
              if s_portWrNotRd = '1' and s_portWrStrb(0) = '1' then
                s_intDoneEn <= s_portWrData(0);
              end if;
            when to_unsigned(3, C_CTRL_SPACE_W) =>
              s_portRdData <= to_unsigned(0, C_CTRL_DATA_W-1) &
                                s_irqDone;
              s_reg3ReadEvent <= not s_portWrNotRd;
            when to_unsigned(4, C_CTRL_SPACE_W) =>
              s_portRdData <= pi_type;
            when to_unsigned(5, C_CTRL_SPACE_W) =>
              s_portRdData <= pi_version;
            when to_unsigned(8, C_CTRL_SPACE_W) =>
              s_portRdData <= s_reg8;
              if s_portWrNotRd = '1' then
                s_reg8 <= f_byteMux(s_portWrStrb, s_reg8, s_portWrData);
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

end ActionControl;
