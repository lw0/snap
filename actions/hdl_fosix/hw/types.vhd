library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.action_types.all;
use work.psl_accel_types.all;
use work.fosix_util.all;

package fosix_types is

  -----------------------------------------------------------------------------
  -- General Action Signal Definitions
  -----------------------------------------------------------------------------

  -- Interrupt source range is split into user and snap range
  --  so only the lower n-1 bits can be used by the action
  constant C_INT_W : integer := INT_BITS - 1;
  subtype t_InterruptSrc is unsigned(C_INT_W-1 downto 0);

  constant C_CTX_W : integer := CONTEXT_BITS;
  subtype t_Context is unsigned(C_CTX_W-1 downto 0);


  -----------------------------------------------------------------------------
  -- AXI Interface Definitions
  -----------------------------------------------------------------------------
  -- byte address bits of the boundary a burst may not cross(4KB blocks)
  constant C_AXI_BURST_ALIGN_W : integer := 12;

  constant C_AXI_LEN_W    : integer := 8;
  subtype t_AxiLen is unsigned(C_AXI_LEN_W-1 downto 0);

  constant C_AXI_SIZE_W   : integer := 3;
  subtype t_AxiSize is unsigned(C_AXI_SIZE_W-1 downto 0);

  constant C_AXI_BURST_W  : integer := 2;
  subtype t_AxiBurst is unsigned(C_AXI_BURST_W-1 downto 0);
  constant c_AxiBurstFixed : t_AxiBurst := "00";
  constant c_AxiBurstIncr : t_AxiBurst := "01";
  constant c_AxiBurstWrap : t_AxiBurst := "10";

  constant C_AXI_LOCK_W  : integer := 2;
  subtype t_AxiLock is unsigned(C_AXI_LOCK_W-1 downto 0);
  constant c_AxiLockNormal : t_AxiLock := "00";
  constant c_AxiLockExclusive : t_AxiLock := "01";
  constant c_AxiLockLocked : t_AxiLock := "10";

  constant C_AXI_CACHE_W  : integer := 4;
  subtype t_AxiCache is unsigned(C_AXI_CACHE_W-1 downto 0);

  constant C_AXI_PROT_W   : integer := 3;
  subtype t_AxiProt is unsigned(C_AXI_PROT_W-1 downto 0);

  constant C_AXI_QOS_W    : integer := 4;
  subtype t_AxiQos is unsigned(C_AXI_QOS_W-1 downto 0);

  constant C_AXI_REGION_W : integer := 4;
  subtype t_AxiRegion is unsigned(C_AXI_REGION_W-1 downto 0);

  constant C_AXI_RESP_W : integer := 2;
  subtype t_AxiResp is unsigned(C_AXI_RESP_W-1 downto 0);
  constant c_AxiRespOkay   : t_AxiResp := "00";
  constant c_AxiRespExOkay : t_AxiResp := "01";
  constant c_AxiRespSlvErr : t_AxiResp := "10";
  constant c_AxiRespDecErr : t_AxiResp := "11";

  -----------------------------------------------------------------------------
  -- Native AXI Interface
  -----------------------------------------------------------------------------

  -- byte address
  constant C_AXI_ADDR_W : integer := 64;
  subtype t_AxiAddr is unsigned(C_AXI_ADDR_W-1 downto 0);

  -- data bus (= word) width
  constant C_AXI_DATA_W : integer := 512;
  subtype t_AxiData is unsigned(C_AXI_DATA_W-1 downto 0);
  subtype t_AxiStrb is unsigned(C_AXI_DATA_W/8-1 downto 0);
  -- address bits required to locate a specific byte within a data word
  constant C_AXI_DATA_BYTES_W : integer := f_clog2(C_AXI_DATA_W/8);

  -- word address
  constant C_AXI_WORDADDR_W : integer := C_AXI_ADDR_W - C_AXI_DATA_BYTES_W;
  subtype t_AxiWordAddr is unsigned(C_AXI_WORDADDR_W-1 downto 0);

  -- Transfer Size Encoding for Entire Data Bus Width
  constant c_AxiSize : t_AxiSize := to_unsigned(f_clog2(C_AXI_DATA_W/8-1), C_AXI_SIZE_W);
  constant C_AXI_BURST_LEN_W : integer := C_AXI_BURST_ALIGN_W - C_AXI_DATA_BYTES_W;
  subtype t_AxiBurstLen is unsigned(C_AXI_BURST_LEN_W-1 downto 0);

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
  constant c_AxiNull_ms : t_Axi_ms := (
    awaddr  => (others => '0'),
    awlen   => (others => '0'),
    awsize  => (others => '0'),
    awburst => (others => '0'),
    awvalid => '0',
    wdata   => (others => '0'),
    wstrb   => (others => '0'),
    wlast   => '0',
    wvalid  => '0',
    bready  => '0',
    araddr  => (others => '0'),
    arlen   => (others => '0'),
    arsize  => (others => '0'),
    arburst => (others => '0'),
    arvalid => '0',
    rready  => '0');
  constant c_AxiNull_sm : t_Axi_sm := (
    awready => '0',
    wready  => '0',
    bresp   => (others => '0'),
    bvalid  => '0',
    arready => '0',
    rdata   => (others => '0'),
    rresp   => (others => '0'),
    rlast   => '0',
    rvalid  => '0');

  type t_AxiRd_ms is record
    araddr  : t_AxiAddr;
    arlen   : t_AxiLen;
    arsize  : t_AxiSize;
    arburst : t_AxiBurst;
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
  constant c_AxiRdNull_ms : t_AxiRd_ms := (
    araddr  => (others => '0'),
    arlen   => (others => '0'),
    arsize  => (others => '0'),
    arburst => (others => '0'),
    arvalid => '0',
    rready  => '0');
  constant c_AxiRdNull_sm : t_AxiRd_sm := (
    arready => '0',
    rdata   => (others => '0'),
    rresp   => (others => '0'),
    rlast   => '0',
    rvalid  => '0');

  type t_AxiWr_ms is record
    awaddr  : t_AxiAddr;
    awlen   : t_AxiLen;
    awsize  : t_AxiSize;
    awburst : t_AxiBurst;
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
  constant c_AxiWrNull_ms : t_AxiWr_ms := (
    awaddr  => (others => '0'),
    awlen   => (others => '0'),
    awsize  => (others => '0'),
    awburst => (others => '0'),
    awvalid => '0',
    wdata   => (others => '0'),
    wstrb   => (others => '0'),
    wlast   => '0',
    wvalid  => '0',
    bready  => '0');
  constant c_AxiWrNull_sm : t_AxiWr_sm := (
    awready => '0',
    wready  => '0',
    bresp   => (others => '0'),
    bvalid  => '0');

  function f_axiSplitRd_ms(v_axi : t_Axi_ms) return t_AxiRd_ms;
  function f_axiSplitWr_ms(v_axi : t_Axi_ms) return t_AxiWr_ms;
  function f_axiJoin_ms(v_axiRd : t_AxiRd_ms; v_axiWr : t_AxiWr_ms) return t_Axi_ms;
  function f_axiSplitRd_sm(v_axi : t_Axi_sm) return t_AxiRd_sm;
  function f_axiSplitWr_sm(v_axi : t_Axi_sm) return t_AxiWr_sm;
  function f_axiJoin_sm(v_axiRd : t_AxiRd_sm; v_axiWr : t_AxiWr_sm) return t_Axi_sm;

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
    tready  : std_logic;
  end record;
  constant c_AxiStreamNull_ms : t_AxiStream_ms := (
    tdata  => (others => '0'),
    tstrb  => (others => '0'),
    tkeep  => (others => '0'),
    tlast  => '0',
    tvalid => '0');
  constant c_AxiStreamNull_sm : t_AxiStream_sm := (
    tready => '0');

  type t_AxiStreams_ms is array (integer range <>) of t_AxiStream_ms;
  type t_AxiStreams_sm is array (integer range <>) of t_AxiStream_sm;

  -----------------------------------------------------------------------------
  -- Control Register Port Definitions
  -----------------------------------------------------------------------------

  constant C_CTRL_ADDR_W   : integer := C_S_AXI_CTRL_REG_ADDR_WIDTH;
  subtype t_CtrlAddr is unsigned (C_CTRL_ADDR_W-1 downto 0);

  constant C_CTRL_DATA_W   : integer := C_S_AXI_CTRL_REG_DATA_WIDTH;
  subtype t_CtrlData is unsigned (C_CTRL_DATA_W-1 downto 0);
  subtype t_CtrlStrb is unsigned (C_CTRL_DATA_W/8-1 downto 0);

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
  subtype t_RegAddr is unsigned (C_CTRL_SPACE_W-1 downto 0);

  -- Address Range for a Single Port (Offset, Count)
  type t_RegRange is array (0 to 1) of t_RegAddr;
  -- Set of Address Ranges to configure the Register Port Demux
  type t_RegMap is array (integer range <>) of t_RegRange;

  subtype t_RegData is unsigned (C_CTRL_DATA_W-1  downto 0);
  subtype t_RegStrb is unsigned (C_CTRL_DATA_W/8-1 downto 0);

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

  type t_RegPorts_ms is array (integer range <>) of t_RegPort_ms;
  type t_RegPorts_sm is array (integer range <>) of t_RegPort_sm;


  -----------------------------------------------------------------------------
  -- Host Memory Port (Axi Master) Definitions
  -----------------------------------------------------------------------------

  constant C_HMEM_ID_W     : integer := C_M_AXI_HOST_MEM_ID_WIDTH;
  subtype t_HmemId   is unsigned(C_HMEM_ID_W-1 downto 0);

  constant C_HMEM_ADDR_W   : integer := C_M_AXI_HOST_MEM_ADDR_WIDTH;
  subtype t_HmemAddr is unsigned(C_HMEM_ADDR_W-1 downto 0);

  constant C_HMEM_DATA_W   : integer := C_M_AXI_HOST_MEM_DATA_WIDTH;
  subtype t_HmemData is unsigned(C_HMEM_DATA_W-1 downto 0);
  subtype t_HmemStrb is unsigned(C_HMEM_DATA_W/8-1 downto 0);

  constant C_HMEM_WOFF_W   : integer := f_clog2(C_HMEM_DATA_W/8-1);

  constant C_HMEM_AWUSER_W : integer := CONTEXT_BITS;
  constant C_HMEM_ARUSER_W : integer := CONTEXT_BITS;

  constant C_HMEM_WUSER_W  : integer := C_M_AXI_HOST_MEM_WUSER_WIDTH;
  subtype t_HmemWUser is unsigned(C_HMEM_WUSER_W-1 downto 0);

  constant C_HMEM_RUSER_W  : integer := C_M_AXI_HOST_MEM_RUSER_WIDTH;
  subtype t_HmemRUser is unsigned(C_HMEM_RUSER_W-1 downto 0);

  constant C_HMEM_BUSER_W  : integer := C_M_AXI_HOST_MEM_BUSER_WIDTH;
  subtype t_HmemBUser is unsigned(C_HMEM_BUSER_W-1 downto 0);

  -----------------------------------------------------------------------------
  -- Card Memory Port (AXI Master) Definitions
  -----------------------------------------------------------------------------

  constant C_CMEM_ID_W     : integer := C_M_AXI_CARD_MEM0_ID_WIDTH;
  subtype t_CmemId is unsigned(C_CMEM_ID_W-1 downto 0);

  constant C_CMEM_ADDR_W   : integer := C_M_AXI_CARD_MEM0_ADDR_WIDTH;
  subtype t_CmemAddr is unsigned(C_CMEM_ADDR_W-1 downto 0);

  constant C_CMEM_DATA_W   : integer := C_M_AXI_CARD_MEM0_DATA_WIDTH;
  subtype t_CmemData is unsigned(C_CMEM_DATA_W-1 downto 0);
  subtype t_CmemStrb is unsigned(C_CMEM_DATA_W/8-1 downto 0);

  constant C_CMEM_AWUSER_W : integer := C_M_AXI_CARD_MEM0_AWUSER_WIDTH;
  constant C_CMEM_ARUSER_W : integer := C_M_AXI_CARD_MEM0_ARUSER_WIDTH;
  constant C_CMEM_WUSER_W  : integer := C_M_AXI_CARD_MEM0_WUSER_WIDTH;
  constant C_CMEM_RUSER_W  : integer := C_M_AXI_CARD_MEM0_RUSER_WIDTH;
  constant C_CMEM_BUSER_W  : integer := C_M_AXI_CARD_MEM0_BUSER_WIDTH;

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
  constant c_NvmeNull_ms : t_Nvme_ms := (
    awid     => (others => '0'),
    awaddr   => (others => '0'),
    awlen    => (others => '0'),
    awsize   => (others => '0'),
    awburst  => (others => '0'),
    awlock   => (others => '0'),
    awcache  => (others => '0'),
    awprot   => (others => '0'),
    awqos    => (others => '0'),
    awregion => (others => '0'),
    awuser   => (others => '0'),
    awvalid  => '0',
    wdata    => (others => '0'),
    wstrb    => (others => '0'),
    wlast    => '0',
    wuser    => (others => '0'),
    wvalid   => '0',
    bready   => '0',
    arid     => (others => '0'),
    araddr   => (others => '0'),
    arlen    => (others => '0'),
    arsize   => (others => '0'),
    arburst  => (others => '0'),
    arlock   => (others => '0'),
    arcache  => (others => '0'),
    arprot   => (others => '0'),
    arqos    => (others => '0'),
    arregion => (others => '0'),
    aruser   => (others => '0'),
    arvalid  => '0',
    rready   => '0');
  constant c_NvmeNull_sm : t_Nvme_sm := (
    awready => '0',
    wready  => '0',
    bid     => (others => '0'),
    bresp   => (others => '0'),
    buser   => (others => '0'),
    bvalid  => '0',
    arready => '0',
    rid     => (others => '0'),
    rdata   => (others => '0'),
    rresp   => (others => '0'),
    rlast   => '0',
    ruser   => (others => '0'),
    rvalid  => '0');


