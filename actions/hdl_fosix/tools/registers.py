#!/usr/bin/env python3
from collections import namedtuple
from itertools import accumulate
from random import shuffle
import re
import yaml

def hex8(val):
  return '0x{:02x}'.format(val & 0xFF)

def hex32(val):
  return '0x{:08x}'.format(val & 0xFFFFFFFF)

def hex32U(val):
  return '0x{:08x}'.format((val>>32) & 0xFFFFFFFF)

def hex64(val):
  return '0x{:016x}'.format(val & 0xFFFFFFFFFFFFFFFF)

def hexReg(val):
  return '0x{:03x}'.format(val & 0xFFF)

def cmdSet32(reg, val):
  return 's{}:{}'.format(hexReg(reg), hex32(val))

def cmdSet64(reg, val):
  return 'S{}:{}'.format(hexReg(reg), hex64(val))

def cmdRel64(reg, base, id, shift):
  return 'R{}:{}+A{:d}|{:d}'.format(hexReg(reg), hex64(base), id, shift)

def cmdGet32(reg):
  return 'g{}'.format(hexReg(reg))

def cmdGet64(reg):
  return 'G{}'.format(hexReg(reg))

def cmdAlloc(id, size):
  return 'A{:d}:{}'.format(id, hex32(size))

def cmdRun(timeout=0):
  return 'r{:d}'.format(timeout)

def cmdQuit():
  return 'q'


###############################################################################
# Action Register Map and Command Buffer
###############################################################################
class RegInfo():
  class RegProxy():
    def __init__(self, parent, name, addr, is64):
      self._parent = parent
      self._name = name
      self._addr = addr
      self._is64 = is64

    def write(self, data):
      if self._is64:
        self._parent._append(cmdSet64(self._addr, data))
      else:
        self._parent._append(cmdSet32(self._addr, data))

    def writeAlloc(self, base, id, shift):
      if not self._is64:
        raise ValueError('Can allocation address requires a 64 bit register')
      self._parent._append(cmdRel64(self._addr, base, id, shift))

    def read(self):
      if self._is64:
        self._parent._append(cmdGet64(self._addr))
      else:
        self._parent._append(cmdGet32(self._addr))

  class RegionProxy():
    def __init__(self, parent, name):
      self._parent = parent
      self._entries = {}

    def __getattr__(self, key):
      if key not in self._entries:
        raise AttributeError(key)
      return self._entries[key]

    def __getitem__(self, key):
      if key not in self._entries:
        raise KeyError(key)
      return self._entries[key]

    def __contains__(self, key):
      return key in self._entries

    def _append(self, cmd):
      self._parent._append(cmd)

    def _add_reg(self, name, addr, is64):
      self._entries[name] = RegInfo.RegProxy(self, name, addr, is64)

    def _add_info(self, name, value):
      self._entries[name] = value

    def is_component(self, comp):
      if 'component' not in self._entries:
        return False
      return self._entries['component'] == comp

  def __init__(self, cfg_path):
    info = yaml.load(cfg_path.read_text())
    self._entries = {}
    self._rev = {}
    for region,regs in info.items():
      proxy = RegInfo.RegionProxy(self, region)
      for key,val in regs.items():
        if key[0].isupper():
          proxy._add_reg(key, val['addr'], val['is64'])
          self._rev[val['addr']] = '{}_{}'.format(region, key)
        else:
          proxy._add_info(key, val)
      self._entries[region] = proxy
    self._cmds = []
    self._alloc_id = 0

  def __getattr__(self, key):
    if key not in self._entries:
      raise AttributeError(key)
    return self._entries[key]

  def __getitem__(self, key):
    if key not in self._entries:
      raise KeyError(key)
    return self._entries[key]

  def __contains__(self, key):
    return key in self._entries

  def _append(self, cmd):
    self._cmds.append(cmd)

  def alloc(self, size):
      id = self._alloc_id
      self._append(cmdAlloc(id, size))
      self._alloc_id += 1
      return id

  def run(self, timeout=0):
      self._append(cmdRun(timeout))

  def quit(self):
      self._append(cmdQuit())

  def takeCmds(self):
    cmds = self._cmds
    self._cmds = []
    self._alloc_id = 0
    return cmds

  GET_PATTERN = re.compile('\((0x[0-9a-fA-F]+)\) => (0x[0-9a-fA-F]+)')
  def decode_reads(self, log):
    results = {}
    for line in log.splitlines():
      m = RegInfo.GET_PATTERN.match(line)
      if m:
        reg_addr = int(m.group(1),0)
        reg_value = int(m.group(2),0)
        if reg_addr in self._rev:
          reg = self._rev[reg_addr]
          results[reg._name] = reg_value
        else:
          results[str(reg_addr)] = reg_value
    return results

