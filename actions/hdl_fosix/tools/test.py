#!/usr/bin/python3
import argparse
import json
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
             0x198 : "ASByt"} # Axi Stream Transferred Bytes

def align(val, boundary):
  val += boundary - 1
  val -= val % boundary
  return val

def upper(val):
  return (val >> 32) & 0xFFFFFFFF

def lower(val):
  return (val) & 0xFFFFFFFF

def mapcfg(mappings):
  map = 0xFFFFFFFFFFFFFFFF
  for (src,dst) in mappings:
    map &= ~(0xF << 4*src)
    map |= (dst & 0xF) << 4*src
  return map

def gen_param_cmdline(src='dummy', dst='dummy', size=0, srcoff=0, dstoff=0, srcburst=0, dstburst=0):
  size &= 0xFFFFFFFF

  srcoff %= 64
  srcalloc = size + srcoff
  if srcburst == 0:
    srcburst = 63
  else:
    srcburst = (srcburst - 1) % 64

  dstoff %= 64
  dstalloc = size + dstoff
  if dstburst == 0:
    dstburst = 63
  else:
    dstburst = (dstburst - 1) % 64

  arguments = []
  # Always observe Total Cycles and Axi Stream Monitor
  observe = [0x018, 0x138, 0x150, 0x168, 0x180, 0x198]
  cmem_base = align(0x1, 4096)

  src_stream = None
  if src == 'dummy':
    arguments.append('-s0x04C:0x{:08x}'.format(size))
    src_stream = 0xf
  else:
    arguments.append('-s0x04C:0x{:08x}'.format(0))
  if src == 'hmem':
    arguments.append('-a0x080:0x{:08x}+{:02d}'.format(srcalloc, srcoff << 6))
    arguments.append('-s0x088:0x{:08x}'.format(size))
    arguments.append('-s0x08C:0x{:08x}'.format(srcburst))
    # Set Monitor Read Map to HMem
    arguments.append('-s0x100:0x{:08x}'.format(0))
    # Observe Axi Read Monitor
    observe.extend([0x108, 0x118, 0x128, 0x140, 0x158, 0x170, 0x188])
    src_stream = 0x0
  else:
    arguments.append('-s0x080:0x{:08x}'.format(0))
    arguments.append('-s0x084:0x{:08x}'.format(0))
    arguments.append('-s0x088:0x{:08x}'.format(0))
    arguments.append('-s0x08C:0x{:08x}'.format(63))
  if src == 'cmem':
    addr = cmem_base + srcoff*64
    cmem_base = align(size*64 + srcoff*64, 4096)
    arguments.append('-s0x0A0:0x{:08x}'.format(lower(addr)))
    arguments.append('-s0x0A4:0x{:08x}'.format(upper(addr)))
    arguments.append('-s0x0A8:0x{:08x}'.format(size))
    arguments.append('-s0x0AC:0x{:08x}'.format(srcburst))
    # Set Axi Read Monitor Map to CMem
    arguments.append('-s0x100:0x{:08x}'.format(1))
    # Observe Axi Read Monitor
    observe.extend([0x108, 0x118, 0x128, 0x140, 0x158, 0x170, 0x188])
    src_stream = 0x1
  else:
    arguments.append('-s0x0A0:0x{:08x}'.format(0))
    arguments.append('-s0x0A4:0x{:08x}'.format(0))
    arguments.append('-s0x0A8:0x{:08x}'.format(0))
    arguments.append('-s0x0AC:0x{:08x}'.format(63))
  if src_stream is None:
    return None

  dst_stream = None
  if dst == 'dummy':
    dst_stream = 0xf
  if dst == 'hmem':
    arguments.append('-a0x090:0x{:08x}+{:02d}'.format(dstalloc, dstoff))
    arguments.append('-s0x098:0x{:08x}'.format(size))
    arguments.append('-s0x09C:0x{:08x}'.format(dstburst))
    # Set Axi Write Monitor Map to HMem
    arguments.append('-s0x104:0x{:08x}'.format(0))
    # Observe Axi Write Monitor
    observe.extend([0x110, 0x120, 0x130, 0x148, 0x160, 0x178, 0x190])
    dst_stream = 0x0
  else:
    arguments.append('-s0x090:0x{:08x}'.format(0))
    arguments.append('-s0x094:0x{:08x}'.format(0))
    arguments.append('-s0x098:0x{:08x}'.format(0))
    arguments.append('-s0x09C:0x{:08x}'.format(63))
  if dst == 'cmem':
    addr = cmem_base + dstoff*64
    cmem_base = align(size*64 + dstoff*64, 4096)
    arguments.append('-s0x0B0:0x{:08x}'.format(lower(addr)))
    arguments.append('-s0x0B4:0x{:08x}'.format(upper(addr)))
    arguments.append('-s0x0B8:0x{:08x}'.format(size))
    arguments.append('-s0x0BC:0x{:08x}'.format(dstburst))
    # Set Axi Write Monitor Map to CMem
    arguments.append('-s0x104:0x{:08x}'.format(1))
    # Observe Axi Write Monitor
    observe.extend([0x110, 0x120, 0x130, 0x148, 0x160, 0x178, 0x190])
    dst_stream = 0x1
  else:
    arguments.append('-s0x0B0:0x{:08x}'.format(0))
    arguments.append('-s0x0B4:0x{:08x}'.format(0))
    arguments.append('-s0x0B8:0x{:08x}'.format(0))
    arguments.append('-s0x0BC:0x{:08x}'.format(63))
  if dst_stream is None:
    return None

  map = mapcfg([(src_stream, dst_stream)])
  arguments.append('-s0x040:0x{:08x}'.format(lower(map)))
  arguments.append('-s0x044:0x{:08x}'.format(upper(map)))
  arguments.append('-s0x048:0x{:08x}'.format(lower(src_stream)))

  for addr in observe:
    arguments.append('-g0x{:03x}'.format(addr))
    arguments.append('-g0x{:03x}'.format(addr+4))

  return arguments

