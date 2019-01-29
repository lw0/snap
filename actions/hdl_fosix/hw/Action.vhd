library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fosix_types.all;
use work.fosix_blockmap.all;

entity Action is
  port (
    pi_clk     : in  std_logic;
    pi_rst_n   : in  std_logic;
    po_intReq  : out std_logic;
    po_intSrc  : out t_InterruptSrc;
    pi_intAck  : in  std_logic;
    po_context : out t_Context;

    -- Ports of Axi Slave Bus Interface AXI_CTRL_REG
    pi_ctrl_ms : in  t_Ctrl_ms;
    po_ctrl_sm : out t_Ctrl_sm;

    -- Ports of Axi Master Bus Interface AXI_HOST_MEM
    po_hmem_ms : out t_Axi_ms;
    pi_hmem_sm : in  t_Axi_sm;

    -- Ports of Axi Master Bus Interface AXI_CARD_MEM0
    po_cmem_ms : out t_Axi_ms;
    pi_cmem_sm : in  t_Axi_sm;

    -- Ports of Axi Master Bus Interface AXI_NVME
    po_nvme_ms : out t_Nvme_ms;
    pi_nvme_sm : in  t_Nvme_sm);
end Action;

architecture Action of Action is

  -----------------------------------------------------------------------------
  -- Register Port Map Configuration
  -----------------------------------------------------------------------------
  constant c_Ports : t_RegMap(0 to 8) := (
    -- Port 0: Control Registers                         (0x000 - 0x02C)
    (to_unsigned(0,   C_CTRL_SPACE_W), to_unsigned(12,  C_CTRL_SPACE_W)),
    -- Port 1: Stream Infrastructure                     (0x040 - 0x06C)
    (to_unsigned(16,  C_CTRL_SPACE_W), to_unsigned(12,  C_CTRL_SPACE_W)),
    -- Port 2: Host Memory Reader                        (0x080 - 0x08C)
    (to_unsigned(32,  C_CTRL_SPACE_W), to_unsigned(4,   C_CTRL_SPACE_W)),
    -- Port 3: Host Memory Writer                        (0x090 - 0x09C)
    (to_unsigned(36,  C_CTRL_SPACE_W), to_unsigned(4,   C_CTRL_SPACE_W)),
    -- Port 4: Card Memory Reader                        (0x0A0 - 0x0AC)
    (to_unsigned(40,  C_CTRL_SPACE_W), to_unsigned(4,   C_CTRL_SPACE_W)),
    -- Port 5: Card Memory Writer                        (0x0B0 - 0x0BC)
    (to_unsigned(44,  C_CTRL_SPACE_W), to_unsigned(4,   C_CTRL_SPACE_W)),
    -- Port 6: Block Mapper                              (0x0C0 - 0x0FC)
    (to_unsigned(48,  C_CTRL_SPACE_W), to_unsigned(16,  C_CTRL_SPACE_W)),
    -- Port 7: Monitor                                   (0x100 - 0x19C)
    (to_unsigned(64,  C_CTRL_SPACE_W), to_unsigned(40,  C_CTRL_SPACE_W)),
    -- Port 8: Debug                                     (0xFC0 - 0xFFC)
    (to_unsigned(1008,  C_CTRL_SPACE_W), to_unsigned(16,  C_CTRL_SPACE_W))
  );
  -----------------------------------------------------------------------------
  signal s_ports_ms : t_RegPorts_ms(c_Ports'range);
  signal s_ports_sm : t_RegPorts_sm(c_Ports'range);

  signal s_ctrlRegs_ms : t_RegPort_ms;
  signal s_ctrlRegs_sm : t_RegPort_sm;
  signal s_appStart : std_logic;
  signal s_appReady : std_logic;

  signal s_hmemStatus : t_RegData;
  signal s_cmemStatus : t_RegData;

  constant c_SwitchInStreams : integer := 2;
  constant c_SwitchOutStreams : integer := 2;
  signal s_switchRegs_ms : t_RegPort_ms;
  signal s_switchRegs_sm : t_RegPort_sm;
  signal s_switchIn_ms  : t_AxiStreams_ms(0 to c_SwitchInStreams-1);
  signal s_switchIn_sm  : t_AxiStreams_sm(0 to c_SwitchInStreams-1);
  signal s_switchOut_ms : t_AxiStreams_ms(0 to c_SwitchOutStreams-1);
  signal s_switchOut_sm : t_AxiStreams_sm(0 to c_SwitchOutStreams-1);
  signal s_switchMon_ms : t_AxiStream_ms;
  signal s_switchMon_sm : t_AxiStream_sm;
  signal s_switchInStatus : t_RegData;
  signal s_switchOutStatus : t_RegData;

  signal s_hwReady : std_logic;
  signal s_hmemRdRegs_ms : t_RegPort_ms;
  signal s_hmemRdRegs_sm : t_RegPort_sm;
  signal s_hmemRdStream_ms : t_AxiStream_ms;
  signal s_hmemRdStream_sm : t_AxiStream_sm;
  signal s_hmemRdLog_ms : t_AxiRd_ms;
  signal s_hmemRdLog_sm : t_AxiRd_sm;
  signal s_hmemRdLogAdr_ms : t_AxiAddr_ms;
  signal s_hmemRdLogAdr_sm : t_AxiAddr_sm;
  signal s_hmemRdPhyAdr_ms : t_AxiAddr_ms;
  signal s_hmemRdPhyAdr_sm : t_AxiAddr_sm;
  signal s_hmemRdPhy_ms : t_AxiRd_ms;
  signal s_hmemRdPhy_sm : t_AxiRd_sm;
  signal s_hmemRdMap_ms : t_BlkMap_ms;
  signal s_hmemRdMap_sm : t_BlkMap_sm;
  signal s_hmemRdMapperStatus : unsigned(11 downto 0);
  signal s_hmemRdReaderStatus : unsigned(19 downto 0);
  signal s_hmemRdStatus : t_RegData;

  signal s_hrReady : std_logic;
  signal s_hmemWrRegs_ms : t_RegPort_ms;
  signal s_hmemWrRegs_sm : t_RegPort_sm;
  signal s_hmemWrStream_ms : t_AxiStream_ms;
  signal s_hmemWrStream_sm : t_AxiStream_sm;
  signal s_hmemWrLog_ms : t_AxiWr_ms;
  signal s_hmemWrLog_sm : t_AxiWr_sm;
  signal s_hmemWrLogAdr_ms : t_AxiAddr_ms;
  signal s_hmemWrLogAdr_sm : t_AxiAddr_sm;
  signal s_hmemWrPhyAdr_ms : t_AxiAddr_ms;
  signal s_hmemWrPhyAdr_sm : t_AxiAddr_sm;
  signal s_hmemWrPhy_ms : t_AxiWr_ms;
  signal s_hmemWrPhy_sm : t_AxiWr_sm;
  signal s_hmemWrMap_ms : t_BlkMap_ms;
  signal s_hmemWrMap_sm : t_BlkMap_sm;
  signal s_hmemWrMapperStatus : unsigned(11 downto 0);
  signal s_hmemWrWriterStatus : unsigned(19 downto 0);
  signal s_hmemWrStatus : t_RegData;

  signal s_cwReady : std_logic;
  signal s_cmemRdRegs_ms : t_RegPort_ms;
  signal s_cmemRdRegs_sm : t_RegPort_sm;
  signal s_cmemRdStream_ms : t_AxiStream_ms;
  signal s_cmemRdStream_sm : t_AxiStream_sm;
  signal s_cmemRdLog_ms : t_AxiRd_ms;
  signal s_cmemRdLog_sm : t_AxiRd_sm;
  signal s_cmemRdLogAdr_ms : t_AxiAddr_ms;
  signal s_cmemRdLogAdr_sm : t_AxiAddr_sm;
  signal s_cmemRdPhyAdr_ms : t_AxiAddr_ms;
  signal s_cmemRdPhyAdr_sm : t_AxiAddr_sm;
  signal s_cmemRdPhy_ms : t_AxiRd_ms;
  signal s_cmemRdPhy_sm : t_AxiRd_sm;
  signal s_cmemRdMap_ms : t_BlkMap_ms;
  signal s_cmemRdMap_sm : t_BlkMap_sm;
  signal s_cmemRdMapperStatus : unsigned(11 downto 0);
  signal s_cmemRdReaderStatus : unsigned(19 downto 0);
  signal s_cmemRdStatus : t_RegData;

  signal s_crReady : std_logic;
  signal s_cmemWrRegs_ms : t_RegPort_ms;
  signal s_cmemWrRegs_sm : t_RegPort_sm;
  signal s_cmemWrStream_ms : t_AxiStream_ms;
  signal s_cmemWrStream_sm : t_AxiStream_sm;
  signal s_cmemWrLog_ms : t_AxiWr_ms;
  signal s_cmemWrLog_sm : t_AxiWr_sm;
  signal s_cmemWrLogAdr_ms : t_AxiAddr_ms;
  signal s_cmemWrLogAdr_sm : t_AxiAddr_sm;
  signal s_cmemWrPhyAdr_ms : t_AxiAddr_ms;
  signal s_cmemWrPhyAdr_sm : t_AxiAddr_sm;
  signal s_cmemWrPhy_ms : t_AxiWr_ms;
  signal s_cmemWrPhy_sm : t_AxiWr_sm;
  signal s_cmemWrMap_ms : t_BlkMap_ms;
  signal s_cmemWrMap_sm : t_BlkMap_sm;
  signal s_cmemWrMapperStatus : unsigned(11 downto 0);
  signal s_cmemWrWriterStatus : unsigned(19 downto 0);
  signal s_cmemWrStatus : t_RegData;

  signal s_mapRegs_ms : t_RegPort_ms;
  signal s_mapRegs_sm : t_RegPort_sm;
  signal s_mapIntReq : std_logic;
  signal s_mapIntAck : std_logic;
  signal s_mapPorts_ms : t_BlkMaps_ms(3 downto 0);
  signal s_mapPorts_sm : t_BlkMaps_sm(3 downto 0);
  signal s_mapStatus : t_RegData;


  signal s_monRegs_ms : t_RegPort_ms;
  signal s_monRegs_sm : t_RegPort_sm;

  signal s_dbgRegs_ms : t_RegPort_ms;
  signal s_dbgRegs_sm : t_RegPort_sm;

begin

  -- Split Memory Ports into Separate Read and Write Portions
  po_hmem_ms <= f_axiJoin_ms(s_hmemRdPhy_ms, s_hmemWrPhy_ms);
  s_hmemRdPhy_sm <= f_axiSplitRd_sm(pi_hmem_sm);
  s_hmemWrPhy_sm <= f_axiSplitWr_sm(pi_hmem_sm);
  po_cmem_ms <= f_axiJoin_ms(s_cmemRdPhy_ms, s_cmemWrPhy_ms);
  s_cmemRdPhy_sm <= f_axiSplitRd_sm(pi_cmem_sm);
  s_cmemWrPhy_sm <= f_axiSplitWr_sm(pi_cmem_sm);

  -- Demultiplex and Simplify Control Register Ports
  i_ctrlDemux : entity work.CtrlRegDemux
    generic map (
      g_Ports => c_Ports)
    port map (
      pi_clk => pi_clk,
      pi_rst_n => pi_rst_n,
      pi_ctrl_ms => pi_ctrl_ms,
      po_ctrl_sm => po_ctrl_sm,
      po_ports_ms => s_ports_ms,
      pi_ports_sm => s_ports_sm);
  s_ctrlRegs_ms <= s_ports_ms(0);
  s_ports_sm(0) <= s_ctrlRegs_sm;
  s_switchRegs_ms <= s_ports_ms(1);
  s_ports_sm(1) <= s_switchRegs_sm;
  s_hmemRdRegs_ms <= s_ports_ms(2);
  s_ports_sm(2) <= s_hmemRdRegs_sm;
  s_hmemWrRegs_ms <= s_ports_ms(3);
  s_ports_sm(3) <= s_hmemWrRegs_sm;
  s_cmemRdRegs_ms <= s_ports_ms(4);
  s_ports_sm(4) <= s_cmemRdRegs_sm;
  s_cmemWrRegs_ms <= s_ports_ms(5);
  s_ports_sm(5) <= s_cmemWrRegs_sm;
  s_mapRegs_ms <= s_ports_ms(6);
  s_ports_sm(6) <= s_mapRegs_sm;
  s_monRegs_ms <= s_ports_ms(7);
  s_ports_sm(7) <= s_monRegs_sm;
  s_dbgRegs_ms <= s_ports_ms(8);
  s_ports_sm(8) <= s_dbgRegs_sm;

  i_actionControl : entity work.ActionControl
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      po_intReq       => po_intReq,
      po_intSrc       => po_intSrc,
      pi_intAck       => pi_intAck,
      pi_regs_ms      => s_ctrlRegs_ms,
      po_regs_sm      => s_ctrlRegs_sm,
      pi_type         => x"0000_006c",
      pi_version      => x"0000_0000",
      po_context      => po_context,
      po_start        => s_appStart,
      pi_ready        => s_appReady,
      pi_irq1         => s_mapIntReq,
      po_iack1        => s_mapIntAck);

  s_appReady <= s_hrReady and s_hwReady and s_crReady and s_cwReady;

  i_infrastructure : entity work.StreamInfrastructure
    generic map (
      g_InPorts => c_SwitchInStreams,
      g_OutPorts => c_SwitchOutStreams)
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_regs_ms      => s_switchRegs_ms,
      po_regs_sm      => s_switchRegs_sm,
      pi_inPorts_ms   => s_switchIn_ms,
      po_inPorts_sm   => s_switchIn_sm,
      po_outPorts_ms  => s_switchOut_ms,
      pi_outPorts_sm  => s_switchOut_sm,
      po_monPort_ms   => s_switchMon_ms,
      po_monPort_sm   => s_switchMon_sm);

  s_switchIn_ms(0) <= s_hmemRdStream_ms;
  s_hmemRdStream_sm <= s_switchIn_sm(0);
  s_hmemWrStream_ms <= s_switchOut_ms(0);
  s_switchOut_sm(0) <= s_hmemWrStream_sm;

  s_switchIn_ms(1) <= s_cmemRdStream_ms;
  s_cmemRdStream_sm <= s_switchIn_sm(1);
  s_cmemWrStream_ms <= s_switchOut_ms(1);
  s_switchOut_sm(1) <= s_cmemWrStream_sm;


  i_hmemReader : entity work.AxiReader
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_start        => s_appStart,
      po_ready        => s_hrReady,
      pi_hold         => '0',
      pi_regs_ms      => s_hmemRdRegs_ms,
      po_regs_sm      => s_hmemRdRegs_sm,
      po_mem_ms       => s_hmemRdLog_ms,
      pi_mem_sm       => s_hmemRdLog_sm,
      po_stream_ms    => s_hmemRdStream_ms,
      pi_stream_sm    => s_hmemRdStream_sm,
      po_status       => s_hmemRdReaderStatus);
  s_hmemRdLogAdr_ms <= f_axiExtractAddrRd_ms(s_hmemRdLog_ms);
  s_hmemRdLog_sm <= f_axiSpliceAddrRd_sm(s_hmemRdPhy_sm, s_hmemRdLogAdr_sm);
  s_hmemRdPhy_ms <= f_axiSpliceAddrRd_ms(s_hmemRdLog_ms, s_hmemRdPhyAdr_ms);
  s_hmemRdPhyAdr_sm <= f_axiExtractAddrRd_sm(s_hmemRdPhy_sm);
  i_hmemRdMapper : entity work.AxiBlockMapper
    port map(
    pi_clk            => pi_clk,
    pi_rst_n          => pi_rst_n,
    pi_axiLog_ms      => s_hmemRdLogAdr_ms,
    po_axiLog_sm      => s_hmemRdLogAdr_sm,
    po_axiPhy_ms      => s_hmemRdPhyAdr_ms,
    pi_axiPhy_sm      => s_hmemRdPhyAdr_sm,
    po_store_ms       => s_hmemRdMap_ms,
    pi_store_sm       => s_hmemRdMap_sm,
    po_status         => s_hmemRdMapperStatus);
  s_hmemRdStatus <= s_hmemRdMapperStatus & s_hmemRdReaderStatus;

  i_hmemWriter : entity work.AxiWriter
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_start        => s_appStart,
      po_ready        => s_hwReady,
      pi_hold         => '0',
      pi_regs_ms      => s_hmemWrRegs_ms,
      po_regs_sm      => s_hmemWrRegs_sm,
      po_mem_ms       => s_hmemWrLog_ms,
      pi_mem_sm       => s_hmemWrLog_sm,
      pi_stream_ms    => s_hmemWrStream_ms,
      po_stream_sm    => s_hmemWrStream_sm,
      po_status       => s_hmemWrWriterStatus);
  s_hmemWrLogAdr_ms <= f_axiExtractAddrWr_ms(s_hmemWrLog_ms);
  s_hmemWrLog_sm <= f_axiSpliceAddrWr_sm(s_hmemWrPhy_sm, s_hmemWrLogAdr_sm);
  s_hmemWrPhy_ms <= f_axiSpliceAddrWr_ms(s_hmemWrLog_ms, s_hmemWrPhyAdr_ms);
  s_hmemWrPhyAdr_sm <= f_axiExtractAddrWr_sm(s_hmemWrPhy_sm);
  i_hmemWrMapper : entity work.AxiBlockMapper
    port map(
    pi_clk            => pi_clk,
    pi_rst_n          => pi_rst_n,
    pi_axiLog_ms      => s_hmemWrLogAdr_ms,
    po_axiLog_sm      => s_hmemWrLogAdr_sm,
    po_axiPhy_ms      => s_hmemWrPhyAdr_ms,
    pi_axiPhy_sm      => s_hmemWrPhyAdr_sm,
    po_store_ms       => s_hmemWrMap_ms,
    pi_store_sm       => s_hmemWrMap_sm,
    po_status         => s_hmemWrMapperStatus);
  s_hmemWrStatus <= s_hmemWrMapperStatus & s_hmemWrWriterStatus;

  i_cmemReader : entity work.AxiReader
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_start        => s_appStart,
      po_ready        => s_crReady,
      pi_hold         => '0',
      pi_regs_ms      => s_cmemRdRegs_ms,
      po_regs_sm      => s_cmemRdRegs_sm,
      po_mem_ms       => s_cmemRdLog_ms,
      pi_mem_sm       => s_cmemRdLog_sm,
      po_stream_ms    => s_cmemRdStream_ms,
      pi_stream_sm    => s_cmemRdStream_sm,
      po_status       => s_cmemRdReaderStatus);
  s_cmemRdLogAdr_ms <= f_axiExtractAddrRd_ms(s_cmemRdLog_ms);
  s_cmemRdLog_sm <= f_axiSpliceAddrRd_sm(s_cmemRdPhy_sm, s_cmemRdLogAdr_sm);
  s_cmemRdPhy_ms <= f_axiSpliceAddrRd_ms(s_cmemRdLog_ms, s_cmemRdPhyAdr_ms);
  s_cmemRdPhyAdr_sm <= f_axiExtractAddrRd_sm(s_cmemRdPhy_sm);
  i_cmemRdMapper : entity work.AxiBlockMapper
    port map(
    pi_clk            => pi_clk,
    pi_rst_n          => pi_rst_n,
    pi_axiLog_ms      => s_cmemRdLogAdr_ms,
    po_axiLog_sm      => s_cmemRdLogAdr_sm,
    po_axiPhy_ms      => s_cmemRdPhyAdr_ms,
    pi_axiPhy_sm      => s_cmemRdPhyAdr_sm,
    po_store_ms       => s_cmemRdMap_ms,
    pi_store_sm       => s_cmemRdMap_sm,
    po_status         => s_cmemRdMapperStatus);
  s_cmemRdStatus <= s_cmemRdMapperStatus & s_cmemRdReaderStatus;

  i_cmemWriter : entity work.AxiWriter
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_start        => s_appStart,
      po_ready        => s_cwReady,
      pi_hold         => '0',
      pi_regs_ms      => s_cmemWrRegs_ms,
      po_regs_sm      => s_cmemWrRegs_sm,
      po_mem_ms       => s_cmemWrLog_ms,
      pi_mem_sm       => s_cmemWrLog_sm,
      pi_stream_ms    => s_cmemWrStream_ms,
      po_stream_sm    => s_cmemWrStream_sm,
      po_status       => s_cmemWrWriterStatus);
  s_cmemWrLogAdr_ms <= f_axiExtractAddrWr_ms(s_cmemWrLog_ms);
  s_cmemWrLog_sm <= f_axiSpliceAddrWr_sm(s_cmemWrPhy_sm, s_cmemWrLogAdr_sm);
  s_cmemWrPhy_ms <= f_axiSpliceAddrWr_ms(s_cmemWrLog_ms, s_cmemWrPhyAdr_ms);
  s_cmemWrPhyAdr_sm <= f_axiExtractAddrWr_sm(s_cmemWrPhy_sm);
  i_cmemWrMapper : entity work.AxiBlockMapper
    port map(
    pi_clk            => pi_clk,
    pi_rst_n          => pi_rst_n,
    pi_axiLog_ms      => s_cmemWrLogAdr_ms,
    po_axiLog_sm      => s_cmemWrLogAdr_sm,
    po_axiPhy_ms      => s_cmemWrPhyAdr_ms,
    pi_axiPhy_sm      => s_cmemWrPhyAdr_sm,
    po_store_ms       => s_cmemWrMap_ms,
    pi_store_sm       => s_cmemWrMap_sm,
    po_status         => s_cmemWrMapperStatus);
  s_cmemWrStatus <= s_cmemWrMapperStatus & s_cmemWrWriterStatus;

  i_extStore : entity work.ExtentStore
  generic map (
    g_Ports     => 4)
  port map (
    pi_clk      => pi_clk,
    pi_rst_n    => pi_rst_n,
    po_intReq   => s_mapIntReq,
    pi_intAck   => s_mapIntAck,
    pi_regs_ms  => s_mapRegs_ms,
    po_regs_sm  => s_mapRegs_sm,
    pi_ports_ms => s_mapPorts_ms,
    po_ports_sm => s_mapPorts_sm,
    po_status   => s_mapStatus);
  s_mapPorts_ms(0) <= s_hmemRdMap_ms;
  s_hmemRdMap_sm <= s_mapPorts_sm(0);
  s_mapPorts_ms(1) <= s_hmemWrMap_ms;
  s_hmemWrMap_sm <= s_mapPorts_sm(1);
  s_mapPorts_ms(2) <= s_cmemRdMap_ms;
  s_cmemRdMap_sm <= s_mapPorts_sm(2);
  s_mapPorts_ms(3) <= s_cmemWrMap_ms;
  s_cmemWrMap_sm <= s_mapPorts_sm(3);

  i_monitor : entity work.AxiMonitor
    port map (
      pi_clk          => pi_clk,
      pi_rst_n        => pi_rst_n,
      pi_regs_ms      => s_monRegs_ms,
      po_regs_sm      => s_monRegs_sm,
      pi_start        => s_appStart,
      pi_axiRd0Stop   => s_hrReady,
      pi_axiRd0_ms    => s_hmemRdPhy_ms,
      pi_axiRd0_sm    => s_hmemRdPhy_sm,
      pi_axiWr0Stop   => s_hwReady,
      pi_axiWr0_ms    => s_hmemWrPhy_ms,
      pi_axiWr0_sm    => s_hmemWrPhy_sm,
      pi_axiRd1Stop   => s_crReady,
      pi_axiRd1_ms    => s_cmemRdPhy_ms,
      pi_axiRd1_sm    => s_cmemRdPhy_sm,
      pi_axiWr1Stop   => s_cwReady,
      pi_axiWr1_ms    => s_cmemWrPhy_ms,
      pi_axiWr1_sm    => s_cmemWrPhy_sm,
      pi_stream_ms    => s_switchMon_ms,
      pi_stream_sm    => s_switchMon_sm);

  po_nvme_ms <= c_NvmeNull_ms;

  -----------------------------------------------------------------------------
  -- Status Register Access
  -----------------------------------------------------------------------------
  s_hmemStatus <=
    s_hmemRdLog_ms.arvalid & "00" & s_hmemRdLog_sm.arready &
    s_hmemRdPhy_ms.arvalid & "00" & s_hmemRdPhy_sm.arready &
    s_hmemRdPhy_sm.rvalid  & "00" & s_hmemRdPhy_ms.rready &
    "0000" &
    s_hmemWrLog_ms.awvalid & "00" & s_hmemWrLog_sm.awready &
    s_hmemWrPhy_ms.awvalid & "00" & s_hmemWrPhy_sm.awready &
    s_hmemWrPhy_ms.wvalid  & "00" & s_hmemWrPhy_sm.wready &
    s_hmemWrPhy_sm.bvalid  & "00" & s_hmemWrPhy_ms.bready;
  s_cmemStatus <=
    s_cmemRdLog_ms.arvalid & "00" & s_cmemRdLog_sm.arready &
    s_cmemRdPhy_ms.arvalid & "00" & s_cmemRdPhy_sm.arready &
    s_cmemRdPhy_sm.rvalid  & "00" & s_cmemRdPhy_ms.rready &
    "0000" &
    s_cmemWrLog_ms.awvalid & "00" & s_cmemWrLog_sm.awready &
    s_cmemWrPhy_ms.awvalid & "00" & s_cmemWrPhy_sm.awready &
    s_cmemWrPhy_ms.wvalid  & "00" & s_cmemWrPhy_sm.wready &
    s_cmemWrPhy_sm.bvalid  & "00" & s_cmemWrPhy_ms.bready;
  process (s_switchIn_ms, s_switchIn_sm)
    variable v_idx : integer range 0 to c_SwitchInStreams-1 := 0;
  begin
    s_switchInStatus <= (others => '0');
    for v_idx in 0 to c_SwitchInStreams-1 loop
      s_switchInStatus(v_idx*2) <= s_switchIn_sm(v_idx).tready;
      s_switchInStatus(v_idx*2+1) <= s_switchIn_ms(v_idx).tvalid;
    end loop;
  end process;
  process (s_switchOut_ms, s_switchOut_sm)
    variable v_idx : integer range 0 to c_SwitchOutStreams-1 := 0;
  begin
    s_switchOutStatus <= (others => '0');
    for v_idx in 0 to c_SwitchOutStreams-1 loop
      s_switchOutStatus(v_idx*2) <= s_switchOut_sm(v_idx).tready;
      s_switchOutStatus(v_idx*2+1) <= s_switchOut_ms(v_idx).tvalid;
    end loop;
  end process;

  process (pi_clk)
    variable v_addr : integer range 0 to 2**C_CTRL_SPACE_W := 0;
  begin
    if pi_clk'event and pi_clk = '1' then
      v_addr := to_integer(s_dbgRegs_ms.addr);
      if pi_rst_n = '0' then
        s_dbgRegs_sm.rddata <= (others => '0');
        s_dbgRegs_sm.ready <= '0';
      else
        if s_dbgRegs_ms.valid = '1' and s_dbgRegs_sm.ready = '0' then
          s_dbgRegs_sm.ready <= '1';
          case v_addr is
            when 0 =>
              s_dbgRegs_sm.rddata <= s_hmemStatus;
            when 1 =>
              s_dbgRegs_sm.rddata <= s_cmemStatus;
            when 2 =>
              s_dbgRegs_sm.rddata <= s_switchInStatus;
            when 3 =>
              s_dbgRegs_sm.rddata <= s_switchOutStatus;
            when 4 =>
              s_dbgRegs_sm.rddata <= s_hmemRdStatus;
            when 5 =>
              s_dbgRegs_sm.rddata <= s_hmemWrStatus;
            when 6 =>
              s_dbgRegs_sm.rddata <= s_cmemRdStatus;
            when 7 =>
              s_dbgRegs_sm.rddata <= s_cmemWrStatus;
            when 8 =>
              s_dbgRegs_sm.rddata <= s_mapStatus;
            when others =>
              s_dbgRegs_sm.rddata <= (others => '0');
          end case;
        else
          s_dbgRegs_sm.ready <= '0';
        end if;
      end if;
    end if;
  end process;

end Action;

