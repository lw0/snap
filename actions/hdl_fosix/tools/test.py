#!/usr/bin/python3
import argparse
from itertools import accumulate,product
import json
from random import shuffle
import re
import subprocess
import sys

counters = { 0x18  : "Cycle", # Action Running Cycles
             0x108 : "ARCnt", # Axi Read   Transaction Count
             0x110 : "AWCnt", # Axi Write  Transaction Count
             0x118 : "ARLat", # Axi Read   Cumulative Latency
             0x120 : "AWLat", # Axi Write  Cumulative Latency
             0x128 : "ARSSt", # Axi Read   Slave Stalls
             0x130 : "AWSSt", # Axi Write  Slave Stalls
             0x138 : "ASSSt", # Axi Stream Slave Stalls
             0x140 : "ARMSt", # Axi Read   Master Stalls
             0x148 : "AWMSt", # Axi Write  Master Stalls
             0x150 : "ASMSt", # Axi Stream Master Stalls
             0x158 : "ARAct", # Axi Read   Active Cycles
             0x160 : "AWAct", # Axi Write  Active Cycles
             0x168 : "ASAct", # Axi Stream Active Cycles
             0x170 : "ARIdl", # Axi Read   Idle Cycles
             0x178 : "AWIdl", # Axi Write  Idle Cycles
             0x180 : "ASIdl", # Axi Stream Idle Cycles
             0x188 : "ARByt", # Axi Read   Transferred Bytes
             0x190 : "AWByt", # Axi Write  Transferred Bytes
             0x198 : "ASByt", # Axi Stream Transferred Bytes
             0xFC0 : "DbgHMem", # Debug HMem Axi Port
             0xFC4 : "DbgCMem", # Debug CMem Axi Port
             0xFC8 : "DbgSIn",  # Debug Switch Input Streams
             0xFCC : "DbgSOut", # Debug Switch Output Streams
             0xFD0 : "DbgHMRd", # Debug HMem Reader and Mapper
             0xFD4 : "DbgHMWr", # Debug HMem Writer and Mapper
             0xFD8 : "DbgCMRd", # Debug CMem Reader and Mapper
             0xFDC : "DbgCMWr", # Debug CMem Writer and Mapper
             0xFE0 : "DbgEMap"} # Debug Extent Store

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
def cmdAlloc(id, size):
  return 'A{:d}:{}'.format(id, hex32(size))
def cmdRel64(reg, base, id, shift):
  return 'R{}:{}+A{:d}|{:d}'.format(hexReg(reg), hex64(base), id, shift)
def cmdGet32(reg):
  return 'g{}'.format(hexReg(reg))
def cmdGet64(reg):
  return 'G{}'.format(hexReg(reg))
def cmdRun(timeout=0):
  return 'r{:d}'.format(timeout)
def cmdQuit():
  return 'q'

def align(val, boundary):
  val += boundary - 1
  val -= val % boundary
  return val

def gen_ext_map(ext_count, size): # [ (lbase, pbase, count) for each extent]
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

def gen_ext_rows(size, ext_count, row_entries=15): # [ [(lbase, pbase) for each entry] + [(llimit, -1)] for each row ]
  ext_map = gen_ext_map(ext_count, size)
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

