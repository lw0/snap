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

{{#AXI}}
  {{>AxiDef}}

{{/AXI}}

{{#AXIS}}
  {{>AxiStreamDef}}

{{/AXIS}}

  -----------------------------------------------------------------------------
  -- Register Map and simplified Port Definitions
  -----------------------------------------------------------------------------

{{#Ctrl}}
  constant c_RegAxiAddrWidth  : integer := {{addrwidth}};
  subtype t_RegAxiAddr is unsigned (c_RegAxiAddrWidth-1 downto 0);
  -- Actual Register Space Spans 1Kx4B Registers (= 10 Bit Register Numbers)
  constant c_RegAddrWidth  : integer := 10;
  subtype t_RegAddr is unsigned (c_RegAddrWidth-1 downto 0);

  -- Address Range for a Single Port (Offset, Count)
  type t_RegRange is array (0 to 1) of t_RegAddr;
  -- Set of Address Ranges to configure the Register Port Demux
  type t_RegMap is array (integer range <>) of t_RegRange;

  constant c_RegDataWidth  : integer := {{datawidth}};
  constant c_RegStrbWidth  : integer := c_RegDataWidth/8;
  subtype t_RegData is unsigned (c_RegDataWidth-1  downto 0);
  subtype t_RegStrb is unsigned (c_RegStrbWidth-1 downto 0);

  type t_RegFile is array (integer range <>) of t_RegData;

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

{{/Ctrl}}

end fosix_types;


package body fosix_types is

{{#AXI}}
  {{>AxiFunc}}

{{/AXI}}

end fosix_types;

