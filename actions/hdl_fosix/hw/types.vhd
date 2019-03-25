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
  constant c_IntSrcWidth : integer := INT_BITS - 1;
  subtype t_InterruptSrc is unsigned(c_IntSrcWidth-1 downto 0);

  constant c_ContextWidth : integer := CONTEXT_BITS;
  subtype t_Context is unsigned(c_ContextWidth-1 downto 0);


  -----------------------------------------------------------------------------
  -- AXI Interface Definitions
  -----------------------------------------------------------------------------
  -- byte address bits of the boundary a burst may not cross(4KB blocks)
  constant C_AXI_BURST_ALIGN_W : integer := 12;

  constant C_AXI_LEN_W    : integer := 8;
  subtype t_AxiLen is unsigned(C_AXI_LEN_W-1 downto 0);
  constant c_AxiNullLen : t_AxiLen := (others => '0');

  constant C_AXI_SIZE_W   : integer := 3;
  subtype t_AxiSize is unsigned(C_AXI_SIZE_W-1 downto 0);

  constant C_AXI_BURST_W  : integer := 2;
  subtype t_AxiBurst is unsigned(C_AXI_BURST_W-1 downto 0);
  constant c_AxiBurstFixed : t_AxiBurst := "00";
  constant c_AxiBurstIncr : t_AxiBurst := "01";
  constant c_AxiBurstWrap : t_AxiBurst := "10";
  constant c_AxiNullBurst : t_AxiBurst := c_AxiBurstFixed;

  constant C_AXI_LOCK_W  : integer := 2;
  subtype t_AxiLock is unsigned(C_AXI_LOCK_W-1 downto 0);
  constant c_AxiLockNormal : t_AxiLock := "00";
  constant c_AxiLockExclusive : t_AxiLock := "01";
  constant c_AxiLockLocked : t_AxiLock := "10";
  constant c_AxiNullLock   : t_AxiLock := c_AxiLockNormal;

  constant C_AXI_CACHE_W  : integer := 4;
  subtype t_AxiCache is unsigned(C_AXI_CACHE_W-1 downto 0);
  constant c_AxiNullCache  : t_AxiCache  := "0010"; -- Normal, NoCache, NoBuffer

  constant C_AXI_PROT_W   : integer := 3;
  subtype t_AxiProt is unsigned(C_AXI_PROT_W-1 downto 0);
  constant c_AxiNullProt   : t_AxiProt   := "000";  -- Unprivileged, Non-Sec, Data

  constant C_AXI_QOS_W    : integer := 4;
  subtype t_AxiQos is unsigned(C_AXI_QOS_W-1 downto 0);
  constant c_AxiNullQos    : t_AxiQos    := "0000"; -- No QOS

  constant C_AXI_REGION_W : integer := 4;
  subtype t_AxiRegion is unsigned(C_AXI_REGION_W-1 downto 0);
  constant c_AxiNullRegion : t_AxiRegion := "0000"; -- Default Region

  constant C_AXI_RESP_W : integer := 2;
  subtype t_AxiResp is unsigned(C_AXI_RESP_W-1 downto 0);
  constant c_AxiRespOkay   : t_AxiResp := "00";
  constant c_AxiRespExOkay : t_AxiResp := "01";
  constant c_AxiRespSlvErr : t_AxiResp := "10";
  constant c_AxiRespDecErr : t_AxiResp := "11";

  -------------------------------------------------------------------------------
  -- Axi Interface: Base
  -------------------------------------------------------------------------------
  --Scalars:
  constant c_BaseDataWidth : integer := 512;
  constant c_BaseStrbWidth : integer := c_BaseDataWidth/8;
  constant c_BaseByteAddrWidth : integer := f_clog2(c_BaseStrbWidth);
  constant c_BaseFullSize : t_AxiSize := to_unsigned(c_BaseByteAddrWidth, t_AxiSize'length);
  constant c_BaseBurstLenWidth : integer := c_AxiBurstAlignWidth - c_BaseByteAddrWidth;
  constant c_BaseAddrWidth : integer := 64;
  constant c_BaseWordAddrWidth : integer := c_BaseAddrWidth - c_BaseByteAddrWidth;
  subtype t_BaseData is unsigned (c_BaseDataWidth-1 downto 0);
  subtype t_BaseStrb is unsigned (c_BaseStrbWidth-1 downto 0);
  subtype t_BaseByteAddr is unsigned (c_BaseByteAddrWidth-1 downto 0);
  subtype t_BaseBurstLen is unsigned(c_BaseBurstLenWidth-1 downto 0);
  subtype t_BaseAddr is unsigned (c_BaseAddrWidth-1 downto 0);
  subtype t_BaseWordAddr is unsigned(c_BaseWordAddrWidth-1 downto 0);
  --Complete Bundle:
  type t_Base_ms is record
    awaddr   : t_BaseAddr;
    awlen    : t_AxiLen;
    awsize   : t_AxiSize;
    awburst  : t_AxiBurst;
    awvalid  : std_logic;
    wdata    : t_BaseData;
    wstrb    : t_BaseStrb;
    wlast    : std_logic;
    wvalid   : std_logic;
    bready   : std_logic;
    araddr   : t_BaseAddr;
    arlen    : t_AxiLen;
    arsize   : t_AxiSize;
    arburst  : t_AxiBurst;
    arvalid  : std_logic;
    rready   : std_logic;
  end record;
  type t_Base_sm is record
    awready  : std_logic;
    wready   : std_logic;
    bresp    : t_AxiResp;
    bvalid   : std_logic;
    arready  : std_logic;
    rdata    : t_BaseData;
    rresp    : t_AxiResp;
    rlast    : std_logic;
    rvalid   : std_logic;
  end record;
  constant c_BaseNull_ms : t_Base_ms := (
    awaddr   => (others => '0'),
    awlen    => c_AxiNullLen,
    awsize   => c_BaseFullSize,
    awburst  => c_AxiNullBurst,
    awvalid  => '0',
    wdata    => (others => '0'),
    wstrb    => (others => '0'),
    wlast    => '0',
    wvalid   => '0',
    bready   => '0',
    araddr   => (others => '0'),
    arlen    => c_AxiNullLen,
    arsize   => c_BaseFullSize,
    arburst  => c_AxiNullBurst,
    arvalid  => '0',
    rready   => '0' );
  constant c_BaseNull_sm : t_BaseNull_sm := (
    awready  => '0',
    wready   => '0',
    bresp    => (others => '0'),
    bvalid   => '0',
    arready  => '0',
    rdata    => (others => '0'),
    rresp    => (others => '0'),
    rlast    => '0',
    rvalid   => '0' );
  -- Read Bundle:
  type t_BaseRd_ms is record
    araddr   : t_BaseAddr;
    arlen    : t_AxiLen;
    arsize   : t_AxiSize;
    arburst  : t_AxiBurst;
    arvalid  : std_logic;
    rready   : std_logic;
  end record;
  type t_BaseRd_sm is record
    arready  : std_logic;
    rdata    : t_BaseData;
    rresp    : t_AxiResp;
    rlast    : std_logic;
    rvalid   : std_logic;
  end record;
  constant c_BaseRdNull_ms : t_BaseRd_ms := (
    araddr   => (others => '0'),
    arlen    => c_AxiNullLen,
    arsize   => c_BaseFullSize,
    arburst  => c_AxiNullBurst,
    arvalid  => '0',
    rready   => '0' );
  constant c_BaseRdNull_sm : t_BaseRd_sm := (
    arready  => '0',
    rdata    => (others => '0'),
    rresp    => (others => '0'),
    rlast    => '0',
    rvalid   => '0' );
  -- Write Bundle:
  type t_BaseWr_ms is record
    awaddr   : t_BaseAddr;
    awlen    : t_AxiLen;
    awsize   : t_AxiSize;
    awburst  : t_AxiBurst;
    awvalid  : std_logic;
    wdata    : t_BaseData;
    wstrb    : t_BaseStrb;
    wlast    : std_logic;
    wvalid   : std_logic;
    bready   : std_logic;
  end record;
  type t_BaseWr_sm is record
    awready  : std_logic;
    wready   : std_logic;
    bresp    : t_AxiResp;
    bvalid   : std_logic;
  end record;
  constant c_BaseWrNull_ms : t_BaseWr_ms := (
    awaddr   => (others => '0'),
    awlen    => c_AxiNullLen,
    awsize   => c_BaseFullSize,
    awburst  => c_AxiNullBurst,
    awvalid  => '0',
    wdata    => (others => '0'),
    wstrb    => (others => '0'),
    wlast    => '0',
    wvalid   => '0',
    bready   => '0' );
  constant c_BaseWrNull_sm : t_BaseWr_sm := (
    awready  => '0',
    wready   => '0',
    bresp    => (others => '0'),
    bvalid   => '0' );
  -- Address Bundle:
  type t_BaseAdr_ms is record
    aaddr    : t_BaseAddr;
    alen     : t_AxiLen;
    asize    : t_AxiSize;
    aburst   : t_AxiBurst;
    avalid   : std_logic;
  end record;
  type t_BaseAdr_sm is record
    aready   : std_logic;
  end record;
  constant t_BaseAdrNull_ms : t_BaseAdr_ms := (
    aaddr    => (others => '0'),
    alen     => c_AxiNullLen,
    asize    => c_BaseFullSize,
    aburst   => c_AxiNullBurst,
    avalid   => '0' );
  constant t_BaseAdrNull_sm : t_BaseAdr_sm := (
    awready  => '0' );
  -- Conversion Functions:
  function f_BaseSplitRd_ms(v_axi : t_Base_ms) return t_BaseRd_ms;
  function f_BaseSplitRd_sm(v_axi : t_Base_sm) return t_BaseRd_sm;
  function f_BaseSplitWr_ms(v_axi : t_Base_ms) return t_BaseWr_ms;
  function f_BaseSplitWr_sm(v_axi : t_Base_sm) return t_BaseWr_sm;
  function f_BaseJoinRdWr_ms(v_axiRd : t_BaseRd_ms; v_axiWr : t_BaseWr_ms) return t_Base_ms;
  function f_BaseJoinRdWr_sm(v_axiRd : t_BaseRd_sm; v_axiWr : t_BaseWr_sm) return t_Base_sm;
  function f_BaseRdSplitAdr_ms(v_axiRd : t_BaseRd_ms) return t_BaseAdr_ms;
  function f_BaseRdSplitAdr_sm(v_axiRd : t_BaseRd_sm) return t_BaseAdr_sm;
  function f_BaseRdJoinAdr_ms(v_axiRdIn : t_BaseRd_ms; v_axiAdr : t_BaseAdr_ms) return t_BaseRd_ms;
  function f_BaseRdJoinAdr_sm(v_axiRdIn : t_BaseRd_sm; v_axiAdr : t_BaseAdr_sm) return t_BaseRd_sm;
  function f_BaseWrSplitAdr_ms(v_axiWr : t_BaseWr_ms) return t_BaseAdr_ms;
  function f_BaseWrSplitAdr_sm(v_axiWr : t_BaseWr_sm) return t_BaseAdr_sm;
  function f_BaseWrJoinAdr_ms(v_axiWrIn : t_BaseWr_ms; v_axiAdr : t_BaseAdr_ms) return t_BaseWr_ms;
  function f_BaseWrJoinAdr_sm(v_axiWrIn : t_BaseWr_sm; v_axiAdr : t_BaseAdr_sm) return t_BaseWr_sm;

  -------------------------------------------------------------------------------
  -- Axi Interface: Nvme
  -------------------------------------------------------------------------------
  --Scalars:
  constant c_NvmeDataWidth : integer := 32;
  constant c_NvmeStrbWidth : integer := c_NvmeDataWidth/8;
  constant c_NvmeByteAddrWidth : integer := f_clog2(c_NvmeStrbWidth);
  constant c_NvmeFullSize : t_AxiSize := to_unsigned(c_NvmeByteAddrWidth, t_AxiSize'length);
  constant c_NvmeBurstLenWidth : integer := c_AxiBurstAlignWidth - c_NvmeByteAddrWidth;
  constant c_NvmeAddrWidth : integer := 32;
  constant c_NvmeWordAddrWidth : integer := c_NvmeAddrWidth - c_NvmeByteAddrWidth;
  subtype t_NvmeData is unsigned (c_NvmeDataWidth-1 downto 0);
  subtype t_NvmeStrb is unsigned (c_NvmeStrbWidth-1 downto 0);
  subtype t_NvmeByteAddr is unsigned (c_NvmeByteAddrWidth-1 downto 0);
  subtype t_NvmeBurstLen is unsigned(c_NvmeBurstLenWidth-1 downto 0);
  subtype t_NvmeAddr is unsigned (c_NvmeAddrWidth-1 downto 0);
  subtype t_NvmeWordAddr is unsigned(c_NvmeWordAddrWidth-1 downto 0);
  --Complete Bundle:
  type t_Nvme_ms is record
    awaddr   : t_NvmeAddr;
    awvalid  : std_logic;
    wdata    : t_NvmeData;
    wstrb    : t_NvmeStrb;
    wlast    : std_logic;
    wvalid   : std_logic;
    bready   : std_logic;
    araddr   : t_NvmeAddr;
    arvalid  : std_logic;
    rready   : std_logic;
  end record;
  type t_Nvme_sm is record
    awready  : std_logic;
    wready   : std_logic;
    bresp    : t_AxiResp;
    bvalid   : std_logic;
    arready  : std_logic;
    rdata    : t_NvmeData;
    rresp    : t_AxiResp;
    rlast    : std_logic;
    rvalid   : std_logic;
  end record;
  constant c_NvmeNull_ms : t_Nvme_ms := (
    awaddr   => (others => '0'),
    awvalid  => '0',
    wdata    => (others => '0'),
    wstrb    => (others => '0'),
    wlast    => '0',
    wvalid   => '0',
    bready   => '0',
    araddr   => (others => '0'),
    arvalid  => '0',
    rready   => '0' );
  constant c_NvmeNull_sm : t_NvmeNull_sm := (
    awready  => '0',
    wready   => '0',
    bresp    => (others => '0'),
    bvalid   => '0',
    arready  => '0',
    rdata    => (others => '0'),
    rresp    => (others => '0'),
    rlast    => '0',
    rvalid   => '0' );
  -- Read Bundle:
  type t_NvmeRd_ms is record
    araddr   : t_NvmeAddr;
    arvalid  : std_logic;
    rready   : std_logic;
  end record;
  type t_NvmeRd_sm is record
    arready  : std_logic;
    rdata    : t_NvmeData;
    rresp    : t_AxiResp;
    rlast    : std_logic;
    rvalid   : std_logic;
  end record;
  constant c_NvmeRdNull_ms : t_NvmeRd_ms := (
    araddr   => (others => '0'),
    arvalid  => '0',
    rready   => '0' );
  constant c_NvmeRdNull_sm : t_NvmeRd_sm := (
    arready  => '0',
    rdata    => (others => '0'),
    rresp    => (others => '0'),
    rlast    => '0',
    rvalid   => '0' );
  -- Write Bundle:
  type t_NvmeWr_ms is record
    awaddr   : t_NvmeAddr;
    awvalid  : std_logic;
    wdata    : t_NvmeData;
    wstrb    : t_NvmeStrb;
    wlast    : std_logic;
    wvalid   : std_logic;
    bready   : std_logic;
  end record;
  type t_NvmeWr_sm is record
    awready  : std_logic;
    wready   : std_logic;
    bresp    : t_AxiResp;
    bvalid   : std_logic;
  end record;
  constant c_NvmeWrNull_ms : t_NvmeWr_ms := (
    awaddr   => (others => '0'),
    awvalid  => '0',
    wdata    => (others => '0'),
    wstrb    => (others => '0'),
    wlast    => '0',
    wvalid   => '0',
    bready   => '0' );
  constant c_NvmeWrNull_sm : t_NvmeWr_sm := (
    awready  => '0',
    wready   => '0',
    bresp    => (others => '0'),
    bvalid   => '0' );
  -- Address Bundle:
  type t_NvmeAdr_ms is record
    aaddr    : t_NvmeAddr;
    avalid   : std_logic;
  end record;
  type t_NvmeAdr_sm is record
    aready   : std_logic;
  end record;
  constant t_NvmeAdrNull_ms : t_NvmeAdr_ms := (
    aaddr    => (others => '0'),
    avalid   => '0' );
  constant t_NvmeAdrNull_sm : t_NvmeAdr_sm := (
    awready  => '0' );
  -- Conversion Functions:
  function f_NvmeSplitRd_ms(v_axi : t_Nvme_ms) return t_NvmeRd_ms;
  function f_NvmeSplitRd_sm(v_axi : t_Nvme_sm) return t_NvmeRd_sm;
  function f_NvmeSplitWr_ms(v_axi : t_Nvme_ms) return t_NvmeWr_ms;
  function f_NvmeSplitWr_sm(v_axi : t_Nvme_sm) return t_NvmeWr_sm;
  function f_NvmeJoinRdWr_ms(v_axiRd : t_NvmeRd_ms; v_axiWr : t_NvmeWr_ms) return t_Nvme_ms;
  function f_NvmeJoinRdWr_sm(v_axiRd : t_NvmeRd_sm; v_axiWr : t_NvmeWr_sm) return t_Nvme_sm;
  function f_NvmeRdSplitAdr_ms(v_axiRd : t_NvmeRd_ms) return t_NvmeAdr_ms;
  function f_NvmeRdSplitAdr_sm(v_axiRd : t_NvmeRd_sm) return t_NvmeAdr_sm;
  function f_NvmeRdJoinAdr_ms(v_axiRdIn : t_NvmeRd_ms; v_axiAdr : t_NvmeAdr_ms) return t_NvmeRd_ms;
  function f_NvmeRdJoinAdr_sm(v_axiRdIn : t_NvmeRd_sm; v_axiAdr : t_NvmeAdr_sm) return t_NvmeRd_sm;
  function f_NvmeWrSplitAdr_ms(v_axiWr : t_NvmeWr_ms) return t_NvmeAdr_ms;
  function f_NvmeWrSplitAdr_sm(v_axiWr : t_NvmeWr_sm) return t_NvmeAdr_sm;
  function f_NvmeWrJoinAdr_ms(v_axiWrIn : t_NvmeWr_ms; v_axiAdr : t_NvmeAdr_ms) return t_NvmeWr_ms;
  function f_NvmeWrJoinAdr_sm(v_axiWrIn : t_NvmeWr_sm; v_axiAdr : t_NvmeAdr_sm) return t_NvmeWr_sm;

  -------------------------------------------------------------------------------
  -- Axi Interface: Ctrl
  -------------------------------------------------------------------------------
  --Scalars:
  constant c_CtrlDataWidth : integer := 32;
  constant c_CtrlStrbWidth : integer := c_CtrlDataWidth/8;
  constant c_CtrlByteAddrWidth : integer := f_clog2(c_CtrlStrbWidth);
  constant c_CtrlFullSize : t_AxiSize := to_unsigned(c_CtrlByteAddrWidth, t_AxiSize'length);
  constant c_CtrlBurstLenWidth : integer := c_AxiBurstAlignWidth - c_CtrlByteAddrWidth;
  constant c_CtrlAddrWidth : integer := 32;
  constant c_CtrlWordAddrWidth : integer := c_CtrlAddrWidth - c_CtrlByteAddrWidth;
  subtype t_CtrlData is unsigned (c_CtrlDataWidth-1 downto 0);
  subtype t_CtrlStrb is unsigned (c_CtrlStrbWidth-1 downto 0);
  subtype t_CtrlByteAddr is unsigned (c_CtrlByteAddrWidth-1 downto 0);
  subtype t_CtrlBurstLen is unsigned(c_CtrlBurstLenWidth-1 downto 0);
  subtype t_CtrlAddr is unsigned (c_CtrlAddrWidth-1 downto 0);
  subtype t_CtrlWordAddr is unsigned(c_CtrlWordAddrWidth-1 downto 0);
  --Complete Bundle:
  type t_Ctrl_ms is record
    awaddr   : t_CtrlAddr;
    awvalid  : std_logic;
    wdata    : t_CtrlData;
    wstrb    : t_CtrlStrb;
    wlast    : std_logic;
    wvalid   : std_logic;
    bready   : std_logic;
    araddr   : t_CtrlAddr;
    arvalid  : std_logic;
    rready   : std_logic;
  end record;
  type t_Ctrl_sm is record
    awready  : std_logic;
    wready   : std_logic;
    bresp    : t_AxiResp;
    bvalid   : std_logic;
    arready  : std_logic;
    rdata    : t_CtrlData;
    rresp    : t_AxiResp;
    rlast    : std_logic;
    rvalid   : std_logic;
  end record;
  constant c_CtrlNull_ms : t_Ctrl_ms := (
    awaddr   => (others => '0'),
    awvalid  => '0',
    wdata    => (others => '0'),
    wstrb    => (others => '0'),
    wlast    => '0',
    wvalid   => '0',
    bready   => '0',
    araddr   => (others => '0'),
    arvalid  => '0',
    rready   => '0' );
  constant c_CtrlNull_sm : t_CtrlNull_sm := (
    awready  => '0',
    wready   => '0',
    bresp    => (others => '0'),
    bvalid   => '0',
    arready  => '0',
    rdata    => (others => '0'),
    rresp    => (others => '0'),
    rlast    => '0',
    rvalid   => '0' );
  -- Read Bundle:
  type t_CtrlRd_ms is record
    araddr   : t_CtrlAddr;
    arvalid  : std_logic;
    rready   : std_logic;
  end record;
  type t_CtrlRd_sm is record
    arready  : std_logic;
    rdata    : t_CtrlData;
    rresp    : t_AxiResp;
    rlast    : std_logic;
    rvalid   : std_logic;
  end record;
  constant c_CtrlRdNull_ms : t_CtrlRd_ms := (
    araddr   => (others => '0'),
    arvalid  => '0',
    rready   => '0' );
  constant c_CtrlRdNull_sm : t_CtrlRd_sm := (
    arready  => '0',
    rdata    => (others => '0'),
    rresp    => (others => '0'),
    rlast    => '0',
    rvalid   => '0' );
  -- Write Bundle:
  type t_CtrlWr_ms is record
    awaddr   : t_CtrlAddr;
    awvalid  : std_logic;
    wdata    : t_CtrlData;
    wstrb    : t_CtrlStrb;
    wlast    : std_logic;
    wvalid   : std_logic;
    bready   : std_logic;
  end record;
  type t_CtrlWr_sm is record
    awready  : std_logic;
    wready   : std_logic;
    bresp    : t_AxiResp;
    bvalid   : std_logic;
  end record;
  constant c_CtrlWrNull_ms : t_CtrlWr_ms := (
    awaddr   => (others => '0'),
    awvalid  => '0',
    wdata    => (others => '0'),
    wstrb    => (others => '0'),
    wlast    => '0',
    wvalid   => '0',
    bready   => '0' );
  constant c_CtrlWrNull_sm : t_CtrlWr_sm := (
    awready  => '0',
    wready   => '0',
    bresp    => (others => '0'),
    bvalid   => '0' );
  -- Address Bundle:
  type t_CtrlAdr_ms is record
    aaddr    : t_CtrlAddr;
    avalid   : std_logic;
  end record;
  type t_CtrlAdr_sm is record
    aready   : std_logic;
  end record;
  constant t_CtrlAdrNull_ms : t_CtrlAdr_ms := (
    aaddr    => (others => '0'),
    avalid   => '0' );
  constant t_CtrlAdrNull_sm : t_CtrlAdr_sm := (
    awready  => '0' );
  -- Conversion Functions:
  function f_CtrlSplitRd_ms(v_axi : t_Ctrl_ms) return t_CtrlRd_ms;
  function f_CtrlSplitRd_sm(v_axi : t_Ctrl_sm) return t_CtrlRd_sm;
  function f_CtrlSplitWr_ms(v_axi : t_Ctrl_ms) return t_CtrlWr_ms;
  function f_CtrlSplitWr_sm(v_axi : t_Ctrl_sm) return t_CtrlWr_sm;
  function f_CtrlJoinRdWr_ms(v_axiRd : t_CtrlRd_ms; v_axiWr : t_CtrlWr_ms) return t_Ctrl_ms;
  function f_CtrlJoinRdWr_sm(v_axiRd : t_CtrlRd_sm; v_axiWr : t_CtrlWr_sm) return t_Ctrl_sm;
  function f_CtrlRdSplitAdr_ms(v_axiRd : t_CtrlRd_ms) return t_CtrlAdr_ms;
  function f_CtrlRdSplitAdr_sm(v_axiRd : t_CtrlRd_sm) return t_CtrlAdr_sm;
  function f_CtrlRdJoinAdr_ms(v_axiRdIn : t_CtrlRd_ms; v_axiAdr : t_CtrlAdr_ms) return t_CtrlRd_ms;
  function f_CtrlRdJoinAdr_sm(v_axiRdIn : t_CtrlRd_sm; v_axiAdr : t_CtrlAdr_sm) return t_CtrlRd_sm;
  function f_CtrlWrSplitAdr_ms(v_axiWr : t_CtrlWr_ms) return t_CtrlAdr_ms;
  function f_CtrlWrSplitAdr_sm(v_axiWr : t_CtrlWr_sm) return t_CtrlAdr_sm;
  function f_CtrlWrJoinAdr_ms(v_axiWrIn : t_CtrlWr_ms; v_axiAdr : t_CtrlAdr_ms) return t_CtrlWr_ms;
  function f_CtrlWrJoinAdr_sm(v_axiWrIn : t_CtrlWr_sm; v_axiAdr : t_CtrlAdr_sm) return t_CtrlWr_sm;


  -------------------------------------------------------------------------------
  -- Stream Interface: Base
  -------------------------------------------------------------------------------
  --Scalars:
  constant c_BaseDataWidth : integer := 512;
  constant c_BaseStrbWidth : integer := c_BaseDataWidth/8;
  subtype t_BaseData is unsigned (c_BaseDataWidth-1 downto 0);
  subtype t_BaseStrb is unsigned (c_BaseStrbWidth-1 downto 0);
  -- Complete Bundle:
  type t_BaseStream_ms is record
    tdata   : t_AxiData;
    tstrb   : t_AxiStrb;
    tkeep   : t_AxiStrb;
    tlast   : std_logic;
    tvalid  : std_logic;
  end record;
  type t_BaseStream_sm is record
    tready  : std_logic;
  end record;
  constant c_BaseStreamNull_ms : t_AxiStream_ms := (
    tdata  => (others => '0'),
    tstrb  => (others => '0'),
    tkeep  => (others => '0'),
    tlast  => '0',
    tvalid => '0');
  constant c_BaseStreamNull_sm : t_AxiStream_sm := (
    tready => '0');
  -- Interface List:
  type t_BaseStreams_ms is array (integer range <>) of t_BaseStream_ms;
  type t_BaseStreams_sm is array (integer range <>) of t_BaseStream_sm;

  -------------------------------------------------------------------------------
  -- Stream Interface: Word
  -------------------------------------------------------------------------------
  --Scalars:
  constant c_WordDataWidth : integer := 64;
  constant c_WordStrbWidth : integer := c_WordDataWidth/8;
  subtype t_WordData is unsigned (c_WordDataWidth-1 downto 0);
  subtype t_WordStrb is unsigned (c_WordStrbWidth-1 downto 0);
  -- Complete Bundle:
  type t_WordStream_ms is record
    tdata   : t_AxiData;
    tstrb   : t_AxiStrb;
    tkeep   : t_AxiStrb;
    tlast   : std_logic;
    tvalid  : std_logic;
  end record;
  type t_WordStream_sm is record
    tready  : std_logic;
  end record;
  constant c_WordStreamNull_ms : t_AxiStream_ms := (
    tdata  => (others => '0'),
    tstrb  => (others => '0'),
    tkeep  => (others => '0'),
    tlast  => '0',
    tvalid => '0');
  constant c_WordStreamNull_sm : t_AxiStream_sm := (
    tready => '0');
  -- Interface List:
  type t_WordStreams_ms is array (integer range <>) of t_WordStream_ms;
  type t_WordStreams_sm is array (integer range <>) of t_WordStream_sm;


  -----------------------------------------------------------------------------
  -- Register Map and simplified Port Definitions
  -----------------------------------------------------------------------------

  constant c_RegAxiAddrWidth  : integer := 32;
  subtype t_RegAxiAddr is unsigned (c_RegAxiAddrWidth-1 downto 0);
  -- Actual Register Space Spans 1Kx4B Registers (= 10 Bit Register Numbers)
  constant c_RegAddrWidth  : integer := 10;
  subtype t_RegAddr is unsigned (c_RegAddrWidth-1 downto 0);

  -- Address Range for a Single Port (Offset, Count)
  type t_RegRange is array (0 to 1) of t_RegAddr;
  -- Set of Address Ranges to configure the Register Port Demux
  type t_RegMap is array (integer range <>) of t_RegRange;

  constant c_RegDataWidth  : integer := 32;
  constant c_RegStrbWidth  : integer := c_RegDataWidth/8;
  subtype t_RegData is unsigned (c_RegDataWidth-1  downto 0);
  subtype t_RegStrb is unsigned (c_RegStrbWidth-1 downto 0);

  type t_RegPort_ms is record
    addr      : t_RegAddr;
    wrdata    : t_RegData;
    wrstrb    : t_RegStrb;
    wrnotrd   : std_logic;
    valid     : std_logic;
  end record;
  type t_RegPort_sm is record
    rddata    : t_RegData;
    ready     : std_logic;
  end record;
  constant c_RegPortNull_ms : t_RegPort_ms := (
    addr     => (others => '0'),
    wrdata   => (others => '0'),
    wrstrb   => (others => '0'),
    wrnotrd  => '0',
    valid    => '0');
  constant c_RegPortNull_sm : t_RegPort_sm := (
    rddata   => (others => '0'),
    ready    => '0');

  type t_RegPorts_ms is array (integer range <>) of t_RegPort_ms;
  type t_RegPorts_sm is array (integer range <>) of t_RegPort_sm;

  type t_RegFile is array (integer range <>) of t_RegData;

end fosix_types;


package body fosix_types is

  -------------------------------------------------------------------------------
  -- Axi Interface: Base
  -------------------------------------------------------------------------------
  -- Conversion Functions:
  function f_BaseSplitRd_ms(v_axi : t_Base_ms) return t_BaseRd_ms is
    variable v_axiRd : t_BaseRd_ms;
  begin
    v_axiRd.araddr   := v_axi.araddr;
    v_axiRd.arlen    := v_axi.arlen;
    v_axiRd.arsize   := v_axi.arsize;
    v_axiRd.arburst  := v_axi.arburst;
    v_axiRd.arvalid  := v_axi.arvalid;
    v_axiRd.rready   := v_axi.rready;
    return v_axiRd;
  end f_BaseSplitRd_ms;
  
  function f_BaseSplitRd_sm(v_axi : t_Base_sm) return t_BaseRd_sm is
    variable v_axiRd : t_BaseRd_sm;
  begin
    v_axiRd.arready  := v_axi.arready;
    v_axiRd.rdata    := v_axi.rdata;
    v_axiRd.rresp    := v_axi.rresp;
    v_axiRd.rlast    := v_axi.rlast;
    v_axiRd.rvalid   := v_axi.rvalid;
    return v_axiRd;
  end f_BaseSplitRd_sm;
  
  
  function f_BaseSplitWr_ms(v_axi : t_Base_ms) return t_BaseWr_ms is
    variable v_axiWr : t_BaseWr_ms;
  begin
    v_axiRd.awaddr   := v_axi.awaddr;
    v_axiRd.awlen    := v_axi.awlen;
    v_axiRd.awsize   := v_axi.awsize;
    v_axiRd.awburst  := v_axi.awburst;
    v_axiRd.awvalid  := v_axi.awvalid;
    v_axiRd.wdata    := v_axi.wdata;
    v_axiRd.wstrb    := v_axi.wstrb;
    v_axiRd.wlast    := v_axi.wlast;
    v_axiRd.wvalid   := v_axi.wvalid;
    v_axiRd.bready   := v_axi.bready;
    return v_axiWr;
  end f_BaseSplitWr_ms;
  
  function f_BaseSplitWr_sm(v_axi : t_Base_sm) return t_BaseWr_sm is
    variable v_axiWr : t_BaseWr_sm;
  begin
    v_axiRd.awready  := v_axi.awready;
    v_axiRd.wready   := v_axi.wready;
    v_axiRd.bresp    := v_axi.bresp;
    v_axiRd.bvalid   := v_axi.bvalid;
    return v_axiWr;
  end f_BaseSplitWr_sm;
  
  
  function f_BaseJoinRdWr_ms(v_axiRd : t_BaseRd_ms; v_axiWr : t_BaseWr_ms) return t_Base_ms is
    variable v_axi : t_Base_ms;
  begin
    v_axi.awaddr   := v_axiWr.awaddr;
    v_axi.awlen    := v_axiWr.awlen;
    v_axi.awsize   := v_axiWr.awsize;
    v_axi.awburst  := v_axiWr.awburst;
    v_axi.awvalid  := v_axiWr.awvalid;
    v_axi.wdata    := v_axiWr.wdata;
    v_axi.wstrb    := v_axiWr.wstrb;
    v_axi.wlast    := v_axiWr.wlast;
    v_axi.wvalid   := v_axiWr.wvalid;
    v_axi.bready   := v_axiWr.bready;
    v_axi.araddr   := v_axiRd.araddr;
    v_axi.arlen    := v_axiRd.arlen;
    v_axi.arsize   := v_axiRd.arsize;
    v_axi.arburst  := v_axiRd.arburst;
    v_axi.arvalid  := v_axiRd.arvalid;
    v_axi.rready   := v_axiRd.rready;
    return v_axi;
  end f_BaseJoinRdWr_ms;
  
  function f_BaseJoinRdWr_sm(v_axiRd : t_BaseRd_sm; v_axiWr : t_BaseWr_sm) return t_Base_sm is
    variable v_axi : t_Base_sm;
  begin
    v_axiRd.awready  := v_axiWr.awready;
    v_axiRd.wready   := v_axiWr.wready;
    v_axiRd.bresp    := v_axiWr.bresp;
    v_axiRd.bvalid   := v_axiWr.bvalid;
    v_axiRd.arready  := v_axiRd.arready;
    v_axiRd.rdata    := v_axiRd.rdata;
    v_axiRd.rresp    := v_axiRd.rresp;
    v_axiRd.rlast    := v_axiRd.rlast;
    v_axiRd.rvalid   := v_axiRd.rvalid;
    return v_axi;
  end f_BaseJoinRdWr_sm;
  
  
  function f_BaseRdSplitAdr_ms(v_axiRd : t_BaseRd_ms) return t_BaseAdr_ms is
    variable v_axiAdr : t_BaseAdr_ms;
  begin
    v_axiAdr.aaddr   := v_axiRd.araddr;
    v_axiAdr.alen    := v_axiRd.arlen;
    v_axiAdr.asize   := v_axiRd.arsize;
    v_axiAdr.aburst  := v_axiRd.arburst;
    v_axiAdr.avalid  := v_axiRd.arvalid;
    return v_addr;
  end f_BaseRdSplitAdr_ms;
  
  function f_BaseRdSplitAdr_sm(v_axiRd : t_BaseRd_sm) return t_BaseAdr_sm is
    variable v_axiAdr : t_BaseAdr_sm;
  begin
    v_axiAdr.aready := v_axiRd.arready;
    return v_addr;
  end f_BaseRdSplitAdr_sm;
  
  
  function f_BaseRdJoinAdr_ms(v_axiRdIn : t_BaseRd_ms; v_axiAdr : t_BaseAdr_ms) return t_BaseRd_ms is
    variable v_axiRdOut : t_BaseRd_ms;
  begin
    v_axiRdOut := v_axiRdIn;
    v_axiRdOut.araddr   := v_axiAdr.aaddr;
    v_axiRdOut.arlen    := v_axiAdr.alen;
    v_axiRdOut.arsize   := v_axiAdr.asize;
    v_axiRdOut.arburst  := v_axiAdr.aburst;
    v_axiRdOut.arvalid  := v_axiAdr.avalid;
    return v_axiRdOut;
  end f_BaseRdJoinAdr_ms;
  
  function f_BaseRdJoinAdr_sm(v_axiRdIn : t_BaseRd_sm; v_axiAdr : t_BaseAdr_sm) return t_BaseRd_sm is
    variable v_axiRdOut : t_BaseRd_sm;
  begin
    v_axiRdOut := v_axiRdIn;
    v_axiRdOut.arready  := v_axiAdr.aready;
    return v_axiRdOut;
  end f_BaseRdJoinAdr_sm;
  
  
  function f_BaseWrSplitAdr_ms(v_axiWr : t_BaseWr_ms) return t_BaseAdr_ms is
    variable v_axiAdr : t_BaseAdr_ms;
  begin
      v_axiAdr.aaddr   := v_axiWr.awaddr;
      v_axiAdr.alen    := v_axiWr.awlen;
      v_axiAdr.asize   := v_axiWr.awsize;
      v_axiAdr.aburst  := v_axiWr.awburst;
      v_axiAdr.avalid  := v_axiWr.awvalid;
    return v_axiAdr;
  end f_BaseWrSplitAdr_ms;
  
  function f_BaseWrSplitAdr_sm(v_axiWr : t_BaseWr_sm) return t_BaseAdr_sm is
    variable v_axiAdr : t_BaseAdr_sm;
  begin
    v_axiAdr.aready := v_axiWr.awready;
    return v_axiAdr;
  end f_BaseWrSplitAdr_sm;
  
  
  function f_BaseWrJoinAdr_ms(v_axiWrIn : t_BaseWr_ms; v_axiAdr : t_BaseAdr_ms) return t_BaseWr_ms is
    variable v_axiWrOut : t_BaseWr_ms;
  begin
    v_axiWrOut := v_axiWrIn;
    v_axiWrOut.awaddr   := v_axiAdr.aaddr;
    v_axiWrOut.awlen    := v_axiAdr.alen;
    v_axiWrOut.awsize   := v_axiAdr.asize;
    v_axiWrOut.awburst  := v_axiAdr.aburst;
    v_axiWrOut.awvalid  := v_axiAdr.avalid;
    return v_axiWrOut;
  end f_BaseWrJoinAdr_ms;
  
  function f_BaseWrJoinAdr_sm(v_axiWrIn : t_BaseWr_sm; v_axiAdr : t_BaseAdr_sm) return t_BaseWr_sm is
    variable v_axiWrOut : t_BaseWr_sm;
  begin
    v_axiWrOut := v_axiWrIn;
    v_axiWrOut.awready  := v_axiAdr.aready;
    return v_axiWrOut;
  end f_BaseSpliceAddrWr_sm;

  -------------------------------------------------------------------------------
  -- Axi Interface: Nvme
  -------------------------------------------------------------------------------
  -- Conversion Functions:
  function f_NvmeSplitRd_ms(v_axi : t_Nvme_ms) return t_NvmeRd_ms is
    variable v_axiRd : t_NvmeRd_ms;
  begin
    v_axiRd.araddr   := v_axi.araddr;
    v_axiRd.arvalid  := v_axi.arvalid;
    v_axiRd.rready   := v_axi.rready;
    return v_axiRd;
  end f_NvmeSplitRd_ms;
  
  function f_NvmeSplitRd_sm(v_axi : t_Nvme_sm) return t_NvmeRd_sm is
    variable v_axiRd : t_NvmeRd_sm;
  begin
    v_axiRd.arready  := v_axi.arready;
    v_axiRd.rdata    := v_axi.rdata;
    v_axiRd.rresp    := v_axi.rresp;
    v_axiRd.rlast    := v_axi.rlast;
    v_axiRd.rvalid   := v_axi.rvalid;
    return v_axiRd;
  end f_NvmeSplitRd_sm;
  
  
  function f_NvmeSplitWr_ms(v_axi : t_Nvme_ms) return t_NvmeWr_ms is
    variable v_axiWr : t_NvmeWr_ms;
  begin
    v_axiRd.awaddr   := v_axi.awaddr;
    v_axiRd.awvalid  := v_axi.awvalid;
    v_axiRd.wdata    := v_axi.wdata;
    v_axiRd.wstrb    := v_axi.wstrb;
    v_axiRd.wlast    := v_axi.wlast;
    v_axiRd.wvalid   := v_axi.wvalid;
    v_axiRd.bready   := v_axi.bready;
    return v_axiWr;
  end f_NvmeSplitWr_ms;
  
  function f_NvmeSplitWr_sm(v_axi : t_Nvme_sm) return t_NvmeWr_sm is
    variable v_axiWr : t_NvmeWr_sm;
  begin
    v_axiRd.awready  := v_axi.awready;
    v_axiRd.wready   := v_axi.wready;
    v_axiRd.bresp    := v_axi.bresp;
    v_axiRd.bvalid   := v_axi.bvalid;
    return v_axiWr;
  end f_NvmeSplitWr_sm;
  
  
  function f_NvmeJoinRdWr_ms(v_axiRd : t_NvmeRd_ms; v_axiWr : t_NvmeWr_ms) return t_Nvme_ms is
    variable v_axi : t_Nvme_ms;
  begin
    v_axi.awaddr   := v_axiWr.awaddr;
    v_axi.awvalid  := v_axiWr.awvalid;
    v_axi.wdata    := v_axiWr.wdata;
    v_axi.wstrb    := v_axiWr.wstrb;
    v_axi.wlast    := v_axiWr.wlast;
    v_axi.wvalid   := v_axiWr.wvalid;
    v_axi.bready   := v_axiWr.bready;
    v_axi.araddr   := v_axiRd.araddr;
    v_axi.arvalid  := v_axiRd.arvalid;
    v_axi.rready   := v_axiRd.rready;
    return v_axi;
  end f_NvmeJoinRdWr_ms;
  
  function f_NvmeJoinRdWr_sm(v_axiRd : t_NvmeRd_sm; v_axiWr : t_NvmeWr_sm) return t_Nvme_sm is
    variable v_axi : t_Nvme_sm;
  begin
    v_axiRd.awready  := v_axiWr.awready;
    v_axiRd.wready   := v_axiWr.wready;
    v_axiRd.bresp    := v_axiWr.bresp;
    v_axiRd.bvalid   := v_axiWr.bvalid;
    v_axiRd.arready  := v_axiRd.arready;
    v_axiRd.rdata    := v_axiRd.rdata;
    v_axiRd.rresp    := v_axiRd.rresp;
    v_axiRd.rlast    := v_axiRd.rlast;
    v_axiRd.rvalid   := v_axiRd.rvalid;
    return v_axi;
  end f_NvmeJoinRdWr_sm;
  
  
  function f_NvmeRdSplitAdr_ms(v_axiRd : t_NvmeRd_ms) return t_NvmeAdr_ms is
    variable v_axiAdr : t_NvmeAdr_ms;
  begin
    v_axiAdr.aaddr   := v_axiRd.araddr;
    v_axiAdr.avalid  := v_axiRd.arvalid;
    return v_addr;
  end f_NvmeRdSplitAdr_ms;
  
  function f_NvmeRdSplitAdr_sm(v_axiRd : t_NvmeRd_sm) return t_NvmeAdr_sm is
    variable v_axiAdr : t_NvmeAdr_sm;
  begin
    v_axiAdr.aready := v_axiRd.arready;
    return v_addr;
  end f_NvmeRdSplitAdr_sm;
  
  
  function f_NvmeRdJoinAdr_ms(v_axiRdIn : t_NvmeRd_ms; v_axiAdr : t_NvmeAdr_ms) return t_NvmeRd_ms is
    variable v_axiRdOut : t_NvmeRd_ms;
  begin
    v_axiRdOut := v_axiRdIn;
    v_axiRdOut.araddr   := v_axiAdr.aaddr;
    v_axiRdOut.arvalid  := v_axiAdr.avalid;
    return v_axiRdOut;
  end f_NvmeRdJoinAdr_ms;
  
  function f_NvmeRdJoinAdr_sm(v_axiRdIn : t_NvmeRd_sm; v_axiAdr : t_NvmeAdr_sm) return t_NvmeRd_sm is
    variable v_axiRdOut : t_NvmeRd_sm;
  begin
    v_axiRdOut := v_axiRdIn;
    v_axiRdOut.arready  := v_axiAdr.aready;
    return v_axiRdOut;
  end f_NvmeRdJoinAdr_sm;
  
  
  function f_NvmeWrSplitAdr_ms(v_axiWr : t_NvmeWr_ms) return t_NvmeAdr_ms is
    variable v_axiAdr : t_NvmeAdr_ms;
  begin
      v_axiAdr.aaddr   := v_axiWr.awaddr;
      v_axiAdr.avalid  := v_axiWr.awvalid;
    return v_axiAdr;
  end f_NvmeWrSplitAdr_ms;
  
  function f_NvmeWrSplitAdr_sm(v_axiWr : t_NvmeWr_sm) return t_NvmeAdr_sm is
    variable v_axiAdr : t_NvmeAdr_sm;
  begin
    v_axiAdr.aready := v_axiWr.awready;
    return v_axiAdr;
  end f_NvmeWrSplitAdr_sm;
  
  
  function f_NvmeWrJoinAdr_ms(v_axiWrIn : t_NvmeWr_ms; v_axiAdr : t_NvmeAdr_ms) return t_NvmeWr_ms is
    variable v_axiWrOut : t_NvmeWr_ms;
  begin
    v_axiWrOut := v_axiWrIn;
    v_axiWrOut.awaddr   := v_axiAdr.aaddr;
    v_axiWrOut.awvalid  := v_axiAdr.avalid;
    return v_axiWrOut;
  end f_NvmeWrJoinAdr_ms;
  
  function f_NvmeWrJoinAdr_sm(v_axiWrIn : t_NvmeWr_sm; v_axiAdr : t_NvmeAdr_sm) return t_NvmeWr_sm is
    variable v_axiWrOut : t_NvmeWr_sm;
  begin
    v_axiWrOut := v_axiWrIn;
    v_axiWrOut.awready  := v_axiAdr.aready;
    return v_axiWrOut;
  end f_NvmeSpliceAddrWr_sm;

  -------------------------------------------------------------------------------
  -- Axi Interface: Ctrl
  -------------------------------------------------------------------------------
  -- Conversion Functions:
  function f_CtrlSplitRd_ms(v_axi : t_Ctrl_ms) return t_CtrlRd_ms is
    variable v_axiRd : t_CtrlRd_ms;
  begin
    v_axiRd.araddr   := v_axi.araddr;
    v_axiRd.arvalid  := v_axi.arvalid;
    v_axiRd.rready   := v_axi.rready;
    return v_axiRd;
  end f_CtrlSplitRd_ms;
  
  function f_CtrlSplitRd_sm(v_axi : t_Ctrl_sm) return t_CtrlRd_sm is
    variable v_axiRd : t_CtrlRd_sm;
  begin
    v_axiRd.arready  := v_axi.arready;
    v_axiRd.rdata    := v_axi.rdata;
    v_axiRd.rresp    := v_axi.rresp;
    v_axiRd.rlast    := v_axi.rlast;
    v_axiRd.rvalid   := v_axi.rvalid;
    return v_axiRd;
  end f_CtrlSplitRd_sm;
  
  
  function f_CtrlSplitWr_ms(v_axi : t_Ctrl_ms) return t_CtrlWr_ms is
    variable v_axiWr : t_CtrlWr_ms;
  begin
    v_axiRd.awaddr   := v_axi.awaddr;
    v_axiRd.awvalid  := v_axi.awvalid;
    v_axiRd.wdata    := v_axi.wdata;
    v_axiRd.wstrb    := v_axi.wstrb;
    v_axiRd.wlast    := v_axi.wlast;
    v_axiRd.wvalid   := v_axi.wvalid;
    v_axiRd.bready   := v_axi.bready;
    return v_axiWr;
  end f_CtrlSplitWr_ms;
  
  function f_CtrlSplitWr_sm(v_axi : t_Ctrl_sm) return t_CtrlWr_sm is
    variable v_axiWr : t_CtrlWr_sm;
  begin
    v_axiRd.awready  := v_axi.awready;
    v_axiRd.wready   := v_axi.wready;
    v_axiRd.bresp    := v_axi.bresp;
    v_axiRd.bvalid   := v_axi.bvalid;
    return v_axiWr;
  end f_CtrlSplitWr_sm;
  
  
  function f_CtrlJoinRdWr_ms(v_axiRd : t_CtrlRd_ms; v_axiWr : t_CtrlWr_ms) return t_Ctrl_ms is
    variable v_axi : t_Ctrl_ms;
  begin
    v_axi.awaddr   := v_axiWr.awaddr;
    v_axi.awvalid  := v_axiWr.awvalid;
    v_axi.wdata    := v_axiWr.wdata;
    v_axi.wstrb    := v_axiWr.wstrb;
    v_axi.wlast    := v_axiWr.wlast;
    v_axi.wvalid   := v_axiWr.wvalid;
    v_axi.bready   := v_axiWr.bready;
    v_axi.araddr   := v_axiRd.araddr;
    v_axi.arvalid  := v_axiRd.arvalid;
    v_axi.rready   := v_axiRd.rready;
    return v_axi;
  end f_CtrlJoinRdWr_ms;
  
  function f_CtrlJoinRdWr_sm(v_axiRd : t_CtrlRd_sm; v_axiWr : t_CtrlWr_sm) return t_Ctrl_sm is
    variable v_axi : t_Ctrl_sm;
  begin
    v_axiRd.awready  := v_axiWr.awready;
    v_axiRd.wready   := v_axiWr.wready;
    v_axiRd.bresp    := v_axiWr.bresp;
    v_axiRd.bvalid   := v_axiWr.bvalid;
    v_axiRd.arready  := v_axiRd.arready;
    v_axiRd.rdata    := v_axiRd.rdata;
    v_axiRd.rresp    := v_axiRd.rresp;
    v_axiRd.rlast    := v_axiRd.rlast;
    v_axiRd.rvalid   := v_axiRd.rvalid;
    return v_axi;
  end f_CtrlJoinRdWr_sm;
  
  
  function f_CtrlRdSplitAdr_ms(v_axiRd : t_CtrlRd_ms) return t_CtrlAdr_ms is
    variable v_axiAdr : t_CtrlAdr_ms;
  begin
    v_axiAdr.aaddr   := v_axiRd.araddr;
    v_axiAdr.avalid  := v_axiRd.arvalid;
    return v_addr;
  end f_CtrlRdSplitAdr_ms;
  
  function f_CtrlRdSplitAdr_sm(v_axiRd : t_CtrlRd_sm) return t_CtrlAdr_sm is
    variable v_axiAdr : t_CtrlAdr_sm;
  begin
    v_axiAdr.aready := v_axiRd.arready;
    return v_addr;
  end f_CtrlRdSplitAdr_sm;
  
  
  function f_CtrlRdJoinAdr_ms(v_axiRdIn : t_CtrlRd_ms; v_axiAdr : t_CtrlAdr_ms) return t_CtrlRd_ms is
    variable v_axiRdOut : t_CtrlRd_ms;
  begin
    v_axiRdOut := v_axiRdIn;
    v_axiRdOut.araddr   := v_axiAdr.aaddr;
    v_axiRdOut.arvalid  := v_axiAdr.avalid;
    return v_axiRdOut;
  end f_CtrlRdJoinAdr_ms;
  
  function f_CtrlRdJoinAdr_sm(v_axiRdIn : t_CtrlRd_sm; v_axiAdr : t_CtrlAdr_sm) return t_CtrlRd_sm is
    variable v_axiRdOut : t_CtrlRd_sm;
  begin
    v_axiRdOut := v_axiRdIn;
    v_axiRdOut.arready  := v_axiAdr.aready;
    return v_axiRdOut;
  end f_CtrlRdJoinAdr_sm;
  
  
  function f_CtrlWrSplitAdr_ms(v_axiWr : t_CtrlWr_ms) return t_CtrlAdr_ms is
    variable v_axiAdr : t_CtrlAdr_ms;
  begin
      v_axiAdr.aaddr   := v_axiWr.awaddr;
      v_axiAdr.avalid  := v_axiWr.awvalid;
    return v_axiAdr;
  end f_CtrlWrSplitAdr_ms;
  
  function f_CtrlWrSplitAdr_sm(v_axiWr : t_CtrlWr_sm) return t_CtrlAdr_sm is
    variable v_axiAdr : t_CtrlAdr_sm;
  begin
    v_axiAdr.aready := v_axiWr.awready;
    return v_axiAdr;
  end f_CtrlWrSplitAdr_sm;
  
  
  function f_CtrlWrJoinAdr_ms(v_axiWrIn : t_CtrlWr_ms; v_axiAdr : t_CtrlAdr_ms) return t_CtrlWr_ms is
    variable v_axiWrOut : t_CtrlWr_ms;
  begin
    v_axiWrOut := v_axiWrIn;
    v_axiWrOut.awaddr   := v_axiAdr.aaddr;
    v_axiWrOut.awvalid  := v_axiAdr.avalid;
    return v_axiWrOut;
  end f_CtrlWrJoinAdr_ms;
  
  function f_CtrlWrJoinAdr_sm(v_axiWrIn : t_CtrlWr_sm; v_axiAdr : t_CtrlAdr_sm) return t_CtrlWr_sm is
    variable v_axiWrOut : t_CtrlWr_sm;
  begin
    v_axiWrOut := v_axiWrIn;
    v_axiWrOut.awready  := v_axiAdr.aready;
    return v_axiWrOut;
  end f_CtrlSpliceAddrWr_sm;


end fosix_types;

