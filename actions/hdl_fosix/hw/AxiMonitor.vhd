library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity AxiMonitor is
  port (
    pi_clk          : in std_logic;
    pi_rst_n        : in std_logic;

    -- Config register port (24 Registers):
    -- AxiMonitor
    --   Write to any register resets all counters
    --  Reg00: [RC] Lower Half of Read Transaction Count (arvalid and arready) cycles
    --  Reg01: [RC] Upper Half of Read Transaction Count (arvalid and arready) cycles
    --  Reg02: [RC] Lower Half of Read Latency from (arvalid and arready) cycle to first (rvalid) cycle
    --  Reg03: [RC] Upper Half of Read Latency from (arvalid and arready) cycle to first (rvalid) cycle
    --  Reg04: [RC] Lower Half of Read Slave Stalls (not rvalid and rready) cycles
    --  Reg05: [RC] Upper Half of Read Slave Stalls (not rvalid and rready) cycles
    --  Reg06: [RC] Lower Half of Read Master Stalls (rvalid and not rready) cycles
    --  Reg07: [RC] Upper Half of Read Master Stalls (rvalid and not rready) cycles
    --  Reg08: [RC] Lower Half of Read Active (rvalid and rready) cycles
    --  Reg09: [RC] Upper Half of Read Active (rvalid and rready) cycles
    --  Reg10: [RC] Lower Half of Read Idle (not rvalid and not rready) cycles
    --  Reg11: [RC] Upper Half of Read Idle (not rvalid and not rready) cycles
    --  Reg12: [RC] Lower Half of Write Transaction Count (arvalid and arready) cycles
    --  Reg13: [RC] Upper Half of Write Transaction Count (arvalid and arready) cycles
    --  Reg14: [RC] Lower Half of Write Latency from (awvalid and awready) cycle to first (wready) cycle
    --  Reg15: [RC] Upper Half of Write Latency from (awvalid and awready) cycle to first (wready) cycle
    --  Reg16: [RC] Lower Half of Write Slave Stalls (wvalid and not wready) cycles
    --  Reg17: [RC] Upper Half of Write Slave Stalls (wvalid and not wready) cycles
    --  Reg18: [RC] Lower Half of Write Master Stalls (not wvalid and wready) cycles
    --  Reg19: [RC] Upper Half of Write Master Stalls (not wvalid and wready) cycles
    --  Reg20: [RC] Lower Half of Write Active (wvalid and wready) cycles
    --  Reg21: [RC] Upper Half of Write Active (wvalid and wready) cycles
    --  Reg22: [RC] Lower Half of Write Idle (not wvalid and not wready) cycles
    --  Reg23: [RC] Upper Half of Write Idle (not wvalid and not wready) cycles
    pi_regs_ms : in  t_RegPort_ms;
    po_regs_sm : out t_RegPort_sm;

    pi_axi_ms  : in  t_Axi_ms;
    pi_axi_sm  : in  t_Axi_sm);
end AxiMonitor;

architecture AxiMonitor of AxiMonitor is

  type t_AxiState is (Idle, Initiated, Running);
  signal s_readState      : t_AxiState;
  signal s_writeState     : t_AxiState;
  signal s_reset          : std_logic;

  constant c_CounterWidth : integer := 48;
  constant c_CounterZero  : unsigned(c_CounterWidth-1 downto 0) :=
                              to_unsigned(0, c_CounterWidth);
  constant c_CounterOne   : unsigned(c_CounterWidth-1 downto 0) :=
                              to_unsigned(1, c_CounterWidth);
  signal s_rtrnCounter    : unsigned(c_CounterWidth-1 downto 0);
  signal s_rlatCounter    : unsigned(c_CounterWidth-1 downto 0);
  signal s_rsstCounter    : unsigned(c_CounterWidth-1 downto 0);
  signal s_rmstCounter    : unsigned(c_CounterWidth-1 downto 0);
  signal s_ractCounter    : unsigned(c_CounterWidth-1 downto 0);
  signal s_ridlCounter    : unsigned(c_CounterWidth-1 downto 0);
  signal s_wtrnCounter    : unsigned(c_CounterWidth-1 downto 0);
  signal s_wlatCounter    : unsigned(c_CounterWidth-1 downto 0);
  signal s_wsstCounter    : unsigned(c_CounterWidth-1 downto 0);
  signal s_wmstCounter    : unsigned(c_CounterWidth-1 downto 0);
  signal s_wactCounter    : unsigned(c_CounterWidth-1 downto 0);
  signal s_widlCounter    : unsigned(c_CounterWidth-1 downto 0);

  -- Control Registers
  signal s_portReady      : std_logic;
  signal s_portValid      : std_logic;
  signal s_portWrNotRd    : std_logic;
  signal s_portWrData     : t_RegData;
  signal s_portWrStrb     : t_RegStrb;
  signal s_portRdData     : t_RegData;
  signal s_portAddr       : t_RegAddr;

