#!/usr/bin/env python3
import argparse
from itertools import accumulate,product
import json
from pathlib import Path
from random import shuffle
import re
import subprocess
import sys
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

class CommandBuffer():
  class RegProxy():
    def __init__(self, cmd_buffer, name, addr, is64):
      self._cmd_buffer = cmd_buffer
      self._name = name
      self._addr = addr
      self._is64 = is64

    def write(self, data):
      if self._is64:
        self._cmd_buffer._append(cmdSet64(self._addr, data))
      else:
        self._cmd_buffer._append(cmdSet32(self._addr, data))

    def writeAlloc(self, base, id, shift):
      if not self._is64:
        raise ValueError('Can allocation address requires a 64 bit register')
      self._cmd_buffer._append(cmdRel64(self._addr, base, id, shift))

    def read(self):
      if self._is64:
        self._cmd_buffer._append(cmdGet64(self._addr))
      else:
        self._cmd_buffer._append(cmdGet32(self._addr))

  def __init__(self, cfg_path):
    info = yaml.load(cfg_path.read_text())
    self._entries = {}
    self._rev = {}
    for comp,regs in info.items():
      for key,val in regs.items():
        name = '{}_{}'.format(comp, key)
        if key[0].isupper():
          reg_proxy = CommandBuffer.RegProxy(self, name, val['addr'], val['is64'])
          self._entries[name] = reg_proxy
          self._rev[val['addr']] = reg_proxy
        else:
          self._entries[name] = val
    self._cmds = []

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

  def alloc(self, id, size):
      self._append(cmdAlloc(id, size))

  def run(self, timeout=0):
      self._append(cmdRun(timeout))

  def quit(self):
      self._append(cmdQuit())

  def take(self):
    cmds = self._cmds
    self._cmds = []
    return cmds

  GET_PATTERN = re.compile('\((0x[0-9a-fA-F]+)\) => (0x[0-9a-fA-F]+)')
  def decode_reads(self, log):
    results = {}
    for line in log.splitlines():
      m = CommandBuffer.GET_PATTERN.match(line)
      if m:
        reg_addr = int(m.group(1),0)
        reg_value = int(m.group(2),0)
        if reg_addr in self._rev:
          reg = self._rev[reg_addr]
          results[reg._name] = reg_value
        else:
          results[str(reg_addr)] = reg_value
    return results

class Allocator():
  @staticmethod
  def align(val, boundary):
    val += boundary -1
    val -= val % boundary
    return val

  def __init__(self, base, boundary):
    self._bound = boundary
    self._addr = Allocator.align(base, self._bound)

  def alloc(self, size):
    addr = self._addr
    self._addr = Allocator.align(self._addr + size, self._bound)
    return addr

def random_ext_map(ext_count, size): # [ (lbase, pbase, count) for each extent]
  size_per_blk = 64 # size unit is 64 Byte, Block size is 4096 Byte
  total_blocks = (size-1) // size_per_blk+1
  surplus_blocks = total_blocks % ext_count
  ext_blocks = total_blocks // ext_count
  counts = [ ext_blocks+1 for i in range(surplus_blocks) ]
  if ext_blocks > 0:
    counts += [ ext_blocks for i in range(ext_count-surplus_blocks) ]
  pbases = list(accumulate(counts))
  pbases = [0] + pbases[0:-1]
  pblks = list(zip(pbases, counts))
  shuffle(pblks)
  lbases = list(accumulate(b[1] for b in pblks))
  lbases = [0] + lbases[0:-1]
  return list(zip(lbases, (b[0] for b in pblks), (b[1] for b in pblks)))

def random_ext_rows(size, ext_count, row_entries=15): # [ [(lbase, pbase) for each entry] + [(llimit, -1)] for each row ]
  ext_map = random_ext_map(ext_count, size)
  entry_count = len(ext_map)
  row_count = (entry_count - 1) // row_entries + 1
  rows = []
  for i in range(row_count):
    beg_entry = row_entries*i
    end_entry = min(row_entries*(i+1), entry_count)
    pad_entries = row_entries - end_entry + beg_entry + 1
    row_content = ext_map[row_entries*i:min(row_entries*(i+1), entry_count)]
    row_end = row_content[-1][0]+row_content[-1][2]
    row = [ (e[0],e[1]) for e in row_content ] + [ (row_end, 0) for i in range(pad_entries) ]
    rows.append(row)
  return rows

def mappercfg(first_row, row_count):
  cfg = row_count & 0xF
  for i in range(row_count):
    cfg |= ((first_row+i)&0xF) << (row_count-i)*4
  return cfg

