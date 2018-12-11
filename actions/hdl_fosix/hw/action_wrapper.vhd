----------------------------------------------------------------------------
----------------------------------------------------------------------------
--
-- Copyright 2016,2017 International Business Machines
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHout WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions AND
-- limitations under the License.
--
----------------------------------------------------------------------------
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.psl_accel_types.all;
use work.action_types.all;
use work.fosix_types.all;


entity action_wrapper is
  port (
    ap_clk                     : in std_logic;
    ap_rst_n                   : in std_logic;
    interrupt                  : out std_logic;
    interrupt_src              : out std_logic_vector(INT_BITS-2 downto 0);
    interrupt_ctx              : out std_logic_vector(CONTEXT_BITS-1 downto 0);
    interrupt_ack              : in std_logic;
    --                                                                                                 -- only for DDRI_USED=TRUE
    -- AXI SDRAM Interface                                                                             -- only for DDRI_USED=TRUE
    m_axi_card_mem0_araddr     : out std_logic_vector ( C_M_AXI_CARD_MEM0_ADDR_WIDTH-1 downto 0 );     -- only for DDRI_USED=TRUE
    m_axi_card_mem0_arburst    : out std_logic_vector ( 1 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_arcache    : out std_logic_vector ( 3 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_arid       : out std_logic_vector ( C_M_AXI_CARD_MEM0_ID_WIDTH-1 downto 0 );       -- only for DDRI_USED=TRUE
    m_axi_card_mem0_arlen      : out std_logic_vector ( 7 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_arlock     : out std_logic_vector ( 1 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_arprot     : out std_logic_vector ( 2 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_arqos      : out std_logic_vector ( 3 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_arready    : in  std_logic;                                                        -- only for DDRI_USED=TRUE
    m_axi_card_mem0_arregion   : out std_logic_vector ( 3 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_arsize     : out std_logic_vector ( 2 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_aruser     : out std_logic_vector ( C_M_AXI_CARD_MEM0_ARUSER_WIDTH-1 downto 0 );   -- only for DDRI_USED=TRUE
    m_axi_card_mem0_arvalid    : out std_logic;                                                        -- only for DDRI_USED=TRUE
    m_axi_card_mem0_awaddr     : out std_logic_vector ( C_M_AXI_CARD_MEM0_ADDR_WIDTH-1 downto 0 );     -- only for DDRI_USED=TRUE
    m_axi_card_mem0_awburst    : out std_logic_vector ( 1 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_awcache    : out std_logic_vector ( 3 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_awid       : out std_logic_vector ( C_M_AXI_CARD_MEM0_ID_WIDTH-1 downto 0 );       -- only for DDRI_USED=TRUE
    m_axi_card_mem0_awlen      : out std_logic_vector ( 7 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_awlock     : out std_logic_vector ( 1 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_awprot     : out std_logic_vector ( 2 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_awqos      : out std_logic_vector ( 3 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_awready    : in  std_logic;                                                        -- only for DDRI_USED=TRUE
    m_axi_card_mem0_awregion   : out std_logic_vector ( 3 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_awsize     : out std_logic_vector ( 2 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_awuser     : out std_logic_vector ( C_M_AXI_CARD_MEM0_AWUSER_WIDTH-1 downto 0 );   -- only for DDRI_USED=TRUE
    m_axi_card_mem0_awvalid    : out std_logic;                                                        -- only for DDRI_USED=TRUE
    m_axi_card_mem0_bid        : in  std_logic_vector ( C_M_AXI_CARD_MEM0_ID_WIDTH-1 downto 0 );       -- only for DDRI_USED=TRUE
    m_axi_card_mem0_bready     : out std_logic;                                                        -- only for DDRI_USED=TRUE
    m_axi_card_mem0_bresp      : in  std_logic_vector ( 1 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_buser      : in  std_logic_vector ( C_M_AXI_CARD_MEM0_BUSER_WIDTH-1 downto 0 );    -- only for DDRI_USED=TRUE
    m_axi_card_mem0_bvalid     : in  std_logic;                                                        -- only for DDRI_USED=TRUE
    m_axi_card_mem0_rdata      : in  std_logic_vector ( C_M_AXI_CARD_MEM0_DATA_WIDTH-1 downto 0 );     -- only for DDRI_USED=TRUE
    m_axi_card_mem0_rid        : in  std_logic_vector ( C_M_AXI_CARD_MEM0_ID_WIDTH-1 downto 0 );       -- only for DDRI_USED=TRUE
    m_axi_card_mem0_rlast      : in  std_logic;                                                        -- only for DDRI_USED=TRUE
    m_axi_card_mem0_rready     : out std_logic;                                                        -- only for DDRI_USED=TRUE
    m_axi_card_mem0_rresp      : in  std_logic_vector ( 1 downto 0 );                                  -- only for DDRI_USED=TRUE
    m_axi_card_mem0_ruser      : in  std_logic_vector ( C_M_AXI_CARD_MEM0_RUSER_WIDTH-1 downto 0 );    -- only for DDRI_USED=TRUE
    m_axi_card_mem0_rvalid     : in  std_logic;                                                        -- only for DDRI_USED=TRUE
    m_axi_card_mem0_wdata      : out std_logic_vector ( C_M_AXI_CARD_MEM0_DATA_WIDTH-1 downto 0 );     -- only for DDRI_USED=TRUE
    m_axi_card_mem0_wlast      : out std_logic;                                                        -- only for DDRI_USED=TRUE
    m_axi_card_mem0_wready     : in  std_logic;                                                        -- only for DDRI_USED=TRUE
    m_axi_card_mem0_wstrb      : out std_logic_vector ( (C_M_AXI_CARD_MEM0_DATA_WIDTH/8)-1 downto 0 ); -- only for DDRI_USED=TRUE
    m_axi_card_mem0_wuser      : out std_logic_vector ( C_M_AXI_CARD_MEM0_WUSER_WIDTH-1 downto 0 );    -- only for DDRI_USED=TRUE
    m_axi_card_mem0_wvalid     : out std_logic;                                                        -- only for DDRI_USED=TRUE
    --
    -- AXI Control Register Interface
    s_axi_ctrl_reg_araddr      : in  std_logic_vector ( C_S_AXI_CTRL_REG_ADDR_WIDTH-1 downto 0 );
    s_axi_ctrl_reg_arready     : out std_logic;
    s_axi_ctrl_reg_arvalid     : in  std_logic;
    s_axi_ctrl_reg_awaddr      : in  std_logic_vector ( C_S_AXI_CTRL_REG_ADDR_WIDTH-1 downto 0 );
    s_axi_ctrl_reg_awready     : out std_logic;
    s_axi_ctrl_reg_awvalid     : in  std_logic;
    s_axi_ctrl_reg_bready      : in  std_logic;
    s_axi_ctrl_reg_bresp       : out std_logic_vector ( 1 downto 0 );
    s_axi_ctrl_reg_bvalid      : out std_logic;
    s_axi_ctrl_reg_rdata       : out std_logic_vector ( C_S_AXI_CTRL_REG_DATA_WIDTH-1 downto 0 );
    s_axi_ctrl_reg_rready      : in  std_logic;
    s_axi_ctrl_reg_rresp       : out std_logic_vector ( 1 downto 0 );
    s_axi_ctrl_reg_rvalid      : out std_logic;
    s_axi_ctrl_reg_wdata       : in  std_logic_vector ( C_S_AXI_CTRL_REG_DATA_WIDTH-1 downto 0 );
    s_axi_ctrl_reg_wready      : out std_logic;
    s_axi_ctrl_reg_wstrb       : in  std_logic_vector ( (C_S_AXI_CTRL_REG_DATA_WIDTH/8)-1 downto 0 );
    s_axi_ctrl_reg_wvalid      : in  std_logic;
    --
    -- AXI Host Memory Interface
    m_axi_host_mem_araddr      : out std_logic_vector ( C_M_AXI_HOST_MEM_ADDR_WIDTH-1 downto 0 );
    m_axi_host_mem_arburst     : out std_logic_vector ( 1 downto 0 );
    m_axi_host_mem_arcache     : out std_logic_vector ( 3 downto 0 );
    m_axi_host_mem_arid        : out std_logic_vector ( C_M_AXI_HOST_MEM_ID_WIDTH-1 downto 0 );
    m_axi_host_mem_arlen       : out std_logic_vector ( 7 downto 0 );
    m_axi_host_mem_arlock      : out std_logic_vector ( 1 downto 0 );
    m_axi_host_mem_arprot      : out std_logic_vector ( 2 downto 0 );
    m_axi_host_mem_arqos       : out std_logic_vector ( 3 downto 0 );
    m_axi_host_mem_arready     : in  std_logic;
    m_axi_host_mem_arregion    : out std_logic_vector ( 3 downto 0 );
    m_axi_host_mem_arsize      : out std_logic_vector ( 2 downto 0 );
    m_axi_host_mem_aruser      : out std_logic_vector ( C_M_AXI_HOST_MEM_ARUSER_WIDTH-1 downto 0 );
    m_axi_host_mem_arvalid     : out std_logic;
    m_axi_host_mem_awaddr      : out std_logic_vector ( C_M_AXI_HOST_MEM_ADDR_WIDTH-1 downto 0 );
    m_axi_host_mem_awburst     : out std_logic_vector ( 1 downto 0 );
    m_axi_host_mem_awcache     : out std_logic_vector ( 3 downto 0 );
    m_axi_host_mem_awid        : out std_logic_vector ( C_M_AXI_HOST_MEM_ID_WIDTH-1 downto 0 );
    m_axi_host_mem_awlen       : out std_logic_vector ( 7 downto 0 );
    m_axi_host_mem_awlock      : out std_logic_vector ( 1 downto 0 );
    m_axi_host_mem_awprot      : out std_logic_vector ( 2 downto 0 );
    m_axi_host_mem_awqos       : out std_logic_vector ( 3 downto 0 );
    m_axi_host_mem_awready     : in  std_logic;
    m_axi_host_mem_awregion    : out std_logic_vector ( 3 downto 0 );
    m_axi_host_mem_awsize      : out std_logic_vector ( 2 downto 0 );
    m_axi_host_mem_awuser      : out std_logic_vector ( C_M_AXI_HOST_MEM_AWUSER_WIDTH-1 downto 0 );
    m_axi_host_mem_awvalid     : out std_logic;
    m_axi_host_mem_bid         : in  std_logic_vector ( C_M_AXI_HOST_MEM_ID_WIDTH-1 downto 0 );
    m_axi_host_mem_bready      : out std_logic;
    m_axi_host_mem_bresp       : in  std_logic_vector ( 1 downto 0 );
    m_axi_host_mem_buser       : in  std_logic_vector ( C_M_AXI_HOST_MEM_BUSER_WIDTH-1 downto 0 );
    m_axi_host_mem_bvalid      : in  std_logic;
    m_axi_host_mem_rdata       : in  std_logic_vector ( C_M_AXI_HOST_MEM_DATA_WIDTH-1 downto 0 );
    m_axi_host_mem_rid         : in  std_logic_vector ( C_M_AXI_HOST_MEM_ID_WIDTH-1 downto 0 );
    m_axi_host_mem_rlast       : in  std_logic;
    m_axi_host_mem_rready      : out std_logic;
    m_axi_host_mem_rresp       : in  std_logic_vector ( 1 downto 0 );
    m_axi_host_mem_ruser       : in  std_logic_vector ( C_M_AXI_HOST_MEM_RUSER_WIDTH-1 downto 0 );
    m_axi_host_mem_rvalid      : in  std_logic;
    m_axi_host_mem_wdata       : out std_logic_vector ( C_M_AXI_HOST_MEM_DATA_WIDTH-1 downto 0 );
    m_axi_host_mem_wlast       : out std_logic;
    m_axi_host_mem_wready      : in  std_logic;
    m_axi_host_mem_wstrb       : out std_logic_vector ( (C_M_AXI_HOST_MEM_DATA_WIDTH/8)-1 downto 0 );
    m_axi_host_mem_wuser       : out std_logic_vector ( C_M_AXI_HOST_MEM_WUSER_WIDTH-1 downto 0 );
    m_axi_host_mem_wvalid      : out std_logic
  );
end action_wrapper;

architecture structure of action_wrapper is

  signal s_intSrc  : t_InterruptSrc;
  signal s_context  : t_Context;
  signal s_ctrl_ms : t_Ctrl_ms;
  signal s_ctrl_sm : t_Ctrl_sm;
  signal s_hmem_ms : t_Axi_ms;
  signal s_hmem_sm : t_Axi_sm;
  signal s_cmem_ms : t_Axi_ms;
  signal s_cmem_sm : t_Axi_sm;
  signal s_nvme_ms : t_Nvme_ms;
  signal s_nvme_sm : t_Nvme_sm;

begin

  i_action: entity work.Action
    port map (
      pi_clk     => ap_clk,
      pi_rst_n   => ap_rst_n,
      po_intReq  => interrupt,
      po_intSrc  => s_intSrc,
      pi_intAck  => interrupt_ack,
      po_context => s_context,
      pi_ctrl_ms => s_ctrl_ms,
      po_ctrl_sm => s_ctrl_sm,
      po_hmem_ms => s_hmem_ms,
      pi_hmem_sm => s_hmem_sm,
      po_cmem_ms => s_cmem_ms,
      pi_cmem_sm => s_cmem_sm,
      po_nvme_ms => s_nvme_ms,
      pi_nvme_sm => s_nvme_sm);

  interrupt_src <= std_logic_vector(s_intSrc);
  interrupt_ctx <= std_logic_vector(s_context);

  s_axi_ctrl_reg_awready   <=                  s_ctrl_sm.awready;
  s_axi_ctrl_reg_wready    <=                  s_ctrl_sm.wready;
  s_axi_ctrl_reg_bresp     <=                  s_ctrl_sm.bresp;
  s_axi_ctrl_reg_bvalid    <=                  s_ctrl_sm.bvalid;
  s_axi_ctrl_reg_arready   <=                  s_ctrl_sm.arready;
  s_axi_ctrl_reg_rdata     <= std_logic_vector(s_ctrl_sm.rdata);
  s_axi_ctrl_reg_rresp     <=                  s_ctrl_sm.rresp;
  s_axi_ctrl_reg_rvalid    <=                  s_ctrl_sm.rvalid;
  s_ctrl_ms.awaddr         <= t_CtrlAddr      (s_axi_ctrl_reg_awaddr);
  s_ctrl_ms.awvalid        <=                  s_axi_ctrl_reg_awvalid;
  s_ctrl_ms.wdata          <= t_CtrlData      (s_axi_ctrl_reg_wdata);
  s_ctrl_ms.wstrb          <= t_CtrlStrb      (s_axi_ctrl_reg_wstrb);
  s_ctrl_ms.wvalid         <=                  s_axi_ctrl_reg_wvalid;
  s_ctrl_ms.bready         <=                  s_axi_ctrl_reg_bready;
  s_ctrl_ms.araddr         <= t_CtrlAddr      (s_axi_ctrl_reg_araddr);
  s_ctrl_ms.arvalid        <=                  s_axi_ctrl_reg_arvalid;
  s_ctrl_ms.rready         <=                  s_axi_ctrl_reg_rready;

  m_axi_host_mem_awid      <=                 (others => '0');
  m_axi_host_mem_awaddr    <= std_logic_vector(s_hmem_ms.awaddr(C_HMEM_ADDR_W-1 downto 0));
  m_axi_host_mem_awlen     <= std_logic_vector(s_hmem_ms.awlen);
  m_axi_host_mem_awsize    <= std_logic_vector(s_hmem_ms.awsize);
  m_axi_host_mem_awburst   <= std_logic_vector(s_hmem_ms.awburst);
  m_axi_host_mem_awlock    <= std_logic_vector(c_AxiDefLock);
  m_axi_host_mem_awcache   <= std_logic_vector(c_AxiDefCache);
  m_axi_host_mem_awprot    <= std_logic_vector(c_AxiDefProt);
  m_axi_host_mem_awqos     <= std_logic_vector(c_AxiDefQos);
  m_axi_host_mem_awregion  <= std_logic_vector(c_AxiDefRegion);
  m_axi_host_mem_awuser    <= std_logic_vector(s_context);
  m_axi_host_mem_awvalid   <=                  s_hmem_ms.awvalid;
  m_axi_host_mem_wdata     <= std_logic_vector(s_hmem_ms.wdata);
  m_axi_host_mem_wstrb     <= std_logic_vector(s_hmem_ms.wstrb);
  m_axi_host_mem_wlast     <=                  s_hmem_ms.wlast;
  m_axi_host_mem_wuser     <=                 (others => '0');
  m_axi_host_mem_wvalid    <=                  s_hmem_ms.wvalid;
  m_axi_host_mem_bready    <=                  s_hmem_ms.bready;
  m_axi_host_mem_arid      <=                 (others => '0');
  m_axi_host_mem_araddr    <= std_logic_vector(s_hmem_ms.araddr(C_HMEM_ADDR_W-1 downto 0));
  m_axi_host_mem_arlen     <= std_logic_vector(s_hmem_ms.arlen);
  m_axi_host_mem_arsize    <= std_logic_vector(s_hmem_ms.arsize);
  m_axi_host_mem_arburst   <= std_logic_vector(s_hmem_ms.arburst);
  m_axi_host_mem_arlock    <= std_logic_vector(c_AxiDefLock);
  m_axi_host_mem_arcache   <= std_logic_vector(c_AxiDefCache);
  m_axi_host_mem_arprot    <= std_logic_vector(c_AxiDefProt);
  m_axi_host_mem_arqos     <= std_logic_vector(c_AxiDefQos);
  m_axi_host_mem_arregion  <= std_logic_vector(c_AxiDefRegion);
  m_axi_host_mem_aruser    <= std_logic_vector(s_context);
  m_axi_host_mem_arvalid   <=                  s_hmem_ms.arvalid;
  m_axi_host_mem_rready    <=                  s_hmem_ms.rready;
  s_hmem_sm.awready        <=                  m_axi_host_mem_awready;
  s_hmem_sm.wready         <=                  m_axi_host_mem_wready;
  -- s_hmem_sm.bid         <=                  m_axi_host_mem_bid;
  s_hmem_sm.bresp          <= t_AxiResp       (m_axi_host_mem_bresp);
  -- s_hmem_sm.buser       <=                  m_axi_host_mem_buser;
  s_hmem_sm.bvalid         <=                  m_axi_host_mem_bvalid;
  s_hmem_sm.arready        <=                  m_axi_host_mem_arready;
  -- s_hmem_sm.rid         <=                  m_axi_host_mem_rid;
  s_hmem_sm.rdata          <= t_HmemData      (m_axi_host_mem_rdata);
  s_hmem_sm.rresp          <= t_AxiResp       (m_axi_host_mem_rresp);
  s_hmem_sm.rlast          <=                  m_axi_host_mem_rlast;
  -- s_hmem_sm.ruser       <=                  m_axi_host_mem_ruser;
  s_hmem_sm.rvalid         <=                  m_axi_host_mem_rvalid;

  m_axi_card_mem0_awid     <=                 (others => '0');          -- only for DDRI_USED=TRUE
  m_axi_card_mem0_awaddr   <= std_logic_vector(s_cmem_ms.awaddr(C_CMEM_ADDR_W-1 downto 0)); -- only for DDRI_USED=TRUE
  m_axi_card_mem0_awlen    <= std_logic_vector(s_cmem_ms.awlen);        -- only for DDRI_USED=TRUE
  m_axi_card_mem0_awsize   <= std_logic_vector(s_cmem_ms.awsize);       -- only for DDRI_USED=TRUE
  m_axi_card_mem0_awburst  <= std_logic_vector(s_cmem_ms.awburst);      -- only for DDRI_USED=TRUE
  m_axi_card_mem0_awlock   <= std_logic_vector(c_AxiDefLock);           -- only for DDRI_USED=TRUE
  m_axi_card_mem0_awcache  <= std_logic_vector(c_AxiDefCache);          -- only for DDRI_USED=TRUE
  m_axi_card_mem0_awprot   <= std_logic_vector(c_AxiDefProt);           -- only for DDRI_USED=TRUE
  m_axi_card_mem0_awqos    <= std_logic_vector(c_AxiDefQos);            -- only for DDRI_USED=TRUE
  m_axi_card_mem0_awregion <= std_logic_vector(c_AxiDefRegion);         -- only for DDRI_USED=TRUE
  m_axi_card_mem0_awuser   <=                 (others => '0');          -- only for DDRI_USED=TRUE
  m_axi_card_mem0_awvalid  <=                  s_cmem_ms.awvalid;       -- only for DDRI_USED=TRUE
  m_axi_card_mem0_wdata    <= std_logic_vector(s_cmem_ms.wdata);        -- only for DDRI_USED=TRUE
  m_axi_card_mem0_wstrb    <= std_logic_vector(s_cmem_ms.wstrb);        -- only for DDRI_USED=TRUE
  m_axi_card_mem0_wlast    <=                  s_cmem_ms.wlast;         -- only for DDRI_USED=TRUE
  m_axi_card_mem0_wuser    <=                 (others => '0');          -- only for DDRI_USED=TRUE
  m_axi_card_mem0_wvalid   <=                  s_cmem_ms.wvalid;        -- only for DDRI_USED=TRUE
  m_axi_card_mem0_bready   <=                  s_cmem_ms.bready;        -- only for DDRI_USED=TRUE
  m_axi_card_mem0_arid     <=                 (others => '0');          -- only for DDRI_USED=TRUE
  m_axi_card_mem0_araddr   <= std_logic_vector(s_cmem_ms.araddr(C_CMEM_ADDR_W-1 downto 0)); -- only for DDRI_USED=TRUE
  m_axi_card_mem0_arlen    <= std_logic_vector(s_cmem_ms.arlen);        -- only for DDRI_USED=TRUE
  m_axi_card_mem0_arsize   <= std_logic_vector(s_cmem_ms.arsize);       -- only for DDRI_USED=TRUE
  m_axi_card_mem0_arburst  <= std_logic_vector(s_cmem_ms.arburst);      -- only for DDRI_USED=TRUE
  m_axi_card_mem0_arlock   <= std_logic_vector(c_AxiDefLock);           -- only for DDRI_USED=TRUE
  m_axi_card_mem0_arcache  <= std_logic_vector(c_AxiDefCache);          -- only for DDRI_USED=TRUE
  m_axi_card_mem0_arprot   <= std_logic_vector(c_AxiDefProt);           -- only for DDRI_USED=TRUE
  m_axi_card_mem0_arqos    <= std_logic_vector(c_AxiDefQos);            -- only for DDRI_USED=TRUE
  m_axi_card_mem0_arregion <= std_logic_vector(c_AxiDefRegion);         -- only for DDRI_USED=TRUE
  m_axi_card_mem0_aruser   <=                 (others => '0');          -- only for DDRI_USED=TRUE
  m_axi_card_mem0_arvalid  <=                  s_cmem_ms.arvalid;       -- only for DDRI_USED=TRUE
  m_axi_card_mem0_rready   <=                  s_cmem_ms.rready;        -- only for DDRI_USED=TRUE
  s_cmem_sm.awready        <=                  m_axi_card_mem0_awready; -- only for DDRI_USED=TRUE
  s_cmem_sm.wready         <=                  m_axi_card_mem0_wready;  -- only for DDRI_USED=TRUE
  -- s_cmem_sm.bid         <=                  m_axi_card_mem0_bid;     -- only for DDRI_USED=TRUE
  s_cmem_sm.bresp          <= t_AxiResp       (m_axi_card_mem0_bresp);  -- only for DDRI_USED=TRUE
  -- s_cmem_sm.buser       <=                  m_axi_card_mem0_buser;   -- only for DDRI_USED=TRUE
  s_cmem_sm.bvalid         <=                  m_axi_card_mem0_bvalid;  -- only for DDRI_USED=TRUE
  s_cmem_sm.arready        <=                  m_axi_card_mem0_arready; -- only for DDRI_USED=TRUE
  -- s_cmem_sm.rid         <=                  m_axi_card_mem0_rid;     -- only for DDRI_USED=TRUE
  s_cmem_sm.rdata          <= t_CmemData      (m_axi_card_mem0_rdata);  -- only for DDRI_USED=TRUE
  s_cmem_sm.rresp          <= t_AxiResp       (m_axi_card_mem0_rresp);  -- only for DDRI_USED=TRUE
  s_cmem_sm.rlast          <=                  m_axi_card_mem0_rlast;   -- only for DDRI_USED=TRUE
  -- s_cmem_sm.ruser       <=                  m_axi_card_mem0_ruser;   -- only for DDRI_USED=TRUE
  s_cmem_sm.rvalid         <=                  m_axi_card_mem0_rvalid;  -- only for DDRI_USED=TRUE



  s_nvme_sm <= c_NvmeNull_sm;                      -- only for NVME_USED!=TRUE

END STRUCTURE;
