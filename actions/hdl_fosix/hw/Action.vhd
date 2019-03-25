library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fosix_types is

  -----------------------------------------------------------------------------
  -- Axi Stream Types
  -----------------------------------------------------------------------------
  -- Interfaces:
  subtype t_BaseData is unsigned (-1 downto 0);
  subtype t_BaseStrb is unsigned (/8-1 downto 0);
  type t_Base_ms is record
    tdata : t_BaseData;
    tstrb : t_BaseStrb;
    tlast : std_logic;
    tvalid : std_logic;
  end record;
  type t_Base_sm is record
    tready : std_logic;
  end record;

  subtype t_WordData is unsigned (-1 downto 0);
  subtype t_WordStrb is unsigned (/8-1 downto 0);
  type t_Word_ms is record
    tdata : t_WordData;
    tstrb : t_WordStrb;
    tlast : std_logic;
    tvalid : std_logic;
  end record;
  type t_Word_sm is record
    tready : std_logic;
  end record;


  -----------------------------------------------------------------------------
  -- Axi Types
  -----------------------------------------------------------------------------
  -- Common Definitions:
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

  -- Interfaces:
  subtype t_BaseAddr is unsigned (64-1 downto 0);
  subtype t_BaseData is unsigned (512-1 downto 0);
  subtype t_BaseStrb is unsigned (512/8-1 downto 0);
  type t_Base_ms is record
    awaddr  : t_BaseAddr;
    awlen   : t_AxiLen;
    awsize  : t_AxiSize;
    awburst : t_AxiBurst;
    awlock  : t_AxiLock;
    awcache : t_AxiCache;
    awprot  : t_AxiProt;
    awqos   : t_AxiQos;
    awregion : t_AxiRegion;
    awvalid : std_logic;
    wdata   : t_BaseData;
    wstrb   : t_BaseStrb;
    wlast   : std_logic;
    wvalid  : std_logic;
    bready  : std_logic;
    araddr  : t_BaseAddr;
    arlen   : t_AxiLen;
    arsize  : t_AxiSize;
    arburst : t_AxiBurst;
    arlock  : t_AxiLock;
    arcache : t_AxiCache;
    arprot  : t_AxiProt;
    arqos   : t_AxiQos;
    arregion : t_AxiRegion;
    arvalid : std_logic;
    rready  : std_logic;
  end record;
  type t_Base_sm is record
    awready : std_logic;
    wready  : std_logic;
    bresp   : t_AxiResp;
    bvalid  : std_logic;
    arready : std_logic;
    rdata   : t_BaseData;
    rresp   : t_AxiResp;
    rlast   : std_logic;
    rvalid  : std_logic;
  end record;

  subtype t_NvmeAddr is unsigned (32-1 downto 0);
  subtype t_NvmeData is unsigned (32-1 downto 0);
  subtype t_NvmeStrb is unsigned (32/8-1 downto 0);
  type t_Nvme_ms is record
    awaddr  : t_NvmeAddr;
    awlen   : t_AxiLen;
    awsize  : t_AxiSize;
    awburst : t_AxiBurst;
    awlock  : t_AxiLock;
    awcache : t_AxiCache;
    awprot  : t_AxiProt;
    awqos   : t_AxiQos;
    awregion : t_AxiRegion;
    awvalid : std_logic;
    wdata   : t_NvmeData;
    wstrb   : t_NvmeStrb;
    wlast   : std_logic;
    wvalid  : std_logic;
    bready  : std_logic;
    araddr  : t_NvmeAddr;
    arlen   : t_AxiLen;
    arsize  : t_AxiSize;
    arburst : t_AxiBurst;
    arlock  : t_AxiLock;
    arcache : t_AxiCache;
    arprot  : t_AxiProt;
    arqos   : t_AxiQos;
    arregion : t_AxiRegion;
    arvalid : std_logic;
    rready  : std_logic;
  end record;
  type t_Nvme_sm is record
    awready : std_logic;
    wready  : std_logic;
    bresp   : t_AxiResp;
    bvalid  : std_logic;
    arready : std_logic;
    rdata   : t_NvmeData;
    rresp   : t_AxiResp;
    rlast   : std_logic;
    rvalid  : std_logic;
  end record;

  subtype t_CtrlAddr is unsigned (32-1 downto 0);
  subtype t_CtrlData is unsigned (32-1 downto 0);
  subtype t_CtrlStrb is unsigned (32/8-1 downto 0);
  type t_Ctrl_ms is record
    awaddr  : t_CtrlAddr;
    awlen   : t_AxiLen;
    awsize  : t_AxiSize;
    awburst : t_AxiBurst;
    awlock  : t_AxiLock;
    awcache : t_AxiCache;
    awprot  : t_AxiProt;
    awqos   : t_AxiQos;
    awregion : t_AxiRegion;
    awvalid : std_logic;
    wdata   : t_CtrlData;
    wstrb   : t_CtrlStrb;
    wlast   : std_logic;
    wvalid  : std_logic;
    bready  : std_logic;
    araddr  : t_CtrlAddr;
    arlen   : t_AxiLen;
    arsize  : t_AxiSize;
    arburst : t_AxiBurst;
    arlock  : t_AxiLock;
    arcache : t_AxiCache;
    arprot  : t_AxiProt;
    arqos   : t_AxiQos;
    arregion : t_AxiRegion;
    arvalid : std_logic;
    rready  : std_logic;
  end record;
  type t_Ctrl_sm is record
    awready : std_logic;
    wready  : std_logic;
    bresp   : t_AxiResp;
    bvalid  : std_logic;
    arready : std_logic;
    rdata   : t_CtrlData;
    rresp   : t_AxiResp;
    rlast   : std_logic;
    rvalid  : std_logic;
  end record;


end fosix_types;


package body fosix_types is

end fosix_types;
