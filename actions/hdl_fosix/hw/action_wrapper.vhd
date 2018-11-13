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

  component action_example is
    port (
      pi_clk     : in  std_logic;
      pi_rst_n   : in  std_logic;
      po_intReq : out std_logic;
      po_intSrc : out t_InterruptSrc;
      po_intCtx : out t_Context;
      pi_intAck : in  std_logic;

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
  end component action_example;

  signal s_intSrc  : t_InterruptSrc;
  signal s_intCtx  : t_Context;
  signal s_ctrl_ms : t_Ctrl_ms;
  signal s_ctrl_sm : t_Ctrl_sm;
  signal s_hmem_ms : t_Axi_ms;
  signal s_hmem_sm : t_Axi_sm;
  signal s_cmem_ms : t_Axi_ms;
  signal s_cmem_sm : t_Axi_sm;
  signal s_nvme_ms : t_Nvme_ms;
  signal s_nvme_sm : t_Nvme_sm;

begin

  i_action: component action_example
    port map (
      pi_clk     => ap_clk,
      pi_rst_n   => ap_rst_n,
      po_intReq  => interrupt,
      po_intSrc  => s_intSrc,
      po_intCtx  => s_intCtx,
      pi_intAck  => interrupt_ack,

      pi_ctrl_ms => s_ctrl_ms,
      po_ctrl_sm => s_ctrl_sm,
      po_hmem_ms => s_hmem_ms,
      pi_hmem_sm => s_hmem_sm,
      po_cmem_ms => s_cmem_ms,
      pi_cmem_sm => s_cmem_sm,
      po_nvme_ms => s_nvme_ms,
      pi_nvme_sm => s_nvme_sm);

  interrupt_src <= std_logic_vector(s_intSrc);
  interrupt_ctx <= std_logic_vector(s_intCtx);

  s_axi_ctrl_reg_awready <= s_ctrl_sm.awready;
  s_axi_ctrl_reg_wready  <= s_ctrl_sm.wready;
  s_axi_ctrl_reg_bresp   <= s_ctrl_sm.bresp;
  s_axi_ctrl_reg_bvalid  <= s_ctrl_sm.bvalid;
  s_axi_ctrl_reg_arready <= s_ctrl_sm.arready;
  s_axi_ctrl_reg_rdata   <= std_logic_vector(s_ctrl_sm.rdata);
  s_axi_ctrl_reg_rresp   <= s_ctrl_sm.rresp;
  s_axi_ctrl_reg_rvalid  <= s_ctrl_sm.rvalid;
  s_ctrl_ms.awaddr  <= t_CtrlAddr(s_axi_ctrl_reg_awaddr);
  s_ctrl_ms.awvalid <=            s_axi_ctrl_reg_awvalid;
  s_ctrl_ms.wdata   <= t_CtrlData(s_axi_ctrl_reg_wdata);
  s_ctrl_ms.wstrb   <= t_CtrlStrb(s_axi_ctrl_reg_wstrb);
  s_ctrl_ms.wvalid  <=            s_axi_ctrl_reg_wvalid;
  s_ctrl_ms.bready  <=            s_axi_ctrl_reg_bready;
  s_ctrl_ms.araddr  <= t_CtrlAddr(s_axi_ctrl_reg_araddr);
  s_ctrl_ms.arvalid <=            s_axi_ctrl_reg_arvalid;
  s_ctrl_ms.rready  <=            s_axi_ctrl_reg_rready;

  m_axi_host_mem_awid     <=  (others => '0');
  m_axi_host_mem_awaddr   <= std_logic_vector(s_hmem_ms.awaddr);
  m_axi_host_mem_awlen    <= std_logic_vector(s_hmem_ms.awlen);
  m_axi_host_mem_awsize   <= std_logic_vector(s_hmem_ms.awsize);
  m_axi_host_mem_awburst  <= std_logic_vector(s_hmem_ms.awburst);
  m_axi_host_mem_awlock   <=  std_logic_vector(c_AxiDefLock);
  m_axi_host_mem_awcache  <=  std_logic_vector(c_AxiDefCache);
  m_axi_host_mem_awprot   <=  std_logic_vector(c_AxiDefProt);
  m_axi_host_mem_awqos    <=  std_logic_vector(c_AxiDefQos);
  m_axi_host_mem_awregion <=  std_logic_vector(c_AxiDefRegion);
  m_axi_host_mem_awuser   <= std_logic_vector(s_hmem_ms.awuser);
  m_axi_host_mem_awvalid  <= s_hmem_ms.awvalid;
  m_axi_host_mem_wdata    <= std_logic_vector(s_hmem_ms.wdata);
  m_axi_host_mem_wstrb    <= std_logic_vector(s_hmem_ms.wstrb);
  m_axi_host_mem_wlast    <= s_hmem_ms.wlast;
  m_axi_host_mem_wuser    <=  (others => '0');
  m_axi_host_mem_wvalid   <= s_hmem_ms.wvalid;
  m_axi_host_mem_bready   <= s_hmem_ms.bready;
  m_axi_host_mem_arid     <=  (others => '0');
  m_axi_host_mem_araddr   <= std_logic_vector(s_hmem_ms.araddr);
  m_axi_host_mem_arlen    <= std_logic_vector(s_hmem_ms.arlen);
  m_axi_host_mem_arsize   <= std_logic_vector(s_hmem_ms.arsize);
  m_axi_host_mem_arburst  <= std_logic_vector(s_hmem_ms.arburst);
  m_axi_host_mem_arlock   <=  std_logic_vector(c_AxiDefLock);
  m_axi_host_mem_arcache  <=  std_logic_vector(c_AxiDefCache);
  m_axi_host_mem_arprot   <=  std_logic_vector(c_AxiDefProt);
  m_axi_host_mem_arqos    <=  std_logic_vector(c_AxiDefQos);
  m_axi_host_mem_arregion <=  std_logic_vector(c_AxiDefRegion);
  m_axi_host_mem_aruser   <= std_logic_vector(s_hmem_ms.aruser);
  m_axi_host_mem_arvalid  <= s_hmem_ms.arvalid;
  m_axi_host_mem_rready   <= s_hmem_ms.rready;
  s_hmem_sm.awready <= m_axi_host_mem_awready;
  s_hmem_sm.wready  <= m_axi_host_mem_wready;
  -- s_hmem_sm.bid     <= m_axi_host_mem_bid;
  s_hmem_sm.bresp   <= t_AxiResp(m_axi_host_mem_bresp);
  -- s_hmem_sm.buser   <= m_axi_host_mem_buser;
  s_hmem_sm.bvalid  <= m_axi_host_mem_bvalid;
  s_hmem_sm.arready <= m_axi_host_mem_arready;
  -- s_hmem_sm.rid     <= m_axi_host_mem_rid;
  s_hmem_sm.rdata   <= t_HmemData(m_axi_host_mem_rdata);
  s_hmem_sm.rresp   <= t_AxiResp(m_axi_host_mem_rresp);
  s_hmem_sm.rlast   <= m_axi_host_mem_rlast;
  -- s_hmem_sm.ruser   <= m_axi_host_mem_ruser;
  s_hmem_sm.rvalid  <= m_axi_host_mem_rvalid;


  s_cmem_sm <= c_AxiNull_sm;                      -- only for DDRI_USED=FALSE


  s_nvme_sm <= c_NvmeNull_sm;                      -- only for NVME_USED=FALSE

END STRUCTURE;
