-->{{name}}StreamRouter.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_user.all;


entity {{name}} is
  port (
{{#stream_ports}}
  {{#is_master}}
    po_{{port_name}}_ms : out t_{{type_name}}_ms;
    pi_{{port_name}}_sm : in t_{{type_name}}_sm;
  {{/is_master}}
  {{#is_slave}}
    pi_{{port_name}}_ms : in t_{{type_name}}_ms;
    po_{{port_name}}_sm : out t_{{type_name}}_sm;
  {{/is_slave}}

{{/stream_ports}}
{{#simple_ports}}
  {{#is_input}}
    pi_{{port_name}} : in t_{{type_name}};
  {{/is_input}}
  {{#is_output}}
    po_{{port_name}} : out t_{{type_name}};
  {{/is_output}}

{{/simple_ports}}
    pi_start : in  std_logic;
    po_ready : out std_logic;

    pi_rst_n : in  std_logic;
    pi_clk : in  std_logic);
end StreamRouter;

architecture {{name}} of {{name}} is


{{#stream_ports}}
  signal s_{{port_name}}_ms : t_{{type_name}}_ms;
  signal s_{{port_name}}_sm : t_{{type_name}}_sm;
  signal s_{{port_name}}_TDATA : std_logic_vector({{type_datawidth}}-1 downto 0);
  signal s_{{port_name}}_TKEEP : std_logic_vector({{type_datawidth}}/8-1 downto 0);
{{/stream_ports}}

{{#simple_ports}}
  signal s_{{port_name}} : std_logic_vector({{type_width}}-1 downto 0);
{{/simple_ports}}

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
  i_hls : entity work.{{hls_name}}
    port map (
{{#simple_ports}}
      {{port_name}}_V => s_{{port_name}},
{{/simple_ports}}
{{#stream_ports}}
      {{port_name}}_TDATA => s_{{portName}}_TDATA,
      {{port_name}}_TKEEP => s_{{portName}}_TKEEP,
      {{port_name}}_TLAST => s_{{portName}}_ms.tlast,
      {{port_name}}_TVALID => s_{{portName}}_ms.tvalid,
      {{port_name}}_TREADY => s_{{portName}}_sm.tready,
{{/stream_ports}}
      ap_start => s_ap_start,
      ap_done => s_ap_done,
      ap_rst_n => pi_rst_n,
      ap_clk => pi_clk);

  -- Signal conversion
{{#stream_ports}}
  {{#is_master}}
    s_{{port_name}}_ms.tdata <= unsigned(s_{{port_name}}_TDATA);
    s_{{port_name}}_ms.tstrb <= unsigned(s_{{port_name}}_TSTRB);
    po_{{port_name}}_ms <= s_{{port_name}}_ms;
    s_{{port_name}}_sm <= pi_{{port_name}}_sm;
  {{/is_master}}
  {{#is_slave}}
    s_{{port_name}}_ms <= pi_{{port_name}}_ms;
    s_{{port_name}}_TDATA <= std_logic_vector(s_{{port_name}}_ms.tdata);
    s_{{port_name}}_TKEEP <= std_logic_vector(s_{{port_name}}_ms.tkeep);
    po_{{port_name}}_sm <= s_{{port_name}}_sm;
  {{/is_slave}}

{{/stream_ports}}
{{#simple_ports}}
  {{#is_input}}
    s_{{port_name}} <= std_logic_vector(pi_{{port_name}});
  {{/is_input}}
  {{#is_output}}
    po_{{port_name}} <= unsigned(s_{{port_name}});
  {{/is_output}}

{{/simple_ports}}
end {{name}};