def gen_mapper_config(mapper_params):
  commands = [ cmdSet32(0x0C0, 0xf) ] # Halt all Ports
  current_row = 0
  for mapper in range(4):
    if mapper in mapper_params:
      size,ext_count,base_addr,alloc = mapper_params[mapper]
      base_block = base_addr >> 12
      rows = gen_ext_rows(size, ext_count)
      first_row = current_row
      row_count = len(rows)
      if alloc:
        commands.append(cmdAlloc(mapper, size))
      for row in rows:
        for i, entry in enumerate(row):
          commands.append(cmdSet32(0x0D4, base_block + entry[0])) # Prepare LBase
          if alloc:
            commands.append(cmdRel64(0x0D8, entry[1], mapper, 12)) # Prepare PBase
          else:
            commands.append(cmdSet64(0x0D8, base_block + entry[1])) # Prepare PBase
          entry_addr = (current_row << 4) + i
          commands.append(cmdSet32(0x0D0, entry_addr)) # Actual Write Command
        current_row += 1
      commands.append(cmdSet32(0x0E0+mapper*4, mappercfg(first_row, row_count)))
    else:
      commands.append(cmdSet32(0x0E0+mapper*4, mappercfg(0, 0)))
  commands.append(cmdSet32(0x0C4, 0xf)) # Flush (and unhalt) all Ports
  return commands

def gen_dma_config(base, addr=0x0, count=0x0, blen=0x0):
  return [ cmdSet64(base+0x0, addr),
           cmdSet32(base+0x8, count),
           cmdSet32(base+0xC, blen)]

def switchcfg(mappings):
  map = 0xFFFFFFFFFFFFFFFF
  for (src,dst) in mappings:
    map &= ~(0xF << 4*src)
    map |= (dst & 0xF) << 4*src
  return map

def gen_switch_config(src_stream, dst_stream):
  return [ cmdSet64(0x040, switchcfg([(src_stream, dst_stream)])), # Stream Switch
           cmdSet32(0x048, src_stream),                            # Stream Monitor
           cmdSet32(0x100, src_stream),                            # Read Monitor
           cmdSet32(0x104, dst_stream) ]                           # Write Monitor

def gen_commands(src, dst, size, srcburst, dstburst, srcfrag, dstfrag):
  size &= 0xFFFFFFFF
  # Allocation sizes must be multiples of 4K blocks to ensure that the
  # Block Mapper remaps no half-allocated blocks
  alloc = align(size, 64)
  if srcburst <= 0:
    srcburst = 63
  else:
    srcburst = (srcburst - 1) % 64
  if dstburst <= 0:
    dstburst = 63
  else:
    dstburst = (dstburst - 1) % 64

  cmem_base = align(0x1, 4096)
  hmem_base = align(0x1, 4096)
  mapper_params = {}
  commands = []

  src_stream = None
  if src == 'dummy':
    commands.append(cmdSet32(0x04C, size))
    src_stream = 0xf
  else:
    commands.append(cmdSet32(0x04C, 0))
  if src == 'hmem':
    commands.extend(gen_dma_config(0x080, hmem_base, size, srcburst))
    mapper_params[0x0] = (alloc, srcfrag, hmem_base, True)
    src_stream = 0x0
    hmem_base = align(hmem_base + alloc*64, 4096)
  else:
    commands.extend(gen_dma_config(0x080))
  if src == 'cmem':
    commands.extend(gen_dma_config(0x0A0, cmem_base, size, srcburst))
    mapper_params[0x2] = (alloc, srcfrag, cmem_base, False)
    src_stream = 0x1
    cmem_base = align(cmem_base + alloc*64, 4096)
  else:
    commands.extend(gen_dma_config(0x0A0))
  if src_stream is None:
    return None

  dst_stream = None
  if dst == 'dummy':
    dst_stream = 0xf
  if dst == 'hmem':
    commands.extend(gen_dma_config(0x090, hmem_base, size, srcburst))
    mapper_params[0x1] = (alloc, dstfrag, hmem_base, True)
    dst_stream = 0x0
    hmem_base = align(hmem_base + alloc*64, 4096)
  else:
    commands.extend(gen_dma_config(0x090))
  if dst == 'cmem':
    commands.extend(gen_dma_config(0x0B0, cmem_base, size, srcburst))
    mapper_params[0x3] = (alloc, dstfrag, cmem_base, False)
    dst_stream = 0x1
    cmem_base = align(cmem_base + alloc*64, 4096)
  else:
    commands.extend(gen_dma_config(0x0B0))
  if dst_stream is None:
    return None

  commands.extend(gen_mapper_config(mapper_params))

  commands.extend(gen_switch_config(src_stream, dst_stream))

  commands.append(cmdRun())

  # Always observe Total Cycles and Axi Stream Monitor
  observe = [0x018, 0x138, 0x150, 0x168, 0x180, 0x198]
  if src != 'dummy':
    # In non-dummy source, also observe Axi Read Monitor
    observe.extend([0x108, 0x118, 0x128, 0x140, 0x158, 0x170, 0x188])
  if dst != 'dummy':
    # In non-dummy destination, also observe Axi Write Monitor
    observe.extend([0x110, 0x120, 0x130, 0x148, 0x160, 0x178, 0x190])
  for addr in observe:
    commands.append('G0x{:08x}'.format(addr))

  # Also Read Out Debug Registers in case a Timeout occurs
  commands.extend([cmdGet32(0xFC0),
                   cmdGet32(0xFC4),
                   cmdGet32(0xFC8),
                   cmdGet32(0xFCC),
                   cmdGet32(0xFD0),
                   cmdGet32(0xFD4),
                   cmdGet32(0xFD8),
                   cmdGet32(0xFDC),
                   cmdGet32(0xFE0)])

  commands.append(cmdQuit())

  return commands


