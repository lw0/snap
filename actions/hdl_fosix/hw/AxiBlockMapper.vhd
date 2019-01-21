library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_util.all;
use work.fosix_blockmap.all;


entity AxiBlockMapper is
  port (
    pi_clk       : in  std_logic;
    pi_rst_n     : in  std_logic;

    pi_axiLog_ms : in  t_AxiAddr_ms;
    po_axiLog_sm : out t_AxiAddr_sm;
    po_axiPhy_ms : out t_AxiAddr_ms;
    pi_axiPhy_sm : in  t_AxiAddr_sm;

    po_store_ms : out t_BlkMap_ms;
    pi_store_sm : in  t_BlkMap_sm
);
end AxiBlockMapper;

architecture AxiBlockMapper of AxiBlockMapper is

  signal s_logAddr : t_LBlk;
  signal s_phyAddr : t_PBlk;
  signal s_blkOffset : t_BlkOffset;
  signal s_relativeBlk : t_LBlk;
  signal s_match : std_logic;

  type t_State is (Idle, FlushAck, MapWait, TestAddr, Pass, Blocked);
  signal s_state : t_State;

  signal s_cacheLBase  : t_LBlk;
  signal s_cacheLLimit : t_LBlk;
  signal s_cachePBase  : t_PBlk;

begin

  -- Splice relevant signals from address channels
  s_logAddr <= f_resize(pi_axiLog_ms.aaddr, c_LBlkWidth, c_BlkOffsetWidth);
  s_blkOffset <= f_resize(pi_axiLog_ms.aaddr, c_BlkOffsetWidth);
  po_axiPhy_ms.aaddr <= f_resize(s_phyAddr & s_blkOffset, C_AXI_ADDR_W);
  po_axiPhy_ms.alen <= pi_axiLog_ms.alen;
  po_axiPhy_ms.asize <= pi_axiLog_ms.asize;
  po_axiPhy_ms.aburst <= pi_axiLog_ms.aburst;

  -- Mapping Logic
  s_relativeBlk <= s_logAddr - s_cacheLBase;
  s_match <= f_logic(s_logAddr >= s_cacheLBase and s_logAddr < s_cacheLLimit);
  s_phyAddr <= s_cachePBase + s_relativeBlk;

  with s_state select po_store_ms.flushAck <=
    '1' when FlushAck,
    '1' when MapWait, -- Fetching new Mapping implies Flushing Cached Mapping
    '0' when others;
  po_store_ms.mapLBlk <= s_logAddr;
  with s_state select po_store_ms.mapReq <=
    '1' when MapWait,
    '0' when others;

  with s_state select po_axiPhy_ms.avalid <=
    '1' when Pass,
    '0' when others;
  with s_state select po_axiLog_sm.aready <=
    pi_axiPhy_sm.aready when Pass,
    '0' when others;

  with s_state select po_store_ms.blocked <=
    '1' when Blocked,
    '0' when others;

  -- Mapping State Machine
  process(pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_cacheLBase <= c_InvalidLBlk;
        s_cacheLLimit <= c_InvalidLBlk;
        s_cachePBase <= c_InvalidPBlk;
        s_state <= Idle;
      else
        case s_state is

          when Idle =>
            if pi_store_sm.flushReq = '1' then
              s_cacheLBase <= c_InvalidLBlk;
              s_cacheLLimit <= c_InvalidLBlk;
              s_cachePBase <= c_InvalidPBlk;
              s_state <= FlushAck;
            elsif pi_axiLog_ms.avalid = '1' and s_match = '1' then
              s_state <= Pass;
            elsif pi_axiLog_ms.avalid = '1' then
              s_state <= MapWait;
            end if;

          when FlushAck =>
            if pi_axiLog_ms.avalid = '1' then
              s_state <= MapWait;
            end if;

          when MapWait =>
            if pi_store_sm.mapAck = '1' then
              s_cacheLBase <= pi_store_sm.mapLBase;
              s_cacheLLimit <= pi_store_sm.mapLLimit;
              s_cachePBase <= pi_store_sm.mapPBase;
              s_state <= TestAddr;
            end if;

          when TestAddr =>
            if s_match = '1' then
              s_state <= Pass;
            else
              s_state <= Blocked;
            end if;

          when Pass =>
            if pi_axiPhy_sm.aready = '1' then
              s_state <= Idle;
            end if;

          when Blocked =>
            if pi_store_sm.flushReq = '1' then
              s_cacheLBase <= c_InvalidLBlk;
              s_cacheLLimit <= c_InvalidLBlk;
              s_cachePBase <= c_InvalidPBlk;
              s_state <= FlushAck;
            end if;

        end case;
      end if;
    end if;
  end process;

end AxiBlockMapper;