def gen_mapper_config(cmds, mapper_params):
  cmds.ext_Halt.write(0xf)
  current_row = 0
  for mapper_idx in range(4):
    cfg_reg = 'ext_Port{}'.format(mapper_idx)
    if mapper_idx in mapper_params:
      size,ext_count,base_addr,alloc = mapper_params[mapper_idx]
      base_block = base_addr >> 12
      rows = random_ext_rows(size, ext_count)
      first_row = current_row
      row_count = len(rows)
      if alloc:
        cmds.alloc(mapper_idx, size)
      for row in rows:
        for entry_idx, entry in enumerate(row):
          cmds.ext_WrLBlk.write(base_block + entry[0])
          if alloc:
            cmds.ext_WrPBlk.writeAlloc(entry[1], mapper_idx, 12)
          else:
            cmds.ext_WrLBlk.write(base_block + entry[1])
          entry_addr = (current_row << 4) + entry_idx
          cmds.ext_WrAddr.write(entry_addr)
        current_row += 1
      cmds[cfg_reg].write(mappercfg(first_row, row_count))
    else:
      cmds[cfg_reg].write(mappercfg(0, 0))
  cmds.ext_Flush.write(0xf)

def gen_dma_config(cmds, comp, addr=0x0, count=0x0, blen=0x0):
  addr_reg = '{}_Addr'.format(comp)
  if addr_reg in cmds:
    cmds[addr_reg].write(addr)
  count_reg = '{}_TCount'.format(comp)
  if count_reg in cmds:
    cmds[count_reg].write(count)
  blen_reg = '{}_Burst'.format(comp)
  if blen_reg in cmds:
    cmds[blen_reg].write(blen)

def switchcfg(mappings):
  map = 0xFFFFFFFFFFFFFFFF
  for src,dst in mappings:
    map &= ~(0xF << 4*dst)
    map |= (src & 0xF) << 4*dst
  return map

def monitorcfg(rd, wr, stm):
  return (0xF   & (rd  << 0)) | \
         (0xF0  & (wr  << 4)) | \
         (0xF00 & (stm << 8))

def gen_commands(cmds, src, dst, tcount, srcburst, dstburst, srcfrag, dstfrag):
  tcount &= 0xFFFFFFFF
  # Allocation sizes must be multiples of 4K blocks to ensure that the
  # Block Mapper remaps no half-allocated blocks
  alloc_size = Allocator.align(tcount*64, 4096)
  cmem = Allocator(0x1, 4096)
  hmem = Allocator(0x1, 4096)

  if srcburst <= 0:
    srcburst = 63
  else:
    srcburst = (srcburst - 1) % 64
  if dstburst <= 0:
    dstburst = 63
  else:
    dstburst = (dstburst - 1) % 64


  components = [
    ('src',  src=='dummy', None, 0),
    ('hrd',  src=='hmem',  hmem, 0),
    ('crd',  src=='cmem',  cmem, 0),
    ('sink', dst=='dummy', None, 1),
    ('hwr',  dst=='hmem',  hmem, 1),
    ('cwr',  dst=='cmem',  cmem, 1)]
  stream = [None, None]
  monitor = [None, None]
  mapper_params = {}
  for comp,is_active,allocator,idx in components:
    if is_active:
      ext_id_parm = '{}_ext_id'.format(comp)
      switch_id_parm = '{}_switch_id'.format(comp)
      aximon_id_parm = '{}_aximon_id'.format(comp)
      alloc_addr = allocator.alloc(alloc_size) if allocator is not None else 0
      gen_dma_config(cmds, comp, alloc_addr, tcount, srcburst)
      if ext_id_parm in cmds:
        mapper_params[cmds[ext_id_parm]] = (alloc_size, srcfrag, alloc_addr, True)
      if aximon_id_parm in cmds:
        monitor[idx] = cmds[aximon_id_parm]
      stream[idx] = cmds[switch_id_parm]
    else:
      gen_dma_config(cmds, comp)

  if stream[0] is None or stream[1] is None:
    return None

  gen_mapper_config(cmds, mapper_params)
  cmds.switch_Mapping.write(switchcfg((stream,)))
  cmds.mon_Mapping.write(monitorcfg(monitor[0] or 0, monitor[1] or 0, stream[1]))

  cmds.run()

  cmds.mon_ASAct.read()
  cmds.mon_ASMSt.read()
  cmds.mon_ASSSt.read()
  cmds.mon_ASIdl.read()
  cmds.mon_ASByt.read()
  if monitor[0] is not None:
    cmds.mon_ARCnt.read()
    cmds.mon_ARLat.read()
    cmds.mon_ARAct.read()
    cmds.mon_ARMSt.read()
    cmds.mon_ARSSt.read()
    cmds.mon_ARIdl.read()
    cmds.mon_ARByt.read()
  if monitor[1] is not None:
    cmds.mon_AWCnt.read()
    cmds.mon_AWLat.read()
    cmds.mon_AWMSt.read()
    cmds.mon_AWAct.read()
    cmds.mon_AWSSt.read()
    cmds.mon_AWIdl.read()
    cmds.mon_AWByt.read()

  cmds.quit()


def gen_series(base, steps, factor, condition=lambda x: True):
  series = [ int(base * factor**step) for step in range(steps) ]
  series = set(filter(condition, series))
  return list(series)

