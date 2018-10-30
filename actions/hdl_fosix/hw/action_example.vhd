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
-- change log:
-- 12/20/2016 R. Rieke fixed case statement issue
----------------------------------------------------------------------------
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.STD_LOGIC_UNSIGNED.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.action_ctrl_types.all;

entity action_example is
  port (
    pi_clk     : in  std_logic;
    pi_rst_n   : in  std_logic;
    po_intReq  : out std_logic;
    po_intSrc  : out t_InterruptSrc;
    po_intCtx  : out t_Context;
    pi_intAck  : in  std_logic;

    -- Ports of Axi Slave Bus Interface AXI_CTRL_REG
    pi_ctrl_ms : in  t_Ctrl_ms;
    po_ctrl_sm : out t_Ctrl_sm;

    -- Ports of Axi Master Bus Interface AXI_HOST_MEM
    po_hmem_ms : out t_Axi_ms;
    pi_hmem_sm : in  t_Axi_sm;

    -- Ports of Axi Master Bus Interface AXI_CARD_MEM0
    po_cmem_ms : out t_Axi_ms;
    pi_cmem_sm : in  t_Axi_sm;

    -- Ports of Axi Master Bus Interface AXI_NVME
    po_nvme_ms : out t_Nvme_ms;
    pi_nvme_sm : in  t_Nvme_sm);
end action_example;