GET_PATTERN = re.compile('\((0x[0-9a-fA-F]+)\) => (0x[0-9a-fA-F]+)')
def parse_results(stdout):
  reg_values = {}
  for line in stdout.splitlines():
    m = GET_PATTERN.match(line)
    if m:
      reg_values[int(m.group(1),0)] = int(m.group(2),0)
  values = {}
  for reg,name in counters.items():
    if reg in reg_values or (reg+4) in reg_values:
      value = (reg_values.get(reg+4, 0) << 32) + reg_values.get(reg,0)
      values[name] = value 
  return values

def gen_params(args):
  param_sets = []
  for size_step in range(args.size_steps):
    size = int(args.size_base * args.size_factor**size_step)
    for src,dst in args.assoc:
      if src == 'dummy' and dst == 'dummy' or not args.use_blen:
        param_sets.append({'src':src, 'dst':dst, 'size':size})
      elif src == 'dummy':
        for blen_step in range(args.blen_steps):
          blen = int(args.blen_base * args.blen_factor**blen_step)
          param_sets.append({'src':src, 'dst':dst, 'size':size, 'dstburst':blen})
      elif dst == 'dummy':
        for blen_step in range(args.blen_steps):
          blen = int(args.blen_base * args.blen_factor**blen_step)
          param_sets.append({'src':src, 'dst':dst, 'size':size, 'srcburst':blen})
      else:
        for sblen_step in range(args.blen_steps):
          for dblen_step in range(args.blen_steps):
            sblen = int(args.blen_base * args.blen_factor**sblen_step)
            dblen = int(args.blen_base * args.blen_factor**dblen_step)
            param_sets.append({'src':src, 'dst':dst, 'size':size, 'srcburst':sblen, 'dstburst':dblen})
  return param_sets

def main(args):
  param_sets = gen_params(args)
  print('Start Sequence with {:d} Param Sets'.format(len(param_sets)), file=sys.stderr)
  results = []
  for params in param_sets:
    params_string = ', '.join(str(k)+'='+str(v) for k,v in params.items())
    print('  Param Set: [{}] Runs: {:d}'.format(params_string, args.runs), file=sys.stderr)
    runs = []
    cmdline_base = [args.binary, '-I', '-t{:d}'.format(args.timeout)]
    cmdline_param = gen_param_cmdline(**params)
    if args.verbose:
      print('    Command:', ' '.join(cmdline_base), '\\', file=sys.stderr)
      print('              ', ' \\\n               '.join(cmdline_param), file=sys.stderr)
    for run in range(args.runs):
      proc = subprocess.run(cmdline_base + cmdline_param, stdout=subprocess.PIPE, universal_newlines=True)
      print('    Run {:d} Returncode: {:d}'.format(run, proc.returncode), file=sys.stderr)
      if proc.returncode == 0:
        metrics = parse_results(proc.stdout)
        if args.verbose:
          print('\n'.join('{:s}: {:08x}'.format(name, value) for name,value in metrics.items()), file=sys.stderr)
        runs.append(metrics)
    results.append({'params':params, 'runs':runs})
  json.dump({'setup': vars(args), 'results': results}, args.out, default=str, sort_keys=True, indent=2)

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
  parser.add_argument('--binary', required=True)
  parser.add_argument('--out', type=argparse.FileType('w'), default=sys.stdout)
  parser.add_argument('--verbose', action='store_true')
  parser.add_argument('--timeout', type=int, default=60)
  parser.add_argument('--runs', type=int, default=1)
  parser.add_argument('--assoc', type=assoc_list, required=True)
  parser.add_argument('--size-steps', type=int, default=1)
  parser.add_argument('--size-base', type=int, default=16)
  parser.add_argument('--size-factor', type=float, default=2.0)
  parser.add_argument('--use-blen', action='store_true')
  parser.add_argument('--blen-steps', type=int, default=4)
  parser.add_argument('--blen-base', type=int, default=1)
  parser.add_argument('--blen-factor', type=float, default=4.0)
  main(parser.parse_args())
