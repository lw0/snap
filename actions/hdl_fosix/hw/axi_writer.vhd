----------------------------------------------------------------------------
----------------------------------------------------------------------------
--
-- Copyright 2016 International Business Machines
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions AND
-- limitations under the License.
--
----------------------------------------------------------------------------
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity HmemWriter is
	port (
    pi_clk     : in  std_logic;
    pi_rst_n   : in  std_logic;

    -- start&ready start operation
    pi_start   : in  std_logic;
    po_ready   : out std_logic;
    -- done signals that ready will be asserted in next cycle
    po_done    : out std_logic;
    -- context id used for Hmem accesses, sampled at start&ready cycle
    pi_context : in  t_Context;

    -- 4 registers (begin lo; begin hi; block count; burst attrib)
    pi_regs_ms : in  t_RegPort_ms;
    po_regs_sm : out t_RegPort_sm;

    po_hmem_ms : out t_HmemWr_ms;
    pi_hmem_sm : in  t_HmemWr_sm;

    pi_stream_ms : in  t_NativeStream_ms;
    po_stream_sm : out t_NativeStream_sm);
end HmemWriter;

architecture HmemWriter of HmemWriter is


  type t_State is (Idle);
  signal s_state : t_State;

  signal s_context : t_Context;
  signal s_address : unsigned(C_HMEM_ADDR_W-C_HMEM_WOFF_W-1 downto 0);
  alias  a_pageOffset : s_address(11 downto 6);
  signal s_count   : t_RegData;
  signal s_maxLen : unsigned(5 downto 0); -- maximum burst length - 1 (range 1 to 64)


  constant c_AddrRegALo : t_RegAddr := to_unsigned(0, C_CTRL_SPACE_W);
  constant c_AddrRegAHi : t_RegAddr := to_unsigned(1, C_CTRL_SPACE_W);
  constant c_AddrRegCnt : t_RegAddr := to_unsigned(2, C_CTRL_SPACE_W);
  constant c_AddrRegBst : t_RegAddr := to_unsigned(3, C_CTRL_SPACE_W);

  signal s_regALo : t_RegData;
  signal s_regAHi : t_RegData;
  signal s_regCnt : t_RegData;
  signal s_regBst : t_RegData;

begin

  po_hmem_ms.awuser  <= s_context;

  -- Fixed Bus Signals
  po_hmem_ms.awid     <= (others => '0');
  po_hmem_ms.awsize   <= c_HmemSize;
  po_hmem_ms.awburst  <= c_AxiBurstIncr;
  po_hmem_ms.awlock   <= c_AxiLockNormal;
  po_hmem_ms.awcache  <= c_HmemCache;
  po_hmem_ms.awprot   <= c_HmemProt;
  po_hmem_ms.awqos    <= c_HmemQos;
  po_hmem_ms.awregion <= c_HmemRegion;
  po_hmem_ms.wuser    <= (others => '0');


  -----------------------------------------------------------------------------
  -- Main State Machine
  -----------------------------------------------------------------------------
  with s_state select po_ready <=
    '1' when Idle,
    '0' when others;
  with s_state select po_stream_sm.tready <=
    '1' when WaitSFirst,
    '0' when others;

  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_state <= Idle;
        s_context <= (others => '0');
      else
        case s_state is
          when Idle =>
            if pi_start = '1' then
              s_state <= StartBurst;
              s_context <= pi_context;
              s_address <= (s_regAHi & s_regALo)(C_HMEM_ADDR_W-1 downto C_HMEM_WOFF_W);
              s_count <= s_regCnt;
              s_maxLen <= s_regBst(5 downto 0);

              tready <= '1';
            end if;
          when WaitSStart =>
            if pi_stream_ms.tvalid = '1' then
              s_state <= WaitAW;
              axi_data <= pi_stream_ms.tdata;
              axi_strb <= pi_stream_ms.tstrb;
              axi_wvalid <= '1';
              axi_len <= min(s_count, s_maxLen, not a_pageOffset + 1);
              axi_addr <= s_address & "000000";
              axi_awvalid <= '1';
              tready <= '0';
              -- s_address <= s_address + axi_len;
              -- s_count <= s_count - axi_len;
            end if;
          when WaitAWStart =>
            if awready = '1' and wready = '1' then
              s_state <= WaitSNext;
              awvalid <= '0';
              wvalid <= '0';
              tready <= '1';
            elsif awready = '1' then
              s_state <= WaitWStart;
              awvalid <= '0';
            elsif wready = '1' then
              s_state <= WaitASStart;
              wvalid <= '0';
              tready <= '1';
            end if;
          when WaitWStart =>
            if wready = '1' then
              s_state <= WaitSNext;
              tready <= '1';
            end if;
          when WaitASStart =>
            if awready = '1' then
              s_state <= WaitSNext;
              tready <= '1';
            end if;
            -- TODO-lw WIP
        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Register Access
  -----------------------------------------------------------------------------
  po_regs_sm.ready <= '1';
  process (pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_regAdrLo <= (others => '0');
        s_regAdrHi <= (others => '0');
        s_regCount <= (others => '0');
        s_regBurst <= (others => '0');
        po_regs_sm.rddata <= (others => '0');
      else
        if pi_regs_ms.valid = '1' then
          case pi_regs_ms.addr is
            when c_AddrRegALo =>
              po_regs_sm.rddata <= s_regALo;
              if pi_regs_ms.wrnotrd = '1' then
                s_regALo <= f_byteMux(pi_regs_ms.wrstrb, s_regALo, pi_regs_ms.wrdata);
              end if;
            when c_AddrRegAHi =>
              po_regs_sm.rddata <= s_regAHi;
              if pi_regs_ms.wrnotrd = '1' then
                s_regAHi <= f_byteMux(pi_regs_ms.wrstrb, s_regAHi, pi_regs_ms.wrdata);
              end if;
            when c_AddrRegCnt =>
              po_regs_sm.rddata <= s_regCnt;
              if pi_regs_ms.wrnotrd = '1' then
                s_regCnt <= f_byteMux(pi_regs_ms.wrstrb, s_regCnt, pi_regs_ms.wrdata);
              end if;
            when c_AddrRegBst =>
              po_regs_sm.rddata <= s_regBst;
              if pi_regs_ms.wrnotrd = '1' then
                s_regBst <= f_byteMux(pi_regs_ms.wrstrb, s_regBst, pi_regs_ms.wrdata);
              end if;
            when others =>
              po_regs_sm.rddata <= (others => '0');
          end case;
        end if;
      end if;
    end if;
  end process;

end HmemWriter;
