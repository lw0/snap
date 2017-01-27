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

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE work.std_ulogic_function_support.ALL;
USE work.std_ulogic_support.ALL;
USE work.std_ulogic_unsigned.ALL;
LIBRARY unisim;                                                                                                           -- only for DDR3_USED=TRUE
 USE unisim.vcomponents.all;                                                                                              -- only for DDR3_USED=TRUE

 USE work.psl_accel_types.ALL;
 USE work.ddr3_sdram_pkg.ALL;                                                                  -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
 USE work.ddr3_sdram_usodimm_pkg.ALL;                                                          -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE


ENTITY afu IS
  GENERIC (
    BRAM_USED  : BOOLEAN := FALSE;

    -- Parameters for Axi Master Bus Interface AXI_CARD_MEM0 : to DDR memory
    C_AXI_CARD_MEM0_ID_WIDTH       : integer   := 1;
    C_AXI_CARD_MEM0_ADDR_WIDTH     : integer   := 33;
    C_AXI_CARD_MEM0_DATA_WIDTH     : integer   := 512;
    C_AXI_CARD_MEM0_AWUSER_WIDTH   : integer   := 1;
    C_AXI_CARD_MEM0_ARUSER_WIDTH   : integer   := 1;
    C_AXI_CARD_MEM0_WUSER_WIDTH    : integer   := 1;
    C_AXI_CARD_MEM0_RUSER_WIDTH    : integer   := 1;
    C_AXI_CARD_MEM0_BUSER_WIDTH    : integer   := 1;

    -- Parameters for Axi Slave Bus Interface AXI_CTRL_REG
    C_AXI_CTRL_REG_DATA_WIDTH      : integer   := 32;
    C_AXI_CTRL_REG_ADDR_WIDTH      : integer   := 32;

    -- Parameters for Axi Master Bus Interface AXI_HOST_MEM : to Host memory
    C_AXI_HOST_MEM_ID_WIDTH        : integer   := 1;
    C_AXI_HOST_MEM_ADDR_WIDTH      : integer   := 64;
    C_AXI_HOST_MEM_DATA_WIDTH      : integer   := 512;
    C_AXI_HOST_MEM_AWUSER_WIDTH    : integer   := 1;
    C_AXI_HOST_MEM_ARUSER_WIDTH    : integer   := 1;
    C_AXI_HOST_MEM_WUSER_WIDTH     : integer   := 1;
    C_AXI_HOST_MEM_RUSER_WIDTH     : integer   := 1;
    C_AXI_HOST_MEM_BUSER_WIDTH     : integer   := 1
  );
  PORT(
    -- Accelerator Command Interface
    ah_cvalid                          : OUT   STD_ULOGIC;  -- A valid command is present
    ah_ctag                            : OUT   STD_ULOGIC_VECTOR(0 TO 7);  -- request id
    ah_com                             : OUT   STD_ULOGIC_VECTOR(0 TO 12);  -- command PSL will execute
    ah_cpad                            : OUT   STD_ULOGIC_VECTOR(0 TO 2);  -- prefetch attributes
    ah_cabt                            : OUT   STD_ULOGIC_VECTOR(0 TO 2);  -- abort if translation intr is generated
    ah_cea                             : OUT   STD_ULOGIC_VECTOR(0 TO 63);  -- Effective byte address for command
    ah_cch                             : OUT   STD_ULOGIC_VECTOR(0 TO 15);  -- Context Handle
    ah_csize                           : OUT   STD_ULOGIC_VECTOR(0 TO 11);  -- Number of bytes
    ha_croom                           : IN    STD_ULOGIC_VECTOR(0 TO 7);  -- Commands PSL is prepared to accept

    -- command parity
    ah_ctagpar                         : OUT   STD_ULOGIC;
    ah_compar                          : OUT   STD_ULOGIC;
    ah_ceapar                          : OUT   STD_ULOGIC;

    -- Accelerator Buffer Interfaces
    ha_brvalid                         : IN    STD_ULOGIC;  -- A read transfer is present
    ha_brtag                           : IN    STD_ULOGIC_VECTOR(0 TO 7);  -- Accelerator generated ID for read
    ha_brad                            : IN    STD_ULOGIC_VECTOR(0 TO 5);  -- half line index of read data
    ah_brlat                           : OUT   STD_ULOGIC_VECTOR(0 TO 3);  -- Read data ready latency
    ah_brdata                          : OUT   STD_ULOGIC_VECTOR(0 TO 511);  -- Read data
    ah_brpar                           : OUT   STD_ULOGIC_VECTOR(0 TO 7);  -- Read data parity
    ha_bwvalid                         : IN    STD_ULOGIC;  -- A write data transfer is present
    ha_bwtag                           : IN    STD_ULOGIC_VECTOR(0 TO 7);  -- Accelerator ID of the write
    ha_bwad                            : IN    STD_ULOGIC_VECTOR(0 TO 5);  -- half line index of write data
    ha_bwdata                          : IN    STD_ULOGIC_VECTOR(0 TO 511);  -- Write data
    ha_bwpar                           : IN    STD_ULOGIC_VECTOR(0 TO 7);  -- Write data parity

    -- buffer tag parity
    ha_brtagpar                        : IN    STD_ULOGIC;
    ha_bwtagpar                        : IN    STD_ULOGIC;

    -- PSL Response Interface
    ha_rvalid                          : IN    STD_ULOGIC;  --A response is present
    ha_rtag                            : IN    STD_ULOGIC_VECTOR(0 TO 7);  --Accelerator generated request ID
    ha_response                        : IN    STD_ULOGIC_VECTOR(0 TO 7);  --response code
    ha_rcredits                        : IN    STD_ULOGIC_VECTOR(0 TO 8);  --twos compliment number of credits
    ha_rcachestate                     : IN    STD_ULOGIC_VECTOR(0 TO 1);  --Resultant Cache State
    ha_rcachepos                       : IN    STD_ULOGIC_VECTOR(0 TO 12);  --Cache location id
    ha_rtagpar                         : IN    STD_ULOGIC;

    -- MMIO Interface
    ha_mmval                           : IN    STD_ULOGIC;  -- A valid MMIO is present
    ha_mmrnw                           : IN    STD_ULOGIC;  -- 1 = read, 0 = write
    ha_mmdw                            : IN    STD_ULOGIC;  -- 1 = doubleword, 0 = word
    ha_mmad                            : IN    STD_ULOGIC_VECTOR(0 TO 23);  -- mmio address
    ha_mmdata                          : IN    STD_ULOGIC_VECTOR(0 TO 63);  -- Write data
    ha_mmcfg                           : IN    STD_ULOGIC;  -- mmio is to afu descriptor space
    ah_mmack                           : OUT   STD_ULOGIC;  -- Write is complete or Read is valid pulse
    ah_mmdata                          : OUT   STD_ULOGIC_VECTOR(0 TO 63);  -- Read data

    -- mmio parity
    ha_mmadpar                         : IN    STD_ULOGIC;
    ha_mmdatapar                       : IN    STD_ULOGIC;
    ah_mmdatapar                       : OUT   STD_ULOGIC;

    -- Accelerator Control Interface
    ha_jval                            : IN    STD_ULOGIC;  -- A valid job control command is present
    ha_jcom                            : IN    STD_ULOGIC_VECTOR(0 TO 7);  -- Job control command opcode
    ha_jea                             : IN    STD_ULOGIC_VECTOR(0 TO 63);  -- Save/Restore address
    ah_jrunning                        : OUT   STD_ULOGIC;  -- Accelerator is running level
    ah_jdone                           : OUT   STD_ULOGIC;  -- Accelerator is finished pulse
    ah_jcack                           : OUT   STD_ULOGIC;  -- Accelerator is with context llcmd pulse
    ah_jerror                          : OUT   STD_ULOGIC_VECTOR(0 TO 63);  -- Accelerator error code. 0 = success
    ah_tbreq                           : OUT   STD_ULOGIC;  -- Timebase request pulse
    ah_jyield                          : OUT   STD_ULOGIC;  -- Accelerator wants to stop
    ha_jeapar                          : IN    STD_ULOGIC;
    ha_jcompar                         : IN    STD_ULOGIC;
    ah_paren                           : OUT   STD_ULOGIC;
    ha_pclock                          : IN    STD_ULOGIC
  );
END afu;


