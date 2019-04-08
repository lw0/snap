library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_ctrl.all;
use work.fosix_stream.all;
use work.fosix_user.all;
use work.fosix_util.all;


entity NativeStreamSwitch is
  generic (
    g_InPortCount      : integer range 1 to 15;
    g_OutPortCount     : integer range 1 to 16);
  port (
    pi_clk         : in std_logic;
    pi_rst_n       : in std_logic;

    -- OutPort n is mapped to InPort pi_mapping(4n+3..4n)
    --  InPort 15 is an infinite Null Byte Stream
    pi_regs_ms : in  t_RegPort_ms;
    po_regs_sm : out t_RegPort_sm;

    pi_inPorts_ms  : in  t_NativeStream_v_ms(0 to g_InPortCount-1);
    po_inPorts_sm  : out t_NativeStream_v_sm(0 to g_InPortCount-1);

    po_outPorts_ms : out t_NativeStream_v_ms(0 to g_OutPortCount-1);
    pi_outPorts_sm : in  t_NativeStream_v_sm(0 to g_OutPortCount-1));
end NativeStreamSwitch;

architecture NativeStreamSwitch of NativeStreamSwitch is

  subtype t_PortIndex is integer range 0 to 15;
  type t_PortGuards is array (0 to 15) of boolean;

  signal s_mapping        : unsigned(g_OutPortCount*4-1 downto 0);
  signal s_inPorts_ms     : t_NativeStream_v_ms(0 to g_InPortCount-1);
  signal s_inPorts_sm     : t_NativeStream_v_sm(0 to g_InPortCount-1);
  signal s_outPorts_ms    : t_NativeStream_v_ms(0 to g_OutPortCount-1);
  signal s_outPorts_sm    : t_NativeStream_v_sm(0 to g_OutPortCount-1);

  signal so_reg_sm_ready : std_logic;
  signal s_regMap : unsigned(2*c_RegDataWidth-1 downto 0);
  alias  a_regMapLo is s_regAdr(c_RegDataWidth-1 downto 0);
  alias  a_regMapHi is s_regAdr(2*c_RegDataWidth-1 downto c_RegDataWidth);

begin

  s_mapping <= f_resize(s_regMap, s_mapping'length);

  -----------------------------------------------------------------------------
  -- Stream Switch
  -----------------------------------------------------------------------------
  s_inPorts_ms   <= pi_inPorts_ms;
  po_inPorts_sm  <= s_inPorts_sm;
  po_outPorts_ms <= s_outPorts_ms;
  s_outPorts_sm  <= pi_outPorts_sm;
  process(s_mapping, s_dummyMap, s_inPorts_ms, s_outPorts_sm)
    variable v_guards : t_PortGuards;
    variable v_srcPort : t_PortIndex;
    variable v_dstPort : t_PortIndex;
  begin
    v_guards := (others => false);
    s_inPorts_sm <= (others => c_NativeStreamNull_sm);
    for v_dstPort in 0 to g_OutPortCount-1 loop
      v_srcPort := to_integer(pi_mapping(4*v_dstPort+3 downto 4*v_dstPort));
      if v_srcPort < g_InPortCount and not v_guards(v_srcPort) then
        v_guards(v_srcPort) <= true;
        s_outPorts_ms(v_srcPort) <= s_inPorts_ms(v_srcPort);
        s_inPorts_sm(v_srcPort) <= s_outPorts_sm(v_srcPort);
      else
        s_outPorts_ms(v_srcPort) <= c_NativeStreamNull_ms;
      end if;
    end loop;
  end process;

  -----------------------------------------------------------------------------
  -- Register Access
  -----------------------------------------------------------------------------
  po_regs_sm.ready <= so_regs_sm_ready;
  process (pi_clk)
    variable v_portAddr : integer range 0 to 2**pi_regs_ms.addr'length-1;
  begin
    if pi_clk'event and pi_clk = '1' then
      v_portAddr := to_integer(pi_regs_ms.addr);
      if pi_rst_n = '0' then
        po_regs_sm.rddata <= (others => '0');
        so_regs_sm_ready <= '0';
        s_regMap <= (others => '0');
      else
        if pi_regs_ms.valid = '1' and so_regs_sm_ready = '0' then
          so_regs_sm_ready <= '1';
          case v_portAddr is
            when 0 =>
              po_regs_sm.rddata <= a_regMapLo;
              if pi_regs_ms.wrnotrd = '1' then
                a_regMapLo <= f_byteMux(pi_regs_ms.wrstrb, a_regMapLo, pi_regs_ms.wrdata);
              end if;
            when 1 =>
              po_regs_sm.rddata <= a_regMapHi;
              if pi_regs_ms.wrnotrd = '1' then
                a_regMapHi <= f_byteMux(pi_regs_ms.wrstrb, a_regMapHi, pi_regs_ms.wrdata);
              end if;
            when others =>
              po_regs_sm.rddata <= (others => '0');
          end case;
        else
          so_regs_sm_ready <= '0';
        end if;
      end if;
    end if;
  end process;

end NativeStreamSwitch;
