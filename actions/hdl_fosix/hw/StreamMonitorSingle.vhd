library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity StreamMonitorSingle is
  generic (
    g_CounterWidth : integer := 48);
  port (
    pi_clk         : in  std_logic;
    pi_rst_n       : in  std_logic;

    pi_start       : in  std_logic;
    pi_stop        : in  std_logic := '0';

    pi_strb        : in  t_AxiStrb := (others => '1');
    pi_last        : in  std_logic;
    pi_masterHS    : in  std_logic;
    pi_slaveHS     : in  std_logic;

    po_actCount    : out unsigned(g_CounterWidth-1 downto 0);
    po_mstCount    : out unsigned(g_CounterWidth-1 downto 0);
    po_sstCount    : out unsigned(g_CounterWidth-1 downto 0);
    po_idlCount    : out unsigned(g_CounterWidth-1 downto 0);
    po_bytCount    : out unsigned(g_CounterWidth-1 downto 0));
end StreamMonitorSingle;

architecture StreamMonitorSingle of StreamMonitorSingle is

  subtype t_Counter is unsigned(g_CounterWidth-1 downto 0);
  constant c_CounterZero  : t_Counter := to_unsigned(0, t_Counter'length);
  constant c_CounterOne   : t_Counter := to_unsigned(1, t_Counter'length);

  type t_State is (Stop, Armed, Transfer);
  signal s_state     : t_State;

  signal s_sstCounter    : t_Counter;
  signal s_mstCounter    : t_Counter;
  signal s_actCounter    : t_Counter;
  signal s_idlCounter    : t_Counter;
  signal s_bytCounter    : t_Counter;

begin

  po_actCount <= s_sstCounter;
  po_mstCount <= s_mstCounter;
  po_sstCount <= s_actCounter;
  po_idlCount <= s_idlCounter;
  po_bytCount <= s_bytCounter;

  process(pi_clk)
    variable v_start : boolean;
    variable v_stop : boolean;
    variable v_shs   : boolean;
    variable v_mhs   : boolean;
    variable v_lst   : boolean;
    variable v_bytes : t_Counter;
  begin
    v_start := pi_start = '1';
    v_stop  := pi_stop = '1';
    v_shs   := pi_slaveHS = '1';
    v_mhs   := pi_masterHS = '1';
    v_lst   := pi_last = '1';
    v_bytes := to_unsigned(f_bitCount(pi_strb), t_Counter'length);

    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_sstCounter <= c_CounterZero;
        s_mstCounter <= c_CounterZero;
        s_actCounter <= c_CounterZero;
        s_idlCounter <= c_CounterZero;
        s_bytCounter <= c_CounterZero;
        s_state      <= Stop;
      else
        case s_state is
          when Stop =>
            if v_start then
              s_sstCounter <= c_CounterZero;
              s_mstCounter <= c_CounterZero;
              s_actCounter <= c_CounterZero;
              s_idlCounter <= c_CounterZero;
              s_bytCounter <= c_CounterZero;
              s_state      <= Armed;
            end if;

          when Armed =>
            if v_stop then
              s_state <= Stop;
            elsif v_mhs and v_shs then
              s_actCounter <= s_actCounter + c_CounterOne;
              s_bytCounter <= s_bytCounter + v_bytes;
              if v_lst then
                s_state <= Stop;
              else
                s_state <= Transfer;
              end if;
            elsif v_shs then
              s_mstCounter <= s_mstCounter + c_CounterOne;
              s_state <= Transfer;
            elsif v_mhs then
              s_sstCounter <= s_sstCounter + c_CounterOne;
              s_state <= Transfer;
            end if;

          when Transfer =>
            if v_stop then
              s_state <= Stop;
            elsif v_mhs and v_shs then
              s_actCounter <= s_actCounter + c_CounterOne;
              s_bytCounter <= s_bytCounter + v_bytes;
              if v_lst then
                s_state <= Stop;
              end if;
            elsif v_shs then
              s_mstCounter <= s_mstCounter + c_CounterOne;
            elsif v_mhs then
              s_sstCounter <= s_sstCounter + c_CounterOne;
            else
              s_idlCounter <= s_idlCounter + c_CounterOne;
            end if;

        end case;
      end if;
    end if;
  end process;

end StreamMonitorSingle;
