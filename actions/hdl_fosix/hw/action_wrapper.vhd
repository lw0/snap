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

    -- AXI SDRAM Interface
    m_axi_card_mem0_araddr     : out std_logic_vector ( C_M_AXI_CARD_MEM0_ADDR_WIDTH-1 downto 0 );
    m_axi_card_mem0_arburst    : out std_logic_vector ( 1 downto 0 );
    m_axi_card_mem0_arcache    : out std_logic_vector ( 3 downto 0 );
    m_axi_card_mem0_arid       : out std_logic_vector ( C_M_AXI_CARD_MEM0_ID_WIDTH-1 downto 0 );
    m_axi_card_mem0_arlen      : out std_logic_vector ( 7 downto 0 );
    m_axi_card_mem0_arlock     : out std_logic_vector ( 1 downto 0 );
    m_axi_card_mem0_arprot     : out std_logic_vector ( 2 downto 0 );
    m_axi_card_mem0_arqos      : out std_logic_vector ( 3 downto 0 );
    m_axi_card_mem0_arready    : in  std_logic;
    m_axi_card_mem0_arregion   : out std_logic_vector ( 3 downto 0 );
    m_axi_card_mem0_arsize     : out std_logic_vector ( 2 downto 0 );
    m_axi_card_mem0_aruser     : out std_logic_vector ( C_M_AXI_CARD_MEM0_ARUSER_WIDTH-1 downto 0 );
    m_axi_card_mem0_arvalid    : out std_logic;
    m_axi_card_mem0_awaddr     : out std_logic_vector ( C_M_AXI_CARD_MEM0_ADDR_WIDTH-1 downto 0 );
    m_axi_card_mem0_awburst    : out std_logic_vector ( 1 downto 0 );
    m_axi_card_mem0_awcache    : out std_logic_vector ( 3 downto 0 );
    m_axi_card_mem0_awid       : out std_logic_vector ( C_M_AXI_CARD_MEM0_ID_WIDTH-1 downto 0 );
    m_axi_card_mem0_awlen      : out std_logic_vector ( 7 downto 0 );
    m_axi_card_mem0_awlock     : out std_logic_vector ( 1 downto 0 );
    m_axi_card_mem0_awprot     : out std_logic_vector ( 2 downto 0 );
    m_axi_card_mem0_awqos      : out std_logic_vector ( 3 downto 0 );
    m_axi_card_mem0_awready    : in  std_logic;
    m_axi_card_mem0_awregion   : out std_logic_vector ( 3 downto 0 );
    m_axi_card_mem0_awsize     : out std_logic_vector ( 2 downto 0 );
    m_axi_card_mem0_awuser     : out std_logic_vector ( C_M_AXI_CARD_MEM0_AWUSER_WIDTH-1 downto 0 );
    m_axi_card_mem0_awvalid    : out std_logic;
    m_axi_card_mem0_bid        : in  std_logic_vector ( C_M_AXI_CARD_MEM0_ID_WIDTH-1 downto 0 );
    m_axi_card_mem0_bready     : out std_logic;
    m_axi_card_mem0_bresp      : in  std_logic_vector ( 1 downto 0 );
    m_axi_card_mem0_buser      : in  std_logic_vector ( C_M_AXI_CARD_MEM0_BUSER_WIDTH-1 downto 0 );
    m_axi_card_mem0_bvalid     : in  std_logic;
    m_axi_card_mem0_rdata      : in  std_logic_vector ( C_M_AXI_CARD_MEM0_DATA_WIDTH-1 downto 0 );
    m_axi_card_mem0_rid        : in  std_logic_vector ( C_M_AXI_CARD_MEM0_ID_WIDTH-1 downto 0 );
    m_axi_card_mem0_rlast      : in  std_logic;
    m_axi_card_mem0_rready     : out std_logic;
    m_axi_card_mem0_rresp      : in  std_logic_vector ( 1 downto 0 );
    m_axi_card_mem0_ruser      : in  std_logic_vector ( C_M_AXI_CARD_MEM0_RUSER_WIDTH-1 downto 0 );
    m_axi_card_mem0_rvalid     : in  std_logic;
    m_axi_card_mem0_wdata      : out std_logic_vector ( C_M_AXI_CARD_MEM0_DATA_WIDTH-1 downto 0 );
    m_axi_card_mem0_wlast      : out std_logic;
    m_axi_card_mem0_wready     : in  std_logic;
    m_axi_card_mem0_wstrb      : out std_logic_vector ( (C_M_AXI_CARD_MEM0_DATA_WIDTH/8)-1 downto 0 );
    m_axi_card_mem0_wuser      : out std_logic_vector ( C_M_AXI_CARD_MEM0_WUSER_WIDTH-1 downto 0 );
    m_axi_card_mem0_wvalid     : out std_logic;


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

  s_ctrl_ms.awaddr       <= f_resizeVU(s_axi_ctrl_reg_awaddr, s_ctrl_ms.awaddr'length);
  s_ctrl_ms.awvalid      <=            s_axi_ctrl_reg_awvalid;
  s_ctrl_ms.wdata        <= f_resizeVU(s_axi_ctrl_reg_wdata, s_ctrl_ms.wdata'length);
  s_ctrl_ms.wstrb        <= f_resizeVU(s_axi_ctrl_reg_wstrb, s_ctrl_ms.wstrb'length);
  s_ctrl_ms.wvalid       <=            s_axi_ctrl_reg_wvalid;
  s_ctrl_ms.bready       <=            s_axi_ctrl_reg_bready;
  s_ctrl_ms.araddr       <= f_resizeVU(s_axi_ctrl_reg_araddr, s_ctrl_ms.araddr'length);
  s_ctrl_ms.arvalid      <=            s_axi_ctrl_reg_arvalid;
  s_ctrl_ms.rready       <=            s_axi_ctrl_reg_rready;
  s_axi_ctrl_reg_awready <=            s_ctrl_sm.awready;
  s_axi_ctrl_reg_wready  <=            s_ctrl_sm.wready;
  s_axi_ctrl_reg_bresp   <=            s_ctrl_sm.bresp;
  s_axi_ctrl_reg_bvalid  <=            s_ctrl_sm.bvalid;
  s_axi_ctrl_reg_arready <=            s_ctrl_sm.arready;
  s_axi_ctrl_reg_rdata   <= f_resizeUV(s_ctrl_sm.rdata, s_axi_ctrl_reg_rdata'length);
  s_axi_ctrl_reg_rresp   <=            s_ctrl_sm.rresp;
  s_axi_ctrl_reg_rvalid  <=            s_ctrl_sm.rvalid;

  m_axi_host_mem_awid     <=           (others => '0');
  m_axi_host_mem_awaddr   <= f_resizeUV(s_hmem_ms.awaddr, m_axi_host_mem_awaddr'length);
  m_axi_host_mem_awlen    <= f_resizeUV(s_hmem_ms.awlen, m_axi_host_mem_awlock'length);
  m_axi_host_mem_awsize   <= f_resizeUV(s_hmem_ms.awsize, m_axi_host_mem_awsize'length);
  m_axi_host_mem_awburst  <= f_resizeUV(s_hmem_ms.awburst, m_axi_host_mem_awburst'length);
  m_axi_host_mem_awlock   <=            c_AxiNullLock;
  m_axi_host_mem_awcache  <=            c_AxiNullCache;
  m_axi_host_mem_awprot   <=            c_AxiNullProt;
  m_axi_host_mem_awqos    <=            c_AxiNullQos;
  m_axi_host_mem_awregion <=            c_AxiNullRegion;
  m_axi_host_mem_awuser   <= f_resizeUV(s_context, m_axi_host_mem_awuser'length);
  m_axi_host_mem_awvalid  <=            s_hmem_ms.awvalid;
  m_axi_host_mem_wdata    <= f_resizeUV(s_hmem_ms.wdata, m_axi_host_mem_wdata'length);
  m_axi_host_mem_wstrb    <= f_resizeUV(s_hmem_ms.wstrb, m_axi_host_mem_wstrb'length);
  m_axi_host_mem_wlast    <=            s_hmem_ms.wlast;
  m_axi_host_mem_wuser    <=           (others => '0');
  m_axi_host_mem_wvalid   <=            s_hmem_ms.wvalid;
  m_axi_host_mem_bready   <=            s_hmem_ms.bready;
  m_axi_host_mem_arid     <=           (others => '0');
  m_axi_host_mem_araddr   <= f_resizeUV(s_hmem_ms.araddr, m_axi_host_mem_araddr'length);
  m_axi_host_mem_arlen    <= f_resizeUV(s_hmem_ms.arlen, m_axi_host_mem_arlock'length);
  m_axi_host_mem_arsize   <= f_resizeUV(s_hmem_ms.arsize, m_axi_host_mem_arsize'length);
  m_axi_host_mem_arburst  <= f_resizeUV(s_hmem_ms.arburst, m_axi_host_mem_arburst'length);
  m_axi_host_mem_arlock   <=            c_AxiNullLock;
  m_axi_host_mem_arcache  <=            c_AxiNullCache;
  m_axi_host_mem_arprot   <=            c_AxiNullProt;
  m_axi_host_mem_arqos    <=            c_AxiNullQos;
  m_axi_host_mem_arregion <=            c_AxiNullRegion;
  m_axi_host_mem_aruser   <= f_resizeUV(s_context, m_axi_host_mem_aruser'length);
  m_axi_host_mem_arvalid  <=            s_hmem_ms.arvalid;
  m_axi_host_mem_rready   <=            s_hmem_ms.rready;
  s_hmem_sm.awready       <=            m_axi_host_mem_awready;
  s_hmem_sm.wready        <=            m_axi_host_mem_wready;
  s_hmem_sm.bresp         <= f_resizeVU(m_axi_host_mem_bresp, s_hmem_sm.bresp'length);
  s_hmem_sm.bvalid        <=            m_axi_host_mem_bvalid;
  s_hmem_sm.arready       <=            m_axi_host_mem_arready;
  s_hmem_sm.rdata         <= f_resizeVU(m_axi_host_mem_rdata, s_hmem_sm.rdata'length);
  s_hmem_sm.rresp         <= f_resizeVU(m_axi_host_mem_rresp, s_hmem_sm.rresp'length);
  s_hmem_sm.rlast         <=            m_axi_host_mem_rlast;
  s_hmem_sm.rvalid        <=            m_axi_host_mem_rvalid;

  m_axi_card_mem0_awid     <=           (others => '0');
  m_axi_card_mem0_awaddr   <= f_resizeUV(s_cmem_ms.awaddr, m_axi_card_mem0_awaddr'length);
  m_axi_card_mem0_awlen    <= f_resizeUV(s_cmem_ms.awlen, m_axi_card_mem0_awlock'length);
  m_axi_card_mem0_awsize   <= f_resizeUV(s_cmem_ms.awsize, m_axi_card_mem0_awsize'length);
  m_axi_card_mem0_awburst  <= f_resizeUV(s_cmem_ms.awburst, m_axi_card_mem0_awburst'length);
  m_axi_card_mem0_awlock   <=            c_AxiNullLock;
  m_axi_card_mem0_awcache  <=            c_AxiNullCache;
  m_axi_card_mem0_awprot   <=            c_AxiNullProt;
  m_axi_card_mem0_awqos    <=            c_AxiNullQos;
  m_axi_card_mem0_awregion <=            c_AxiNullRegion;
  m_axi_card_mem0_awvalid  <=            s_cmem_ms.awvalid;
  m_axi_card_mem0_wdata    <= f_resizeUV(s_cmem_ms.wdata, m_axi_card_mem0_wdata'length);
  m_axi_card_mem0_wstrb    <= f_resizeUV(s_cmem_ms.wstrb, m_axi_card_mem0_wstrb'length);
  m_axi_card_mem0_wlast    <=            s_cmem_ms.wlast;
  m_axi_card_mem0_wuser    <=           (others => '0');
  m_axi_card_mem0_wvalid   <=            s_cmem_ms.wvalid;
  m_axi_card_mem0_bready   <=            s_cmem_ms.bready;
  m_axi_card_mem0_arid     <=           (others => '0');
  m_axi_card_mem0_araddr   <= f_resizeUV(s_cmem_ms.araddr, m_axi_card_mem0_araddr'length);
  m_axi_card_mem0_arlen    <= f_resizeUV(s_cmem_ms.arlen, m_axi_card_mem0_arlock'length);
  m_axi_card_mem0_arsize   <= f_resizeUV(s_cmem_ms.arsize, m_axi_card_mem0_arsize'length);
  m_axi_card_mem0_arburst  <= f_resizeUV(s_cmem_ms.arburst, m_axi_card_mem0_arburst'length);
  m_axi_card_mem0_arlock   <=            c_AxiNullLock;
  m_axi_card_mem0_arcache  <=            c_AxiNullCache;
  m_axi_card_mem0_arprot   <=            c_AxiNullProt;
  m_axi_card_mem0_arqos    <=            c_AxiNullQos;
  m_axi_card_mem0_arregion <=            c_AxiNullRegion;
  m_axi_card_mem0_arvalid  <=            s_cmem_ms.arvalid;
  m_axi_card_mem0_rready   <=            s_cmem_ms.rready;
  s_cmem_sm.awready        <=            m_axi_card_mem0_awready;
  s_cmem_sm.wready         <=            m_axi_card_mem0_wready;
  s_cmem_sm.bresp          <= f_resizeVU(m_axi_card_mem0_bresp, s_cmem_sm.bresp'length);
  s_cmem_sm.bvalid         <=            m_axi_card_mem0_bvalid;
  s_cmem_sm.arready        <=            m_axi_card_mem0_arready;
  s_cmem_sm.rdata          <= f_resizeVU(m_axi_card_mem0_rdata, s_cmem_sm.rdata'length);
  s_cmem_sm.rresp          <= f_resizeVU(m_axi_card_mem0_rresp, s_cmem_sm.rresp'length);
  s_cmem_sm.rlast          <=            m_axi_card_mem0_rlast;
  s_cmem_sm.rvalid         <=            m_axi_card_mem0_rvalid;


  s_nvme_sm <= c_NvmeNull_sm;


end structure;
