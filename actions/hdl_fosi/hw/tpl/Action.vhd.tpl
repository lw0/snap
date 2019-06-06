library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosi_axi.all;
use work.fosi_blockmap.all;
use work.fosi_ctrl.all;
use work.fosi_stream.all;
use work.fosi_user.all;
use work.fosi_util.all;

entity Action is
  port (
    pi_clk     : in  std_logic;
    pi_rst_n   : in  std_logic;
    po_intReq  : out std_logic;
    po_intSrc  : out t_InterruptSrc;
    pi_intAck  : in  std_logic;

    -- Ports of Axi Slave Bus Interface AXI_CTRL_REG
    pi_ctrl_ms : in  t_Ctrl_ms;
    po_ctrl_sm : out t_Ctrl_sm;

    -- Ports of Axi Master Bus Interface AXI_HOST_MEM
    po_hmem_ms : out t_NativeAxi_ms;
    pi_hmem_sm : in  t_NativeAxi_sm;

    -- Ports of Axi Master Bus Interface AXI_CARD_MEM0
    po_cmem_ms : out t_NativeAxi_ms;
    pi_cmem_sm : in  t_NativeAxi_sm;

    -- Ports of Axi Master Bus Interface AXI_NVME
    po_nvme_ms : out t_Ctrl_ms;
    pi_nvme_sm : in  t_Ctrl_sm;

    po_context : out t_Context);
end Action;

