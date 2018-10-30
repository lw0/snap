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


entity HmemReader is
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

    po_hmem_ms : out t_HmemRd_ms;
    pi_hmem_sm : in  t_HmemRd_sm;

    po_stream_ms : out t_NativeStream_ms;
    pi_stream_sm : in  t_NativeStream_sm);
end HmemReader;

architecture HmemReader of HmemReader is

  constant c_AddrRegALo : t_RegAddr := to_unsigned(0, C_CTRL_SPACE_W);
  constant c_AddrRegAHi : t_RegAddr := to_unsigned(1, C_CTRL_SPACE_W);
  constant c_AddrRegCnt : t_RegAddr := to_unsigned(2, C_CTRL_SPACE_W);
  constant c_AddrRegBst : t_RegAddr := to_unsigned(3, C_CTRL_SPACE_W);

  signal s_regALo : t_RegData;
  signal s_regAHi : t_RegData;
  signal s_regCnt : t_RegData;
  signal s_regBst : t_RegData;

begin

  -- TODO-lw implement Read Burst Logic

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

end HmemReader;