architecture action_example of action_example is

  -----------------------------------------------------------------------------
  -- Register Port Map Configuration
  -----------------------------------------------------------------------------
  constant c_PortCount : positive := 2;
  constant c_Ports : t_RegMap(0 to c_PortCount-1) := (
    -- Port 0: Control Registers                         (0x000 - 0x02C)
    (to_unsigned(0,   C_CTRL_SPACE_W), to_unsigned(12,  C_CTRL_SPACE_W)),
    -- Port 1: Blockmapper Registers                     (0x040 - 0x080)
    (to_unsigned(16,  C_CTRL_SPACE_W), to_unsigned(16,  C_CTRL_SPACE_W)),
  );
  -----------------------------------------------------------------------------

  signal s_ports_ms : array(c_Ports'range) of t_RegPort_ms;
  signal s_ports_sm : array(c_Ports'range) of t_RegPort_sm;
  signal s_ctrlRegs_ms : t_RegPort_ms;
  signal s_ctrlRegs_sm : t_RegPort_sm;
  signal s_bmapRegs_ms : t_RegPort_ms;
  signal s_bmapRegs_sm : t_RegPort_sm;

  signal s_hmemRd_ms : t_AxiRd_ms;
  signal s_hmemRd_sm : t_AxiRd_sm;
  signal s_hmemWr_ms : t_AxiWr_ms;
  signal s_hmemWr_sm : t_AxiWr_sm;
  signal s_cmemRd_ms : t_AxiRd_ms;
  signal s_cmemRd_sm : t_AxiRd_sm;
  signal s_cmemWr_ms : t_AxiWr_ms;
  signal s_cmemWr_sm : t_AxiWr_sm;

  signal s_context : t_Context;

  signal s_appStart : std_logic;
  signal s_appDone : std_logic;
  signal s_appReady : std_logic;
  signal s_appIdle : std_logic;

begin

  i_ctrlDemux : entity work.CtrlRegDemux
    generic map (
      g_PortCount => c_PortCount,
      g_Ports => c_Ports)
    port map ( 
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_ctrl_ms => pi_ctrl_ms,
      po_ctrl_sm => po_ctrl_sm,
      po_ports_ms => s_ports_ms,
      pi_ports_sm => s_ports_sm);
  s_ctrlRegs_ms <= s_ports_ms(0);
  s_ports_sm(0) <= s_ctrlRegs_ms;
  s_bmapRegs_ms <= s_ports_ms(1);
  s_ports_sm(1) <= s_bmapRegs_sm;

  i_actionControl : entity work.ActionControl
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      po_intReq       => po_intReq,
      po_intSrc       => po_intSrc,
      po_intCtx       => po_intCtx,
      pi_intAck       => pi_intAck,
      pi_ctrlRegs_ms  => s_ctrlRegs_ms,
      po_ctrlRegs_sm  => s_ctrlRegs_sm,
      pi_type         => x"1014_0000",
      pi_version      => x"0000_0000",
      po_context      => s_context,
      po_start        => s_appStart,
      pi_done         => s_appDone,
      pi_ready        => s_appReady,
      pi_idle         => s_appIdle,
      pi_userInt1Req  => s_bmapIntReq,
      po_userInt1Ack  => s_bmapIntAck);

  i_hmemReader : entity work.AxiReader
    port map ();

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
  i_hmemWriter : entity work.AxiWriter
    port map ();

  i_cmemReader : entity work.AxiReader
    port map ();

  i_cmemWriter : entity work.AxiWriter
    port map ();


    process(pi_clk) is
    begin
      if (rising_edge (pi_clk)) then
            start_copy          <= '0';
            start_nvme_copy     <= '0';                                               -- only for NVME_USED=TRUE
            start_fill          <= '0';
            if reg_0x30(3 downto 0) = x"2" or reg_0x30(3 downto 0) = x"3" or
               reg_0x30(3 downto 0) = x"4" or reg_0x30(3 downto 0) = x"5"   then
              memcopy <= true;
            else
              memcopy <= false;
            end if;
        if ( pi_rst_n = '0' ) then
              fsm_app_q         <= IDLE;
              s_appReady         <= '0';
              s_appIdle          <= '0';
            else
              s_appDone          <= '0';
              s_appIdle          <= '0';
              s_appReady         <= '1';
              case fsm_app_q is
                when IDLE  =>
                  s_appIdle <= '1';

                  if s_appStart = '1' then
                    src_nvme  <= '0';                                                    -- only for NVME_USED=TRUE
                    src_ddr   <= '0';                                                    -- only for DDRI_USED=TRUE
                    src_host  <= '0';
                    dest_nvme <= '0';                                                    -- only for NVME_USED=TRUE
                    dest_ddr  <= '0';                                                    -- only for DDRI_USED=TRUE
                    dest_host <= '0';
                    case reg_0x30(3 downto 0) is

                      when x"1" =>
                        -- just count a counter down
                        fsm_app_q  <= JUST_COUNT_DOWN;
                        counter_q  <= reg_0x44;

                       when x"2" =>
                        -- memcopy host to host memory
                        fsm_app_q  <= WAIT_FOR_MEMCOPY_DONE;
                        src_host   <= '1';
                        dest_host  <= '1';
                        start_copy <= '1';


                       when x"8" =>
                        -- host memory fill
                        fsm_app_q  <= WAIT_FOR_MEMCOPY_DONE;
                        dest_host  <= '1';
                        start_fill <= '1';

                       when x"9" =>                                                      -- only for DDRI_USED=TRUE
                        -- DDR memory fill                                               -- only for DDRI_USED=TRUE
                        fsm_app_q  <= WAIT_FOR_MEMCOPY_DONE;                             -- only for DDRI_USED=TRUE
                        dest_ddr   <= '1';                                               -- only for DDRI_USED=TRUE
                        start_fill <= '1';                                               -- only for DDRI_USED=TRUE

                       when x"3" =>                                                      -- only for DDRI_USED=TRUE
                        -- memcopy host to DDR memory                                    -- only for DDRI_USED=TRUE
                        fsm_app_q  <= WAIT_FOR_MEMCOPY_DONE;                             -- only for DDRI_USED=TRUE
                        src_host   <= '1';                                               -- only for DDRI_USED=TRUE
                        dest_ddr   <= '1';                                               -- only for DDRI_USED=TRUE
                        start_copy <= '1';                                               -- only for DDRI_USED=TRUE

                       when x"4" =>                                                      -- only for DDRI_USED=TRUE
                        -- memcopy DDR to host memory                                    -- only for DDRI_USED=TRUE
                        fsm_app_q  <= WAIT_FOR_MEMCOPY_DONE;                             -- only for DDRI_USED=TRUE
                        src_ddr    <= '1';                                               -- only for DDRI_USED=TRUE
                        dest_host  <= '1';                                               -- only for DDRI_USED=TRUE
                        start_copy <= '1';                                               -- only for DDRI_USED=TRUE

                       when x"5" =>                                                      -- only for DDRI_USED=TRUE
                        -- memcopy DDR to DDR memory                                     -- only for DDRI_USED=TRUE
                        fsm_app_q  <= WAIT_FOR_MEMCOPY_DONE;                             -- only for DDRI_USED=TRUE
                        src_ddr    <= '1';                                               -- only for DDRI_USED=TRUE
                        dest_ddr   <= '1';                                               -- only for DDRI_USED=TRUE
                        start_copy <= '1';                                               -- only for DDRI_USED=TRUE
                        
                       when x"a" =>                                                      -- only for NVME_USED=TRUE
                        -- memcopy DDR to NVMe                                           -- only for NVME_USED=TRUE
                        fsm_app_q       <= WAIT_FOR_MEMCOPY_DONE;                        -- only for NVME_USED=TRUE
                        src_ddr         <= '1';                                          -- only for NVME_USED=TRUE
                        dest_nvme       <= '1';                                          -- only for NVME_USED=TRUE
                        start_nvme_copy <= '1';                                          -- only for NVME_USED=TRUE
                        
                       when x"b" =>                                                      -- only for NVME_USED=TRUE
                        -- memcopy NVMe to DDR                                           -- only for NVME_USED=TRUE
                        fsm_app_q       <= WAIT_FOR_MEMCOPY_DONE;                        -- only for NVME_USED=TRUE
                        src_nvme        <= '1';                                          -- only for NVME_USED=TRUE
                        dest_ddr        <= '1';                                          -- only for NVME_USED=TRUE
                        start_nvme_copy <= '1';                                          -- only for NVME_USED=TRUE

                       when others =>
                         s_appDone   <= '1';

                    end case;
                  end if ;

                when  JUST_COUNT_DOWN =>
                  if counter_q > x"0000_0001" then
                    counter_q <= counter_q - '1';
                  else
                    s_appDone   <= '1';
                    fsm_app_q  <= IDLE;
                  end if;

                when WAIT_FOR_MEMCOPY_DONE =>
                  if last_write_done = '1' 
                     or nvme_copy_done = '1'  -- only for NVME_USED=TRUE              
                  then
                    s_appDone   <= '1';
                    fsm_app_q  <= IDLE;
                  end if;


                when others => null;
              end case;
        end if;
      end if;
    end process;

  rd_req_ack <= dma_rd_req_ack
                when src_host  = '1' else ddr_rd_req_ack                                 -- only for DDRI_USED=TRUE
                ;
  wr_req_ack <= dma_wr_req_ack
                when dest_host = '1' else ddr_wr_req_ack                                 -- only for DDRI_USED=TRUE
                ;

-- NVME copy process
    nvme_lba_addr         <= reg_0x38 & reg_0x34 when src_nvme  = '1' else reg_0x40 & reg_0x3c;               -- only for NVME_USED=TRUE 
    nvme_mem_addr        <= (reg_0x38 + 2) & reg_0x34 when dest_nvme = '1' else (reg_0x40 + 2) & reg_0x3c;    -- only for NVME_USED=TRUE 
    nvme_cmd(11 downto 8) <= reg_0x30(11 downto 8);  -- action id                                             -- only for NVME_USED=TRUE 
    nvme_cmd( 3 downto 0) <= x"1" when reg_0x30(3 downto 0) = x"a"  else x"0"; -- a one is a read cmd         -- only for NVME_USED=TRUE 
    nvme_cmd( 7 downto 4) <= x"1" when reg_0x30(4)          = '0'   else x"3"; -- a one is SSD 0              -- only for NVME_USED=TRUE 
    nvme_lba_count        <= reg_0x44 - 1;                                                                    -- only for NVME_USED=TRUE 
                                                                                                              -- only for NVME_USED=TRUE 
    process(pi_clk) is                                                                                    -- only for NVME_USED=TRUE 
                                                                                                              -- only for NVME_USED=TRUE 
    begin                                                                                                     -- only for NVME_USED=TRUE 
       if (rising_edge (pi_clk)) then                                                                     -- only for NVME_USED=TRUE 
         nvme_copy_done <= '0';                                                                               -- only for NVME_USED=TRUE 
         nvme_cmd_valid <= '0';                                                                               -- only for NVME_USED=TRUE 
         if start_nvme_copy = '1' then                                                                        -- only for NVME_USED=TRUE 
           nvme_cmd_valid <= '1';                                                                             -- only for NVME_USED=TRUE 
         end if;                                                                                              -- only for NVME_USED=TRUE 
         if nvme_status(8) = '1'  then                                                                        -- only for NVME_USED=TRUE 
           nvme_copy_done <= '1';                                                                             -- only for NVME_USED=TRUE 
         end if;                                                                                              -- only for NVME_USED=TRUE 
       end if;                                                                                                -- only for NVME_USED=TRUE 
    end process;                                                                                              -- only for NVME_USED=TRUE 
-------------------------------------------------------------------------------

       
    process(pi_clk) is
    variable j,k : integer range 0 to 63;
    begin
       if (rising_edge (pi_clk)) then
          j := to_integer(unsigned(reg_0x34(5 downto 0)));
          for x in 0 to 63 loop
            if x >= j then
              first_write_mask(x) <= '1';
            else
              first_write_mask(x) <= '0';
            end if;
          end loop;  -- x
          k := to_integer(unsigned(reg_0x3c(5 downto 0)));
          for x in 0 to 63 loop
            if x > k then
              last_write_mask(x) <= '0';
            else
              last_write_mask(x) <= '1';
            end if;
          end loop;  -- x
       end if;
    end process;


    block_diff <= "000000" & ((reg_0x40 & reg_0x3c(31 downto 6)) - (reg_0x38 & reg_0x34(31 downto 6)));

    process(pi_clk ) is
     variable temp64 : std_logic_vector(63 downto 0);
    begin
      if (rising_edge (pi_clk)) then
        last_write_done   <= '0';
        mem_wr            <= '0';                                                        -- only for DDRI_USED=TRUE
        if ( pi_rst_n = '0' ) then
              fsm_copy_q         <= IDLE;
              dma_rd_req         <= '0';
              dma_wr_req         <= '0';
              dma_wr_bready      <= '0';
              ddr_rd_req         <= '0';                                                 -- only for DDRI_USED=TRUE
              ddr_wr_req         <= '0';                                                 -- only for DDRI_USED=TRUE
              ddr_wr_bready      <= '0';                                                 -- only for DDRI_USED=TRUE
              wr_gate            <= '0';
            else
              case fsm_copy_q is
                when IDLE =>
                  wr_req_count     <= 0;
                  wr_done_count    <= 0;
                  wr_gate          <= '0';
                  blocks_to_read   <= "000000"   & reg_0x44(31 downto 6);
                  if memcopy then
                    -- memcopy
                    blocks_to_write  <= "000000"   & reg_0x44(31 downto 6);
                    blocks_expected  <= "000000"   & reg_0x44(31 downto 6);
                    first_max_blk_w    <= x"0000_00" & (x"40" - reg_0x3c(11 downto 6));
                  else
                    -- memfill
                    blocks_to_write  <= block_diff(31 downto 0) + 1;
                    blocks_expected  <= block_diff(31 downto 0) + 1;
                    first_max_blk_w    <= x"0000_00" & (x"40" - reg_0x34(11 downto 6));
                  end if;
                  first_max_blk_r    <= x"0000_00" & (x"40" - reg_0x34(11 downto 6));

                  if first_max_blk_r < blocks_to_read then
                    first_blk_r      <= first_max_blk_r;
                  else
                    first_blk_r      <= blocks_to_read;
                  end if;
                  if first_max_blk_w < blocks_to_write then
                    first_blk_w      <= first_max_blk_w;
                  else
                    first_blk_w      <= blocks_to_write ;
                  end if;
                  rd_addr            <= reg_0x38 & reg_0x34(31 downto 6) & "000000";
                  if memcopy then
                    wr_addr          <= reg_0x40 & reg_0x3c(31 downto 6) & "000000";
                  else
                    wr_addr          <= reg_0x38 & reg_0x34(31 downto 6) & "000000";
                  end if;

                  rd_requests_done <= '0';
                  wr_requests_done <= '0';
                  rd_len          <= first_blk_r (7 downto 0) - '1';
                  wr_len          <= first_blk_w (7 downto 0) - '1';

                  rd_addr_adder   <= x"1000" - (reg_0x34(11 downto 6) & (5 downto 0 =>'0'));

                  if start_copy = '1' then
                    wr_addr_adder   <= x"1000" - (reg_0x3c(11 downto 6) & (5 downto 0 =>'0'));
                    blocks_to_read  <= blocks_to_read  -first_blk_r (7 downto 0) ;
                    blocks_to_write <= blocks_to_write -first_blk_w (7 downto 0) ;
                    -- request data either from host or
                    dma_rd_req    <= src_host;
                    ddr_rd_req    <= src_ddr;                                            -- only for DDRI_USED=TRUE
                    dma_wr_req    <= dest_host;
                    dma_wr_bready <= dest_host;
                    ddr_wr_req    <= dest_ddr;                                           -- only for DDRI_USED=TRUE
                    ddr_wr_bready <= dest_ddr;                                           -- only for DDRI_USED=TRUE
                    wr_gate       <= '1';
                    fsm_copy_q    <= PROCESS_COPY;
                  end if;
                  if start_fill = '1' then
                    wr_addr_adder   <= x"1000" - (reg_0x34(11 downto 6) & (5 downto 0 =>'0'));
                    wr_gate         <= '1';
                    blocks_to_write <= blocks_to_write -first_blk_w (7 downto 0) ;
                    dma_wr_req      <= dest_host;
                    dma_wr_bready   <= dest_host;
                    ddr_wr_req      <= dest_ddr;                                         -- only for DDRI_USED=TRUE
                    ddr_wr_bready   <= dest_ddr;                                         -- only for DDRI_USED=TRUE
                    fsm_copy_q      <= PROCESS_FILL;
                  end if;

                when PROCESS_FILL =>
                  if wr_req_ack = '1' and or_reduce(blocks_to_write) = '1' then
                    wr_addr         <= wr_addr + wr_addr_adder;
                    wr_addr_adder   <= x"1000";
                    dma_wr_req      <= dest_host;
                    ddr_wr_req      <= dest_ddr;                                         -- only for DDRI_USED=TRUE
                    if blocks_to_write >  x"0000_0040" then
                      wr_len     <= x"3f";
                      blocks_to_write <= blocks_to_write - x"40";
                    else
                      wr_len         <= blocks_to_write(7 downto 0) - '1';
                      blocks_to_write <= (others => '0');
                    end if;
                  end if;
                  if wr_req_ack = '1' and or_reduce(blocks_to_write) = '0' then
                    dma_wr_req       <= '0';
                    ddr_wr_req       <= '0';                                             -- only for DDRI_USED=TRUE
                    wr_requests_done <= '1';
                    fsm_copy_q       <= WAIT_FOR_WRITE_DONE;
                  end if;


                when PROCESS_COPY =>

                  if rd_req_ack = '1' and or_reduce(blocks_to_read) = '1' then
                    rd_addr          <= rd_addr + rd_addr_adder;
                    rd_addr_adder    <= x"1000";
                    dma_rd_req       <= src_host;
                    ddr_rd_req       <= src_ddr;                                         -- only for DDRI_USED=TRUE
                    if blocks_to_read >  x"0000_0040" then
                      rd_len         <= x"3f";
                      blocks_to_read <= blocks_to_read - x"40";
                    else
                      rd_len         <= blocks_to_read(7 downto 0) - '1';
                      blocks_to_read <= (others => '0');
                    end if;
                  end if;
                  if rd_req_ack = '1' and or_reduce(blocks_to_read) = '0' then
                    dma_rd_req       <= '0';
                    ddr_rd_req       <= '0';                                             -- only for DDRI_USED=TRUE
                    rd_requests_done <= '1';
                  end if;

                  if wr_req_ack = '1' and or_reduce(blocks_to_write) = '1' then
                    wr_addr         <= wr_addr + wr_addr_adder;
                    wr_addr_adder   <= x"1000";
                    dma_wr_req      <= dest_host;
                    ddr_wr_req      <= dest_ddr;                                         -- only for DDRI_USED=TRUE
                    if blocks_to_write >  x"0000_0040" then
                      wr_len     <= x"3f";
                      blocks_to_write <= blocks_to_write - x"40";
                    else
                      wr_len         <= blocks_to_write(7 downto 0) - '1';
                      blocks_to_write <= (others => '0');
                    end if;
                  end if;
                  if wr_req_ack = '1' and or_reduce(blocks_to_write) = '0' then
                    dma_wr_req       <= '0';
                    ddr_wr_req       <= '0';                                             -- only for DDRI_USED=TRUE
                    wr_requests_done <= '1';
                  end if;
                  if rd_requests_done = '1' and wr_requests_done = '1' then
                    fsm_copy_q      <= WAIT_FOR_WRITE_DONE;
                  end if;

                 when WAIT_FOR_WRITE_DONE =>
                   if or_reduce(write_counter_dn) = '0' and wr_req_count = wr_done_count then
                     last_write_done <= '1';
                     fsm_copy_q      <= IDLE;
                     ddr_wr_bready   <= '0';                                             -- only for DDRI_USED=TRUE
                     dma_wr_bready   <= '0';
                   end if;

               end case;
               if (dma_wr_done = '1' and dest_host = '1')
                  or (ddr_wr_done = '1' and dest_ddr = '1')                              -- only for DDRI_USED=TRUE
               then
                 wr_done_count <= wr_done_count + 1;
               end if;
               if (dma_wr_req = '1' and dma_wr_req_ack = '1' and dest_host = '1')
                  or (ddr_wr_req = '1' and ddr_wr_req_ack = '1' and dest_ddr  = '1')     -- only for DDRI_USED=TRUE
               then
                 wr_req_count <= wr_req_count + 1;
               end if;
            end if;
          end if;




        end process;
    -- User logic ends

  rd_data_taken <= '1' when (head = 0 and reg0_valid = '0') or
                            (head = 1 and reg1_valid = '0') or
                            (head = 2 and reg2_valid = '0')     else '0';
  dma_rd_data_taken <= rd_data_taken and src_host;
  ddr_rd_data_taken <= rd_data_taken and src_ddr;                                        -- only for DDRI_USED=TRUE

read_write_process:
      process(pi_clk ) is
    begin
      if (rising_edge (pi_clk)) then
            if start_copy = '1' or pi_rst_n = '0' or start_fill = '1' then

              tail              <= 0;
              head              <= 0;
              reg0_valid        <= '0';
              reg0_data         <= dma_rd_data;   -- assigning reset value in order to get around 'partial antenna' problems
              reg1_valid        <= '0';
              reg1_data         <= dma_rd_data;   -- assigning reset value in order to get around 'partial antenna' problems
              reg2_valid        <= '0';
              reg2_data         <= dma_rd_data;   -- assigning reset value in order to get around 'partial antenna' problems
              total_write_count <=(31 downto 1 => '0') & '1';
              if memcopy then
                write_counter_up  <=(31 downto 0 => '0' ) + reg_0x3c(11 downto 6) + 1;
              else
                write_counter_up  <=(31 downto 0 => '0' ) + reg_0x34(11 downto 6) + 1;
              end if;

              write_counter_dn  <= blocks_to_write(25 downto 0);
              last_write_q      <= '0';
              first_write_q     <= '1';
            else
              if dest_ddr = '1' THEN                                                                                                -- only for DDRI_USED=TRUE
                last_write_q      <= (last_write and ddr_wr_ready and ( dma_wr_data_valid or  ddr_wr_data_valid)) or last_write_q;  -- only for DDRI_USED=TRUE
              ELSE                                                                                                                  -- only for DDRI_USED=TRUE
               last_write_q      <= (last_write and dma_wr_ready and ( dma_wr_data_valid or  ddr_wr_data_valid)) or last_write_q;   -- only for DDRI_USED=TRUE
              end if;                                                                                                               -- only for DDRI_USED=TRUE
              if head = 0 and reg0_valid = '0' then
                if src_host = '1' then
                  if dma_rd_data_valid = '1' then
                    reg0_data  <= dma_rd_data;
                    reg0_valid <= '1';
                    head       <= 1;
                  end if;
                end if;
                if src_ddr = '1' then                                                    -- only for DDRI_USED=TRUE
                  if ddr_rd_data_valid = '1' then                                        -- only for DDRI_USED=TRUE
                    reg0_data  <= ddr_rd_data;                                           -- only for DDRI_USED=TRUE
                    reg0_valid <= '1';                                                   -- only for DDRI_USED=TRUE
                    head       <= 1;                                                     -- only for DDRI_USED=TRUE
                  end if;                                                                -- only for DDRI_USED=TRUE
                end if;                                                                  -- only for DDRI_USED=TRUE
              end if;
              if head = 1 and reg1_valid = '0' then
                if src_host = '1' then
                   if dma_rd_data_valid = '1' then
                     reg1_data  <= dma_rd_data;
                     reg1_valid <= '1';
                     head            <= 2;
                   end if;
                end if;
                if src_ddr = '1' then                                                    -- only for DDRI_USED=TRUE
                  if ddr_rd_data_valid = '1' then                                        -- only for DDRI_USED=TRUE
                    reg1_data  <= ddr_rd_data;                                           -- only for DDRI_USED=TRUE
                    reg1_valid <= '1';                                                   -- only for DDRI_USED=TRUE
                    head       <= 2;                                                     -- only for DDRI_USED=TRUE
                  end if;                                                                -- only for DDRI_USED=TRUE
                end if;                                                                  -- only for DDRI_USED=TRUE
              end if;

              if head = 2 and reg2_valid = '0' then
                if src_host = '1' then
                   if dma_rd_data_valid = '1' then
                     reg2_data  <= dma_rd_data;
                     reg2_valid <= '1';
                     head       <= 0;
                   end if;
                end if;
                if src_ddr = '1' then                                                    -- only for DDRI_USED=TRUE
                  if ddr_rd_data_valid = '1' then                                        -- only for DDRI_USED=TRUE
                    reg2_data  <= ddr_rd_data;                                           -- only for DDRI_USED=TRUE
                    reg2_valid <= '1';                                                   -- only for DDRI_USED=TRUE
                    head       <= 0;                                                     -- only for DDRI_USED=TRUE
                  end if;                                                                -- only for DDRI_USED=TRUE
                end if;                                                                  -- only for DDRI_USED=TRUE
              end if;
            end if;
            if (dma_wr_data_valid = '1' and dma_wr_ready = '1' and dest_host = '1')
               or (ddr_wr_data_valid = '1' and ddr_wr_ready = '1' and dest_ddr  = '1')   -- only for DDRI_USED=TRUE
            then
              first_write_q <= '0';
              total_write_count <= total_write_count + '1';
              write_counter_up  <= write_counter_up  + '1';
              write_counter_dn  <= write_counter_dn  - '1';
              if tail = 0 then
                tail <= 1;
                reg0_valid <= '0';
              end if;
              if tail = 1 then
                tail <= 2;
                reg1_valid <= '0';
              end if;
              if tail = 2 then
                tail <= 0;
                reg2_valid <= '0';
              end if;
            end if;

          end if;                       -- rising edge
        end process;

write_data_process:
  process(reg0_data, reg1_data, reg2_data, reg0_valid, reg1_valid, reg2_valid,
          write_counter_up, total_write_count, reg_0x44, reg_0x30, last_write_q,
          dest_ddr,                                                                      -- only for DDRI_USED=TRUE
          dest_host, tail, blocks_expected,wr_gate, memcopy  ) is
    begin
      case tail is
      -- mem copy
        when 0 =>
          wr_data           <= reg0_data;
          dma_wr_data_valid <= reg0_valid and dest_host;
          ddr_wr_data_valid <= reg0_valid and dest_ddr;                                  -- only for DDRI_USED=TRUE
        when 1 =>
          wr_data           <= reg1_data;
          dma_wr_data_valid <= reg1_valid and dest_host;
          ddr_wr_data_valid <= reg1_valid and dest_ddr;                                  -- only for DDRI_USED=TRUE
        when others =>
          wr_data           <= reg2_data;
          dma_wr_data_valid <= reg2_valid and dest_host;
          ddr_wr_data_valid <= reg2_valid and dest_ddr;                                  -- only for DDRI_USED=TRUE
      end case;
      if not memcopy then
      --  mem fill
        for i in 1 to 64 loop
          if reg_0x30(23 downto 16) = x"00" then
            wr_data(i * 8 -1 downto (i-1) *8) <= reg_0x30(15 downto 8);
          else
            wr_data(i * 8 -1 downto (i-1) *8) <= std_logic_vector(to_unsigned(i-1, 8));
          end if;
        end loop;  -- i
        dma_wr_data_valid <= not last_write_q and dest_host and wr_gate;
        ddr_wr_data_valid <= not last_write_q and dest_ddr  and wr_gate;                 -- only for DDRI_USED=TRUE
      end if;

      if total_write_count = blocks_expected or
          or_reduce(write_counter_up(5 downto 0)) = '0'                 then
        dma_wr_data_last <= '1' and dest_host;
        ddr_wr_data_last <= '1' and dest_ddr;                                            -- only for DDRI_USED=TRUE
      else
        dma_wr_data_last <= '0';
        ddr_wr_data_last <= '0';                                                         -- only for DDRI_USED=TRUE
      end if;
      if total_write_count >= blocks_expected then
        last_write <= '1';
      else
        last_write <= '0';
      end if;
    end process;

wr_strobes: process(dma_wr_data_valid, memcopy,
                    ddr_wr_data_valid,                                                   -- only for DDRI_USED=TRUE
                    last_write, first_write_q, last_write_mask,first_write_mask  )
  begin
    dma_wr_data_strobe <= (63 downto 0 => '0');
    if dma_wr_data_valid = '1' then
      dma_wr_data_strobe <= (63 downto 0 => '1');
      if last_write = '1' and first_write_q = '0' then
        dma_wr_data_strobe <= last_write_mask;
      end if;
      if last_write = '0' and first_write_q = '1' then
        dma_wr_data_strobe <= first_write_mask;
      end if;
      if last_write = '1' and first_write_q = '1' then
        dma_wr_data_strobe <= first_write_mask and last_write_mask;
      end if;
      if memcopy  then
        dma_wr_data_strobe <= (63 downto 0 => '1');
      end if;
    end if;

    ddr_wr_data_strobe <= (63 downto 0 => '0');                          -- only for DDRI_USED=TRUE
    if ddr_wr_data_valid = '1' then                                      -- only for DDRI_USED=TRUE
      ddr_wr_data_strobe <= (63 downto 0 => '1');                        -- only for DDRI_USED=TRUE
      if last_write = '1' and first_write_q = '0' then                   -- only for DDRI_USED=TRUE
        ddr_wr_data_strobe <= last_write_mask;                           -- only for DDRI_USED=TRUE
      end if;                                                            -- only for DDRI_USED=TRUE
      if last_write = '0' and first_write_q = '1' then                   -- only for DDRI_USED=TRUE
        ddr_wr_data_strobe <= first_write_mask;                          -- only for DDRI_USED=TRUE
      end if;                                                            -- only for DDRI_USED=TRUE
      if last_write = '1' and first_write_q = '1' then                   -- only for DDRI_USED=TRUE
        ddr_wr_data_strobe <= first_write_mask and last_write_mask;      -- only for DDRI_USED=TRUE
      end if;                                                            -- only for DDRI_USED=TRUE
      if memcopy  THEN                                                   -- only for DDRI_USED=TRUE
        ddr_wr_data_strobe <= (63 downto 0 => '1');                      -- only for DDRI_USED=TRUE
      end if;                                                            -- only for DDRI_USED=TRUE
    end if;                                                              -- only for DDRI_USED=TRUE

  end process;





end action_example;