architecture Action of Action is

  -----------------------------------------------------------------------------
  -- Register Port Map Configuration
  -----------------------------------------------------------------------------
  constant c_Ports : t_RegMap(0 to {{env.g_reg_cnt.value}}-1) := (
{{#env.regmap}}
    (to_unsigned({{offset}}, c_RegAddrWidth), to_unsigned({{count}}, c_RegAddrWidth)){{^_last}},{{/_last}}{{#_last}});{{/_last}}
{{/env.regmap}}
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Signal Declaration
  -----------------------------------------------------------------------------
{{#signals}}
{{#  is_complex}}
  signal {{identifier_ms}} : {{#is_vector}}{{type.identifier_v_ms}}({{width}}-1 downto 0){{/is_vector}}{{^is_vector}}{{type.identifier_ms}}{{/is_vector}};
  signal {{identifier_sm}} : {{#is_vector}}{{type.identifier_v_sm}}({{width}}-1 downto 0){{/is_vector}}{{^is_vector}}{{type.identifier_sm}}{{/is_vector}};
{{/  is_complex}}
{{#  is_simple}}
  signal {{identifier}} : {{#is_vector}}{{type.identifier_v}}({{width}}-1 downto 0){{/is_vector}}{{^is_vector}}{{type.identifier}}{{/is_vector}};
{{/  is_simple}}
{{/signals}}
  -----------------------------------------------------------------------------

begin

  -----------------------------------------------------------------------------
  -- FOSIX Environment
  -----------------------------------------------------------------------------
  -- Handle Axi Ports
{{#env.p_hmem.is_connected}}
  po_hmem_ms <= {{env.p_hmem.connection.identifier_ms}};
  {{env.p_hmem.connection.identifier_sm}} <= pi_hmem_sm;
{{/env.p_hmem.is_connected}}
{{^env.p_hmem.is_connected}}
  po_hmem_ms <= c_NativeAxiNull_ms;
{{/env.p_hmem.is_connected}}

{{#env.p_cmem.is_connected}}
  po_cmem_ms <= {{env.p_cmem.connection.identifier_ms}};
  {{env.p_cmem.connection.identifier_sm}} <= pi_cmem_sm;
{{/env.p_cmem.is_connected}}
{{^env.p_cmem.is_connected}}
  po_cmem_ms <= c_NativeAxiNull_ms;
{{/env.p_cmem.is_connected}}

{{#env.p_nvme.is_connected}}
  po_nvme_ms <= {{env.p_nvme.connection.identifier_ms}};
  {{env.p_nvme.connection.identifier_sm}} <= pi_nvme_sm;
{{/env.p_nvme.is_connected}}
{{^env.p_nvme.is_connected}}
  po_nvme_ms <= c_CtrlNull_ms;
{{/env.p_nvme.is_connected}}

  -- Demultiplex and Simplify Control Register Ports
  i_ctrlDemux : entity work.CtrlRegDemux
    generic map (
      g_Ports => c_Ports)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_ctrl_ms => pi_ctrl_ms,
      po_ctrl_sm => po_ctrl_sm,
      po_ports_ms => {{env.p_regs.unpack_signal.identifier_ms}},
      pi_ports_sm => {{env.p_regs.unpack_signal.identifier_sm}});
{{#env.p_regs.connections}}
  {{identifier_ms}} <= {{env.p_regs.unpack_signal.identifier_ms}}({{_idx}});
  {{env.p_regs.unpack_signal.identifier_sm}}({{_idx}}) <= {{identifier_sm}};
{{/env.p_regs.connections}}

  -- Action Status and Interrupt Logic:
  i_actionControl : entity work.ActionControl
    generic map (
      g_ReadyCount => {{env.g_ready_cnt.value}},
      g_ActionType => {{env.g_action_type.value}},
      g_ActionRev => {{env.g_action_rev.value}})
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      po_intReq       => po_intReq,
      po_intSrc       => po_intSrc,
      pi_intAck       => pi_intAck,
      po_context      => po_context,
      pi_regs_ms      => {{env.s_ctrlRegs.identifier_ms}},
      po_regs_sm      => {{env.s_ctrlRegs.identifier_sm}},
{{#env.p_int1.is_connected}}
      pi_irq1         => {{env.p_int1.connection.identifier_ms}},
      po_iack1        => {{env.p_int1.connection.identifier_sm}},
{{/env.p_int1.is_connected}}
{{#env.p_int2.is_connected}}
      pi_irq2         => {{env.p_int2.connection.identifier_ms}},
      po_iack2        => {{env.p_int2.connection.identifier_sm}},
{{/env.p_int2.is_connected}}
{{#env.p_int3.is_connected}}
      pi_irq3         => {{env.p_int3.connection.identifier_ms}},
      po_iack3        => {{env.p_int3.connection.identifier_sm}},
{{/env.p_int3.is_connected}}
      po_start        => {{env.p_start.connection.identifier}},
      pi_ready        => {{env.p_ready.unpack_signal.identifier}});
{{#env.p_ready.connections}}
  {{env.p_ready.unpack_signal.identifier}}({{_idx}}) <= {{identifier}};
{{/env.p_ready.connections}}
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- User Instances
  -----------------------------------------------------------------------------
{{#instances}}
  {{identifier}} : entity work.{{entity_identifier}}
{{# has_generics}}
    generic map (
{{#  generics}}
{{#   is_assigned}}
      {{identifier}} => {{value}}{{^_last}},{{/_last}}{{#_last}}){{/_last}}
{{/   is_assigned}}
{{^   is_assigned}}
      {{identifier}} => open{{^_last}},{{/_last}}{{#_last}}){{/_last}}
{{/   is_assigned}}
{{/  generics}}
{{/ has_generics}}
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
{{# ports}}
{{#  is_vector}}
{{#   is_simple}}
      {{identifier}} => {{#is_connected}}{{unpack_signal.identifier}}{{/is_connected}}{{^is_connected}}open{{/is_connected}}{{^_last}},{{/_last}}{{#_last}});{{/_last}}
{{/   is_simple}}
{{#   is_complex}}
      {{identifier_ms}} => {{#is_connected}}{{unpack_signal.identifier_ms}}{{/is_connected}}{{^is_connected}}open{{/is_connected}},
      {{identifier_sm}} => {{#is_connected}}{{unpack_signal.identifier_sm}}{{/is_connected}}{{^is_connected}}open{{/is_connected}}{{^_last}},{{/_last}}{{#_last}});{{/_last}}
{{/   is_complex}}
{{/  is_vector}}
{{^  is_vector}}
{{#   is_simple}}
      {{identifier}} => {{#is_connected}}{{connection.identifier}}{{/is_connected}}{{^is_connected}}open{{/is_connected}}{{^_last}},{{/_last}}{{#_last}});{{/_last}}
{{/   is_simple}}
{{#   is_complex}}
      {{identifier_ms}} => {{#is_connected}}{{connection.identifier_ms}}{{/is_connected}}{{^is_connected}}open{{/is_connected}},
      {{identifier_sm}} => {{#is_connected}}{{connection.identifier_sm}}{{/is_connected}}{{^is_connected}}open{{/is_connected}}{{^_last}},{{/_last}}{{#_last}});{{/_last}}
{{/   is_complex}}
{{/  is_vector}}
{{/ ports}}
{{# ports}}
{{#  is_connected}}
{{#   is_vector}}
  -- Unpack {{name}}:
{{#    connections}}
{{#     is_input}}
  {{unpack_signal.identifier}}({{_idx}}) <= {{identifier}};
{{/     is_input}}
{{#     is_output}}
  {{identifier}} <= {{unpack_signal.identifier}}({{_idx}});
{{/     is_output}}
{{#     is_view}}
  {{unpack_signal.identifier_ms}}({{_idx}}) <= {{identifier_ms}};
  {{unpack_signal.identifier_sm}}({{_idx}}) <= {{identifier_sm}};
{{/     is_view}}
{{#     is_slave}}
  {{unpack_signal.identifier_ms}}({{_idx}}) <= {{identifier_ms}};
  {{identifier_sm}} <= {{unpack_signal.identifier_sm}}({{_idx}});
{{/     is_slave}}
{{#     is_master}}
  {{identifier_ms}} <= {{unpack_signal.identifier_ms}}({{_idx}});
  {{unpack_signal.identifier_sm}}({{_idx}}) <= {{identifier_sm}};
{{/     is_master}}
{{/    connections}}
{{/   is_vector}}
{{/  is_connected}}
{{/ ports}}

{{/instances}}
  -----------------------------------------------------------------------------

end Action;
