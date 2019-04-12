library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_ctrl.all;
use work.fosix_util.all;


entity RegisterFile is
  generic (
    g_RegCount    : natural);
  port (
    pi_clk        : in  std_logic;
    pi_rst_n      : in  std_logic;

    pi_regs_ms    : in  t_RegPort_ms;
    po_regs_sm    : out t_RegPort_sm;

    pi_regRd      : in  t_RegData_v (g_RegCount-1 downto 0);
    po_regWr      : out t_RegData_v (g_RegCount-1 downto 0);

    po_eventRdAny : out std_logic;
    po_eventWrAny : out std_logic;
    po_eventRd    : out unsigned (g_RegCount-1 downto 0);
    po_eventWr    : out unsigned (g_RegCount-1 downto 0));
end RegisterFile;

architecture RegisterFile of RegisterFile is

  signal so_regs_sm_ready : std_logic;
  signal so_regWr         : t_RegData_v (g_RegCount-1 downto 0);

begin

  po_regs_sm.ready <= so_regs_sm_ready;
  po_regWr <= so_regWr;
  process (pi_clk)
    variable v_portAddr : integer range 0 to 2**pi_regs_ms.addr'length-1;
  begin
    if pi_clk'event and pi_clk = '1' then
      v_portAddr := to_integer(pi_regs_ms.addr);
      po_eventRdAny <= '0';
      po_eventWrAny <= '0';
      po_eventRd    <= (others => '0');
      po_eventWr    <= (others => '0');

      if pi_rst_n = '0' then
        po_regs_sm.rddata <= (others => '0');
        so_regs_sm_ready <= '0';
        po_regWr <= (others => (others => '0'));
      else
        if pi_regs_ms.valid = '1' and so_regs_sm_ready = '0' then
          so_regs_sm_ready <= '1';
          if v_portAddr < g_RegCount then
            po_regs_sm.rddata <= pi_regRd(v_portAddr);
            if pi_regs_ms.wrnotrd = '1' then
              po_regWr(v_portAddr) <= f_byteMux(pi_regs_ms.wrstrb, po_regWr(v_portAddr), pi_regs_ms.wrdata);
              po_eventWr(v_portAddr) <= '1';
              po_eventWrAny <= '1';
            else
              po_eventRd(v_portAddr) <= '1';
              po_eventRdAny <= '1';
            end if;
          else
            po_regs_sm.rddata <= (others => '0');
          end if;
        else
          so_regs_sm_ready <= '0';
        end if;
      end if;
    end if;
  end process;

end RegisterFile;