def gen_params(args):
  param_sets = []
  sizes = gen_series(args.size_base, args.size_steps, args.size_factor)
  blens = gen_series(args.blen_base, args.blen_steps, args.blen_factor)
  blen_base = args.blen_base
  for tcount in sizes:
    frags = gen_series(args.frag_base, args.frag_steps, args.frag_factor, condition=lambda frag: frag<=((tcount-1)//64+1))
    frag_base = args.frag_base
    for src,dst in args.assoc:
      param_sets.append({'src':src, 'dst':dst, 'tcount':tcount,
                         'srcburst':blen_base, 'dstburst':blen_base,
                         'srcfrag':frag_base, 'dstfrag':frag_base})
      for blen,frag in product(blens, frags):
        if src != 'dummy' and blen != blen_base and frag != frag_base:
          param_sets.append({'src':src, 'dst':dst, 'tcount':tcount,
                             'srcburst':blen, 'dstburst':blen_base,
                             'srcfrag':frag, 'dstfrag':frag_base})
        if dst != 'dummy' and blen != blen_base and frag != frag_base:
          param_sets.append({'src':src, 'dst':dst, 'tcount':tcount,
                             'srcburst':blen_base, 'dstburst':blen,
                             'srcfrag':frag_base, 'dstfrag':frag})
        if src != 'dummy' and dst != 'dummy' and blen != blen_base and frag != frag_base:
          param_sets.append({'src':src, 'dst':dst, 'tcount':tcount,
                             'srcburst':blen, 'dstburst':blen,
                             'srcfrag':frag, 'dstfrag':frag})
  return param_sets


def setup_runs(args):
  environment = {}
  if args.verbose:
    environment['SNAP_TRACE'] = '0xf'

  cmdline = [args.binary]
  if args.interrupt:
    cmdline.append('-I')
  if args.timeout > 0:
    cmdline.append('-t{:d}'.format(args.timeout))

  return cmdline, environment


def main(args):
  cmds = CommandBuffer(args.reg_config)
  param_sets = gen_params(args)
  if args.binary is None:
    print('Starting dry-run as --binary was not set', file=sys.stderr)
  else:
    print('Start Sequence with {:d} Param Sets'.format(len(param_sets)), file=sys.stderr)
  cmd,env = setup_runs(args)
  results = []
  try:
    for params in param_sets:
      params_string = ', '.join(str(k)+'='+str(v) for k,v in params.items())
      print('  Param Set: [{}] Runs: {:d}'.format(params_string, args.runs), file=sys.stderr)
      gen_commands(cmds, **params)
      commands = cmds.take()
      input = '\n'.join(commands)
      runs = []
      if args.binary is not None:
        for run in range(args.runs):
          proc = subprocess.run(cmd, env=env, input=input,
                                stdout=subprocess.PIPE,
                                universal_newlines=True)
          print('    Run {:d} Returncode: {:d}'.format(run, proc.returncode), file=sys.stderr)
          metrics = cmds.decode_reads(proc.stdout)
          runs.append({'returncode':proc.returncode, 'output':proc.stdout, 'metrics':metrics})
      results.append({'params':params, 'commands':commands, 'runs':runs})
  except KeyboardInterrupt:
    print('ABORT due to Ctrl-C', file=sys.stderr)
  json.dump({'setup': vars(args), 'cmdline':cmd, 'environment':env, 'results': results}, args.out, default=str, sort_keys=True, indent=2)

def assoc_list(arg_str):
  assocs = []
  abbr = {'D': 'dummy', 'H': 'hmem', 'C': 'cmem'}
  pairs = arg_str.split(',')
  for pair in pairs:
    if len(pair) != 2 or pair[0] not in abbr or pair[1] not in abbr:
      raise argparse.ArgumentTypeError
    assocs.append((abbr[pair[0]], abbr[pair[1]]))
  return assocs

if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('--binary', default=None)
  parser.add_argument('--out', type=argparse.FileType('w'), default=sys.stdout)
  parser.add_argument('--reg-config', type=Path, default='./registers.yml')
  parser.add_argument('--verbose', action='store_true')
  parser.add_argument('--interrupt', action='store_true')
  parser.add_argument('--timeout', type=int, default=0)
  parser.add_argument('--runs', type=int, default=1)
  parser.add_argument('--assoc', type=assoc_list, required=True)
  parser.add_argument('--size-steps', type=int, default=1)
  parser.add_argument('--size-base', type=int, default=16)
  parser.add_argument('--size-factor', type=float, default=2.0)
  parser.add_argument('--frag-steps', type=int, default=1)
  parser.add_argument('--frag-base', type=int, default=1)
  parser.add_argument('--frag-factor', type=float, default=2)
  parser.add_argument('--blen-steps', type=int, default=1)
  parser.add_argument('--blen-base', type=int, default=64)
  parser.add_argument('--blen-factor', type=float, default=0.25)
  main(parser.parse_args())