end fosix_types;


package body fosix_types is

  function f_axiSplitRd_ms(v_axi : t_Axi_ms) return t_AxiRd_ms is
    variable v_axiRd : t_AxiRd_ms;
  begin
    v_axiRd.araddr  := v_axi.araddr;
    v_axiRd.arlen   := v_axi.arlen;
    v_axiRd.arsize  := v_axi.arsize;
    v_axiRd.arburst := v_axi.arburst;
    v_axiRd.arvalid := v_axi.arvalid;
    v_axiRd.rready  := v_axi.rready;
    return v_axiRd;
  end f_axiSplitRd_ms;

  function f_axiSplitWr_ms(v_axi : t_Axi_ms) return t_AxiWr_ms is
    variable v_axiWr : t_AxiWr_ms;
  begin
    v_axiWr.awaddr  := v_axi.awaddr;
    v_axiWr.awlen   := v_axi.awlen;
    v_axiWr.awsize  := v_axi.awsize;
    v_axiWr.awburst := v_axi.awburst;
    v_axiWr.awvalid := v_axi.awvalid;
    v_axiWr.wdata   := v_axi.wdata;
    v_axiWr.wstrb   := v_axi.wstrb;
    v_axiWr.wlast   := v_axi.wlast;
    v_axiWr.wvalid  := v_axi.wvalid;
    v_axiWr.bready  := v_axi.bready;
    return v_axiWr;
  end f_axiSplitWr_ms;

  function f_axiJoin_ms(v_axiRd : t_AxiRd_ms; v_axiWr : t_AxiWr_ms) return t_Axi_ms is
    variable v_axi : t_Axi_ms;
  begin
    v_axi.awaddr  := v_axiWr.awaddr;
    v_axi.awlen   := v_axiWr.awlen;
    v_axi.awsize  := v_axiWr.awsize;
    v_axi.awburst := v_axiWr.awburst;
    v_axi.awvalid := v_axiWr.awvalid;
    v_axi.wdata   := v_axiWr.wdata;
    v_axi.wstrb   := v_axiWr.wstrb;
    v_axi.wlast   := v_axiWr.wlast;
    v_axi.wvalid  := v_axiWr.wvalid;
    v_axi.bready  := v_axiWr.bready;
    v_axi.araddr  := v_axiRd.araddr;
    v_axi.arlen   := v_axiRd.arlen;
    v_axi.arsize  := v_axiRd.arsize;
    v_axi.arburst := v_axiRd.arburst;
    v_axi.arvalid := v_axiRd.arvalid;
    v_axi.rready  := v_axiRd.rready;
    return v_axi;
  end f_axiJoin_ms;

  function f_axiSplitRd_sm(v_axi : t_Axi_sm) return t_AxiRd_sm is
    variable v_axiRd : t_AxiRd_sm;
  begin
    v_axiRd.arready := v_axi.arready;
    v_axiRd.rdata   := v_axi.rdata;
    v_axiRd.rresp   := v_axi.rresp;
    v_axiRd.rlast   := v_axi.rlast;
    v_axiRd.rvalid  := v_axi.rvalid;
    return v_axiRd;
  end f_axiSplitRd_sm;

  function f_axiSplitWr_sm(v_axi : t_Axi_sm) return t_AxiWr_sm is
    variable v_axiWr : t_AxiWr_sm;
  begin
    v_axiWr.awready := v_axi.awready;
    v_axiWr.wready  := v_axi.wready;
    v_axiWr.bresp   := v_axi.bresp;
    v_axiWr.bvalid  := v_axi.bvalid;
    return v_axiWr;
  end f_axiSplitWr_sm;

  function f_axiJoin_sm(v_axiRd : t_AxiRd_sm; v_axiWr : t_AxiWr_sm) return t_Axi_sm is
    variable v_axi : t_Axi_sm;
  begin
    v_axi.awready := v_axiWr.awready;
    v_axi.wready  := v_axiWr.wready;
    v_axi.bresp   := v_axiWr.bresp;
    v_axi.bvalid  := v_axiWr.bvalid;
    v_axi.arready := v_axiRd.arready;
    v_axi.rdata   := v_axiRd.rdata;
    v_axi.rresp   := v_axiRd.rresp;
    v_axi.rlast   := v_axiRd.rlast;
    v_axi.rvalid  := v_axiRd.rvalid;
    return v_axi;
  end f_axiJoin_sm;

end fosix_types;