ARCHITECTURE afu OF afu IS
  --
  -- DONUT
  --
  COMPONENT donut
    PORT (
      ah_cvalid                : OUT STD_ULOGIC;
      ah_ctag                  : OUT STD_ULOGIC_VECTOR(0 TO 7);
      ah_com                   : OUT STD_ULOGIC_VECTOR(0 TO 12);
      ah_cabt                  : OUT STD_ULOGIC_VECTOR(0 TO 2);
      ah_cea                   : OUT STD_ULOGIC_VECTOR(0 TO 63);
      ah_cch                   : OUT STD_ULOGIC_VECTOR(0 TO 15);
      ah_csize                 : OUT STD_ULOGIC_VECTOR(0 TO 11);
      ha_croom                 : IN  STD_ULOGIC_VECTOR(0 TO 7);
      ah_ctagpar               : OUT STD_ULOGIC;
      ah_compar                : OUT STD_ULOGIC;
      ah_ceapar                : OUT STD_ULOGIC;
      ha_brvalid               : IN  STD_ULOGIC;
      ha_brtag                 : IN  STD_ULOGIC_VECTOR(0 TO 7);
      ha_brad                  : IN  STD_ULOGIC_VECTOR(0 TO 5);
      ah_brlat                 : OUT STD_ULOGIC_VECTOR(0 TO 3);
      ah_brdata                : OUT STD_ULOGIC_VECTOR(0 TO 511);
      ah_brpar                 : OUT STD_ULOGIC_VECTOR(0 TO 7);
      ha_bwvalid               : IN  STD_ULOGIC;
      ha_bwtag                 : IN  STD_ULOGIC_VECTOR(0 TO 7);
      ha_bwad                  : IN  STD_ULOGIC_VECTOR(0 TO 5);
      ha_bwdata                : IN  STD_ULOGIC_VECTOR(0 TO 511);
      ha_bwpar                 : IN  STD_ULOGIC_VECTOR(0 TO 7);
      ha_brtagpar              : IN  STD_ULOGIC;
      ha_bwtagpar              : IN  STD_ULOGIC;
      ha_rvalid                : IN  STD_ULOGIC;
      ha_rtag                  : IN  STD_ULOGIC_VECTOR(0 TO 7);
      ha_response              : IN  STD_ULOGIC_VECTOR(0 TO 7);
      ha_rcredits              : IN  STD_ULOGIC_VECTOR(0 TO 8);
      ha_rcachestate           : IN  STD_ULOGIC_VECTOR(0 TO 1);
      ha_rcachepos             : IN  STD_ULOGIC_VECTOR(0 TO 12);
      ha_rtagpar               : IN  STD_ULOGIC;
      ha_mmval                 : IN  STD_ULOGIC;
      ha_mmrnw                 : IN  STD_ULOGIC;
      ha_mmdw                  : IN  STD_ULOGIC;
      ha_mmad                  : IN  STD_ULOGIC_VECTOR(0 TO 23);
      ha_mmdata                : IN  STD_ULOGIC_VECTOR(0 TO 63);
      ha_mmcfg                 : IN  STD_ULOGIC;
      ah_mmack                 : OUT STD_ULOGIC;
      ah_mmdata                : OUT STD_ULOGIC_VECTOR(0 TO 63);
      ha_mmadpar               : IN  STD_ULOGIC;
      ha_mmdatapar             : IN  STD_ULOGIC;
      ah_mmdatapar             : OUT STD_ULOGIC;
      ha_jval                  : IN  STD_ULOGIC;
      ha_jcom                  : IN  STD_ULOGIC_VECTOR(0 TO 7);
      ha_jea                   : IN  STD_ULOGIC_VECTOR(0 TO 63);
      ah_jrunning              : OUT STD_ULOGIC;
      ah_jdone                 : OUT STD_ULOGIC;
      ah_jcack                 : OUT STD_ULOGIC;
      ah_jerror                : OUT STD_ULOGIC_VECTOR(0 TO 63);
      ah_tbreq                 : OUT STD_ULOGIC;
      ah_jyield                : OUT STD_ULOGIC;
      ha_jeapar                : IN  STD_ULOGIC;
      ha_jcompar               : IN  STD_ULOGIC;
      ah_paren                 : OUT STD_ULOGIC;
      ha_pclock                : IN  STD_ULOGIC;
      --
      -- ACTION Interface
      --
      -- misc
      action_reset             : OUT STD_ULOGIC;
      --
      -- Kernel AXI Master Interface
      xk_d_o                   : OUT XK_D_T;
      kx_d_i                   : IN  KX_D_T;
      --
      -- Kernel AXI Slave Interface
      sk_d_o                   : OUT SK_D_T;
      ks_d_i                   : IN  KS_D_T
    );
  END COMPONENT;

  --
  -- ACTION WRAPPER
  --
  COMPONENT action_wrapper
    GENERIC (
      -- Parameters for Axi Master Bus Interface AXI_CARD_MEM0 : to DDR memory
      C_M_AXI_CARD_MEM0_ID_WIDTH       : integer;
      C_M_AXI_CARD_MEM0_ADDR_WIDTH     : integer;
      C_M_AXI_CARD_MEM0_DATA_WIDTH     : integer;
      C_M_AXI_CARD_MEM0_AWUSER_WIDTH   : integer;
      C_M_AXI_CARD_MEM0_ARUSER_WIDTH   : integer;
      C_M_AXI_CARD_MEM0_WUSER_WIDTH    : integer;
      C_M_AXI_CARD_MEM0_RUSER_WIDTH    : integer;
      C_M_AXI_CARD_MEM0_BUSER_WIDTH    : integer;

      -- Parameters for Axi Slave Bus Interface AXI_CTRL_REG
      C_S_AXI_CTRL_REG_DATA_WIDTH      : integer;
      C_S_AXI_CTRL_REG_ADDR_WIDTH      : integer;

      -- Parameters for Axi Master Bus Interface AXI_HOST_MEM : to Host memory
      C_M_AXI_HOST_MEM_ID_WIDTH        : integer;
      C_M_AXI_HOST_MEM_ADDR_WIDTH      : integer;
      C_M_AXI_HOST_MEM_DATA_WIDTH      : integer;
      C_M_AXI_HOST_MEM_AWUSER_WIDTH    : integer;
      C_M_AXI_HOST_MEM_ARUSER_WIDTH    : integer;
      C_M_AXI_HOST_MEM_WUSER_WIDTH     : integer;
      C_M_AXI_HOST_MEM_RUSER_WIDTH     : integer;
      C_M_AXI_HOST_MEM_BUSER_WIDTH     : integer
    );

    PORT (
      ap_clk                     : IN STD_LOGIC;
      ap_rst_n                   : IN STD_LOGIC;
       --                                                                                                 -- only for DDR3_USED=TRUE
       -- AXI DDR3 Interface                                                                              -- only for DDR3_USED=TRUE
       m_axi_card_mem0_araddr     : OUT STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ADDR_WIDTH-1 DOWNTO 0 );       -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arburst    : OUT STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arcache    : OUT STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arid       : OUT STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0 );         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arlen      : OUT STD_LOGIC_VECTOR ( 7 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arlock     : OUT STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arprot     : OUT STD_LOGIC_VECTOR ( 2 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arqos      : OUT STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arready    : IN  STD_LOGIC;                                                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arregion   : OUT STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arsize     : OUT STD_LOGIC_VECTOR ( 2 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_aruser     : OUT STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ARUSER_WIDTH-1 DOWNTO 0 );     -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arvalid    : OUT STD_LOGIC;                                                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awaddr     : OUT STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ADDR_WIDTH-1 DOWNTO 0 );       -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awburst    : OUT STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awcache    : OUT STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awid       : OUT STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0 );         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awlen      : OUT STD_LOGIC_VECTOR ( 7 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awlock     : OUT STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awprot     : OUT STD_LOGIC_VECTOR ( 2 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awqos      : OUT STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awready    : IN  STD_LOGIC;                                                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awregion   : OUT STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awsize     : OUT STD_LOGIC_VECTOR ( 2 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awuser     : OUT STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_AWUSER_WIDTH-1 DOWNTO 0 );     -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awvalid    : OUT STD_LOGIC;                                                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_bid        : IN  STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0 );         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_bready     : OUT STD_LOGIC;                                                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_bresp      : IN  STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_buser      : IN  STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_BUSER_WIDTH-1 DOWNTO 0 );      -- only for DDR3_USED=TRUE
       m_axi_card_mem0_bvalid     : IN  STD_LOGIC;                                                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_rdata      : IN  STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_DATA_WIDTH-1 DOWNTO 0 );       -- only for DDR3_USED=TRUE
       m_axi_card_mem0_rid        : IN  STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0 );         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_rlast      : IN  STD_LOGIC;                                                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_rready     : OUT STD_LOGIC;                                                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_rresp      : IN  STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                  -- only for DDR3_USED=TRUE
       m_axi_card_mem0_ruser      : IN  STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_RUSER_WIDTH-1 DOWNTO 0 );      -- only for DDR3_USED=TRUE
       m_axi_card_mem0_rvalid     : IN  STD_LOGIC;                                                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_wdata      : OUT STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_DATA_WIDTH-1 DOWNTO 0 );       -- only for DDR3_USED=TRUE
       m_axi_card_mem0_wlast      : OUT STD_LOGIC;                                                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_wready     : IN  STD_LOGIC;                                                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_wstrb      : OUT STD_LOGIC_VECTOR ( (C_AXI_CARD_MEM0_DATA_WIDTH/8)-1 DOWNTO 0 );   -- only for DDR3_USED=TRUE
       m_axi_card_mem0_wuser      : OUT STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_WUSER_WIDTH-1 DOWNTO 0 );      -- only for DDR3_USED=TRUE
       m_axi_card_mem0_wvalid     : OUT STD_LOGIC;                                                        -- only for DDR3_USED=TRUE
      --
      -- AXI Control Register Interface
      s_axi_ctrl_reg_araddr      : IN  STD_LOGIC_VECTOR ( C_AXI_CTRL_REG_ADDR_WIDTH-1 DOWNTO 0 );
      s_axi_ctrl_reg_arready     : OUT STD_LOGIC;
      s_axi_ctrl_reg_arvalid     : IN  STD_LOGIC;
      s_axi_ctrl_reg_awaddr      : IN  STD_LOGIC_VECTOR ( C_AXI_CTRL_REG_ADDR_WIDTH-1 DOWNTO 0 );
      s_axi_ctrl_reg_awready     : OUT STD_LOGIC;
      s_axi_ctrl_reg_awvalid     : IN  STD_LOGIC;
      s_axi_ctrl_reg_bready      : IN  STD_LOGIC;
      s_axi_ctrl_reg_bresp       : OUT STD_LOGIC_VECTOR ( 1 DOWNTO 0 );
      s_axi_ctrl_reg_bvalid      : OUT STD_LOGIC;
      s_axi_ctrl_reg_rdata       : OUT STD_LOGIC_VECTOR ( C_AXI_CTRL_REG_DATA_WIDTH-1 DOWNTO 0 );
      s_axi_ctrl_reg_rready      : IN  STD_LOGIC;
      s_axi_ctrl_reg_rresp       : OUT STD_LOGIC_VECTOR ( 1 DOWNTO 0 );
      s_axi_ctrl_reg_rvalid      : OUT STD_LOGIC;
      s_axi_ctrl_reg_wdata       : IN  STD_LOGIC_VECTOR ( C_AXI_CTRL_REG_DATA_WIDTH-1 DOWNTO 0 );
      s_axi_ctrl_reg_wready      : OUT STD_LOGIC;
      s_axi_ctrl_reg_wstrb       : IN  STD_LOGIC_VECTOR ( (C_AXI_CTRL_REG_DATA_WIDTH/8)-1 DOWNTO 0 );
      s_axi_ctrl_reg_wvalid      : IN  STD_LOGIC;
      interrupt                  : OUT STD_LOGIC;
      --
      -- AXI Host Memory Interface
      m_axi_host_mem_araddr      : OUT STD_LOGIC_VECTOR ( C_AXI_HOST_MEM_ADDR_WIDTH-1 DOWNTO 0 );
      m_axi_host_mem_arburst     : OUT STD_LOGIC_VECTOR ( 1 DOWNTO 0 );
      m_axi_host_mem_arcache     : OUT STD_LOGIC_VECTOR ( 3 DOWNTO 0 );
      m_axi_host_mem_arid        : OUT STD_LOGIC_VECTOR ( C_AXI_HOST_MEM_ID_WIDTH-1 DOWNTO 0 );
      m_axi_host_mem_arlen       : OUT STD_LOGIC_VECTOR ( 7 DOWNTO 0 );
      m_axi_host_mem_arlock      : OUT STD_LOGIC_VECTOR ( 1 DOWNTO 0 );
      m_axi_host_mem_arprot      : OUT STD_LOGIC_VECTOR ( 2 DOWNTO 0 );
      m_axi_host_mem_arqos       : OUT STD_LOGIC_VECTOR ( 3 DOWNTO 0 );
      m_axi_host_mem_arready     : IN  STD_LOGIC;
      m_axi_host_mem_arregion    : OUT STD_LOGIC_VECTOR ( 3 DOWNTO 0 );
      m_axi_host_mem_arsize      : OUT STD_LOGIC_VECTOR ( 2 DOWNTO 0 );
      m_axi_host_mem_aruser      : OUT STD_LOGIC_VECTOR ( C_AXI_HOST_MEM_ARUSER_WIDTH-1 DOWNTO 0 );
      m_axi_host_mem_arvalid     : OUT STD_LOGIC;
      m_axi_host_mem_awaddr      : OUT STD_LOGIC_VECTOR ( C_AXI_HOST_MEM_ADDR_WIDTH-1 DOWNTO 0 );
      m_axi_host_mem_awburst     : OUT STD_LOGIC_VECTOR ( 1 DOWNTO 0 );
      m_axi_host_mem_awcache     : OUT STD_LOGIC_VECTOR ( 3 DOWNTO 0 );
      m_axi_host_mem_awid        : OUT STD_LOGIC_VECTOR ( C_AXI_HOST_MEM_ID_WIDTH-1 DOWNTO 0 );
      m_axi_host_mem_awlen       : OUT STD_LOGIC_VECTOR ( 7 DOWNTO 0 );
      m_axi_host_mem_awlock      : OUT STD_LOGIC_VECTOR ( 1 DOWNTO 0 );
      m_axi_host_mem_awprot      : OUT STD_LOGIC_VECTOR ( 2 DOWNTO 0 );
      m_axi_host_mem_awqos       : OUT STD_LOGIC_VECTOR ( 3 DOWNTO 0 );
      m_axi_host_mem_awready     : IN  STD_LOGIC;
      m_axi_host_mem_awregion    : OUT STD_LOGIC_VECTOR ( 3 DOWNTO 0 );
      m_axi_host_mem_awsize      : OUT STD_LOGIC_VECTOR ( 2 DOWNTO 0 );
      m_axi_host_mem_awuser      : OUT STD_LOGIC_VECTOR ( C_AXI_HOST_MEM_AWUSER_WIDTH-1 DOWNTO 0 );
      m_axi_host_mem_awvalid     : OUT STD_LOGIC;
      m_axi_host_mem_bid         : IN  STD_LOGIC_VECTOR ( C_AXI_HOST_MEM_ID_WIDTH-1 DOWNTO 0 );
      m_axi_host_mem_bready      : OUT STD_LOGIC;
      m_axi_host_mem_bresp       : IN  STD_LOGIC_VECTOR ( 1 DOWNTO 0 );
      m_axi_host_mem_buser       : IN  STD_LOGIC_VECTOR ( C_AXI_HOST_MEM_BUSER_WIDTH-1 DOWNTO 0 );
      m_axi_host_mem_bvalid      : IN  STD_LOGIC;
      m_axi_host_mem_rdata       : IN  STD_LOGIC_VECTOR ( C_AXI_HOST_MEM_DATA_WIDTH-1 DOWNTO 0 );
      m_axi_host_mem_rid         : IN  STD_LOGIC_VECTOR ( C_AXI_HOST_MEM_ID_WIDTH-1 DOWNTO 0 );
      m_axi_host_mem_rlast       : IN  STD_LOGIC;
      m_axi_host_mem_rready      : OUT STD_LOGIC;
      m_axi_host_mem_rresp       : IN  STD_LOGIC_VECTOR ( 1 DOWNTO 0 );
      m_axi_host_mem_ruser       : IN  STD_LOGIC_VECTOR ( C_AXI_HOST_MEM_RUSER_WIDTH-1 DOWNTO 0 );
      m_axi_host_mem_rvalid      : IN  STD_LOGIC;
      m_axi_host_mem_wdata       : OUT STD_LOGIC_VECTOR ( C_AXI_HOST_MEM_DATA_WIDTH-1 DOWNTO 0 );
      m_axi_host_mem_wlast       : OUT STD_LOGIC;
      m_axi_host_mem_wready      : IN  STD_LOGIC;
      m_axi_host_mem_wstrb       : OUT STD_LOGIC_VECTOR ( (C_AXI_HOST_MEM_DATA_WIDTH/8)-1 DOWNTO 0 );
      m_axi_host_mem_wuser       : OUT STD_LOGIC_VECTOR ( C_AXI_HOST_MEM_WUSER_WIDTH-1 DOWNTO 0 );
      m_axi_host_mem_wvalid      : OUT STD_LOGIC
    );
  END COMPONENT;

