-->fosix_user.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package fosix_user is

{{#StreamTypes}}
  -------------------------------------------------------------------------------
  -- Stream Interface: {{name}}
  -------------------------------------------------------------------------------
  --Scalars:
  subtype t_{{name}}Data is unsigned ({{datawidth}}-1 downto 0);
  subtype t_{{name}}Strb is unsigned ({{datawidth}}/8-1 downto 0);
  -- Complete Bundle:
  type t_{{name}}_ms is record
    tdata   : t_AxiData;
    tkeep   : t_AxiStrb;
    tlast   : std_logic;
    tvalid  : std_logic;
  end record;
  type t_{{name}}_sm is record
    tready  : std_logic;
  end record;
  constant c_{{name}}Null_ms : t_{{name}}_ms := (
    tdata  => (others => '0'),
    tkeep  => (others => '0'),
    tlast  => '0',
    tvalid => '0');
  constant c_{{name}}Null_sm : t_{{name}}_sm := (
    tready => '0');
  -- Safe {{name}} masters produce unlimited Null bytes
  -- and assert tlast to minimize deadlock probability.
  constant c_{{name}}Safe_ms : t_{{name}}_ms := (
    tdata  => (others => '0'),
    tkeep  => (others => '0'),
    tlast  => '1',
    tvalid => '1');
  -- Safe {{name}} slaves accept and ignore arbitrary transfers.
  constant c_{{name}}Safe_sm : t_{{name}}_sm := (
    tready => '1');
  -- Interface List:
  type t_{{name}}_v_ms is array (integer range <>) of t_{{name}}_v_ms;
  type t_{{name}}_v_sm is array (integer range <>) of t_{{name}}_v_sm;
{{/StreamTypes}}

  -----------------------------------------------------------------------------
  -- Simple Types
  -----------------------------------------------------------------------------
{{#SimpleTypes}}
  subtype t_{{name}} is unsigned ({{width}}-1 downto 0);
  type t_{{name}}_v is array (integer range <>) of t_{{name}};

{{/SimpleTypes}}

end fosix_user;
