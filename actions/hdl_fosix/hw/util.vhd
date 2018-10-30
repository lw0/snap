
package fosix_util is

  function f_clogb2(a_depth : natural) return positive;
  function f_or(a_bits : std_logic_vector) return std_logic;

  function f_byteMux(a_select : unsigned, a_data0 : unsigned, a_data1 : unsigned) return unsigned;

end fosix_util;

package body fosix_util is

  function f_clog2 (a_depth : natural) return positive is
    variable v_depth  : natural := a_depth;
    variable v_count  : positive := 1;
  begin
    while v_depth > 2 loop
      v_depth := v_depth / 2;
      v_count := v_count + 1;
    end loop;
    return v_count;
  end f_clog2;

  function f_or(a_bits : std_logic_vector) return std_logic is
    variable v_or : std_logic := '0';
  begin
    for i in a_bits'low to a_bits'high loop
      v_or := v_or or a_bits(i);
    end loop;
    return v_or;
  end f_or;

  function f_byteMux(a_select : unsigned, a_data0 : unsigned, a_data1 : unsigned) return unsigned is
    variable v_result : unsigned (a_data0'range);
    variable v_index : integer range a_select'range;
  begin
    assert a_select'length * 8 = a_data0'length report "f_byteMux arg width mismatch" severity failure;
    assert a_select'length * 8 = a_data1'length report "f_byteMux arg width mismatch" severity failure;
    for v_index in a_select'range loop
      if a_select(v_index) = '1' then
        v_result(v_index*8+7 downto v_index*8) <= s_data1(v_index*8+7 downto v_index*8);
      else
        v_result(v_index*8+7 downto v_index*8) <= s_data0(v_index*8+7 downto v_index*8);
      end if;
    end for
    return v_result;
  end f_byteMux;

end fosix_util;
