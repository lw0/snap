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
0x080 to 0x08C: Host Memory Reader @ Source Port 0
  0x080 [RW] Start Address (lower half)
  0x084 [RW] Start Address (upper half)
  0x088 [RW] Transfer Count (64Byte units)
  0x08C [RW] Maximum Burst Length
0x090 to 0x09C: Host Memory Writer @ Sink Port 0
  0x090 [RW] Start Address (lower half)
  0x094 [RW] Start Address (upper half)
  0x098 [RW] Transfer Count (64Byte units)
  0x09C [RW] Maximum Burst Length
0x0A0 to 0x0AC: Card Memory Reader @ Source Port 1
  0x0A0 [RW] Start Address (lower half)
  0x0A4 [RW] Start Address (upper half)
  0x0A8 [RW] Transfer Count (64Byte units)
  0x0AC [RW] Maximum Burst Length
0x0B0 to 0x0BC: Card Memory Writer @ Sink Port 1
  0x0B0 [RW] Start Address (lower half)
  0x0B4 [RW] Start Address (upper half)
  0x0B8 [RW] Transfer Count (64Byte units)
  0x0BC [RW] Maximum Burst Length
0x100 to 0x14C: Host Memory Monitor
  0x100: [RC] Read Transaction Count (lower half)
  0x104: [RC] Read Transaction Count (upper half)
  0x108: [RC] Read Latency (lower half)
  0x10C: [RC] Read Latency (upper half)
  0x110: [RC] Read Slave Stalls (lower half)
  0x114: [RC] Read Slave Stalls (upper half)
  0x118: [RC] Read Master Stalls (lower half)
  0x11C: [RC] Read Master Stalls (upper half)
  0x120: [RC] Read Active (lower half)
  0x124: [RC] Read Active (upper half)
  0x128: [RC] Read Idle (lower half)
  0x12C: [RC] Read Idle (upper half)
  0x130: [RC] Write Transaction Count (lower half)
  0x134: [RC] Write Transaction Count (upper half)
  0x138: [RC] Write Latency (lower half)
  0x13C: [RC] Write Latency (upper half)
  0x140: [RC] Write Slave Stalls (lower half)
  0x144: [RC] Write Slave Stalls (upper half)
  0x148: [RC] Write Master Stalls (lower half)
  0x14C: [RC] Write Master Stalls (upper half)
  0x150: [RC] Write Active (lower half)
  0x154: [RC] Write Active (upper half)
  0x158: [RC] Write Idle (lower half)
  0x15C: [RC] Write Idle (upper half)
0x180 to 0x1DC: Card Memory Monitor
  0x180: [RC] Read Transaction Count (lower half)
  0x184: [RC] Read Transaction Count (upper half)
  0x188: [RC] Read Latency (lower half)
  0x18C: [RC] Read Latency (upper half)
  0x190: [RC] Read Slave Stalls (lower half)
  0x194: [RC] Read Slave Stalls (upper half)
  0x198: [RC] Read Master Stalls (lower half)
  0x19C: [RC] Read Master Stalls (upper half)
  0x1A0: [RC] Read Active (lower half)
  0x1A4: [RC] Read Active (upper half)
  0x1A8: [RC] Read Idle (lower half)
  0x1AC: [RC] Read Idle (upper half)
  0x1B0: [RC] Write Transaction Count (lower half)
  0x1B4: [RC] Write Transaction Count (upper half)
  0x1B8: [RC] Write Latency (lower half)
  0x1BC: [RC] Write Latency (upper half)
  0x1C0: [RC] Write Slave Stalls (lower half)
  0x1C4: [RC] Write Slave Stalls (upper half)
  0x1C8: [RC] Write Master Stalls (lower half)
  0x1CC: [RC] Write Master Stalls (upper half)
  0x1D0: [RC] Write Active (lower half)
  0x1D4: [RC] Write Active (upper half)
  0x1D8: [RC] Write Idle (lower half)
  0x1DC: [RC] Write Idle (upper half)
```
Legend:

 * `[CS]` Clear Flags on Read, Set Bits on Writing 1 
 * `[RW]` Readable, Writable
 * `[RT]` Readable, Toggle Bits on Write
 * `[R-]` Readable, Writes Ignored
 * `[RC]` Readable, Clear on Write
 * `[0-]` Read 0, Writes Ignored

