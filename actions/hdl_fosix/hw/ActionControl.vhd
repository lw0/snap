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
    pi_done         : in  std_logic;
    pi_ready        : in  std_logic;
    pi_idle         : in  std_logic;

    pi_userInt1Req  : in  std_logic := '0';
    po_userInt1Ack  : out std_logic;
    pi_userInt2Req  : in  std_logic := '0';
    po_userInt2Ack  : out std_logic;
    pi_userInt3Req  : in  std_logic := '0';
    po_userInt3Ack  : out std_logic);
end ActionControl;

architecture ActionControl of ActionControl is

  -- Register Access Logic
  signal s_ctrlReg0Rd : t_RegData;
  signal s_ctrlReg1Rd : t_RegData;
  signal s_ctrlReg2Rd : t_RegData;
  signal s_ctrlReg3Rd : t_RegData;
  signal s_ctrlReg4Rd : t_RegData;
  signal s_ctrlReg5Rd : t_RegData;
  signal s_ctrlReg8   : t_RegData;
  signal s_reg0ReadEvent : std_logic;
  signal s_startSetEvent : std_logic;
  signal s_reg3ReadEvent : std_logic;

  constant c_CtrlReg0Addr : t_RegAddr := to_unsigned(0, C_CTRL_SPACE_W);
  constant c_CtrlReg1Addr : t_RegAddr := to_unsigned(1, C_CTRL_SPACE_W);
  constant c_CtrlReg2Addr : t_RegAddr := to_unsigned(2, C_CTRL_SPACE_W);
  constant c_CtrlReg3Addr : t_RegAddr := to_unsigned(3, C_CTRL_SPACE_W);
  constant c_CtrlReg4Addr : t_RegAddr := to_unsigned(4, C_CTRL_SPACE_W);
  constant c_CtrlReg5Addr : t_RegAddr := to_unsigned(5, C_CTRL_SPACE_W);
  constant c_CtrlReg8Addr : t_RegAddr := to_unsigned(8, C_CTRL_SPACE_W);

  -- Interrupt and Action Logic
  signal s_int1Last      : std_logic;
  signal s_int1SetEvent  : std_logic;
  signal s_int2Last      : std_logic;
  signal s_int2SetEvent  : std_logic;
  signal s_int3Last      : std_logic;
  signal s_int3SetEvent  : std_logic;
  signal s_doneLast      : std_logic;
  signal s_doneSetEvent  : std_logic;
  signal s_readyLast     : std_logic;
  signal s_readySetEvent : std_logic;

  signal s_int0Pending : std_logic;
  signal s_int1Pending : std_logic;
  signal s_int2Pending : std_logic;
  signal s_int3Pending : std_logic;

  signal s_startBit : std_logic;
  signal s_doneBit : std_logic;
  signal s_readyBit : std_logic;

  signal s_int0En : std_logic;
  signal s_int1En : std_logic;
  signal s_int2En : std_logic;
  signal s_int3En : std_logic;

  signal s_int0DoneEn : std_logic;
  signal s_int0ReadyEn : std_logic;

  signal s_int0DoneFlag : std_logic;
  signal s_int0ReadyFlag : std_logic;


