library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.action_types.all;
use work.psl_accel_types.all;
use work.fosix_util.all;

package fosix_types is

  -----------------------------------------------------------------------------
  -- AXI Interface Definitions
  -----------------------------------------------------------------------------
  constant C_AXI_LEN_W    : integer := 8;
  type t_AxiLen is unsigned(C_AXI_LEN_W-1 downto 0);

  constant C_AXI_SIZE_W   : integer := 3;
  type t_AxiSize is unsigned(C_AXI_SIZE_W-1 downto 0);

  constant C_AXI_BURST_W  : integer := 2;
  type t_AxiBurst is unsigned(C_AXI_BURST_W-1 downto 0);
  constant c_AxiBurstFixed : t_AxiBurst := "00";
  constant c_AxiBurstIncr : t_AxiBurst := "01";
  constant c_AxiBurstWrap : t_AxiBurst := "10";

  constant C_AXI_LOCK_W  : integer := 2;
  type t_AxiLock is unsigned(C_AXI_LOCK_W-1 downto 0);
  constant c_AxiLockNormal : t_AxiLock := "00";
  constant c_AxiLockExclusive : t_AxiLock := "01";
  constant c_AxiLockLocked : t_AxiLock := "10";

  constant C_AXI_CACHE_W  : integer := 4;
  type t_AxiCache is unsigned(C_AXI_CACHE_W-1 downto 0);

  constant C_AXI_PROT_W   : integer := 3;
  type t_AxiProt is unsigned(C_AXI_PROT_W-1 downto 0);

  constant C_AXI_QOS_W    : integer := 4;
  type t_AxiQos is unsigned(C_AXI_QOS_W-1 downto 0);

  constant C_AXI_REGION_W : integer := 4;
  type t_AxiRegion is unsigned(C_AXI_REGION_W-1 downto 0);

  constant C_AXI_RESP_W : integer := 2;
  type t_AxiResp is unsigned(C_AXI_RESP_W-1 downto 0);
  constant c_AxiRespOkay   : t_AxiResp := "00";
  constant c_AxiRespExOkay : t_AxiResp := "01";
  constant c_AxiRespSlvErr : t_AxiResp := "10";
  constant c_AxiRespDecErr : t_AxiResp := "11";

  -----------------------------------------------------------------------------
  -- Native AXI Interface
  -----------------------------------------------------------------------------

  constant C_AXI_ADDR_W : integer := 64;
  type t_AxiAddr is unsigned(C_AXI_ADDR_W-1 downto 0);

  constant C_AXI_DATA_W : integer := 512;
  type t_AxiData is unsigned(C_AXI_DATA_W-1 downto 0);
  type t_AxiStrb is unsigned(C_AXI_DATA_W/8-1 downto 0);

  -- Transfer Size for Entire Data Bus Width
  constant c_AxiSize : t_AxiSize := to_unsigned(f_clog2(C_AXI_DATA_W/8-1), C_AXI_SIZE_W);
  constant c_AxiDefLock   : t_AxiLock   := c_AxiLockNormal;
  constant c_AxiDefCache  : t_AxiCache  := "0010"; -- Normal, NoCache, NoBuffer
  constant c_AxiDefProt   : t_AxiProt   := "000";  -- Unprivileged, Non-Sec, Data
  constant c_AxiDefQos    : t_AxiQos    := "0000"; -- No QOS
  constant c_AxiDefRegion : t_AxiRegion := "0000"; -- Default Region

  type t_Axi_ms is record
    awaddr  : t_AxiAddr;
    awlen   : t_AxiLen;
    awsize  : t_AxiSize;
    awburst : t_AxiBurst;
    awuser  : t_Context;
    awvalid : std_logic;
    wdata   : t_AxiData;
    wstrb   : t_AxiStrb;
    wlast   : std_logic;
    wvalid  : std_logic;
    bready  : std_logic;
    araddr  : t_AxiAddr;
    arlen   : t_AxiLen;
    arsize  : t_AxiSize;
    arburst : t_AxiBurst;
    aruser  : t_Context;
    arvalid : std_logic;
    rready  : std_logic;
  end record;
  type t_Axi_sm is record
    awready : std_logic;
    wready  : std_logic;
    bresp   : t_AxiResp;
    bvalid  : std_logic;
    arready : std_logic;
    rdata   : t_AxiData;
    rresp   : t_AxiResp;
    rlast   : std_logic;
    rvalid  : std_logic;
  end record;

  type t_AxiRd_ms is record
    araddr  : t_AxiAddr;
    arlen   : t_AxiLen;
    arsize  : t_AxiSize;
    arburst : t_AxiBurst;
    aruser  : t_Context;
    arvalid : std_logic;
    rready  : std_logic;
  end record;
  type t_AxiRd_sm is record
    arready : std_logic;
    rdata   : t_AxiData;
    rresp   : t_AxiResp;
    rlast   : std_logic;
    rvalid  : std_logic;
  end record;

  type t_AxiWr_ms is record
    awaddr  : t_AxiAddr;
    awlen   : t_AxiLen;
    awsize  : t_AxiSize;
    awburst : t_AxiBurst;
    awuser  : t_Context;
    awvalid : std_logic;
    wdata   : t_AxiData;
    wstrb   : t_AxiStrb;
    wlast   : std_logic;
    wvalid  : std_logic;
    bready  : std_logic;
  end record;
  type t_AxiWr_sm is record
    awready : std_logic;
    wready  : std_logic;
    bresp   : t_AxiResp;
    bvalid  : std_logic;
  end record;

  function f_axiSplitRd_ms(a_axi : t_Axi_ms) return t_AxiRd_ms;
  function f_axiSplitWr_ms(a_axi : t_Axi_ms) return t_AxiWr_ms;
  function f_axiJoin_ms(a_axiRd : t_AxiRd_ms, a_axiWr : t_AxiWr_ms) return t_Axi_ms;
  function f_axiSplitRd_sm(a_axi : t_Axi_sm) return t_AxiRd_sm;
  function f_axiSplitWr_sm(a_axi : t_Axi_sm) return t_AxiWr_sm;
  function f_axiJoin_sm(a_axiRd : t_AxiRd_sm, a_axiWr : t_AxiWr_sm) return t_Axi_sm;

  -----------------------------------------------------------------------------
  -- Native AXI Stream Interface
  -----------------------------------------------------------------------------
  type t_AxiStream_ms is record
    tdata   : t_AxiData;
    tstrb   : t_AxiStrb;
    tkeep   : t_AxiStrb;
    tlast   : std_logic;
    tvalid  : std_logic;
  end record;
  type t_AxiStream_sm is record
    tvalid  : std_logic;
  end record;


  -----------------------------------------------------------------------------
  -- General Action Signal Definitions
  -----------------------------------------------------------------------------

  -- Interrupt source range is split into user and snap range
  --  so only the lower n-1 bits can be used by the action
  constant C_INT_W : integer := INT_BITS - 1;
  type t_InterruptSrc : unsigned(C_INT_W-1 downto 0);

  constant C_CTX_W : integer := CONTEXT_BITS;
  type t_Context : unsigned(C_CTX_W-1 downto 0);


  -----------------------------------------------------------------------------
  -- Control Register Port Definitions
  -----------------------------------------------------------------------------

  constant C_CTRL_DATA_W   : integer := C_S_AXI_CTRL_REG_DATA_WIDTH;
  type t_CtrlAddr is unsigned (C_CTRL_ADDR_W-1 downto 0);

  constant C_CTRL_ADDR_W   : integer := C_S_AXI_CTRL_REG_ADDR_WIDTH;
  type t_CtrlData is unsigned (C_CTRL_DATA_W-1 downto 0);
  type t_CtrlStrb is unsigned (C_CTRL_DATA_W/8-1 downto 0);

  type t_Ctrl_ms is record
    awaddr  : t_CtrlAddr;
    awvalid : std_logic;
    wdata   : t_CtrlData;
    wstrb   : t_CtrlStrb;
    wvalid  : std_logic;
    bready  : std_logic;
    araddr  : t_CtrlAddr;
    arvalid : std_logic;
    rready  : std_logic;
  end record;
  type t_Ctrl_sm is record
    awready : std_logic;
    wready  : std_logic;
    bresp   : std_logic_vector(1 downto 0);
    bvalid  : std_logic;
    arready : std_logic;
    rdata   : t_CtrlData;
    rresp   : std_logic_vector(1 downto 0);
    rvalid  : std_logic;
  end record;


  -----------------------------------------------------------------------------
  -- Register Map and simplified Port Definitions
  -----------------------------------------------------------------------------

  -- Actual Register Space Spans 1Kx4B Registers (= 10 Bit Register Numbers)
  constant C_CTRL_SPACE_W  : integer := 10;
  type t_RegAddr is unsigned (C_CTRL_SPACE_W-1 downto 0);

  -- Address Range for a Single Port (Offset, Count)
  type t_RegRange is array (0 to 1) of t_RegAddr;
  -- Set of Address Ranges to configure the Register Port Demux
  type t_RegMap is array (integer range <>) of t_RegRange;

  type t_RegData is unsigned (C_CTRL_DATA_W-1  downto 0);
  type t_RegStrb is unsigned (C_CTRL_DATA_W/8-1 downto 0);

  type t_RegPort_ms is record
    addr : t_RegAddr;
    wrdata : t_RegData;
    wrstrb : t_RegStrb;
    wrnotrd : std_logic;
    valid : std_logic;
  end record;
  type t_RegPort_sm is record
    rddata : t_RegData;
    ready : std_logic;
  end record;


  -----------------------------------------------------------------------------
  -- Host Memory Port (Axi Master) Definitions
  -----------------------------------------------------------------------------

  constant C_HMEM_ID_W     : integer := C_M_AXI_HOST_MEM_ID_WIDTH;
  type t_HmemId   is unsigned(C_HMEM_ID_W-1 downto 0);

  constant C_HMEM_ADDR_W   : integer := C_M_AXI_HOST_MEM_ADDR_WIDTH;
  type t_HmemAddr is unsigned(C_HMEM_ADDR_W-1 downto 0);

  constant C_HMEM_DATA_W   : integer := C_M_AXI_HOST_MEM_DATA_WIDTH;
  type t_HmemData is unsigned(C_HMEM_DATA_W-1 downto 0);
  type t_HmemStrb is unsigned(C_HMEM_DATA_W/8-1 downto 0);

  constant C_HMEM_WOFF_W   : integer := f_clog2(C_HMEM_DATA_W/8-1);



  constant C_HMEM_AWUSER_W : integer := CONTEXT_BITS;
  constant C_HMEM_ARUSER_W : integer := CONTEXT_BITS;

  constant C_HMEM_WUSER_W  : integer := C_M_AXI_HOST_MEM_WUSER_WIDTH;
  type t_HmemWUser is unsigned(C_HMEM_WUSER_W-1 downto 0);

  constant C_HMEM_RUSER_W  : integer := C_M_AXI_HOST_MEM_RUSER_WIDTH;
  type t_HmemRUser is unsigned(C_HMEM_RUSER_W-1 downto 0);

  constant C_HMEM_BUSER_W  : integer := C_M_AXI_HOST_MEM_BUSER_WIDTH;
  type t_HmemBUser is unsigned(C_HMEM_BUSER_W-1 downto 0);

  type t_Hmem_ms is record
    awid    : t_HmemId;
    awaddr  : t_HmemAddr;
    awlen   : t_AxiLen;
    awsize  : t_AxiSize;
    awburst : t_AxiBurst;
    -- awlock  : t_AxiLock;
    awcache : t_AxiCache;
    awprot  : t_AxiProt;
    awqos   : t_AxiQos;
    awregion :t_AxiRegion;
    awuser  : t_Context;
    awvalid : std_logic;
    wdata   : t_HmemData;
    wstrb   : t_HmemStrb;
    wlast   : std_logic;
    wuser   : t_HmemWUser;
    wvalid  : std_logic;
    bready  : std_logic;
    arid    : t_HmemId;
    araddr  : t_HmemAddr;
    arlen   : t_AxiLen;
    arsize  : t_AxiSize;
    arburst : t_AxiBurst;
    -- arlock  : t_AxiLock;
    arcache : t_AxiCache;
    arprot  : t_AxiProt;
    arqos   : t_AxiQos;
    arregion :t_AxiRegion;
    aruser  : t_Context;
    arvalid : std_logic;
    rready  : std_logic;
  end record;
  type t_Hmem_sm is record
    awready : std_logic;
    wready  : std_logic;
    bid     : t_HmemId;
    bresp   : t_AxiResp;
    buser   : t_HmemBUser;
    bvalid  : std_logic;
    arready : std_logic;
    rid     : t_HmemId;
    rdata   : t_HmemData;
    rresp   : t_AxiResp;
    rlast   : std_logic;
    ruser   : t_HmemRUser;
    rvalid  : std_logic;
  end record;


  -----------------------------------------------------------------------------
  -- Card Memory Port (AXI Master) Definitions
  -----------------------------------------------------------------------------

  constant C_CMEM_ID_W     : integer := C_M_AXI_CARD_MEM0_ID_WIDTH;
  type t_CmemId is unsigned(C_CMEM_ID_W-1 downto 0);

  constant C_CMEM_ADDR_W   : integer := C_M_AXI_CARD_MEM0_ADDR_WIDTH;
  type t_CmemAddr is unsigned(C_CMEM_ADDR_W-1 downto 0);

  constant C_CMEM_DATA_W   : integer := C_M_AXI_CARD_MEM0_DATA_WIDTH;
  type t_CmemData is unsigned(C_CMEM_DATA_W-1 downto 0);
  type t_CmemStrb is unsigned(C_CMEM_DATA_W/8-1 downto 0);

  constant C_CMEM_AWUSER_W : integer := C_M_AXI_CARD_MEM0_AWUSER_WIDTH;
  constant C_CMEM_ARUSER_W : integer := C_M_AXI_CARD_MEM0_ARUSER_WIDTH;
  constant C_CMEM_WUSER_W  : integer := C_M_AXI_CARD_MEM0_WUSER_WIDTH;
  constant C_CMEM_RUSER_W  : integer := C_M_AXI_CARD_MEM0_RUSER_WIDTH;
  constant C_CMEM_BUSER_W  : integer := C_M_AXI_CARD_MEM0_BUSER_WIDTH;

  type t_cmem_ms is record
    awid    : t_CmemId;
    awaddr  : t_CmemAddr;
    awlen   : t_AxiLen;
    awsize  : t_AxiSize;
    awburst : t_AxiBurst;
    awlock  : t_AxiLock;
    awcache : t_AxiCache;
    awprot  : t_AxiProt;
    awqos   : t_AxiQos;
    awregion :t_AxiRegion;
    awuser  : std_logic_vector(C_CMEM_AWUSER_W-1 downto 0);
    awvalid : std_logic;
    wdata   : t_CmemData;
    wstrb   : t_CmemStrb;
    wlast   : std_logic;
    wuser   : std_logic_vector(C_CMEM_WUSER_W-1 downto 0);
    wvalid  : std_logic;
    bready  : std_logic;
    arid    : t_CmemId;
    araddr  : t_CmemAddr;
    arlen   : t_AxiLen;
    arsize  : t_AxiSize;
    arburst : t_AxiBurst;
    arlock  : t_AxiLock;
    arcache : t_AxiCache;
    arprot  : t_AxiProt;
    arqos   : t_AxiQos;
    arregion :t_AxiRegion;
    aruser  : std_logic_vector(C_CMEM_ARUSER_W-1 downto 0);
    arvalid : std_logic;
    rready  : std_logic;
  end record;
  type t_cmem_sm is record
    awready : std_logic;
    wready  : std_logic;
    bid     : t_CmemId;
    bresp   : t_AxiResp;
    buser   : std_logic_vector(C_CMEM_BUSER_W-1 downto 0);
    bvalid  : std_logic;
    arready : std_logic;
    rid     : t_CmemId;
    rdata   : t_CmemData;
    rresp   : t_AxiResp;
    rlast   : std_logic;
    ruser   : std_logic_vector(C_CMEM_RUSER_W-1 downto 0);
    rvalid  : std_logic;
  end record;


  -----------------------------------------------------------------------------
  -- NVME Controller Port (AXI Master) Definitions
  -----------------------------------------------------------------------------

  constant C_NVME_ID_W     : integer := C_M_AXI_NVME_ID_WIDTH;
  constant C_NVME_ADDR_W   : integer := C_M_AXI_NVME_ADDR_WIDTH;
  constant C_NVME_DATA_W   : integer := C_M_AXI_NVME_DATA_WIDTH;
  constant C_NVME_AWUSER_W : integer := C_M_AXI_NVME_AWUSER_WIDTH;
  constant C_NVME_ARUSER_W : integer := C_M_AXI_NVME_ARUSER_WIDTH;
  constant C_NVME_WUSER_W  : integer := C_M_AXI_NVME_WUSER_WIDTH;
  constant C_NVME_RUSER_W  : integer := C_M_AXI_NVME_RUSER_WIDTH;
  constant C_NVME_BUSER_W  : integer := C_M_AXI_NVME_BUSER_WIDTH;

  type t_nvme_ms is record
    awid    : std_logic_vector(C_NVME_ID_W-1 downto 0);
    awaddr  : std_logic_vector(C_NVME_ADDR_W-1 downto 0);
    awlen   : std_logic_vector(7 downto 0);
    awsize  : std_logic_vector(2 downto 0);
    awburst : std_logic_vector(1 downto 0);
    awlock  : std_logic_vector(1 downto 0);
    awcache : std_logic_vector(3 downto 0);
    awprot  : std_logic_vector(2 downto 0);
    awqos   : std_logic_vector(3 downto 0);
    awregion :std_logic_vector(3 downto 0);
    awuser  : std_logic_vector(C_NVME_AWUSER_W-1 downto 0);
    awvalid : std_logic;
    wdata   : std_logic_vector(C_NVME_DATA_W-1 downto 0);
    wstrb   : std_logic_vector(C_NVME_DATA_W/8-1 downto 0);
    wlast   : std_logic;
    wuser   : std_logic_vector(C_NVME_WUSER_W-1 downto 0);
    wvalid  : std_logic;
    bready  : std_logic;
    arid    : std_logic_vector(C_NVME_ID_W-1 downto 0);
    araddr  : std_logic_vector(C_NVME_ADDR_W-1 downto 0);
    arlen   : std_logic_vector(7 downto 0);
    arsize  : std_logic_vector(2 downto 0);
    arburst : std_logic_vector(1 downto 0);
    arlock  : std_logic_vector(1 downto 0);
    arcache : std_logic_vector(3 downto 0);
    arprot  : std_logic_vector(2 downto 0);
    arqos   : std_logic_vector(3 downto 0);
    arregion :std_logic_vector(3 downto 0);
    aruser  : std_logic_vector(C_NVME_ARUSER_W-1 downto 0);
    arvalid : std_logic;
    rready  : std_logic;
  end record;
  type t_nvme_sm is record
    awready : std_logic;
    wready  : std_logic;
    bid     : std_logic_vector(C_NVME_ID_W-1 downto 0);
    bresp   : std_logic_vector(1 downto 0);
    buser   : std_logic_vector(C_NVME_BUSER_W-1 downto 0);
    bvalid  : std_logic;
    arready : std_logic;
    rid     : std_logic_vector(C_NVME_ID_W-1 downto 0);
    rdata   : std_logic_vector(C_NVME_DATA_W-1 downto 0);
    rresp   : std_logic_vector(1 downto 0);
    rlast   : std_logic;
    ruser   : std_logic_vector(C_NVME_RUSER_W-1 downto 0);
    rvalid  : std_logic;
  end record;


