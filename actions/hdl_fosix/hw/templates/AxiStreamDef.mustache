-------------------------------------------------------------------------------
-- Stream Interface: {{name}}
-------------------------------------------------------------------------------
--Scalars:
constant c_Stm{{name}}DataWidth : integer := {{datawidth}};
constant c_Stm{{name}}StrbWidth : integer := c_{{name}}DataWidth/8;
subtype t_Stm{{name}}Data is unsigned (c_{{name}}DataWidth-1 downto 0);
subtype t_Stm{{name}}Strb is unsigned (c_{{name}}StrbWidth-1 downto 0);
-- Complete Bundle:
type t_Stm{{name}}_ms is record
  tdata   : t_AxiData;
  tstrb   : t_AxiStrb;
  tkeep   : t_AxiStrb;
  tlast   : std_logic;
  tvalid  : std_logic;
end record;
type t_Stm{{name}}_sm is record
  tready  : std_logic;
end record;
constant c_Stm{{name}}Null_ms : t_AxiStream_ms := (
  tdata  => (others => '0'),
  tstrb  => (others => '0'),
  tkeep  => (others => '0'),
  tlast  => '0',
  tvalid => '0');
constant c_Stm{{name}}Null_sm : t_AxiStream_sm := (
  tready => '0');
-- Safe Stm{{name}} masters produce unlimited Null bytes
-- and assert tlast to minimize deadlock probability.
constant c_Stm{{name}}Safe_ms : t_AxiStream_ms := (
  tdata  => (others => '0'),
  tstrb  => (others => '0'),
  tkeep  => (others => '0'),
  tlast  => '1',
  tvalid => '1');
-- Safe Stm{{name}} slaves accept and ignore arbitrary transfers.
constant c_Stm{{name}}Safe_sm : t_AxiStream_sm := (
  tready => '1');
-- Interface List:
type t_Stm{{name}}_ms_v is array (integer range <>) of t_Stm{{name}}_ms_v;
type t_Stm{{name}}_sm_v is array (integer range <>) of t_Stm{{name}}_sm_v;