begin

  -----------------------------------------------------------------------------
  -- Monitor Counters
  -----------------------------------------------------------------------------
  process(pi_clk)
    variable v_arvld : boolean;
    variable v_arrdy : boolean;
    variable v_rlst  : boolean;
    variable v_rvld  : boolean;
    variable v_rrdy  : boolean;
    variable v_awvld : boolean;
    variable v_awrdy : boolean;
    variable v_wlst  : boolean;
    variable v_wvld  : boolean;
    variable v_wrdy  : boolean;
  begin
    v_arvld := pi_axi_ms.arvalid = '1';
    v_arrdy := pi_axi_sm.arready = '1';
    v_rlst  := pi_axi_sm.rlast = '1';
    v_rvld  := pi_axi_sm.rvalid = '1';
    v_rrdy  := pi_axi_ms.rready = '1';
    v_awvld := pi_axi_ms.awvalid = '1';
    v_awrdy := pi_axi_sm.awready = '1';
    v_wlst  := pi_axi_ms.wlast = '1';
    v_wvld  := pi_axi_ms.wvalid = '1';
    v_wrdy  := pi_axi_sm.wready = '1';
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' or s_reset = '1' then
        s_readState   <= Idle;
        s_writeState  <= Idle;
        s_rtrnCounter <= c_CounterZero;
        s_rlatCounter <= c_CounterZero;
        s_rsstCounter <= c_CounterZero;
        s_rmstCounter <= c_CounterZero;
        s_ractCounter <= c_CounterZero;
        s_ridlCounter <= c_CounterZero;
        s_wtrnCounter <= c_CounterZero;
        s_wlatCounter <= c_CounterZero;
        s_wsstCounter <= c_CounterZero;
        s_wmstCounter <= c_CounterZero;
        s_wactCounter <= c_CounterZero;
        s_widlCounter <= c_CounterZero;
      else
        case s_readState is
          when Idle =>
            if v_arvld and v_arrdy then
              s_rtrnCounter <= s_rtrnCounter + c_CounterOne;
              if v_rvld then
                if v_rrdy then
                  s_ractCounter <= s_ractCounter + c_CounterOne;
                else
                  s_rmstCounter <= s_rmstCounter + c_CounterOne;
                end if;
                s_readState <= Running;
              else
                s_readState <= Initiated;
              end if;
            end if;

          when Initiated =>
            s_rlatCounter <= s_rlatCounter + c_CounterOne;
            if v_rvld then
              s_readState <= Running;
              if v_rrdy then
                s_ractCounter <= s_ractCounter + c_CounterOne;
                if v_rlst then
                  s_readState <= Idle;
                end if;
              else
                s_rmstCounter <= s_rmstCounter + c_CounterOne;
              end if;
            end if;

          when Running =>
            if v_rvld and v_rrdy then
              s_ractCounter <= s_ractCounter + c_CounterOne;
              if v_rlst then
                s_readState <= Idle;
              end if;
            elsif v_rvld then
              s_rmstCounter <= s_rmstCounter + c_CounterOne;
            elsif v_rrdy then
              s_rsstCounter <= s_rsstCounter + c_CounterOne;
            else
              s_ridlCounter <= s_ridlCounter + c_CounterOne;
            end if;
        end case;

        case s_writeState is
          when Idle =>
            if v_awvld and v_awrdy then
              s_wtrnCounter <= s_wtrnCounter + c_CounterOne;
              if v_wrdy then
                if v_wvld then
                  s_wactCounter <= s_wactCounter + c_CounterOne;
                else
                  s_wmstCounter <= s_wmstCounter + c_CounterOne;
                end if;
                s_writeState <= Running;
              else
                s_writeState <= Initiated;
              end if;
            end if;

          when Initiated =>
            s_wlatCounter <= s_wlatCounter + c_CounterOne;
            if v_wrdy then
              s_writeState <= Running;
              if v_wvld then
                s_wactCounter <= s_wactCounter + c_CounterOne;
                if v_rlst then
                  s_writeState <= Idle;
                end if;
              else
                s_wmstCounter <= s_wmstCounter + c_CounterOne;
              end if;
            end if;

          when Running =>
            if v_wvld and v_wrdy then
              s_wactCounter <= s_wactCounter + c_CounterOne;
              if v_wlst then
                s_writeState <= Idle;
              end if;
            elsif v_wvld then
              s_wsstCounter <= s_wsstCounter + c_CounterOne;
            elsif v_wrdy then
              s_wmstCounter <= s_wmstCounter + c_CounterOne;
            else
              s_widlCounter <= s_widlCounter + c_CounterOne;
            end if;
        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Register Interface
  -----------------------------------------------------------------------------
  s_portAddr <= pi_regs_ms.addr;
  s_portWrData <= pi_regs_ms.wrdata;
  s_portWrStrb <= pi_regs_ms.wrstrb;
  s_portWrNotRd <= pi_regs_ms.wrnotrd;
  s_portValid <= pi_regs_ms.valid;
  po_regs_sm.rddata <= s_portRdData;
  po_regs_sm.ready <= s_portReady;
  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_reset <= '0';
        s_portRdData <= (others => '0');
        s_portReady <= '0';
      else
        s_reset <= '0';
        if s_portValid = '1' and s_portReady = '0' then
          s_portReady <= '1';
          s_reset <= s_portWrNotRd;
          case s_portAddr is
            when to_unsigned(0, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_rtrnCounter, C_CTRL_DATA_W, 0);
            when to_unsigned(1, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_rtrnCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
            when to_unsigned(2, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_rlatCounter, C_CTRL_DATA_W, 0);
            when to_unsigned(3, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_rlatCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
            when to_unsigned(4, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_rsstCounter, C_CTRL_DATA_W, 0);
            when to_unsigned(5, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_rsstCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
            when to_unsigned(6, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_rmstCounter, C_CTRL_DATA_W, 0);
            when to_unsigned(7, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_rmstCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
            when to_unsigned(8, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_ractCounter, C_CTRL_DATA_W, 0);
            when to_unsigned(9, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_ractCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
            when to_unsigned(10, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_ridlCounter, C_CTRL_DATA_W, 0);
            when to_unsigned(11, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_ridlCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
            when to_unsigned(12, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_wtrnCounter, C_CTRL_DATA_W, 0);
            when to_unsigned(13, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_wtrnCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
            when to_unsigned(14, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_wlatCounter, C_CTRL_DATA_W, 0);
            when to_unsigned(15, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_wlatCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
            when to_unsigned(16, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_wsstCounter, C_CTRL_DATA_W, 0);
            when to_unsigned(17, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_wsstCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
            when to_unsigned(18, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_wmstCounter, C_CTRL_DATA_W, 0);
            when to_unsigned(19, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_wmstCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
            when to_unsigned(20, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_wactCounter, C_CTRL_DATA_W, 0);
            when to_unsigned(21, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_wactCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
            when to_unsigned(22, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_widlCounter, C_CTRL_DATA_W, 0);
            when to_unsigned(23, C_CTRL_SPACE_W) =>
              s_portRdData <= f_resize(s_widlCounter, C_CTRL_DATA_W, C_CTRL_DATA_W);
            when others =>
              s_portRdData <= (others => '0');
          end case;
        else
          s_portReady <= '0';
        end if;
      end if;
    end if;
  end process;

end AxiMonitor;