###############################################################################
# Component Configuration
###############################################################################

# Generate up to <ext_count> extents spanning a region of <size>
# returns [ (lbase, pbase, count), ...]
def random_extents(ext_count, size): 
  size_per_blk = 64 # size unit is 64 Byte, Block size is 4096 Byte
  total_blocks = (size-1) // size_per_blk + 1
  surplus_blocks = total_blocks % ext_count
  blocks_per_ext = total_blocks // ext_count

  counts = [ blocks_per_ext+1 for i in range(surplus_blocks) ]
  if blocks_per_ext > 0:
    counts += [ blocks_per_ext for i in range(ext_count-surplus_blocks) ]

  pbases = list(accumulate(counts))
  pbases = [0] + pbases[0:-1]
  pblks = list(zip(pbases, counts))
  shuffle(pblks)
  lbases = list(accumulate(b[1] for b in pblks))
  lbases = [0] + lbases[0:-1]
  return list(zip(lbases, (b[0] for b in pblks), (b[1] for b in pblks)))

# Group <ext_list> into a individual rows
# returns  [ [(lbase, pbase), ... (llimit, -1) ] ]
def split_extent_rows(ext_list, row_entries=15): 
  entry_count = len(ext_list)
  row_count = (entry_count - 1) // row_entries + 1
  rows = []
  for i in range(row_count):
    beg_entry = row_entries*i
    end_entry = min(row_entries*(i+1), entry_count)
    pad_entries = row_entries - end_entry + beg_entry + 1
    row_content = ext_list[row_entries*i:min(row_entries*(i+1), entry_count)]
    row_end = row_content[-1][0]+row_content[-1][2]
    row = [ (e[0],e[1]) for e in row_content ] + [ (row_end, 0) for i in range(pad_entries) ]
    rows.append(row)
  return rows

# Encode a list of row ids into a Port config value
def extent_store_port_config(rows):
  cfg = len(rows) & 0xF
  for idx,row in enumerate(rows):
    cfg |= (row&0xF) << (len(rows)-idx)*4
  return cfg

BlockMapperConfig = namedtuple('BlockMapperConfig', ['size', 'ext_count', 'loffset', 'poffset', 'alloc_id'])

# Configures all ports of an ExtentStore component with a map { port_id: BlockMapperConfig }
def configure_extent_store(ext_store, ext_store_config):
  ext_store.Halt.write(0xf)
  current_row = 0
  for mapper_idx in range(ext_store.port_count):
    port_reg = 'Port{}'.format(mapper_idx)
    if mapper_idx in ext_store_config:
      mapper_config = ext_store_config[mapper_idx]
      rows = split_extent_rows(random_extents(mapper_config.ext_count, mapper_config.size))
      lblock_offset = mapper_config.loffset >> 12
      pblock_offset = mapper_config.poffset >> 12
      row_ids = []
      for row in rows:
        for entry_idx, entry in enumerate(row):
          ext_store.WrLBlk.write(lblock_offset + entry[0])
          if mapper_config.alloc_id is not None:
            ext_store.WrPBlk.writeAlloc(entry[1], mapper_config.alloc_id, 12)
          else:
            ext_store.WrPBlk.write(pblock_offset + entry[1])
          entry_addr = (current_row << 4) + entry_idx
          ext_store.WrAddr.write(entry_addr)
        row_ids.append(current_row)
        current_row += 1
      ext_store[cfg_reg].write(extent_store_port_config(row_ids))
    else:
      ext_store[cfg_reg].write(extent_store_port_config([]))
  ext_store.Flush.write(0xf)


# Configures AxiReader, AxiWriter, StreamSource, StreamSink
def configure_dma(dma, addr=0x0, count=0x0, blen=0x0):
  if 'Addr' in dma:
    dma.Addr.write(addr)
  if 'TCount' in dma:
    dma.TCount.write(count)
  if 'Burst' in dma:
    dma.Burst.write(blen)

def configure_dma_alloc(dma, alloc_id, count=0x0, blen=0x0):
  if 'Addr' in dma:
    dma.Addr.writeAlloc(0, alloc_id, 0)
  if 'TCount' in dma:
    dma.TCount.write(count)
  if 'Burst' in dma:
    dma.Burst.write(blen)

# Configures StreamSwitch, StreamRouter, AxiMonitor
def configure_switch(switch, mapping):
  map = 0xFFFFFFFFFFFFFFFF
  for src,dst in mapping.items():
    map &= ~(0xF << 4*dst)
    map |= (src & 0xF) << 4*dst
  switch.Mapping.write(map)

