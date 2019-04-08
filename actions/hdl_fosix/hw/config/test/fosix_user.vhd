library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package fosix_user is

  -------------------------------------------------------------------------------
  -- Stream Type: MaskStream
  -------------------------------------------------------------------------------
  type t_MaskStream_ms is record
    tdata   : unsigned (16-1 downto 0);
    tkeep   : unsigned (16/8-1 downto 0);
    tlast   : std_logic;
    tvalid  : std_logic;
  end record;
  type t_MaskStream_ms is record
    tready  : std_logic;
  end record;
  constant c_MaskStreamNull_ms : t_MaskStream_ms := (
    tdata  => (others => '0'),
    tkeep  => (others => '0'),
    tlast  => '0',
    tvalid => '0');
  constant c_MaskStreamNull_sm : t_MaskStream_sm := (
    tready => '0');
  type t_MaskStream_v_ms is array (integer range <>) of t_MaskStream_ms;
  type t_MaskStream_v_sm is array (integer range <>) of t_MaskStream_sm;

end fosix_user;
