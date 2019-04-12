library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_util.all;

{{#x_type.x_stream}}
entity {{name}} is
  generic (
    g_LogDepth  : positive,
    g_InEnableFree : natural := 0,
    g_OutEnableFill : natural := 0,
    g_OmitKeep : boolean := false);
  port (
    pi_clk       : in  std_logic;
    pi_rst_n     : in  std_logic;

    pi_stmIn_ms  : in  {{x_type.identifier_ms}};
    po_stmIn_sm  : out {{x_type.identifier_sm}};

    po_inEnable  : out std_logic;

    po_stmOut_ms : out {{x_type.identifier_ms}};
    pi_stmOut_sm : in  {{x_type.identifier_sm}};

    po_outEnable : out std_logic);
end {{name}};

architecture {{name}} of {{name}} is

  constant c_DataWidth : integer := {{x_type.x_datawidth}};
  constant c_KeepWidth : integer := c_DataWidth/8;

  function f_packedWidth() return integer is
  begin
    if g_OmitKeep then
      return c_DataWidth + 1;
    else
      return c_DataWidth + c_KeepWidth + 1;
    end if;
  end f_packedWidth;
  constant c_PackedWidth : integer = f_packedWidth();
  subtype t_Packed is unsigned (c_PackedWidth-1 downto 0);

  function f_pack(v_stm : {{x_type.identifier_ms}}) return t_Packed is
    variable v_packed : t_Packed;
  begin
    v_packed(c_DataWidth-1 downto 0) := v_stm.tdata;
    v_packed(c_DataWidth) := v_stm.tlast;
    if not g_OmitKeep then
      v_packed(c_DataWidth+c_KeepWidth downto c_DataWidth+1) := v_stm.tkeep;
    end if;
    return v_packed;
  end f_pack;

  function f_unpack(v_packed : t_Data, v_valid : std_logic) return {{x_type.identifier_ms}} is
    variable v_stm : {{x_type.identifier_ms}};
  begin
    v_stm.tdata := v_packed(g_DataWidth-1 downto 0);
    v_stm.tlast := v_packed(g_DataWidth);
    if not g_OmitKeep then
      v_stm.tkeep := v_packed(g_DataWidth+g_KeepWidth downto g_DataWidth+1);
    else
      v_stm.tkeep := (others => '1');
    end if;
    v_stm.tvalid := v_valid;
    return v_stm;
  end f_unpack;

  type t_Count is unsigned (g_LogDepth downto 0);
  constant c_InLimit : t_Count := to_unsigned(2**g_LogDepth - g_InEnableFree, t_Count'length);
  constant c_OutLimit : t_Count := to_unsigned(g_OutEnableFill, t_Count'length);

  signal s_packedStmIn   : t_Packed;
  signal s_packedStmOut  : t_Packed;
  signal so_stmOut_ms_tvalid : std_logic;
  signal s_count  : t_Count;

begin

  s_packedStmIn <= f_pack(pi_stmIn_ms);
  i_fifo : entity work.UtilFIFO
    generic map (
      g_LogDepth => g_LogDepth,
      g_DataWidth => c_PackedWidth)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_inData   => s_packedStmIn,
      pi_inValid  => pi_stmIn_ms.tvalid,
      po_inReady  => po_stmIn_sm.tready,
      po_outData  => s_packedStmOut,
      po_outValid => so_stmOut_ms_tvalid,
      pi_outReady => pi_stmOut_sm.tready,
      po_count    => s_count);
  po_stmOut_ms <= f_unpack(pi_stmOut_ms, so_stmOut_ms_tvalid);

  po_outEnable <= f_logic(s_count <= c_InLimit);

  po_outEnable <= f_logic(s_count >= c_OutLimit);

end {{name}};
{{/x_type.x_stream}}
{{^x_type.x_stream}}
-- StreamBuffer requires type {{x_type.name}} to be an AxiStream
{{/x_type.x_stream}}