begin

  -- Control Register Access Logic
  s_ctrlReg0Rd <= to_unsigned(0, C_CTRL_DATA_W-4) & s_readyBit & pi_idle & s_doneBit & s_startBit;
  s_ctrlReg1Rd <= to_unsigned(0, C_CTRL_DATA_W-4) & s_int3En & s_int2En & s_int1En & s_int0En;
  s_ctrlReg2Rd <= to_unsigned(0, C_CTRL_DATA_W-2) & s_int0ReadyEn & s_int0DoneEn;
  s_ctrlReg3Rd <= to_unsigned(0, C_CTRL_DATA_W-2) & s_int0ReadyFlag & s_int0DoneFlag;
  s_ctrlReg4Rd <= pi_type;
  s_ctrlReg5Rd <= pi_version;
  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_int0En <= '0';
        s_int1En <= '0';
        s_int2En <= '0';
        s_int3En <= '0';
        s_int0DoneEn <= '0';
        s_int0ReadyEn <= '0';
        s_ctrlReg8 <= (others => '0');
        po_ctrlRegs_sm.rddata <= (others => '0');
        po_ctrlRegs_sm.ready <= '0';
        s_reg0ReadEvent <= '0';
        s_reg3ReadEvent <= '0';
        s_startSetEvent <= '0';
      else
        po_ctrlRegs_sm.rddata <= (others => '0');
        po_ctrlRegs_sm.ready <= '0';
        s_reg0ReadEvent <= '0';
        s_reg3ReadEvent <= '0';
        s_startSetEvent <= '0';
        if pi_ctrlRegs_ms.valid = '1' then
          po_ctrlRegs_sm.ready <= '1';
          case pi_ctrlRegs_ms.addr is
            when c_CtrlReg0Addr =>
              po_ctrlRegs_sm.rddata <= s_ctrlReg0Rd;
              s_reg0ReadEvent <= '1';
              if pi_ctrlRegs_ms.wrnotrd = '1' then
                s_reg0ReadEvent <= '0';
                s_startSetEvent <= pi_ctrlRegs_ms.wrstrb(0) and
                                   pi_ctrlRegs_ms.wrdata(0);
              end if;
            when c_CtrlReg1Addr =>
              po_ctrlRegs_sm.rddata <= s_ctrlReg1Rd;
              if pi_ctrlRegs_ms.wrnotrd = '1' and pi_ctrlRegs_ms.wrstrb(0) = '1' then
                s_int0En <= pi_ctrlRegs_ms.wrdata(0);
                s_int1En <= pi_ctrlRegs_ms.wrdata(1);
                s_int2En <= pi_ctrlRegs_ms.wrdata(2);
                s_int3En <= pi_ctrlRegs_ms.wrdata(3);
              end if;
            when c_CtrlReg2Addr =>
              po_ctrlRegs_sm.rddata <= s_ctrlReg2Rd;
              if pi_ctrlRegs_ms.wrnotrd = '1' and pi_ctrlRegs_ms.wrstrb(0) = '1' then
                s_int0DoneEn <= pi_ctrlRegs_ms.wrdata(0);
                s_int0ReadyEn <= pi_ctrlRegs_ms.wrdata(1);
              end if;
            when c_CtrlReg3Addr =>
              po_ctrlRegs_sm.rddata <= s_ctrlReg3Rd;
              s_reg3ReadEvent <= '1';
              if pi_ctrlRegs_ms.wrnotrd = '1' then
                s_reg3ReadEvent <= '0';
              end if;
            when c_CtrlReg4Addr =>
              po_ctrlRegs_sm.rddata <= s_ctrlReg4Rd;
            when c_CtrlReg5Addr =>
              po_ctrlRegs_sm.rddata <= s_ctrlReg5Rd;
            when c_CtrlReg8Addr =>
              po_ctrlRegs_sm.rddata <= s_ctrlReg8;
              if pi_ctrlRegs_ms.wrnotrd = '1' then
                s_ctrlReg8 <= f_byteMux(pi_ctrlRegs_ms.wrstrb, s_ctrlReg8,
                                        pi_ctrlRegs_ms.wrdata);
              end if;
            when others =>
              po_ctrlRegs_sm.rddata <= (others => '0');
          end case;
        end if;
      end if;
    end if;
  end process;

  -- Edge Detector (Ready, Done, Int1, Int2, Int3)
  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_int1SetEvent  <= '0';
        s_int2SetEvent  <= '0';
        s_int3SetEvent  <= '0';
        s_doneSetEvent  <= '0';
        s_readySetEvent <= '0';
        s_int1Last  <= '0';
        s_int2Last  <= '0';
        s_int3Last  <= '0';
        s_doneLast  <= '0';
        s_readyLast <= '0';
      else
        s_int1SetEvent  <= '0';
        s_int2SetEvent  <= '0';
        s_int3SetEvent  <= '0';
        s_doneSetEvent  <= '0';
        s_readySetEvent <= '0';
        if s_int1Last = '0' and pi_userInt1Req = '1' then
          s_int1SetEvent <= '1';
        end if;
        if s_int2Last = '0' and pi_userInt2Req = '1' then
          s_int2SetEvent <= '1';
        end if;
        if s_int3Last = '0' and pi_userInt3Req = '1' then
          s_int3SetEvent <= '1';
        end if;
        if s_doneLast = '0' and pi_done = '1' then
          s_doneSetEvent <= '1';
        end if;
        if s_readyLast = '0' and pi_ready = '1' then
          s_readySetEvent <= '1';
        end if;
        s_int1Last  <= pi_userInt1Req;
        s_int2Last  <= pi_userInt2Req;
        s_int3Last  <= pi_userInt3Req;
        s_doneLast  <= pi_done;
        s_readyLast <= pi_ready;
      end if;
    end if;
  end process;

  -- Interrupt Logic
  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        po_intSrc <= to_unsigned(0, C_INT_W);
        po_intReq <= '0';
        s_int0Pending <= '0';
        s_int1Pending <= '0';
        s_int2Pending <= '0';
        s_int3Pending <= '0';
        s_int0DoneFlag <= '0';
        s_int0ReadyFlag <= '0';
      else
        -- Clear Oneshot Signals and Int0 Flags
        po_intReq <= '0';
        po_userInt1Ack <= '0';
        po_userInt2Ack <= '0';
        po_userInt3Ack <= '0';
        if s_reg3ReadEvent = '1' then
          s_int0DoneFlag <= '0';
          s_int0ReadyFlag <= '0';
        end if;
        -- With Pending Interrupts, Wait for pi_intAck
        if s_int0Pending = '1' then
          if pi_intAck = '1' then
            s_int0Pending <= '0';
          end if;
        elsif s_int1Pending = '1' then
          if pi_intAck = '1' then
            s_int1Pending <= '0';
            po_userInt1Ack <= '1';
          end if;
        elsif s_int2Pending = '1' then
          if pi_intAck = '1' then
            s_int2Pending <= '0';
            po_userInt2Ack <= '1';
          end if;
        elsif s_int3Pending = '1' then
          if pi_intAck = '1' then
            s_int3Pending <= '0';
            po_userInt3Ack <= '1';
          end if;
        -- Otherwise Select New Interrupt to Issue
        else
          if s_int0En = '1' and s_int0DoneEn = '1' and s_doneSetEvent = '1' then
            s_int0DoneFlag <= '1';
            s_int0Pending <= '1';
            po_intSrc <= to_unsigned(0, C_INT_W);
            po_intReq <= '1';
          elsif s_int0En = '1' and s_int0ReadyEn = '1' and s_readySetEvent = '1' then
            s_int0ReadyFlag <= '1';
            s_int0Pending <= '1';
            po_intSrc <= to_unsigned(0, C_INT_W);
            po_intReq <= '1';
          elsif pi_userInt1Req = '1' then
            s_int1Pending <= '1';
            po_intSrc <= to_unsigned(1, C_INT_W);
            po_intReq <= '1';
          elsif pi_userInt2Req = '1' then
            s_int2Pending <= '1';
            po_intSrc <= to_unsigned(2, C_INT_W);
            po_intReq <= '1';
          elsif pi_userInt3Req = '1' then
            s_int3Pending <= '1';
            po_intSrc <= to_unsigned(3, C_INT_W);
            po_intReq <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Action Handshake Logic
  po_context <= s_ctrlReg8(po_context'range);
  po_start <= s_startBit;
  process(pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_startBit <= '0';
        s_doneBit  <= '0';
        s_readyBit <= '0';
      else
        -- s_startBit: (is also po_start)
        if s_startSetEvent = '1' then
          s_startBit <= '1';
        elsif pi_ready = '1' then
          s_startBit <= '0';
        end if;
        -- s_doneBit:
        if s_doneSetEvent = '1' then
          s_doneBit <= '1';
        elsif s_reg0ReadEvent = '1' then
          s_doneBit <= '0';
        end if;
        -- s_readyBit:
        if s_readySetEvent = '1' then
          s_readyBit <= '1';
        elsif s_reg0ReadEvent = '1' then
          s_readyBit <= '0';
        end if;
      end if;
    end if;
  end process;

end ActionControl;
