-->{{name}}StreamRouter.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_user.all;


entity {{name}} is
  port (
{{#port_list}}
{{# is_complex}}
{{# type.x_stream}}
    {{identifier_ms}} : {{mode_ms}} {{type.identifier_ms}};
    {{identifier_sm}} : {{mode_sm}} {{type.identifier_sm}};

{{/ type.x_stream}}
{{/ is_complex}}
{{# is_simple}}
{{# type.x_unsigned}}
    {{identifier}} : {{mode}} {{type.identifier}};

{{/ type.x_unsigned}}
{{/ is_simple}}
{{/port_list}}
    pi_start : in  std_logic;
    po_ready : out std_logic;

    pi_rst_n : in  std_logic;
    pi_clk : in  std_logic);
end {{name}};

architecture {{name}} of {{name}} is

{{#port_list}}
 {{#is_complex}}
 {{#type.x_stream}}
  signal s_{{name}}_ms : {{type.identifier_ms}};
  signal s_{{name}}_sm : {{type.identifier_sm}};
  signal s_{{name}}_TDATA : std_logic_vector({{type.x_datawidth}}-1 downto 0);
  signal s_{{name}}_TKEEP : std_logic_vector({{type.x_datawidth}}/8-1 downto 0);

 {{/type.x_stream}}
 {{/is_complex}}
 {{#is_simple}}
 {{#type.x_unsigned}}
  signal s_{{name}} : std_logic_vector({{type.x_width}}-1 downto 0);

 {{/type.x_unsigned}}
 {{/is_simple}}
{{/port_list}}
  signal s_ap_start : std_logic;
  signal s_ap_done : std_logic;

begin

  -- Protocol State Machine
  process(pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_ap_start <= '0';
      elsif s_ap_start = '0' and pi_start = '1' then
        s_ap_start <= '1';
      elsif s_ap_start = '1' and s_ap_done = '1' then
        s_ap_start <= '0';
      end if;
    end if;
  end process;
  po_ready <= not s_ap_start;

  -- Instantiation
  i_hls : entity work.{{props.hls_name}}
    port map (
{{#port_list}}
 {{#is_complex}}
 {{#type.x_stream}}
      {{name}}_TDATA => s_{{name}}_TDATA,
      {{name}}_TKEEP => s_{{name}}_TKEEP,
      {{name}}_TLAST => s_{{name}}_ms.tlast,
      {{name}}_TVALID => s_{{name}}_ms.tvalid,
      {{name}}_TREADY => s_{{name}}_sm.tready,
 {{/type.x_stream}}
 {{/is_complex}}
 {{#is_simple}}
 {{#type.x_unsigned}}
      {{name}}_V => s_{{name}},
 {{/type.x_unsigned}}
 {{/is_simple}}
{{/port_list}}
      ap_start => s_ap_start,
      ap_done => s_ap_done,
      ap_rst_n => pi_rst_n,
      ap_clk => pi_clk);

  -- Signal conversion
{{#port_list}}
{{# is_complex}}
{{# type.x_stream}}
{{#  is_master}}
  s_{{name}}_ms.tdata <= unsigned(s_{{name}}_TDATA);
  s_{{name}}_ms.tstrb <= unsigned(s_{{name}}_TSTRB);
  po_{{name}}_ms <= s_{{name}}_ms;
  s_{{name}}_sm <= pi_{{name}}_sm;
{{/  is_master}}
{{#  is_slave}}
  s_{{name}}_TDATA <= std_logic_vector(s_{{name}}_ms.tdata);
  s_{{name}}_TKEEP <= std_logic_vector(s_{{name}}_ms.tkeep);
  s_{{name}}_ms <= pi_{{name}}_ms;
  po_{{name}}_sm <= s_{{name}}_sm;
{{/  is_slave}}

{{/ type.x_stream}}
{{/ is_complex}}
{{# is_simple}}
{{# type.x_unsigned}}
{{#  is_input}}
  s_{{name}} <= std_logic_vector(pi_{{name}});
{{/  is_input}}
{{#  is_output}}
  po_{{name}} <= unsigned(s_{{name}});
{{/  is_output}}

{{/ type.x_unsigned}}
{{/ is_simple}}
{{/port_list}}
end {{name}};