def gen_series(base, steps, factor, condition=lambda x: True):
  series = [ int(base * factor**step) for step in range(steps) ]
  series = set(filter(condition, series))
  return list(series)

def gen_params(args):
  param_sets = []
  sizes = gen_series(args.size_base, args.size_steps, args.size_factor)
  blens = gen_series(args.blen_base, args.blen_steps, args.blen_factor)
  blen_base = args.blen_base
  for size in sizes:
    frags = gen_series(args.frag_base, args.frag_steps, args.frag_factor, condition=lambda frag: frag<=((size-1)//64+1))
    frag_base = args.frag_base
    for src,dst in args.assoc:
      param_sets.append({'src':src, 'dst':dst, 'size':size,
                         'srcburst':blen_base, 'dstburst':blen_base,
                         'srcfrag':frag_base, 'dstfrag':frag_base})
      for blen,frag in product(blens, frags):
        if src != 'dummy' and blen != blen_base and frag != frag_base:
          param_sets.append({'src':src, 'dst':dst, 'size':size,
                             'srcburst':blen, 'dstburst':blen_base,
                             'srcfrag':frag, 'dstfrag':frag_base})
        if dst != 'dummy' and blen != blen_base and frag != frag_base:
          param_sets.append({'src':src, 'dst':dst, 'size':size,
                             'srcburst':blen_base, 'dstburst':blen,
                             'srcfrag':frag_base, 'dstfrag':frag})
        if src != 'dummy' and dst != 'dummy' and blen != blen_base and frag != frag_base:
          param_sets.append({'src':src, 'dst':dst, 'size':size,
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


GET_PATTERN = re.compile('\((0x[0-9a-fA-F]+)\) => (0x[0-9a-fA-F]+)')
def parse_results(stdout):
  results = {}
  for line in stdout.splitlines():
    m = GET_PATTERN.match(line)
    if m:
      reg_addr = int(m.group(1),0)
      reg_value = int(m.group(2),0)
      if reg_addr in counters:
        results[counters[reg_addr]] = reg_value
      else:
        results[str(reg_addr)] = reg_value
  return results


def main(args):
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
      commands = gen_commands(**params)
      input = '\n'.join(commands)
      runs = []
      if args.binary is not None:
        for run in range(args.runs):
          proc = subprocess.run(cmd, env=env, input=input,
                                stdout=subprocess.PIPE,
                                universal_newlines=True)
          print('    Run {:d} Returncode: {:d}'.format(run, proc.returncode), file=sys.stderr)
          metrics = parse_results(proc.stdout)
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
