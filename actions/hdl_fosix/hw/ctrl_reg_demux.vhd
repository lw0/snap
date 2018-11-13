library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;


entity CtrlRegDemux is
  generic (
    g_Ports : t_RegMap);
  port (
    pi_clk          : in std_logic;
    pi_rst_n        : in std_logic;

    pi_ctrl_ms      : in  t_ctrl_ms;
    po_ctrl_sm      : out t_ctrl_sm;

    po_ports_ms     : out t_RegPorts_ms(g_Ports'range);
    pi_ports_sm     : in  t_RegPorts_sm(g_Ports'range));
end CtrlRegDemux;

architecture CtrlRegDemux of CtrlRegDemux is

  -- AXI protocol state
  signal s_writing   : std_logic;
  signal s_reading   : std_logic;
  signal s_state     : unsigned(1 downto 0);

  -- Pre-demux operation
  signal s_regAddr   : t_RegAddr;
  signal s_regWrData : t_RegData;
  signal s_regWrStrb : t_RegStrb;
  signal s_regWrNotRd : std_logic;
  signal s_regValid  : std_logic;

  -- Post-demux result
  signal s_regRdData : t_RegData;
  signal s_regReady  : std_logic;

begin

  po_ctrl_sm.bresp <= "00"; -- write status is always OKAY, absent registers ignore writes
  po_ctrl_sm.rresp <= "00"; -- read status is always OKAY, absent registers read as zero

  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_writing <= '0';
        s_reading <= '0';
        s_regValid <= '0';
        po_ctrl_sm.awready <= '0';
        po_ctrl_sm.wready <= '0';
        po_ctrl_sm.arready <= '0';
        po_ctrl_sm.bvalid <= '0';
        po_ctrl_sm.rvalid <= '0';
        po_ctrl_sm.rdata <= (others => '0');
      else
        -- Idle:
        if s_writing = '0' and s_reading = '0' then
          if pi_ctrl_ms.awvalid = '1' and pi_ctrl_ms.wvalid = '1' then
            s_writing <= '1';
            s_regValid <= '1';
          elsif pi_ctrl_ms.arvalid = '1' then
            s_reading <= '1';
            s_regValid <= '1';
          end if;
        -- Write Transaction:
        elsif s_writing = '1' then
          if s_regValid = '1' and s_regReady = '1' then
            po_ctrl_sm.awready <= '1';
            po_ctrl_sm.wready <= '1';
            s_regValid <= '0';
            po_ctrl_sm.bvalid <= '1';
          elsif s_regValid = '0' and pi_ctrl_ms.bready = '1' then
            s_writing <= '0';
            po_ctrl_sm.bvalid <= '0';
          end if;
        -- Read Transaction:
        elsif s_reading = '1' then
          if s_regValid = '1' and s_regReady = '1' then
            po_ctrl_sm.arready <= '1';
            s_regValid <= '0';
            po_ctrl_sm.rdata <= s_regRdData;
            po_ctrl_sm.rvalid <= '1';
          elsif s_regValid = '0' and pi_ctrl_ms.rready = '1' then
            s_reading <= '0';
            po_ctrl_sm.rdata <= (others => '0');
            po_ctrl_sm.rvalid <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  s_state <= s_writing & s_reading;
  with s_state select s_regAddr <=
    pi_ctrl_ms.awaddr(C_CTRL_SPACE_W+1 downto 2) when "10",
    pi_ctrl_ms.araddr(C_CTRL_SPACE_W+1 downto 2) when "01",
    (others => '0')   when others;
  s_regWrData <= pi_ctrl_ms.wdata;
  s_regWrStrb <= pi_ctrl_ms.wstrb;
  s_regWrNotRd <= s_writing;

  -- demultiplexer
  process(s_regAddr, s_regWrData, s_regWrStrb, s_regWrNotRd, pi_ports_sm)
    variable v_port : integer range g_Ports'range;
    variable v_portRange : t_RegRange;
    variable v_guard : boolean;
    variable v_addrAbs : t_RegAddr;
    variable v_addrRel : t_RegAddr;
    variable v_portBegin : t_RegAddr;
    variable v_portCount : t_RegAddr;
    variable v_portEnd : t_RegAddr;
  begin
    v_addrAbs := s_regAddr;
    v_guard := false;
    for v_port in g_Ports'range loop
      v_portRange := g_Ports(v_port);
      v_portBegin := v_portRange(0);
      v_portCount := v_portRange(1);
      v_addrRel := v_addrAbs - v_portBegin;

      po_ports_ms(v_port).addr <= v_addrRel;
      po_ports_ms(v_port).wrdata <= s_regWrData;
      po_ports_ms(v_port).wrstrb <= s_regWrStrb;
      po_ports_ms(v_port).wrnotrd <= s_regWrNotRd;
      po_ports_ms(v_port).valid <= '0';

      if v_addrAbs >= v_portBegin and v_addrRel < v_portCount and v_guard = false then
        po_ports_ms(v_port).valid <= s_regValid;
        s_regReady <= pi_ports_sm(v_port).ready;
        s_regRdData <= pi_ports_sm(v_port).rddata;
        v_guard := true;
      end if;
    end loop;
    if v_guard = false then
      s_regReady <= '1';
      s_regRdData <= (others => '0');
    end if;
  end process;

end CtrlRegDemux;
