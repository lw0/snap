-------------------------------------------------------------------------------
-- Axi Interface: {{name}}
-------------------------------------------------------------------------------
--Scalars:
constant c_{{name}}DataWidth : integer := {{datawidth}};
constant c_{{name}}StrbWidth : integer := c_{{name}}DataWidth/8;
constant c_{{name}}ByteAddrWidth : integer := f_clog2(c_{{name}}StrbWidth);
constant c_{{name}}FullSize : t_AxiSize := to_unsigned(c_{{name}}ByteAddrWidth, t_AxiSize'length);
constant c_{{name}}BurstLenWidth : integer := c_AxiBurstAlignWidth - c_{{name}}ByteAddrWidth;
constant c_{{name}}AddrWidth : integer := {{addrwidth}};
constant c_{{name}}WordAddrWidth : integer := c_{{name}}AddrWidth - c_{{name}}ByteAddrWidth;
subtype t_{{name}}Data is unsigned (c_{{name}}DataWidth-1 downto 0);
subtype t_{{name}}Strb is unsigned (c_{{name}}StrbWidth-1 downto 0);
subtype t_{{name}}ByteAddr is unsigned (c_{{name}}ByteAddrWidth-1 downto 0);
subtype t_{{name}}BurstLen is unsigned(c_{{name}}BurstLenWidth-1 downto 0);
subtype t_{{name}}Addr is unsigned (c_{{name}}AddrWidth-1 downto 0);
subtype t_{{name}}WordAddr is unsigned(c_{{name}}WordAddrWidth-1 downto 0);
{{#idwidth}}
subtype t_{{name}}Id is unsigned ({{idwidth}}-1 downto 0);
{{/idwidth}}
--Complete Bundle:
type t_{{name}}_ms is record
{{#idwidth}}
  awid     : t_{{name}}Id;
{{/idwidth}}
  awaddr   : t_{{name}}Addr;
{{^no_burst}}
  awlen    : t_AxiLen;
  awsize   : t_AxiSize;
  awburst  : t_AxiBurst;
{{/no_burst}}
{{^no_attrib}}
  awlock   : t_AxiLock;
  awcache  : t_AxiCache;
  awprot   : t_AxiProt;
  awqos    : t_AxiQos;
  awregion : t_AxiRegion;
{{/no_attrib}}
  awvalid  : std_logic;
  wdata    : t_{{name}}Data;
  wstrb    : t_{{name}}Strb;
  wlast    : std_logic;
  wvalid   : std_logic;
  bready   : std_logic;
{{#idwidth}}
  arid     : t_{{name}}Id;
{{/idwidth}}
  araddr   : t_{{name}}Addr;
{{^no_burst}}
  arlen    : t_AxiLen;
  arsize   : t_AxiSize;
  arburst  : t_AxiBurst;
{{/no_burst}}
{{^no_attrib}}
  arlock   : t_AxiLock;
  arcache  : t_AxiCache;
  arprot   : t_AxiProt;
  arqos    : t_AxiQos;
  arregion : t_AxiRegion;
{{/no_attrib}}
  arvalid  : std_logic;
  rready   : std_logic;
end record;
type t_{{name}}_sm is record
  awready  : std_logic;
  wready   : std_logic;
{{#idwidth}}
  bid      : t_{{name}}Id;
{{/idwidth}}
  bresp    : t_AxiResp;
  bvalid   : std_logic;
  arready  : std_logic;
{{#idwidth}}
  rid      : t_{{name}}Id;
{{/idwidth}}
  rdata    : t_{{name}}Data;
  rresp    : t_AxiResp;
  rlast    : std_logic;
  rvalid   : std_logic;
end record;
constant c_{{name}}Null_ms : t_{{name}}_ms := (
{{#idwidth}}
  awid     => (others => '0'),
{{/idwidth}}
  awaddr   => (others => '0'),
{{^no_burst}}
  awlen    => c_AxiNullLen,
  awsize   => c_{{name}}FullSize,
  awburst  => c_AxiNullBurst,
{{/no_burst}}
{{^no_attrib}}
  awlock   => c_AxiNullLock,
  awcache  => c_AxiNullCache,
  awprot   => c_AxiNullProt,
  awqos    => c_AxiNullQos,
  awregion => c_AxiNullRegion,
{{/no_attrib}}
  awvalid  => '0',
  wdata    => (others => '0'),
  wstrb    => (others => '0'),
  wlast    => '0',
  wvalid   => '0',
  bready   => '0',
{{#idwidth}}
  arid     => (others => '0'),
{{/idwidth}}
  araddr   => (others => '0'),
{{^no_burst}}
  arlen    => c_AxiNullLen,
  arsize   => c_{{name}}FullSize,
  arburst  => c_AxiNullBurst,
{{/no_burst}}
{{^no_attrib}}
  arlock   => c_AxiNullLock,
  arcache  => c_AxiNullCache,
  arprot   => c_AxiNullProt,
  arqos    => c_AxiNullQos,
  arregion => c_AxiNullRegion,
{{/no_attrib}}
  arvalid  => '0',
  rready   => '0' );
constant c_{{name}}Null_sm : t_{{name}}Null_sm := (
  awready  => '0',
  wready   => '0',
{{#idwidth}}
  bid      => (others => '0'),
{{/idwidth}}
  bresp    => (others => '0'),
  bvalid   => '0',
  arready  => '0',
{{#idwidth}}
  rid      => (others => '0'),
{{/idwidth}}
  rdata    => (others => '0'),
  rresp    => (others => '0'),
  rlast    => '0',
  rvalid   => '0' );
-- Read Bundle:
type t_{{name}}Rd_ms is record
{{#idwidth}}
  arid     : t_{{name}}Id;
{{/idwidth}}
  araddr   : t_{{name}}Addr;
{{^no_burst}}
  arlen    : t_AxiLen;
  arsize   : t_AxiSize;
  arburst  : t_AxiBurst;
{{/no_burst}}
{{^no_attrib}}
  arlock   : t_AxiLock;
  arcache  : t_AxiCache;
  arprot   : t_AxiProt;
  arqos    : t_AxiQos;
  arregion : t_AxiRegion;
{{/no_attrib}}
  arvalid  : std_logic;
  rready   : std_logic;
end record;
type t_{{name}}Rd_sm is record
  arready  : std_logic;
{{#idwidth}}
  rid      : t_{{name}}Id;
{{/idwidth}}
  rdata    : t_{{name}}Data;
  rresp    : t_AxiResp;
  rlast    : std_logic;
  rvalid   : std_logic;
end record;
constant c_{{name}}RdNull_ms : t_{{name}}Rd_ms := (
{{#idwidth}}
  arid     => (others => '0'),
{{/idwidth}}
  araddr   => (others => '0'),
{{^no_burst}}
  arlen    => c_AxiNullLen,
  arsize   => c_{{name}}FullSize,
  arburst  => c_AxiNullBurst,
{{/no_burst}}
{{^no_attrib}}
  arlock   => c_AxiNullLock,
  arcache  => c_AxiNullCache,
  arprot   => c_AxiNullProt,
  arqos    => c_AxiNullQos,
  arregion => c_AxiNullRegion,
{{/no_attrib}}
  arvalid  => '0',
  rready   => '0' );
constant c_{{name}}RdNull_sm : t_{{name}}Rd_sm := (
  arready  => '0',
{{#idwidth}}
  rid      => (others => '0'),
{{/idwidth}}
  rdata    => (others => '0'),
  rresp    => (others => '0'),
  rlast    => '0',
  rvalid   => '0' );
-- Write Bundle:
type t_{{name}}Wr_ms is record
{{#idwidth}}
  awid     : t_{{name}}Id;
{{/idwidth}}
  awaddr   : t_{{name}}Addr;
{{^no_burst}}
  awlen    : t_AxiLen;
  awsize   : t_AxiSize;
  awburst  : t_AxiBurst;
{{/no_burst}}
{{^no_attrib}}
  awlock   : t_AxiLock;
  awcache  : t_AxiCache;
  awprot   : t_AxiProt;
  awqos    : t_AxiQos;
  awregion : t_AxiRegion;
{{/no_attrib}}
  awvalid  : std_logic;
  wdata    : t_{{name}}Data;
  wstrb    : t_{{name}}Strb;
  wlast    : std_logic;
  wvalid   : std_logic;
  bready   : std_logic;
end record;
type t_{{name}}Wr_sm is record
  awready  : std_logic;
  wready   : std_logic;
{{#idwidth}}
  bid      : t_{{name}}Id;
{{/idwidth}}
  bresp    : t_AxiResp;
  bvalid   : std_logic;
end record;
constant c_{{name}}WrNull_ms : t_{{name}}Wr_ms := (
{{#idwidth}}
  awid     => (others => '0'),
{{/idwidth}}
  awaddr   => (others => '0'),
{{^no_burst}}
  awlen    => c_AxiNullLen,
  awsize   => c_{{name}}FullSize,
  awburst  => c_AxiNullBurst,
{{/no_burst}}
{{^no_attrib}}
  awlock   => c_AxiNullLock,
  awcache  => c_AxiNullCache,
  awprot   => c_AxiNullProt,
  awqos    => c_AxiNullQos,
  awregion => c_AxiNullRegion,
{{/no_attrib}}
  awvalid  => '0',
  wdata    => (others => '0'),
  wstrb    => (others => '0'),
  wlast    => '0',
  wvalid   => '0',
  bready   => '0' );
constant c_{{name}}WrNull_sm : t_{{name}}Wr_sm := (
  awready  => '0',
  wready   => '0',
{{#idwidth}}
  bid      => (others => '0'),
{{/idwidth}}
  bresp    => (others => '0'),
  bvalid   => '0' );
-- Address Channel AR or AW:
type t_{{name}}A_od is record
{{#idwidth}}
  id      : t_{{name}}Id;
{{/idwidth}}
  addr    : t_{{name}}Addr;
{{^no_burst}}
  len     : t_AxiLen;
  size    : t_AxiSize;
  burst   : t_AxiBurst;
{{/no_burst}}
{{^no_attrib}}
  lock    : t_AxiLock;
  cache   : t_AxiCache;
  prot    : t_AxiProt;
  qos     : t_AxiQos;
  region  : t_AxiRegion;
{{/no_attrib}}
  valid   : std_logic;
end record;
type t_{{name}}A_do is record
  ready   : std_logic;
end record;
constant t_{{name}}ANull_od : t_{{name}}A_od := (
{{#idwidth}}
  id      => (others => '0'),
{{/idwidth}}
  addr    => (others => '0'),
{{^no_burst}}
  len     => c_AxiNullLen,
  size    => c_{{name}}FullSize,
  burst   => c_AxiNullBurst,
{{/no_burst}}
{{^no_attrib}}
  lock    => c_AxiNullLock,
  cache   => c_AxiNullCache,
  prot    => c_AxiNullProt,
  qos     => c_AxiNullQos,
  region  => c_AxiNullRegion,
{{/no_attrib}}
  valid   => '0' );
constant t_{{name}}ANull_do : t_{{name}}A_do := (
  ready  => '0' );
-- Read Channel R:
type t_{{name}}R_od is record
{{#idwidth}}
  id      : t_{{name}}Id;
{{/idwidth}}
  data    : t_{{name}}Data;
  resp    : t_AxiResp;
  last    : std_logic;
  valid   : std_logic;
end record;
type t_{{name}}R_do is record
  ready   : std_logic;
end record;
constant c_{{name}}RNull_od : t_{{name}}R_od := (
{{#idwidth}}
  id      => (others => '0'),
{{/idwidth}}
  data    => (others => '0'),
  resp    => (others => '0'),
  last    => '0',
  valid   => '0' );
constant c_{{name}}RNull_do : t_{{name}}R_do := (
  ready   => '0' );
-- Write Channel W:
type t_{{name}}W_od is record
  data    : t_{{name}}Data;
  strb    : t_{{name}}Strb;
  last    : std_logic;
  valid   : std_logic;
end record;
type t_{{name}}W_do is record
  ready   : std_logic;
end record;
constant c_{{name}}WNull_od : t_{{name}}W_od := (
  data    => (others => '0'),
  strb    => (others => '0'),
  last    => '0',
  valid   => '0' );
constant c_{{name}}WNull_do : t_{{name}}W_do := (
  ready   => '0' );
-- Write Response Channel B:
type t_{{name}}B_od is record
{{#idwidth}}
  id      : t_{{name}}Id;
{{/idwidth}}
  resp    : t_AxiResp;
  valid   : std_logic;
end record;
type t_{{name}}B_do is record
  ready   : std_logic;
end record;
constant c_{{name}}BNull_od : t_{{name}}B_od := (
{{#idwidth}}
  id      => (others => '0'),
{{/idwidth}}
  resp    => (others => '0'),
  valid   => '0' );
constant c_{{name}}BNull_do : t_{{name}}B_do := (
  ready   => '0' );
-- Conversion Functions:
function f_{{name}}SplitRd_ms(v_axi : t_{{name}}_ms) return t_{{name}}Rd_ms;
function f_{{name}}SplitRd_sm(v_axi : t_{{name}}_sm) return t_{{name}}Rd_sm;
function f_{{name}}SplitWr_ms(v_axi : t_{{name}}_ms) return t_{{name}}Wr_ms;
function f_{{name}}SplitWr_sm(v_axi : t_{{name}}_sm) return t_{{name}}Wr_sm;
function f_{{name}}JoinRdWr_ms(v_axiRd : t_{{name}}Rd_ms; v_axiWr : t_{{name}}Wr_ms) return t_{{name}}_ms;
function f_{{name}}JoinRdWr_sm(v_axiRd : t_{{name}}Rd_sm; v_axiWr : t_{{name}}Wr_sm) return t_{{name}}_sm;
function f_{{name}}RdSplitA_ms(v_axiRd : t_{{name}}Rd_ms) return t_{{name}}A_od;
function f_{{name}}RdSplitA_sm(v_axiRd : t_{{name}}Rd_sm) return t_{{name}}A_do;
function f_{{name}}RdSplitR_ms(v_axiRd : t_{{name}}Rd_ms) return t_{{name}}R_do;
function f_{{name}}RdSplitR_sm(v_axiRd : t_{{name}}Rd_sm) return t_{{name}}R_od;
function f_{{name}}RdJoin_ms(v_axiA : t_{{name}}A_od; v_axiR : t_{{name}}R_do) return t_{{name}}Rd_ms;
function f_{{name}}RdJoin_sm(v_axiA : t_{{name}}A_do; v_axiR : t_{{name}}R_od) return t_{{name}}Rd_sm;
function f_{{name}}WrSplitA_ms(v_axiWr : t_{{name}}Wr_ms) return t_{{name}}A_od;
function f_{{name}}WrSplitA_sm(v_axiWr : t_{{name}}Wr_sm) return t_{{name}}A_do;
function f_{{name}}WrSplitW_ms(v_axiWr : t_{{name}}Wr_ms) return t_{{name}}W_od;
function f_{{name}}WrSplitW_sm(v_axiWr : t_{{name}}Wr_sm) return t_{{name}}W_do;
function f_{{name}}WrSplitB_ms(v_axiWr : t_{{name}}Wr_ms) return t_{{name}}B_do;
function f_{{name}}WrSplitB_sm(v_axiWr : t_{{name}}Wr_sm) return t_{{name}}B_od;
function f_{{name}}WrJoin_ms(v_axiA : t_{{name}}A_od; v_axiW : t_{{name}}W_od; v_axiB : t_{{name}}B_do) return t_{{name}}Wr_ms;
function f_{{name}}WrJoin_sm(v_axiA : t_{{name}}A_do; v_axiW : t_{{name}}W_do; v_axiB : t_{{name}}B_od) return t_{{name}}Wr_sm;
