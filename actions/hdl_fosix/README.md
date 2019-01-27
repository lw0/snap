# HDL FOSIX

hdl_fosix is a reimplementation of the metalfs hardware *link* in VHDL instead of HLS. The software is written in C.

## Hardware
The hardware part implements the following units:
 * Control Logic that implements the HLS-compatible Control Register Layout and provides a simple start/ready handshake as well as interrupt lines for the actual action design
 * A Stream Infrastructure that provides a Switch, Monitor and Dummy Source for 64Byte wide Axi Streams
 * DMA Units that convert the Axi Interfaces to Host and Card Memory to 64Byte Axi Streams

## Software 
 `snap_fosix.c` implements a minimal interface to interact with the Action's MMIO registers, i.e. writing specific registers before the Action is started or reading others once the Action has completed its operation. As a further convenience, the program may allocate a host buffer of a specific size and write its address to two consecutive MMIO registers.

## MMIO Register Map:
```
0x000 to 0x02C: Action Control
  0x000 [CS] Action Control Bits
  0x004 [RW] Global Interrupt Enable
  0x008 [RW] Done Interrupt Enable
  0x00C [RT] Done Interrupt Flag
  0x010 [R-] Action Number
  0x014 [R-] Action Revision
  0x018 [RC] Global Cycle Counter (lower half)
  0x01C [RC] Global Cycle Counter (upper half)
  0x020 [R-] Action Context
  0x024 [0-] <unimplemented>
  0x028 [0-] <unimplemented>
  0x02C [0-] <unimplemented>
0x040 to 0x06C: Stream Infrastructure
  0x040 [RW] Source Ports 0 to 7 Mapping
  0x044 [RW] Source Ports 8 to 14 and Dummy Source Mapping
  0x048 [RW] Monitor Source
  0x04C [RW] Dummy Source Transfer Count (64Byte units)
  0x050 [RC] Total Cycle Counter (lower half)
  0x054 [RC] Total Cycle Counter (upper half)
  0x058 [RC] Active Cycle Counter (lower half)
  0x05C [RC] Active Cycle Counter (upper half)
  0x060 [RC] Slave Stall Cycle Counter (lower half)
  0x064 [RC] Slave Stall Cycle Counter (upper half)
  0x068 [RC] Master Stall Cycle Counter (lower half)
  0x06C [RC] Master Stall Cycle Counter (upper half)
0x080 to 0x08C: Host Memory Reader @ Source Port 0 @ Map Port 0
  0x080 [RW] Start Address (lower half)
  0x084 [RW] Start Address (upper half)
  0x088 [RW] Transfer Count (64Byte units)
  0x08C [RW] Maximum Burst Length
0x090 to 0x09C: Host Memory Writer @ Sink Port 0 @ Map Port 1
  0x090 [RW] Start Address (lower half)
  0x094 [RW] Start Address (upper half)
  0x098 [RW] Transfer Count (64Byte units)
  0x09C [RW] Maximum Burst Length
0x0A0 to 0x0AC: Card Memory Reader @ Source Port 1 @ Map Port 2
  0x0A0 [RW] Start Address (lower half)
  0x0A4 [RW] Start Address (upper half)
  0x0A8 [RW] Transfer Count (64Byte units)
  0x0AC [RW] Maximum Burst Length
0x0B0 to 0x0BC: Card Memory Writer @ Sink Port 1 @ Map Port 3
  0x0B0 [RW] Start Address (lower half)
  0x0B4 [RW] Start Address (upper half)
  0x0B8 [RW] Transfer Count (64Byte units)
  0x0BC [RW] Maximum Burst Length
0x0C0 to 0x0FC: Block Mapper
  0x0C0 [RW] Halt Command
  0x0C4 [0W] Flush Flush
  0x0C8 [RW] Interrupt Mask
  0x0CC [R-] Interrupt Flags
  0x0D0 [0W] Extent Store Write Address
  0x0D4 [RW] Extent Store Logical Base Block
  0x0D8 [RW] Extent Store Physical Base Block (lower half)
  0x0DC [RW] Extent Store Physical Base Block (upper half)
  0x0E0 [RW] Port 0 Config and Status
  0x0E4 [0W] Port 1 Config and Status
  0x0E8 [RW] Port 2 Config and Status
  0x0EC [R-] Port 3 Config and Status
  0x0F0 [0-] <unimplemented>
  0x0F4 [0-] <unimplemented>
  0x0F8 [0-] <unimplemented>
  0x0FC [0-] <unimplemented>
0x100 to 0x19C: Memory Monitor
  0x100 [RW] Read Channel Mapping
  0x104 [RW] Write Channel Mapping
  0x108 [R-] Read Transaction Count (lower half)
  0x10C [R-] Read Transaction Count (upper half)
  0x110 [R-] Write Transaction Count (lower half)
  0x114 [R-] Write Transaction Count (upper half)
  0x118 [R-] Read Latency (lower half)
  0x11C [R-] Read Latency (upper half)
  0x120 [R-] Write Latency (lower half)
  0x124 [R-] Write Latency (upper half)
  0x128 [R-] Read Slave Stalls (lower half)
  0x12C [R-] Read Slave Stalls (upper half)
  0x130 [R-] Write Slave Stalls (lower half)
  0x134 [R-] Write Slave Stalls (upper half)
  0x138 [R-] Stream Slave Stalls (lower half)
  0x13C [R-] Stream Slave Stalls (upper half)
  0x140 [R-] Read Master Stalls (lower half)
  0x144 [R-] Read Master Stalls (upper half)
  0x148 [R-] Write Master Stalls (lower half)
  0x14C [R-] Write Master Stalls (upper half)
  0x150 [R-] Stream Master Stalls (lower half)
  0x154 [R-] Stream Master Stalls (upper half)
  0x158 [R-] Read Active Cycles (lower half)
  0x15C [R-] Read Active Cycles (upper half)
  0x160 [R-] Write Active Cycles (lower half)
  0x164 [R-] Write Active Cycles (upper half)
  0x168 [R-] Stream Active Cycles (lower half)
  0x16C [R-] Stream Active Cycles (upper half)
  0x170 [R-] Read Idle Cycles (lower half)
  0x174 [R-] Read Idle Cycles (upper half)
  0x178 [R-] Write Idle Cycles (lower half)
  0x17C [R-] Write Idle Cycles (upper half)
  0x180 [R-] Stream Idle Cycles (lower half)
  0x184 [R-] Stream Idle Cycles (upper half)
  0x188 [R-] Read Bytes (lower half)
  0x18C [R-] Read Bytes (upper half)
  0x190 [R-] Write Bytes (lower half)
  0x194 [R-] Write Bytes (upper half)
  0x198 [R-] Stream Bytes (lower half)
  0x19C [R-] Stream Bytes (upper half)

0xFC0 to 0xFFC: Debug Registers
  0xFC0 [R-] HMem Axi Status
    ARLog|ARPhy|R|-|AWLog|AWPhy|W|B
    0x0 not valid not ready -> idle
    0x1 not valid ready     -> master stall
    0x8 valid not ready     -> slave stall
    0x9 valid ready         -> active
  0xFC4 [R-] CMem Axi Status
    see 0xFC0
  0xFC8 [R-] Switch Input Status
    0x0 not valid not ready -> idle
    0x1 not valid ready     -> master stall
    0x2 valid not ready     -> slave stall
    0x3 valid ready         -> active
  0xFCC [R-] Switch Output Status
    see 0xFC8
  0xFD0 [R-] HMem Reader Status
    [31..28] MapperState
      0x0 Idle
      0x1 MapWait
      0x2 TestAddr
      0x3 Pass
      0x4 FlushAck
      0x7 Blocked
    [27..24] CachedLBase
    [23..20] CachedLLimit
    [19..16] DataState
      0x0 Idle
      0x1 Thru
      0x2 ThruWait
      0x3 ThruLast
      0x5 Fill
      0x6 FillWait
      0x7 FillLast
    [15..15] NextBurstLast
    [13..08] RemainingBurstTransfers
    [07..07] Queue Read Valid
    [06..06] Queue Read Ready
    [05..05] Queue Write Valid
    [04..04] Queue Write Ready
    [03..00] AddrMachine State
      0x0 Idle
      0x1 Init
      0x2 WaitBurst
      0x5 ReqInit
      0x9 WaitADoneF
      0xA DoneAWaitF
      0xB WaitAWaitF
      0xD WaitADoneFLast
      0xE DoneAWaitFLast
      0xF WaitAWAitFLast
  0xFD4 [0-] HMem Writer Status
    see 0xFD0
  0xFD8 [0-] CMem Reader Status
    see 0xFD0
  0xFDC [0-] CMem Writer Status
    see 0xFD0
  0xFE0 [0-] Block Mapper Status
  0xFE4 [0-] <unimplemented>
  0xFE8 [0-] <unimplemented>
  0xFEC [0-] <unimplemented>
  0xFF0 [0-] <unimplemented>
  0xFF4 [0-] <unimplemented>
  0xFF8 [0-] <unimplemented>
  0xFFC [0-] <unimplemented>
```
Legend:

 * `[CS]` Clear Flags on Read, Set Bits on Writing 1 
 * `[RW]` Readable, Writable
 * `[RT]` Readable, Toggle Bits on Write
 * `[R-]` Readable, Writes Ignored
 * `[RC]` Readable, Clear on Write
 * `[0-]` Read 0, Writes Ignored

