library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;


entity AxiBlockMapper is
  port (
    pi_clk       : in  std_logic;
    pi_rst_n     : in  std_logic;

    pi_axiLog_ms : in  t_AxiAddr_ms;
    po_axiLog_sm : out t_AxiAddr_sm;
    po_axiPhy_ms : out t_AxiAddr_ms;
    pi_axiPhy_sm : in  t_AxiAddr_sm;

    po_lookup_ms : out t_BlkMap_ms;
    po_lookup_sm : in  t_BlkMap_sm
);
end AxiBlockMapper;

architecture AxiBlockMapper of AxiBlockMapper is

  signal s_logAddr : t_AxiAddr;
  signal s_logValid : std_logic;
  signal s_logReady : std_logic;

  signal s_phyAddr : t_AxiAddr;
  signal s_phyValid : std_logic;
  signal s_phyReady : std_logic;

  signal s_mapReq : std_logic;
  signal s_mapAck : std_logic;
  signal s_flushReq : std_logic;
  signal s_flushAck : std_logic;

  type t_State is (Idle);
  signal s_state : t_State;

  signal s_curExtLBlk : t_LBlk;
  signal s_curExtLCnt : t_LBlk;
  signal s_curExtPBlk : t_PBlk;

begin

  -- Splice relevant signals from address channels
  s_logAddr <= pi_axiLog_ms.aaddr;
  s_logValid <= pi_axiLog_ms.avalid;
  po_axiLog_sm.aready <= s_logReady;
  po_axiPhy_ms.aaddr <= s_phyAddr;
  po_axiPhy_ms.avalid <= s_logValid;
  s_phyReady <= pi_axiPhy_sm.aready;

  po_axiPhy_ms.alen <= pi_axiLog_ms.alen;
  po_axiPhy_ms.asize <= pi_axiLog_ms.asize;
  po_axiPhy_ms.aburst <= pi_axiLog_ms.aburst;

  s_curExtRelBlk <= s_logAddr - s_curExtLBlk;
  s_curExtMatch <= f_logic(s_logAddr >= s_curExtLBlk and s_curExtRelBlk < s_curExtLCnt);

  -- Mapping State Machine
  with s_state select po_lookup_ms.flushAck <=
    '1' when FlushAck,
    '0' when others;

  po_lookup_ms.mapLBlk <= s_mapReqAddr;
  with s_state select po_lookup_ms.mapReq <=
    '1' when MapWait,
    '0' when others;
  process(pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_state <= Idle;
      else
        case s_state is
          when Idle =>
            if s_flushReq = '1' then
              s_curExtLBlk <= c_InvalidLBlk;
              s_curExtLCnt <= (others => 0);
              s_curExtPBlk <= c_InvalidPBlk;
              s_state <= FlushAck;
            elsif s_logValid = '1' and s_curExtMatch = '1' then
                po_axiPhy_ms.aaddr <= s_curExtPBlk + s_curExtRelBlk + s_logAddr(11 downto 0);
                po_axiPhy_ms.avalid <= '1'; -- TODO-lw Outline!!!
            elsif s_logValid = '1' then
              s_state <= MapWait;
              s_mapReqAddr <= pi_axiLog_ms.aaddr;-- TODO-lw strip lower 12 bits for 4KB blocks
              
            end if;

          when FlushAck =>
            if s_logValid = '1' then
            end if;

        end case;
      end if;
    end if;
  end process;

end AxiBlockMapper;