-- only for BRAM_USED=TRUE  --                                                                                      
-- only for BRAM_USED=TRUE  -- BLOCK RAM                                                                            
-- only for BRAM_USED=TRUE  --                                                                                      
-- only for BRAM_USED=TRUE  COMPONENT block_RAM                                                                     
-- only for BRAM_USED=TRUE    PORT (                                                                                
-- only for BRAM_USED=TRUE      s_aclk              : IN  STD_LOGIC;                                                
-- only for BRAM_USED=TRUE      s_aresetn           : IN  STD_LOGIC;                                                
-- only for BRAM_USED=TRUE      s_axi_awid          : IN  STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);    
-- only for BRAM_USED=TRUE      s_axi_awaddr        : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);                            
-- only for BRAM_USED=TRUE      s_axi_awlen         : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);                             
-- only for BRAM_USED=TRUE      s_axi_awsize        : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);                             
-- only for BRAM_USED=TRUE      s_axi_awburst       : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);                             
-- only for BRAM_USED=TRUE      s_axi_awvalid       : IN  STD_LOGIC;                                                
-- only for BRAM_USED=TRUE      s_axi_awready       : OUT STD_LOGIC;                                                
-- only for BRAM_USED=TRUE      s_axi_wdata         : IN  STD_LOGIC_VECTOR(255 DOWNTO 0);                           
-- only for BRAM_USED=TRUE      s_axi_wstrb         : IN  STD_LOGIC_VECTOR((C_AXI_HOST_MEM_DATA_WIDTH/16)-1 DOWNTO 0); 
-- only for BRAM_USED=TRUE      s_axi_wlast         : IN  STD_LOGIC;                                                
-- only for BRAM_USED=TRUE      s_axi_wvalid        : IN  STD_LOGIC;                                                
-- only for BRAM_USED=TRUE      s_axi_wready        : OUT STD_LOGIC;                                                
-- only for BRAM_USED=TRUE      s_axi_bid           : OUT STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);    
-- only for BRAM_USED=TRUE      s_axi_bresp         : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);                             
-- only for BRAM_USED=TRUE      s_axi_bvalid        : OUT STD_LOGIC;                                                
-- only for BRAM_USED=TRUE      s_axi_bready        : IN  STD_LOGIC;                                                
-- only for BRAM_USED=TRUE      s_axi_arid          : IN  STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);   
-- only for BRAM_USED=TRUE      s_axi_araddr        : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);                            
-- only for BRAM_USED=TRUE      s_axi_arlen         : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);                             
-- only for BRAM_USED=TRUE      s_axi_arsize        : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);                             
-- only for BRAM_USED=TRUE      s_axi_arburst       : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);                             
-- only for BRAM_USED=TRUE      s_axi_arvalid       : IN  STD_LOGIC;                                                
-- only for BRAM_USED=TRUE      s_axi_arready       : OUT STD_LOGIC;                                                
-- only for BRAM_USED=TRUE      s_axi_rid           : OUT STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);     
-- only for BRAM_USED=TRUE      s_axi_rdata         : OUT STD_LOGIC_VECTOR(255 DOWNTO 0);                           
-- only for BRAM_USED=TRUE      s_axi_rresp         : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);                             
-- only for BRAM_USED=TRUE      s_axi_rlast         : OUT STD_LOGIC;                                                
-- only for BRAM_USED=TRUE      s_axi_rvalid        : OUT STD_LOGIC;                                                
-- only for BRAM_USED=TRUE      s_axi_rready        : IN  STD_LOGIC                                                 
-- only for BRAM_USED=TRUE    );                                                                                    
-- only for BRAM_USED=TRUE  END COMPONENT;                                                                          

  --                                                                                      -- only for DDR3_USED=TRUE
  -- AXI Clock converter                                                                  -- only for DDR3_USED=TRUE
  --                                                                                      -- only for DDR3_USED=TRUE
  COMPONENT axi_clock_converter                                                           -- only for DDR3_USED=TRUE
    PORT (                                                                                -- only for DDR3_USED=TRUE
      s_axi_aclk      : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      s_axi_aresetn   : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      s_axi_awid      : IN  STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);        -- only for DDR3_USED=TRUE
      s_axi_awaddr    : IN  STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ADDR_WIDTH-1 DOWNTO 0);      -- only for DDR3_USED=TRUE
      s_axi_awlen     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_awsize    : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_awburst   : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_awlock    : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_awcache   : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_awprot    : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_awregion  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_awqos     : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_awvalid   : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      s_axi_awready   : OUT STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      s_axi_wdata     : IN  STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_DATA_WIDTH-1 DOWNTO 0);      -- only for DDR3_USED=TRUE
      s_axi_wstrb     : IN  STD_LOGIC_VECTOR((C_AXI_CARD_MEM0_DATA_WIDTH/8)-1 DOWNTO 0);  -- only for DDR3_USED=TRUE
      s_axi_wlast     : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      s_axi_wvalid    : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      s_axi_wready    : OUT STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      s_axi_bid       : OUT STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);        -- only for DDR3_USED=TRUE
      s_axi_bresp     : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_bvalid    : OUT STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      s_axi_bready    : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      s_axi_arid      : IN  STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);        -- only for DDR3_USED=TRUE
      s_axi_araddr    : IN  STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ADDR_WIDTH-1 DOWNTO 0);      -- only for DDR3_USED=TRUE
      s_axi_arlen     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_arsize    : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_arburst   : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_arlock    : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_arcache   : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_arprot    : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_arregion  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_arqos     : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_arvalid   : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      s_axi_arready   : OUT STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      s_axi_rid       : OUT STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);        -- only for DDR3_USED=TRUE
      s_axi_rdata     : OUT STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_DATA_WIDTH-1 DOWNTO 0);      -- only for DDR3_USED=TRUE
      s_axi_rresp     : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      s_axi_rlast     : OUT STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      s_axi_rvalid    : OUT STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      s_axi_rready    : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      m_axi_aclk      : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      m_axi_aresetn   : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      m_axi_awid      : OUT STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);        -- only for DDR3_USED=TRUE
      m_axi_awaddr    : OUT STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ADDR_WIDTH-1 DOWNTO 0);      -- only for DDR3_USED=TRUE
      m_axi_awlen     : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_awsize    : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_awburst   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_awlock    : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_awcache   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_awprot    : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_awregion  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_awqos     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_awvalid   : OUT STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      m_axi_awready   : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      m_axi_wdata     : OUT STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_DATA_WIDTH-1 DOWNTO 0);      -- only for DDR3_USED=TRUE
      m_axi_wstrb     : OUT STD_LOGIC_VECTOR((C_AXI_CARD_MEM0_DATA_WIDTH/8)-1 DOWNTO 0);  -- only for DDR3_USED=TRUE
      m_axi_wlast     : OUT STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      m_axi_wvalid    : OUT STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      m_axi_wready    : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      m_axi_bid       : IN  STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);        -- only for DDR3_USED=TRUE
      m_axi_bresp     : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_bvalid    : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      m_axi_bready    : OUT STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      m_axi_arid      : OUT STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);        -- only for DDR3_USED=TRUE
      m_axi_araddr    : OUT STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ADDR_WIDTH-1 DOWNTO 0);      -- only for DDR3_USED=TRUE
      m_axi_arlen     : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_arsize    : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_arburst   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_arlock    : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_arcache   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_arprot    : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_arregion  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_arqos     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_arvalid   : OUT STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      m_axi_arready   : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      m_axi_rid       : IN  STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);        -- only for DDR3_USED=TRUE
      m_axi_rdata     : IN  STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_DATA_WIDTH-1 DOWNTO 0);      -- only for DDR3_USED=TRUE
      m_axi_rresp     : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);                                 -- only for DDR3_USED=TRUE
      m_axi_rlast     : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      m_axi_rvalid    : IN  STD_LOGIC;                                                    -- only for DDR3_USED=TRUE
      m_axi_rready    : OUT STD_LOGIC                                                     -- only for DDR3_USED=TRUE
    );                                                                                    -- only for DDR3_USED=TRUE
  END COMPONENT;                                                                          -- only for DDR3_USED=TRUE

   --                                                                                                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
   -- DDR3 RAM                                                                                                   -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
   --                                                                                                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
   COMPONENT ddr3sdram                                                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
     PORT (                                                                                                      -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_init_calib_complete       : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_sys_clk_p                 : IN    STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_sys_clk_n                 : IN    STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_addr                 : OUT   STD_LOGIC_VECTOR(15 DOWNTO 0);                                       -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_ba                   : OUT   STD_LOGIC_VECTOR(2 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_cas_n                : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_cke                  : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_ck_n                 : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_ck_p                 : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_cs_n                 : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_dq                   : INOUT STD_LOGIC_VECTOR(71 DOWNTO 0);                                       -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_dqs_n                : INOUT STD_LOGIC_VECTOR(8 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_dqs_p                : INOUT STD_LOGIC_VECTOR(8 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_odt                  : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_ras_n                : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_reset_n              : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_we_n                 : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_ui_clk               : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_ui_clk_sync_rst      : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_aresetn              : IN    STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_awvalid   : IN    STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_awready   : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_awaddr    : IN    STD_LOGIC_VECTOR(C_AXI_CTRL_REG_ADDR_WIDTH-1 DOWNTO 0);              -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_wvalid    : IN    STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_wready    : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_wdata     : IN    STD_LOGIC_VECTOR(C_AXI_CTRL_REG_DATA_WIDTH-1 DOWNTO 0);              -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_bvalid    : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_bready    : IN    STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_bresp     : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_arvalid   : IN    STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_arready   : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_araddr    : IN    STD_LOGIC_VECTOR(C_AXI_CTRL_REG_ADDR_WIDTH-1 DOWNTO 0);              -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_rvalid    : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_rready    : IN    STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_rdata     : OUT   STD_LOGIC_VECTOR(C_AXI_CTRL_REG_DATA_WIDTH-1 DOWNTO 0);              -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_rresp     : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_interrupt            : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awid           : IN    STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);               -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awaddr         : IN    STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ADDR_WIDTH-1 DOWNTO 0);             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awlen          : IN    STD_LOGIC_VECTOR(7 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awsize         : IN    STD_LOGIC_VECTOR(2 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awburst        : IN    STD_LOGIC_VECTOR(1 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awlock         : IN    STD_LOGIC_VECTOR(0 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awcache        : IN    STD_LOGIC_VECTOR(3 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awprot         : IN    STD_LOGIC_VECTOR(2 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awqos          : IN    STD_LOGIC_VECTOR(3 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awvalid        : IN    STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awready        : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_wdata          : IN    STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_DATA_WIDTH-1 DOWNTO 0);             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_wstrb          : IN    STD_LOGIC_VECTOR((C_AXI_CARD_MEM0_DATA_WIDTH/8)-1 DOWNTO 0);         -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_wlast          : IN    STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_wvalid         : IN    STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_wready         : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_bready         : IN    STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_bid            : OUT   STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);               -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_bresp          : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_bvalid         : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arid           : IN    STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);               -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_araddr         : IN    STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ADDR_WIDTH-1 DOWNTO 0);             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arlen          : IN    STD_LOGIC_VECTOR(7 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arsize         : IN    STD_LOGIC_VECTOR(2 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arburst        : IN    STD_LOGIC_VECTOR(1 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arlock         : IN    STD_LOGIC_VECTOR(0 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arcache        : IN    STD_LOGIC_VECTOR(3 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arprot         : IN    STD_LOGIC_VECTOR(2 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arqos          : IN    STD_LOGIC_VECTOR(3 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arvalid        : IN    STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arready        : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_rready         : IN    STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_rlast          : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_rvalid         : OUT   STD_LOGIC;                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_rresp          : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_rid            : OUT   STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0);               -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_rdata          : OUT   STD_LOGIC_VECTOR(C_AXI_CARD_MEM0_DATA_WIDTH-1 DOWNTO 0);             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
        sys_rst                      : IN    STD_LOGIC                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
      );                                                                                                         -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
    END COMPONENT;                                                                                               -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE

    CONSTANT OWN_W16ESB8G8M : usodimm_part_t := (                                                                                 -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
      base_chip  => ( -- Generic DDR3-1600 x8 chip, 4 Gbit, 260 ns tRFC, CL11                                                     -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
                      part_size              => M64_X_B8_X_D8,                                                                    -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
                      speed_grade_cl_cwl_min => MT41K_125E_CL_CWL_MIN,  -- 125E with CL=5,6,7,8,9,10,11                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
                      speed_grade_cl_cwl_max => MT41K_125E_CL_CWL_MAX,  -- 125E with CL=5,6,7,8,9,10,11                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
                      speed_grade            => MT41K_125E,             -- 125E                                                   -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
                      check_timing           => false                                                                             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
                    ),                                                                                                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
      geometry   => USODIMM_2x72                                                                                                  -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
    );                                                                                                                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
    CONSTANT W16ESB8G8M_AS_2_RANK : usodimm_part_t := (                                                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
      base_chip  => W16ESB8G8M.base_chip, -- Base chip characteristics retained.                                                  -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
      geometry   => USODIMM_2x64          -- Using only one of the two ranks.                                                     -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
    );                                                                                                                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
    CONSTANT usodimm_part : usodimm_part_t :=  OWN_W16ESB8G8M; --choice(mig_ranks = 2, W16ESB8G8M, W16ESB8G8M_AS_1_RANK);         -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE

  CONSTANT sys_clk_period : time := 2.5 ns;                                                                                -- only for DDR3_USED=TRUE
  CONSTANT ref_clk_period : time := 5.0 ns;                                                                                -- only for DDR3_USED=TRUE

  --
  -- SIGNALS
  --

  SIGNAL action_reset               : STD_ULOGIC;
  SIGNAL action_reset_n_q           : STD_ULOGIC;
  SIGNAL action_reset_q             : STD_ULOGIC;
  SIGNAL action_reset_qq            : STD_ULOGIC;
  SIGNAL xk_d                       : XK_D_T;
  SIGNAL kx_d                       : KX_D_T;
  SIGNAL sk_d                       : SK_D_T;
  SIGNAL ks_d                       : KS_D_T;

   SIGNAL c0_ddr3_axi_clk            : STD_ULOGIC;                                                              -- only for DDR3_USED=TRUE
   SIGNAL c0_ddr3_axi_rst_n          : STD_ULOGIC;                                                              -- only for DDR3_USED=TRUE
   SIGNAL ddr3_reset_q               : STD_ULOGIC;                                                              -- only for DDR3_USED=TRUE
   SIGNAL ddr3_reset_n_q             : STD_ULOGIC;                                                              -- only for DDR3_USED=TRUE

  --                                                                                                         -- only for DDR3_USED=TRUE
  -- ACTION <-> CLOCK CONVERTER Interface                                                                    -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_awaddr       : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ADDR_WIDTH-1 DOWNTO 0 );            -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_awlen        : STD_LOGIC_VECTOR ( 7 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_awsize       : STD_LOGIC_VECTOR ( 2 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_awburst      : STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_awlock       : STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_awcache      : STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_awprot       : STD_LOGIC_VECTOR ( 2 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_awregion     : STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_awqos        : STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_awvalid      : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_awready      : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_wdata        : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_DATA_WIDTH-1 DOWNTO 0 );            -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_wstrb        : STD_LOGIC_VECTOR ( (C_AXI_CARD_MEM0_DATA_WIDTH/8)-1 DOWNTO 0 );        -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_wlast        : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_wvalid       : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_wready       : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_bresp        : STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_bvalid       : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_bready       : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_araddr       : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ADDR_WIDTH-1 DOWNTO 0 );            -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_arlen        : STD_LOGIC_VECTOR ( 7 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_arsize       : STD_LOGIC_VECTOR ( 2 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_arburst      : STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_arlock       : STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_arcache      : STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_arprot       : STD_LOGIC_VECTOR ( 2 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_arregion     : STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_arqos        : STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_arvalid      : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_arready      : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_rdata        : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_DATA_WIDTH-1 DOWNTO 0 );            -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_rresp        : STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_rlast        : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_rvalid       : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_rready       : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_arid         : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0 );              -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_awid         : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0 );              -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_bid          : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0 );              -- only for DDR3_USED=TRUE
  SIGNAL axi_card_mem0_rid          : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0 );              -- only for DDR3_USED=TRUE
  --                                                                                                         -- only for DDR3_USED=TRUE
  -- CLOCK CONVERTER <-> DDR3 Interface                                                                      -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_awaddr         : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ADDR_WIDTH-1 DOWNTO 0 );            -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_awlen          : STD_LOGIC_VECTOR ( 7 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_awsize         : STD_LOGIC_VECTOR ( 2 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_awburst        : STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_awlock         : STD_LOGIC_VECTOR ( 0 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_awcache        : STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_awprot         : STD_LOGIC_VECTOR ( 2 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_awregion       : STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_awqos          : STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_awvalid        : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_awready        : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_wdata          : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_DATA_WIDTH-1 DOWNTO 0 );            -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_wstrb          : STD_LOGIC_VECTOR ( (C_AXI_CARD_MEM0_DATA_WIDTH/8)-1 DOWNTO 0 );        -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_wlast          : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_wvalid         : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_wready         : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_bresp          : STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_bvalid         : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_bready         : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_araddr         : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ADDR_WIDTH-1 DOWNTO 0 );            -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_arlen          : STD_LOGIC_VECTOR ( 7 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_arsize         : STD_LOGIC_VECTOR ( 2 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_arburst        : STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_arlock         : STD_LOGIC_VECTOR ( 0 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_arcache        : STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_arprot         : STD_LOGIC_VECTOR ( 2 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_arregion       : STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_arqos          : STD_LOGIC_VECTOR ( 3 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_arvalid        : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_arready        : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_rdata          : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_DATA_WIDTH-1 DOWNTO 0 );            -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_rresp          : STD_LOGIC_VECTOR ( 1 DOWNTO 0 );                                       -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_rlast          : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_rvalid         : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_rready         : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_arid           : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0 );              -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_awid           : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0 );              -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_bid            : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0 );              -- only for DDR3_USED=TRUE
  SIGNAL c0_ddr3_axi_rid            : STD_LOGIC_VECTOR ( C_AXI_CARD_MEM0_ID_WIDTH-1 DOWNTO 0 );              -- only for DDR3_USED=TRUE
  --                                                                                                         -- only for DDR3_USED=TRUE
  -- DDR3 Bank1 Interace                                                                                     -- only for DDR3_USED=TRUE
  SIGNAL c1_init_calib_complete     : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_sys_clk_p               : STD_LOGIC := '0';                                                      -- only for DDR3_USED=TRUE
  SIGNAL c1_sys_clk_n               : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_addr               : STD_LOGIC_VECTOR(15 DOWNTO 0);                                         -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_ba                 : STD_LOGIC_VECTOR(2 DOWNTO 0);                                          -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_cas_n              : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_cke                : STD_LOGIC_VECTOR(1 DOWNTO 0);                                          -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_ck_n               : STD_LOGIC_VECTOR(1 DOWNTO 0);                                          -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_ck_p               : STD_LOGIC_VECTOR(1 DOWNTO 0);                                          -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_cs_n               : STD_LOGIC_VECTOR(1 DOWNTO 0);                                          -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_dm                 : STD_LOGIC_VECTOR(8 DOWNTO 0):= (OTHERS => '0');                        -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_dq                 : STD_LOGIC_VECTOR(71 DOWNTO 0);                                         -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_dqs_n              : STD_LOGIC_VECTOR(8 DOWNTO 0);                                          -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_dqs_p              : STD_LOGIC_VECTOR(8 DOWNTO 0);                                          -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_odt                : STD_LOGIC_VECTOR(1 DOWNTO 0);                                          -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_ras_n              : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_reset_n            : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_we_n               : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL refclk200_p                : STD_LOGIC := '0';                                                      -- only for DDR3_USED=TRUE
  SIGNAL refclk200_n                : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_ui_clk             : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_ui_clk_sync_rst    : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_aresetn            : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL sys_rst                    : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_awvalid : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_awready : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_awaddr  : STD_LOGIC_VECTOR(31 DOWNTO 0);                                         -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_wvalid  : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_wready  : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_wdata   : STD_LOGIC_VECTOR(31 DOWNTO 0);                                         -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_bvalid  : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_bready  : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_bresp   : STD_LOGIC_VECTOR(1 DOWNTO 0);                                          -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_arvalid : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_arready : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_araddr  : STD_LOGIC_VECTOR(31 DOWNTO 0);                                         -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_rvalid  : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_rready  : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_rdata   : STD_LOGIC_VECTOR(31 DOWNTO 0);                                         -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_s_axi_ctrl_rresp   : STD_LOGIC_VECTOR(1 DOWNTO 0);                                          -- only for DDR3_USED=TRUE
  SIGNAL c1_ddr3_interrupt          : STD_LOGIC;                                                             -- only for DDR3_USED=TRUE
  SIGNAL refclk200_ibuf             : std_logic;                                                             -- only for DDR3_USED=TRUE   
  SIGNAL refclk200_bufg             : std_logic;                                                             -- only for DDR3_USED=TRUE   
  signal ddr3_reset_m               : std_logic;                                                             -- only for DDR3_USED=TRUE

BEGIN
  action_reset_reg : PROCESS (ha_pclock)
  BEGIN
    IF (rising_edge(ha_pclock)) THEN
      action_reset_q   <=     action_reset;
      action_reset_qq  <=     action_reset_q;
      action_reset_n_q <= NOT action_reset;
    END IF;
  END PROCESS action_reset_reg;

  ddr3_reset : PROCESS (refclk200_bufg)          -- only for DDR3_USED=TRUE         
  BEGIN  -- PROCESS                              -- only for DDR3_USED=TRUE
    IF (rising_edge(refclk200_bufg)) THEN        -- only for DDR3_USED=TRUE
      IF ((action_reset   = '1') OR              -- only for DDR3_USED=TRUE
          (action_reset_q = '1') or              -- only for DDR3_USED=TRUE
          (action_reset_qq= '1')) THEN           -- only for DDR3_USED=TRUE
        ddr3_reset_m <= '1';                     -- only for DDR3_USED=TRUE
      ELSE                                       -- only for DDR3_USED=TRUE
        ddr3_reset_m <= '0';                     -- only for DDR3_USED=TRUE
      END IF;                                    -- only for DDR3_USED=TRUE
                                                 -- only for DDR3_USED=TRUE
      ddr3_reset_q   <=     ddr3_reset_m;        -- only for DDR3_USED=TRUE
      ddr3_reset_n_q <= NOT ddr3_reset_m;        -- only for DDR3_USED=TRUE
    END IF;                                      -- only for DDR3_USED=TRUE
  END PROCESS ddr3_reset;                        -- only for DDR3_USED=TRUE
                                                 -- only for DDR3_USED=TRUE
                                                 -- only for DDR3_USED=TRUE
  ibuf_refclk200 : IBUFGDS                       -- only for DDR3_USED=TRUE
  port map(                                      -- only for DDR3_USED=TRUE
    I  => refclk200_p,                           -- only for DDR3_USED=TRUE
    IB => refclk200_n,                           -- only for DDR3_USED=TRUE
    O => refclk200_ibuf                          -- only for DDR3_USED=TRUE
  );                                             -- only for DDR3_USED=TRUE
                                                 -- only for DDR3_USED=TRUE 
  bufg_clk : BUFG                                -- only for DDR3_USED=TRUE 
  port map(                                      -- only for DDR3_USED=TRUE 
    I => refclk200_ibuf,                         -- only for DDR3_USED=TRUE 
    O => refclk200_bufg                          -- only for DDR3_USED=TRUE 
  );                                             -- only for DDR3_USED=TRUE  
                                                
                                                 
  
  --                                                                                     -- only for DDR3_USED=TRUE
  --                                                                                     -- only for DDR3_USED=TRUE
  --                                                                                     -- only for DDR3_USED=TRUE
  c1_ddr3_dm <= (OTHERS => '0');                                                         -- only for DDR3_USED=TRUE -- only for BRAM_USED!=TRUE 

  donut_i: donut
    PORT MAP (
      --
      -- PSL Interface
      --
      -- Command interface
      ah_cvalid      => ah_cvalid,
      ah_ctag        => ah_ctag,
      ah_com         => ah_com,
      ah_cabt        => ah_cabt,
      ah_cea         => ah_cea,
      ah_cch         => ah_cch,
      ah_csize       => ah_csize,
      ha_croom       => ha_croom,
      ah_ctagpar     => ah_ctagpar,
      ah_compar      => ah_compar,
      ah_ceapar      => ah_ceapar,
      --
      -- Buffer interface
      ha_brvalid     => ha_brvalid,
      ha_brtag       => ha_brtag,
      ha_brad        => ha_brad,
      ah_brlat       => ah_brlat,
      ah_brdata      => ah_brdata,
      ah_brpar       => ah_brpar,
      ha_bwvalid     => ha_bwvalid,
      ha_bwtag       => ha_bwtag,
      ha_bwad        => ha_bwad,
      ha_bwdata      => ha_bwdata,
      ha_bwpar       => ha_bwpar,
      ha_brtagpar    => ha_brtagpar,
      ha_bwtagpar    => ha_bwtagpar,
      --
      --  Response interface
      ha_rvalid      => ha_rvalid,
      ha_rtag        => ha_rtag,
      ha_response    => ha_response,
      ha_rcredits    => ha_rcredits,
      ha_rcachestate => ha_rcachestate,
      ha_rcachepos   => ha_rcachepos,
      ha_rtagpar     => ha_rtagpar,
      --
      -- MMIO interface
      ha_mmval       => ha_mmval,
      ha_mmrnw       => ha_mmrnw,
      ha_mmdw        => ha_mmdw,
      ha_mmad        => ha_mmad,
      ha_mmdata      => ha_mmdata,
      ha_mmcfg       => ha_mmcfg,
      ah_mmack       => ah_mmack,
      ah_mmdata      => ah_mmdata,
      ha_mmadpar     => ha_mmadpar,
      ha_mmdatapar   => ha_mmdatapar,
      ah_mmdatapar   => ah_mmdatapar,
      --
      -- Control interface
      ha_jval        => ha_jval,
      ha_jcom        => ha_jcom,
      ha_jea         => ha_jea,
      ah_jrunning    => ah_jrunning,
      ah_jdone       => ah_jdone,
      ah_jcack       => ah_jcack,
      ah_jerror      => ah_jerror,
      ah_tbreq       => ah_tbreq,
      ah_jyield      => ah_jyield,
      ha_jeapar      => ha_jeapar,
      ha_jcompar     => ha_jcompar,
      ah_paren       => ah_paren,
      ha_pclock      => ha_pclock,
      --
      -- ACTION Interface
      --
      -- misc
      action_reset   => action_reset,
      --
      -- Kernel AXI Master Interface
      xk_d_o         => xk_d,
      kx_d_i         => kx_d,
      --
      -- Kernel AXI Slave Interface
      sk_d_o         => sk_d,
      ks_d_i         => ks_d
    );

  --
  -- ACTION
  --
  action_w: action_wrapper
    GENERIC MAP (
      -- Parameters for Axi Master Bus Interface AXI_CARD_MEM0 : to DDR memory
      C_M_AXI_CARD_MEM0_ID_WIDTH       => C_AXI_CARD_MEM0_ID_WIDTH,
      C_M_AXI_CARD_MEM0_ADDR_WIDTH     => C_AXI_CARD_MEM0_ADDR_WIDTH,
      C_M_AXI_CARD_MEM0_DATA_WIDTH     => C_AXI_CARD_MEM0_DATA_WIDTH,
      C_M_AXI_CARD_MEM0_AWUSER_WIDTH   => C_AXI_CARD_MEM0_AWUSER_WIDTH,
      C_M_AXI_CARD_MEM0_ARUSER_WIDTH   => C_AXI_CARD_MEM0_ARUSER_WIDTH,
      C_M_AXI_CARD_MEM0_WUSER_WIDTH    => C_AXI_CARD_MEM0_WUSER_WIDTH,
      C_M_AXI_CARD_MEM0_RUSER_WIDTH    => C_AXI_CARD_MEM0_RUSER_WIDTH,
      C_M_AXI_CARD_MEM0_BUSER_WIDTH    => C_AXI_CARD_MEM0_BUSER_WIDTH,

      -- Parameters for Axi Slave Bus Interface AXI_CTRL_REG
      C_S_AXI_CTRL_REG_DATA_WIDTH      => C_AXI_CTRL_REG_DATA_WIDTH,
      C_S_AXI_CTRL_REG_ADDR_WIDTH      => C_AXI_CTRL_REG_ADDR_WIDTH,

      -- Parameters for Axi Master Bus Interface AXI_HOST_MEM : to Host memory
      C_M_AXI_HOST_MEM_ID_WIDTH        => C_AXI_HOST_MEM_ID_WIDTH,
      C_M_AXI_HOST_MEM_ADDR_WIDTH      => C_AXI_HOST_MEM_ADDR_WIDTH,
      C_M_AXI_HOST_MEM_DATA_WIDTH      => C_AXI_HOST_MEM_DATA_WIDTH,
      C_M_AXI_HOST_MEM_AWUSER_WIDTH    => C_AXI_HOST_MEM_AWUSER_WIDTH,
      C_M_AXI_HOST_MEM_ARUSER_WIDTH    => C_AXI_HOST_MEM_ARUSER_WIDTH,
      C_M_AXI_HOST_MEM_WUSER_WIDTH     => C_AXI_HOST_MEM_WUSER_WIDTH,
      C_M_AXI_HOST_MEM_RUSER_WIDTH     => C_AXI_HOST_MEM_RUSER_WIDTH,
      C_M_AXI_HOST_MEM_BUSER_WIDTH     => C_AXI_HOST_MEM_BUSER_WIDTH
    )
    PORT MAP (
      ap_clk                               => ha_pclock,
      ap_rst_n                             => action_reset_n_q,
       --                                                                                   -- only for DDR3_USED=TRUE
       -- AXI DDR3 Interface                                                                -- only for DDR3_USED=TRUE
       m_axi_card_mem0_araddr               => axi_card_mem0_araddr,                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arburst              => axi_card_mem0_arburst,                       -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arcache              => axi_card_mem0_arcache,                       -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arid                 => axi_card_mem0_arid,                          -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arlen                => axi_card_mem0_arlen,                         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arlock               => axi_card_mem0_arlock,                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arprot               => axi_card_mem0_arprot,                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arqos                => axi_card_mem0_arqos,                         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arready              => axi_card_mem0_arready,                       -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arregion             => axi_card_mem0_arregion,                      -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arsize               => axi_card_mem0_arsize,                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_aruser               => OPEN,                                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_arvalid              => axi_card_mem0_arvalid,                       -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awaddr               => axi_card_mem0_awaddr,                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awburst              => axi_card_mem0_awburst,                       -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awcache              => axi_card_mem0_awcache,                       -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awid                 => axi_card_mem0_awid,                          -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awlen                => axi_card_mem0_awlen,                         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awlock               => axi_card_mem0_awlock,                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awprot               => axi_card_mem0_awprot,                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awqos                => axi_card_mem0_awqos,                         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awready              => axi_card_mem0_awready,                       -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awregion             => axi_card_mem0_awregion,                      -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awsize               => axi_card_mem0_awsize,                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awuser               => OPEN,                                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_awvalid              => axi_card_mem0_awvalid,                       -- only for DDR3_USED=TRUE
       m_axi_card_mem0_bid                  => axi_card_mem0_bid,                           -- only for DDR3_USED=TRUE
       m_axi_card_mem0_bready               => axi_card_mem0_bready,                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_bresp                => axi_card_mem0_bresp,                         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_buser                => (OTHERS => '0'),                             -- only for DDR3_USED=TRUE
       m_axi_card_mem0_bvalid               => axi_card_mem0_bvalid,                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_rdata                => axi_card_mem0_rdata,                         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_rid                  => axi_card_mem0_rid,                           -- only for DDR3_USED=TRUE
       m_axi_card_mem0_rlast                => axi_card_mem0_rlast,                         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_rready               => axi_card_mem0_rready,                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_rresp                => axi_card_mem0_rresp,                         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_ruser                => (OTHERS => '0'),                             -- only for DDR3_USED=TRUE
       m_axi_card_mem0_rvalid               => axi_card_mem0_rvalid,                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_wdata                => axi_card_mem0_wdata,                         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_wlast                => axi_card_mem0_wlast,                         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_wready               => axi_card_mem0_wready,                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_wstrb                => axi_card_mem0_wstrb,                         -- only for DDR3_USED=TRUE
       m_axi_card_mem0_wuser                => OPEN,                                        -- only for DDR3_USED=TRUE
       m_axi_card_mem0_wvalid               => axi_card_mem0_wvalid,                        -- only for DDR3_USED=TRUE
      --
      -- AXI Control Register Interface
      s_axi_ctrl_reg_araddr                => xk_d.m_axi_araddr,
      s_axi_ctrl_reg_arready               => kx_d.m_axi_arready,
      s_axi_ctrl_reg_arvalid               => xk_d.m_axi_arvalid,
      s_axi_ctrl_reg_awaddr                => xk_d.m_axi_awaddr,
      s_axi_ctrl_reg_awready               => kx_d.m_axi_awready,
      s_axi_ctrl_reg_awvalid               => xk_d.m_axi_awvalid,
      s_axi_ctrl_reg_bready                => xk_d.m_axi_bready,
      s_axi_ctrl_reg_bresp                 => kx_d.m_axi_bresp,
      s_axi_ctrl_reg_bvalid                => kx_d.m_axi_bvalid,
      s_axi_ctrl_reg_rdata                 => kx_d.m_axi_rdata,
      s_axi_ctrl_reg_rready                => xk_d.m_axi_rready,
      s_axi_ctrl_reg_rresp                 => kx_d.m_axi_rresp,
      s_axi_ctrl_reg_rvalid                => kx_d.m_axi_rvalid,
      s_axi_ctrl_reg_wdata                 => xk_d.m_axi_wdata,
      s_axi_ctrl_reg_wready                => kx_d.m_axi_wready,
      s_axi_ctrl_reg_wstrb                 => xk_d.m_axi_wstrb,
      s_axi_ctrl_reg_wvalid                => xk_d.m_axi_wvalid,
      interrupt                            => OPEN,
      --
      -- AXI Host Memory Interface
      m_axi_host_mem_araddr                => ks_d.s_axi_araddr(C_AXI_HOST_MEM_ADDR_WIDTH-1 DOWNTO 0),
      m_axi_host_mem_arburst               => ks_d.s_axi_arburst,
      m_axi_host_mem_arcache               => ks_d.s_axi_arcache,
      m_axi_host_mem_arid                  => ks_d.s_axi_arid(C_AXI_HOST_MEM_ID_WIDTH-1 DOWNTO 0),
      m_axi_host_mem_arlen                 => ks_d.s_axi_arlen,
      m_axi_host_mem_arlock                => OPEN,
      m_axi_host_mem_arprot                => ks_d.s_axi_arprot,
      m_axi_host_mem_arqos                 => ks_d.s_axi_arqos,
      m_axi_host_mem_arready               => sk_d.s_axi_arready,
      m_axi_host_mem_arregion              => OPEN,
      m_axi_host_mem_arsize                => ks_d.s_axi_arsize,
      m_axi_host_mem_aruser                => OPEN,
      m_axi_host_mem_arvalid               => ks_d.s_axi_arvalid,
      m_axi_host_mem_awaddr                => ks_d.s_axi_awaddr(C_AXI_HOST_MEM_ADDR_WIDTH-1 DOWNTO 0),
      m_axi_host_mem_awburst               => ks_d.s_axi_awburst,
      m_axi_host_mem_awcache               => ks_d.s_axi_awcache,
      m_axi_host_mem_awid                  => ks_d.s_axi_awid(C_AXI_HOST_MEM_ID_WIDTH-1 DOWNTO 0),
      m_axi_host_mem_awlen                 => ks_d.s_axi_awlen,
      m_axi_host_mem_awlock                => OPEN,
      m_axi_host_mem_awprot                => ks_d.s_axi_awprot,
      m_axi_host_mem_awqos                 => ks_d.s_axi_awqos,
      m_axi_host_mem_awready               => sk_d.s_axi_awready,
      m_axi_host_mem_awregion              => OPEN,
      m_axi_host_mem_awsize                => ks_d.s_axi_awsize,
      m_axi_host_mem_awuser                => OPEN,
      m_axi_host_mem_awvalid               => ks_d.s_axi_awvalid,
      m_axi_host_mem_bid                   => sk_d.s_axi_bid(C_AXI_HOST_MEM_ID_WIDTH-1 DOWNTO 0),
      m_axi_host_mem_bready                => ks_d.s_axi_bready,
      m_axi_host_mem_bresp                 => sk_d.s_axi_bresp,
      m_axi_host_mem_buser                 => (OTHERS => '0'),
      m_axi_host_mem_bvalid                => sk_d.s_axi_bvalid,
      m_axi_host_mem_rdata                 => sk_d.s_axi_rdata,
      m_axi_host_mem_rid                   => sk_d.s_axi_rid(C_AXI_HOST_MEM_ID_WIDTH-1 DOWNTO 0),
      m_axi_host_mem_rlast                 => sk_d.s_axi_rlast,
      m_axi_host_mem_rready                => ks_d.s_axi_rready,
      m_axi_host_mem_rresp                 => sk_d.s_axi_rresp,
      m_axi_host_mem_ruser                 => (OTHERS => '0'),
      m_axi_host_mem_rvalid                => sk_d.s_axi_rvalid,
      m_axi_host_mem_wdata                 => ks_d.s_axi_wdata(C_AXI_HOST_MEM_DATA_WIDTH-1 DOWNTO 0),
      m_axi_host_mem_wlast                 => ks_d.s_axi_wlast,
      m_axi_host_mem_wready                => sk_d.s_axi_wready,
      m_axi_host_mem_wstrb                 => ks_d.s_axi_wstrb((C_AXI_HOST_MEM_DATA_WIDTH/8)-1 DOWNTO 0),
      m_axi_host_mem_wuser                 => OPEN,
      m_axi_host_mem_wvalid                => ks_d.s_axi_wvalid
    );

   --                                                                                       -- only for DDR3_USED=TRUE
   -- DDR3                                                                                  -- only for DDR3_USED=TRUE
   --                                                                                       -- only for DDR3_USED=TRUE
   c1_sys_clk_p <= TRANSPORT NOT c1_sys_clk_p AFTER sys_clk_period / 2;                     -- only for DDR3_USED=TRUE
   c1_sys_clk_n <= NOT c1_sys_clk_p;                                                        -- only for DDR3_USED=TRUE
   refclk200_p  <= TRANSPORT NOT refclk200_p  AFTER ref_clk_period / 2;                     -- only for DDR3_USED=TRUE
   refclk200_n  <= NOT refclk200_p;                                                         -- only for DDR3_USED=TRUE

   c1_ddr3_s_axi_ctrl_awvalid   <= '0';                                                     -- only for DDR3_USED=TRUE
   c1_ddr3_s_axi_ctrl_awaddr    <= (OTHERS => '0');                                         -- only for DDR3_USED=TRUE
   c1_ddr3_s_axi_ctrl_wvalid    <= '0';                                                     -- only for DDR3_USED=TRUE
   c1_ddr3_s_axi_ctrl_wdata     <= (OTHERS => '0');                                         -- only for DDR3_USED=TRUE
   c1_ddr3_s_axi_ctrl_bready    <= '0';                                                     -- only for DDR3_USED=TRUE
   c1_ddr3_s_axi_ctrl_arvalid   <= '0';                                                     -- only for DDR3_USED=TRUE
   c1_ddr3_s_axi_ctrl_araddr    <= (OTHERS => '0');                                         -- only for DDR3_USED=TRUE
   c1_ddr3_s_axi_ctrl_rready    <= '0';                                                     -- only for DDR3_USED=TRUE

   c0_ddr3_axi_clk   <=     c1_ddr3_ui_clk;                                                 -- only for DDR3_USED=TRUE -- only for BRAM_USED!=TRUE
   c0_ddr3_axi_rst_n <= NOT c1_ddr3_ui_clk_sync_rst;                                        -- only for DDR3_USED=TRUE -- only for BRAM_USED!=TRUE

-- only for BRAM_USED=TRUE   c0_ddr3_axi_clk   <= refclk200_bufg;                                                      -- only for DDR3_USED=TRUE 
-- only for BRAM_USED=TRUE   c0_ddr3_axi_rst_n <= ddr3_reset_n_q;                                                      -- only for DDR3_USED=TRUE 

   axi_clock_converter_i : axi_clock_converter                                              -- only for DDR3_USED=TRUE
     PORT MAP (                                                                             -- only for DDR3_USED=TRUE
       s_axi_aclk      => ha_pclock,                                                        -- only for DDR3_USED=TRUE
       s_axi_aresetn   => action_reset_n_q,                                                 -- only for DDR3_USED=TRUE
       m_axi_aclk      => c0_ddr3_axi_clk,                                                  -- only for DDR3_USED=TRUE
       m_axi_aresetn   => c0_ddr3_axi_rst_n,                                                -- only for DDR3_USED=TRUE
       --                                                                                   -- only for DDR3_USED=TRUE
       -- FROM ACTION                                                                       -- only for DDR3_USED=TRUE
       s_axi_araddr    => axi_card_mem0_araddr,                                             -- only for DDR3_USED=TRUE
       s_axi_arburst   => axi_card_mem0_arburst,                                            -- only for DDR3_USED=TRUE
       s_axi_arcache   => axi_card_mem0_arcache,                                            -- only for DDR3_USED=TRUE
       s_axi_arid      => axi_card_mem0_arid,                                               -- only for DDR3_USED=TRUE
       s_axi_arlen     => axi_card_mem0_arlen,                                              -- only for DDR3_USED=TRUE
       s_axi_arlock    => axi_card_mem0_arlock(0 DOWNTO 0),                                 -- only for DDR3_USED=TRUE
       s_axi_arprot    => axi_card_mem0_arprot,                                             -- only for DDR3_USED=TRUE
       s_axi_arqos     => axi_card_mem0_arqos,                                              -- only for DDR3_USED=TRUE
       s_axi_arready   => axi_card_mem0_arready,                                            -- only for DDR3_USED=TRUE
       s_axi_arregion  => axi_card_mem0_arregion,                                           -- only for DDR3_USED=TRUE
       s_axi_arsize    => axi_card_mem0_arsize,                                             -- only for DDR3_USED=TRUE
       s_axi_arvalid   => axi_card_mem0_arvalid,                                            -- only for DDR3_USED=TRUE
       s_axi_awaddr    => axi_card_mem0_awaddr,                                             -- only for DDR3_USED=TRUE
       s_axi_awburst   => axi_card_mem0_awburst,                                            -- only for DDR3_USED=TRUE
       s_axi_awcache   => axi_card_mem0_awcache,                                            -- only for DDR3_USED=TRUE
       s_axi_awid      => axi_card_mem0_awid,                                               -- only for DDR3_USED=TRUE
       s_axi_awlen     => axi_card_mem0_awlen,                                              -- only for DDR3_USED=TRUE
       s_axi_awlock    => axi_card_mem0_awlock(0 DOWNTO 0),                                 -- only for DDR3_USED=TRUE
       s_axi_awprot    => axi_card_mem0_awprot,                                             -- only for DDR3_USED=TRUE
       s_axi_awqos     => axi_card_mem0_awqos,                                              -- only for DDR3_USED=TRUE
       s_axi_awready   => axi_card_mem0_awready,                                            -- only for DDR3_USED=TRUE
       s_axi_awregion  => axi_card_mem0_awregion,                                           -- only for DDR3_USED=TRUE
       s_axi_awsize    => axi_card_mem0_awsize,                                             -- only for DDR3_USED=TRUE
       s_axi_awvalid   => axi_card_mem0_awvalid,                                            -- only for DDR3_USED=TRUE
       s_axi_bid       => axi_card_mem0_bid,                                                -- only for DDR3_USED=TRUE
       s_axi_bready    => axi_card_mem0_bready,                                             -- only for DDR3_USED=TRUE
       s_axi_bresp     => axi_card_mem0_bresp,                                              -- only for DDR3_USED=TRUE
       s_axi_bvalid    => axi_card_mem0_bvalid,                                             -- only for DDR3_USED=TRUE
       s_axi_rdata     => axi_card_mem0_rdata,                                              -- only for DDR3_USED=TRUE
       s_axi_rid       => axi_card_mem0_rid,                                                -- only for DDR3_USED=TRUE
       s_axi_rlast     => axi_card_mem0_rlast,                                              -- only for DDR3_USED=TRUE
       s_axi_rready    => axi_card_mem0_rready,                                             -- only for DDR3_USED=TRUE
       s_axi_rresp     => axi_card_mem0_rresp,                                              -- only for DDR3_USED=TRUE
       s_axi_rvalid    => axi_card_mem0_rvalid,                                             -- only for DDR3_USED=TRUE
       s_axi_wdata     => axi_card_mem0_wdata,                                              -- only for DDR3_USED=TRUE
       s_axi_wlast     => axi_card_mem0_wlast,                                              -- only for DDR3_USED=TRUE
       s_axi_wready    => axi_card_mem0_wready,                                             -- only for DDR3_USED=TRUE
       s_axi_wstrb     => axi_card_mem0_wstrb,                                              -- only for DDR3_USED=TRUE
       s_axi_wvalid    => axi_card_mem0_wvalid,                                             -- only for DDR3_USED=TRUE
       --                                                                                   -- only for DDR3_USED=TRUE
       -- TO DDR3                                                                           -- only for DDR3_USED=TRUE
       m_axi_araddr    => c0_ddr3_axi_araddr,                                               -- only for DDR3_USED=TRUE
       m_axi_arburst   => c0_ddr3_axi_arburst,                                              -- only for DDR3_USED=TRUE
       m_axi_arcache   => c0_ddr3_axi_arcache,                                              -- only for DDR3_USED=TRUE
       m_axi_arid      => c0_ddr3_axi_arid,                                                 -- only for DDR3_USED=TRUE
       m_axi_arlen     => c0_ddr3_axi_arlen,                                                -- only for DDR3_USED=TRUE
       m_axi_arlock    => c0_ddr3_axi_arlock,                                               -- only for DDR3_USED=TRUE
       m_axi_arprot    => c0_ddr3_axi_arprot,                                               -- only for DDR3_USED=TRUE
       m_axi_arqos     => c0_ddr3_axi_arqos,                                                -- only for DDR3_USED=TRUE
       m_axi_arready   => c0_ddr3_axi_arready,                                              -- only for DDR3_USED=TRUE
       m_axi_arregion  => c0_ddr3_axi_arregion,                                             -- only for DDR3_USED=TRUE
       m_axi_arsize    => c0_ddr3_axi_arsize,                                               -- only for DDR3_USED=TRUE
       m_axi_arvalid   => c0_ddr3_axi_arvalid,                                              -- only for DDR3_USED=TRUE
       m_axi_awaddr    => c0_ddr3_axi_awaddr,                                               -- only for DDR3_USED=TRUE
       m_axi_awburst   => c0_ddr3_axi_awburst,                                              -- only for DDR3_USED=TRUE
       m_axi_awcache   => c0_ddr3_axi_awcache,                                              -- only for DDR3_USED=TRUE
       m_axi_awid      => c0_ddr3_axi_awid,                                                 -- only for DDR3_USED=TRUE
       m_axi_awlen     => c0_ddr3_axi_awlen,                                                -- only for DDR3_USED=TRUE
       m_axi_awlock    => c0_ddr3_axi_awlock,                                               -- only for DDR3_USED=TRUE
       m_axi_awprot    => c0_ddr3_axi_awprot,                                               -- only for DDR3_USED=TRUE
       m_axi_awqos     => c0_ddr3_axi_awqos,                                                -- only for DDR3_USED=TRUE
       m_axi_awready   => c0_ddr3_axi_awready,                                              -- only for DDR3_USED=TRUE
       m_axi_awregion  => c0_ddr3_axi_awregion,                                             -- only for DDR3_USED=TRUE
       m_axi_awsize    => c0_ddr3_axi_awsize,                                               -- only for DDR3_USED=TRUE
       m_axi_awvalid   => c0_ddr3_axi_awvalid,                                              -- only for DDR3_USED=TRUE
       m_axi_bid       => c0_ddr3_axi_bid,                                                  -- only for DDR3_USED=TRUE
       m_axi_bready    => c0_ddr3_axi_bready,                                               -- only for DDR3_USED=TRUE
       m_axi_bresp     => c0_ddr3_axi_bresp,                                                -- only for DDR3_USED=TRUE
       m_axi_bvalid    => c0_ddr3_axi_bvalid,                                               -- only for DDR3_USED=TRUE
       m_axi_rdata     => c0_ddr3_axi_rdata,                                                -- only for DDR3_USED=TRUE
       m_axi_rid       => c0_ddr3_axi_rid,                                                  -- only for DDR3_USED=TRUE
       m_axi_rlast     => c0_ddr3_axi_rlast,                                                -- only for DDR3_USED=TRUE
       m_axi_rready    => c0_ddr3_axi_rready,                                               -- only for DDR3_USED=TRUE
       m_axi_rresp     => c0_ddr3_axi_rresp,                                                -- only for DDR3_USED=TRUE
       m_axi_rvalid    => c0_ddr3_axi_rvalid,                                               -- only for DDR3_USED=TRUE
       m_axi_wdata     => c0_ddr3_axi_wdata,                                                -- only for DDR3_USED=TRUE
       m_axi_wlast     => c0_ddr3_axi_wlast,                                                -- only for DDR3_USED=TRUE
       m_axi_wready    => c0_ddr3_axi_wready,                                               -- only for DDR3_USED=TRUE
       m_axi_wstrb     => c0_ddr3_axi_wstrb,                                                -- only for DDR3_USED=TRUE
       m_axi_wvalid    => c0_ddr3_axi_wvalid                                                -- only for DDR3_USED=TRUE
     );                                                                                     -- only for DDR3_USED=TRUE

-- only for BRAM_USED=TRUE    block_ram_i0 : block_RAM                                                              
-- only for BRAM_USED=TRUE      PORT MAP (                                                                          
-- only for BRAM_USED=TRUE        s_aresetn      => c0_ddr3_axi_rst_n,                                              
-- only for BRAM_USED=TRUE        s_aclk         => c0_ddr3_axi_clk,                                                
-- only for BRAM_USED=TRUE        s_axi_araddr   => c0_ddr3_axi_araddr(31 DOWNTO 0),                                
-- only for BRAM_USED=TRUE        s_axi_arburst  => c0_ddr3_axi_arburst(1 DOWNTO 0),                                
-- only for BRAM_USED=TRUE        s_axi_arid     => c0_ddr3_axi_arid,                                               
-- only for BRAM_USED=TRUE        s_axi_arlen    => c0_ddr3_axi_arlen(7 DOWNTO 0),                                  
-- only for BRAM_USED=TRUE        s_axi_arready  => c0_ddr3_axi_arready,                                            
-- only for BRAM_USED=TRUE        s_axi_arsize   => "101",                                                          
-- only for BRAM_USED=TRUE        s_axi_arvalid  => c0_ddr3_axi_arvalid,                                            
-- only for BRAM_USED=TRUE        s_axi_awaddr   => c0_ddr3_axi_awaddr(31 DOWNTO 0),                                
-- only for BRAM_USED=TRUE        s_axi_awburst  => c0_ddr3_axi_awburst(1 DOWNTO 0),                                
-- only for BRAM_USED=TRUE        s_axi_awid     => c0_ddr3_axi_awid,                                               
-- only for BRAM_USED=TRUE        s_axi_awlen    => c0_ddr3_axi_awlen(7 DOWNTO 0),                                  
-- only for BRAM_USED=TRUE        s_axi_awready  => c0_ddr3_axi_awready,                                            
-- only for BRAM_USED=TRUE        s_axi_awsize   => "101",                                 
-- only for BRAM_USED=TRUE        s_axi_awvalid  => c0_ddr3_axi_awvalid,                                            
-- only for BRAM_USED=TRUE        s_axi_bid      => c0_ddr3_axi_bid,                                                
-- only for BRAM_USED=TRUE        s_axi_bready   => c0_ddr3_axi_bready,                                             
-- only for BRAM_USED=TRUE        s_axi_bresp    => c0_ddr3_axi_bresp(1 DOWNTO 0),                                  
-- only for BRAM_USED=TRUE        s_axi_bvalid   => c0_ddr3_axi_bvalid,                                             
-- only for BRAM_USED=TRUE        s_axi_rdata    => c0_ddr3_axi_rdata((C_AXI_CARD_MEM0_DATA_WIDTH/2-1) DOWNTO 0),   
-- only for BRAM_USED=TRUE        s_axi_rid      => c0_ddr3_axi_rid,                                                
-- only for BRAM_USED=TRUE        s_axi_rlast    => c0_ddr3_axi_rlast,                                              
-- only for BRAM_USED=TRUE        s_axi_rready   => c0_ddr3_axi_rready,                                             
-- only for BRAM_USED=TRUE        s_axi_rresp    => c0_ddr3_axi_rresp(1 DOWNTO 0),                                  
-- only for BRAM_USED=TRUE        s_axi_rvalid   => c0_ddr3_axi_rvalid,                                             
-- only for BRAM_USED=TRUE        s_axi_wdata    => c0_ddr3_axi_wdata((C_AXI_CARD_MEM0_DATA_WIDTH/2)-1 DOWNTO 0),   
-- only for BRAM_USED=TRUE        s_axi_wlast    => c0_ddr3_axi_wlast,                                              
-- only for BRAM_USED=TRUE        s_axi_wready   => c0_ddr3_axi_wready,                                             
-- only for BRAM_USED=TRUE        s_axi_wstrb    => c0_ddr3_axi_wstrb((C_AXI_CARD_MEM0_DATA_WIDTH/16)-1 DOWNTO 0),  
-- only for BRAM_USED=TRUE        s_axi_wvalid   => c0_ddr3_axi_wvalid                                              
-- only for BRAM_USED=TRUE      );                                                                                  

-- only for BRAM_USED=TRUE    block_ram_i1 : block_RAM                                                                                         
-- only for BRAM_USED=TRUE      PORT MAP (                                                                                                     
-- only for BRAM_USED=TRUE        s_aresetn      => c0_ddr3_axi_rst_n,                                                                         
-- only for BRAM_USED=TRUE        s_aclk         => c0_ddr3_axi_clk,                                                                           
-- only for BRAM_USED=TRUE        s_axi_araddr   => c0_ddr3_axi_araddr(31 DOWNTO 0),                                                           
-- only for BRAM_USED=TRUE        s_axi_arburst  => c0_ddr3_axi_arburst(1 DOWNTO 0),                                                           
-- only for BRAM_USED=TRUE        s_axi_arid     => c0_ddr3_axi_arid,                                                                          
-- only for BRAM_USED=TRUE        s_axi_arlen    => c0_ddr3_axi_arlen(7 DOWNTO 0),                                                             
-- only for BRAM_USED=TRUE        s_axi_arready  => open,                                                                                      
-- only for BRAM_USED=TRUE        s_axi_arsize   => "101",                                                            
-- only for BRAM_USED=TRUE        s_axi_arvalid  => c0_ddr3_axi_arvalid,                                                                       
-- only for BRAM_USED=TRUE        s_axi_awaddr   => c0_ddr3_axi_awaddr(31 DOWNTO 0),                                                           
-- only for BRAM_USED=TRUE        s_axi_awburst  => c0_ddr3_axi_awburst(1 DOWNTO 0),                                                           
-- only for BRAM_USED=TRUE        s_axi_awid     => c0_ddr3_axi_awid,                                                                          
-- only for BRAM_USED=TRUE        s_axi_awlen    => c0_ddr3_axi_awlen(7 DOWNTO 0),                                                             
-- only for BRAM_USED=TRUE        s_axi_awready  => open,                                                                                      
-- only for BRAM_USED=TRUE        s_axi_awsize   => "101",                                                            
-- only for BRAM_USED=TRUE        s_axi_awvalid  => c0_ddr3_axi_awvalid,                                                                       
-- only for BRAM_USED=TRUE        s_axi_bid      => open,                                                                                      
-- only for BRAM_USED=TRUE        s_axi_bready   => c0_ddr3_axi_bready,                                                                        
-- only for BRAM_USED=TRUE        s_axi_bresp    => open,                                                                                      
-- only for BRAM_USED=TRUE        s_axi_bvalid   => open,                                                                                      
-- only for BRAM_USED=TRUE        s_axi_rdata    => c0_ddr3_axi_rdata(C_AXI_CARD_MEM0_DATA_WIDTH-1 DOWNTO (C_AXI_CARD_MEM0_DATA_WIDTH/2)),     
-- only for BRAM_USED=TRUE        s_axi_rid      => open,                                                                                      
-- only for BRAM_USED=TRUE        s_axi_rlast    => open,                                                                                      
-- only for BRAM_USED=TRUE        s_axi_rready   => c0_ddr3_axi_rready,                                                                        
-- only for BRAM_USED=TRUE        s_axi_rresp    => open,                                                                                      
-- only for BRAM_USED=TRUE        s_axi_rvalid   => open,                                                                                      
-- only for BRAM_USED=TRUE        s_axi_wdata    => c0_ddr3_axi_wdata(C_AXI_CARD_MEM0_DATA_WIDTH-1 DOWNTO (C_AXI_CARD_MEM0_DATA_WIDTH/2)),     
-- only for BRAM_USED=TRUE        s_axi_wlast    => c0_ddr3_axi_wlast,                                                                         
-- only for BRAM_USED=TRUE        s_axi_wready   => open,                                                                                      
-- only for BRAM_USED=TRUE        s_axi_wstrb    => c0_ddr3_axi_wstrb((C_AXI_CARD_MEM0_DATA_WIDTH/8)-1 DOWNTO (C_AXI_CARD_MEM0_DATA_WIDTH/16)), 
-- only for BRAM_USED=TRUE        s_axi_wvalid   => c0_ddr3_axi_wvalid                                                                         
-- only for BRAM_USED=TRUE      );                                                                                                             

   ddr3sdram_bank1 : ddr3sdram                                                               -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
     PORT MAP (                                                                              -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_init_calib_complete       => c1_init_calib_complete,                               -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_sys_clk_p                 => c1_sys_clk_p,                                         -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_sys_clk_n                 => c1_sys_clk_n,                                         -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_addr                 => c1_ddr3_addr,                                         -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_ba                   => c1_ddr3_ba,                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_cas_n                => c1_ddr3_cas_n,                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_cke                  => c1_ddr3_cke,                                          -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_ck_n                 => c1_ddr3_ck_n,                                         -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_ck_p                 => c1_ddr3_ck_p,                                         -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_cs_n                 => c1_ddr3_cs_n,                                         -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       -- c0_ddr3_dm => OPEN, -- ECC DIMM, don't use dm. dm is assigned above.               -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_dq                   => c1_ddr3_dq,                                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_dqs_n                => c1_ddr3_dqs_n,                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_dqs_p                => c1_ddr3_dqs_p,                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_odt                  => c1_ddr3_odt,                                          -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_ras_n                => c1_ddr3_ras_n,                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_reset_n              => c1_ddr3_reset_n,                                      -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_we_n                 => c1_ddr3_we_n,                                         -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_ui_clk               => c1_ddr3_ui_clk,                                       -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_ui_clk_sync_rst      => c1_ddr3_ui_clk_sync_rst,                              -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_aresetn              => ddr3_reset_n_q,                                       -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_interrupt            => c1_ddr3_interrupt,                                    -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_awvalid   => c1_ddr3_s_axi_ctrl_awvalid,                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_awready   => c1_ddr3_s_axi_ctrl_awready,                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_awaddr    => c1_ddr3_s_axi_ctrl_awaddr,                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_wvalid    => c1_ddr3_s_axi_ctrl_wvalid,                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_wready    => c1_ddr3_s_axi_ctrl_wready,                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_wdata     => c1_ddr3_s_axi_ctrl_wdata,                             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_bvalid    => c1_ddr3_s_axi_ctrl_bvalid,                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_bready    => c1_ddr3_s_axi_ctrl_bready,                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_bresp     => c1_ddr3_s_axi_ctrl_bresp,                             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_arvalid   => c1_ddr3_s_axi_ctrl_arvalid,                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_arready   => c1_ddr3_s_axi_ctrl_arready,                           -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_araddr    => c1_ddr3_s_axi_ctrl_araddr,                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_rvalid    => c1_ddr3_s_axi_ctrl_rvalid,                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_rready    => c1_ddr3_s_axi_ctrl_rready,                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_rdata     => c1_ddr3_s_axi_ctrl_rdata,                             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_ctrl_rresp     => c1_ddr3_s_axi_ctrl_rresp,                             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_araddr         => c0_ddr3_axi_araddr(32 DOWNTO 0),                      -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arburst        => c0_ddr3_axi_arburst(1 DOWNTO 0),                      -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arcache        => c0_ddr3_axi_arcache(3 DOWNTO 0),                      -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arid           => c0_ddr3_axi_arid,                                     -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arlen          => c0_ddr3_axi_arlen(7 DOWNTO 0),                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arlock         => c0_ddr3_axi_arlock,                                   -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arprot         => c0_ddr3_axi_arprot(2 DOWNTO 0),                       -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arqos          => c0_ddr3_axi_arqos(3 DOWNTO 0),                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arready        => c0_ddr3_axi_arready,                                  -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arsize         => c0_ddr3_axi_arsize(2 DOWNTO 0),                       -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_arvalid        => c0_ddr3_axi_arvalid,                                  -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awaddr         => c0_ddr3_axi_awaddr(32 DOWNTO 0),                      -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awburst        => c0_ddr3_axi_awburst(1 DOWNTO 0),                      -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awcache        => c0_ddr3_axi_awcache(3 DOWNTO 0),                      -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awid           => c0_ddr3_axi_awid,                                     -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awlen          => c0_ddr3_axi_awlen(7 DOWNTO 0),                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awlock         => c0_ddr3_axi_awlock,                                   -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awprot         => c0_ddr3_axi_awprot(2 DOWNTO 0),                       -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awqos          => c0_ddr3_axi_awqos(3 DOWNTO 0),                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awready        => c0_ddr3_axi_awready,                                  -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awsize         => c0_ddr3_axi_awsize(2 DOWNTO 0),                       -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_awvalid        => c0_ddr3_axi_awvalid,                                  -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_bid            => c0_ddr3_axi_bid,                                      -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_bready         => c0_ddr3_axi_bready,                                   -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_bresp          => c0_ddr3_axi_bresp(1 DOWNTO 0),                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_bvalid         => c0_ddr3_axi_bvalid,                                   -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_rdata          => c0_ddr3_axi_rdata,                                    -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_rid            => c0_ddr3_axi_rid,                                      -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_rlast          => c0_ddr3_axi_rlast,                                    -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_rready         => c0_ddr3_axi_rready,                                   -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_rresp          => c0_ddr3_axi_rresp(1 DOWNTO 0),                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_rvalid         => c0_ddr3_axi_rvalid,                                   -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_wdata          => c0_ddr3_axi_wdata,                                    -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_wlast          => c0_ddr3_axi_wlast,                                    -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_wready         => c0_ddr3_axi_wready,                                   -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_wstrb          => c0_ddr3_axi_wstrb,                                    -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       c0_ddr3_s_axi_wvalid         => c0_ddr3_axi_wvalid,                                   -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       sys_rst                      => ddr3_reset_q                                          -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
     );                                                                                      -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE

   --                                                                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
   -- DDR3 RAM model                                                                         -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
   --                                                                                        -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
   bank1_model : ddr3_sdram_usodimm                                                          -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
     GENERIC MAP(                                                                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       message_level  => 0,                                                                  -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       part           => usodimm_part,                                                       -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       short_init_dly => true,                                                               -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       read_undef_val => 'U'                                                                 -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
     )                                                                                       -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
     PORT MAP(                                                                               -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       ck       => c1_ddr3_ck_p,                                                             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       ck_l     => c1_ddr3_ck_n,                                                             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       reset_l  => c1_ddr3_reset_n,                                                          -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       cke      => c1_ddr3_cke,                                                              -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       cs_l     => c1_ddr3_cs_n,                                                             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       ras_l    => c1_ddr3_ras_n,                                                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       cas_l    => c1_ddr3_cas_n,                                                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       we_l     => c1_ddr3_we_n,                                                             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       odt      => c1_ddr3_odt,                                                              -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       dm       => c1_ddr3_dm,                                                               -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       ba       => c1_ddr3_ba,                                                               -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       a        => c1_ddr3_addr,                                                             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       dq       => c1_ddr3_dq,                                                               -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       dqs      => c1_ddr3_dqs_p,                                                            -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
       dqs_l    => c1_ddr3_dqs_n                                                             -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
     );                                                                                      -- only for DDR3_USED=TRUE-- only for BRAM_USED!=TRUE
END afu;
