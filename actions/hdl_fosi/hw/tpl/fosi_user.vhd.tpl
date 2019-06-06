library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package fosi_user is

{{#type_list}}
{{# x_user}}
{{#  x_stream}}
  -------------------------------------------------------------------------------
  -- Stream Type: {{name}}
  -------------------------------------------------------------------------------
  type {{identifier_ms}} is record
    tdata   : unsigned ({{x_datawidth}}-1 downto 0);
    tkeep   : unsigned ({{x_datawidth}}/8-1 downto 0);
    tlast   : std_logic;
    tvalid  : std_logic;
  end record;
  type {{identifier_ms}} is record
    tready  : std_logic;
  end record;
  constant {{const_null_ms}} : {{identifier_ms}} := (
    tdata  => (others => '0'),
    tkeep  => (others => '0'),
    tlast  => '0',
    tvalid => '0');
  constant {{const_null_sm}} : {{identifier_sm}} := (
    tready => '0');
  type {{identifier_v_ms}} is array (integer range <>) of {{identifier_ms}};
  type {{identifier_v_sm}} is array (integer range <>) of {{identifier_sm}};

{{/  x_stream}}
{{#  x_unsigned}}
  -----------------------------------------------------------------------------
  -- Unsigned Type: {{name}}
  -----------------------------------------------------------------------------
  subtype {{identifier}} is unsigned ({{x_width}}-1 downto 0);
  type {{identifier_v}} is array (integer range <>) of {{identifier}};

{{/  x_unsigned}}
{{/ x_user}}
{{/type_list}}
end fosi_user;