end fosix_types;


package body fosix_types is

  function f_axiSplitRd_ms(a_axi : t_Axi_ms) return t_AxiRd_ms
    variable v_axiRd : t_AxiRd_ms;
  begin
    v_axiRd.araddr  := a_axi.araddr;
    v_axiRd.arlen   := a_axi.arlen;
    v_axiRd.arsize  := a_axi.arsize;
    v_axiRd.arburst := a_axi.arburst;
    v_axiRd.aruser  := a_axi.aruser;
    v_axiRd.arvalid := a_axi.arvalid;
    v_axiRd.rready  := a_axi.rready;
    return v_axiRd;
  end f_axiSplitRd_ms;

  function f_axiSplitWr_ms(a_axi : t_Axi_ms) return t_AxiWr_ms
    variable v_axiWr : t_AxiWr_ms;
  begin
    v_axiWr.awaddr  := a_axi.awaddr;
    v_axiWr.awlen   := a_axi.awlen;
    v_axiWr.awsize  := a_axi.awsize;
    v_axiWr.awburst := a_axi.awburst;
    v_axiWr.awuser  := a_axi.awuser;
    v_axiWr.awvalid := a_axi.awvalid;
    v_axiWr.wdata   := a_axi.wdata;
    v_axiWr.wstrb   := a_axi.wstrb;
    v_axiWr.wlast   := a_axi.wlast;
    v_axiWr.wvalid  := a_axi.wvalid;
    v_axiWr.bready  := a_axi.bready;
    return v_axiWr;
  end f_axiSplitWr_ms;

  function f_axiJoin_ms(a_axiRd : t_AxiRd_ms, a_axiWr : t_AxiWr_ms) return t_Axi_ms
    variable v_axi : t_Axi_ms;
  begin
    v_axi.awaddr  := a_axiWr.awaddr;
    v_axi.awlen   := a_axiWr.awlen;
    v_axi.awsize  := a_axiWr.awsize;
    v_axi.awburst := a_axiWr.awburst;
    v_axi.awuser  := a_axiWr.awuser;
    v_axi.awvalid := a_axiWr.awvalid;
    v_axi.wdata   := a_axiWr.wdata;
    v_axi.wstrb   := a_axiWr.wstrb;
    v_axi.wlast   := a_axiWr.wlast;
    v_axi.wvalid  := a_axiWr.wvalid;
    v_axi.bready  := a_axiWr.bready;
    v_axi.araddr  := a_axiRd.araddr;
    v_axi.arlen   := a_axiRd.arlen;
    v_axi.arsize  := a_axiRd.arsize;
    v_axi.arburst := a_axiRd.arburst;
    v_axi.aruser  := a_axiRd.aruser;
    v_axi.arvalid := a_axiRd.arvalid;
    v_axi.rready  := a_axiRd.rready;
    return v_axi;
  end f_axiJoin_ms;

  function f_axiSplitRd_sm(a_axi : t_Axi_sm) return t_AxiRd_sm
    variable v_axiRd : t_AxiRd_sm;
  begin
    v_axiRd.arready := a_axi.arready;
    v_axiRd.rdata   := a_axi.rdata;
    v_axiRd.rresp   := a_axi.rresp;
    v_axiRd.rlast   := a_axi.rlast;
    v_axiRd.rvalid  := a_axi.rvalid;
    return v_axiRd;
  end f_axiSplitRd_sm;

  function f_axiSplitWr_sm(a_axi : t_Axi_sm) return t_AxiWr_sm
    variable v_axiWr : t_AxiWr_sm;
  begin
    v_axiWr.awready := a_axi.awready;
    v_axiWr.wready  := a_axi.wready;
    v_axiWr.bresp   := a_axi.bresp;
    v_axiWr.bvalid  := a_axi.bvalid;
    return v_axiWr;
  end f_axiSplitWr_sm;

  function f_axiJoin_sm(a_axiRd : t_AxiRd_sm, a_axiWr : t_AxiWr_sm) return t_Axi_sm
    variable v_axi : t_Axi_sm;
  begin
    v_axi.awready := a_axiWr.awready;
    v_axi.wready  := a_axiWr.wready;
    v_axi.bresp   := a_axiWr.bresp;
    v_axi.bvalid  := a_axiWr.bvalid;
    v_axi.arready := a_axiRd.arready;
    v_axi.rdata   := a_axiRd.rdata;
    v_axi.rresp   := a_axiRd.rresp;
    v_axi.rlast   := a_axiRd.rlast;
    v_axi.rvalid  := a_axiRd.rvalid;
    return v_axi;
  end f_axiJoin_sm;

end fosix_types;
