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

    po_store_ms : out t_BlkMap_ms;
    pi_store_sm : in  t_BlkMap_sm
);
end AxiBlockMapper;

architecture AxiBlockMapper of AxiBlockMapper is

  signal s_logAddr : t_LBlk;
  signal s_logValid : std_logic;
  signal s_logReady : std_logic;

  signal s_blkOffset : t_BlkOffset;

  signal s_phyAddr : t_PBlk;
  signal s_phyValid : std_logic;
  signal s_phyReady : std_logic;

  type t_State is (Idle);
  signal s_state : t_State;

  signal s_cacheLBlk : t_LBlk;
  signal s_cacheLCnt : t_LBlk;
  signal s_cachePBlk : t_PBlk;

begin

  -- Splice relevant signals from address channels
  s_logAddr <= f_resize(pi_axiLog_ms.aaddr, c_LBlkWidth, c_BlkOffsetWidth);
  s_blkOffset <= f_resize(pi_axiLog_ms.aaddr, c_BlkOffsetWidth);
  po_axiPhy_ms.aaddr <= f_resize(s_phyAddr & s_blkOffset, C_AXI_ADDR_W);

  s_logValid <= pi_axiLog_ms.avalid;
  po_axiLog_sm.aready <= s_logReady;
  po_axiPhy_ms.avalid <= s_logValid;
  s_phyReady <= pi_axiPhy_sm.aready;

  po_axiPhy_ms.alen <= pi_axiLog_ms.alen;
  po_axiPhy_ms.asize <= pi_axiLog_ms.asize;
  po_axiPhy_ms.aburst <= pi_axiLog_ms.aburst;

  -- Mapping Logic
  s_relativeBlk <= s_logAddr - s_cacheLBlk;
  s_match <= f_logic(s_logAddr >= s_cacheLBlk and s_relativeBlk < s_cacheLCnt);
  s_phyAddr <= s_cachePBlk + s_relativeBlk;

  with s_state select po_store_ms.flushAck <=
    '1' when FlushAck,
    '1' when InvalidFlushAck,
    '0' when others;
  po_store_ms.mapLBlk <= s_logAddr;
  with s_state select po_store_ms.mapReq <=
    '1' when MapWait,
    '0' when others;

  with s_state select s_phyValid <=
    '1' when Pass,
    '0' when others;
  with s_state select s_logReady <=
    s_phyReady when Pass,
    '0' when others;

  with s_state select po_store_ms.mapInvalid <=
    '1' when Invalid,
    '1' when InvalidFlushAck,
    '0' when others;

  -- Mapping State Machine
  process(pi_clk)
  begin
    if pi_clk'event and pi_clk = '1' then
      if pi_rst_n = '0' then
        s_cacheLBlk <= c_InvalidLBlk;
        s_cacheLCnt <= c_InvalidLCnt;
        s_cachePBlk <= c_InvalidPBlk;
        s_state <= Idle;
      else
        case s_state is

          when Idle =>
            if s_flushReq = '1' then
              s_cacheLBlk <= c_InvalidLBlk;
              s_cacheLCnt <= c_InvalidLCnt;
              s_cachePBlk <= c_InvalidPBlk;
              s_state <= FlushAck;
            elsif s_logValid = '1' and s_match = '1' then
              s_state <= Pass;
            elsif s_logValid = '1' then
              s_state <= MapWait;
            end if;

          when FlushAck =>
            if s_logValid = '1' then
              s_state <= MapWait;
            end if;

          when MapWait =>
            if pi_store_sm.mapAck = '1' then
              s_cacheLBlk <= pi_store_sm.mapExtLBlk;
              s_cacheLCnt <= pi_store_sm.mapExtLCnt;
              s_cachePBlk <= pi_store_sm.mapExtPBlk;
              s_state <= TestAddr;
            end if;

          when TestAddr =>
            if s_match = '1' then
              s_state <= Pass;
            else
              s_state <= Invalid;
            end if;

          when Pass =>
            if s_phyReady = '1' then
              s_state <= Idle;
            end if;

          when Invalid =>
            if s_flushReq = '1' then
              s_cacheLBlk <= c_InvalidLBlk;
              s_cacheLCnt <= c_InvalidLCnt;
              s_cachePBlk <= c_InvalidPBlk;
              s_state <= InvalidFlushAck;
            elsif pi_store_sm.mapRetry = '1' then
              s_state <= MapWait;
            end if;

          when InvalidFlushAck =>
            s_state <= Invalid;

        end case;
      end if;
    end if;
  end process;

end AxiBlockMapper;
