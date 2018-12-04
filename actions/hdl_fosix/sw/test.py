#!/usr/bin/python3
import argparse
import json
import re
import subprocess
import sys

observe = { 0x18  : "Cycle", # Cycles
            0x50  : "StTot", # Stream Total
            0x58  : "StAct", # Stream Active
            0x60  : "StSSt", # Stream SlaveStall
            0x68  : "StMSt", # Stream MasterStall
            0x100 : "HRCnt", # HMem Read  TransCount
            0x108 : "HRLat", # HMem Read  Latency
            0x110 : "HRSSt", # HMem Read  SlaveStall
            0x118 : "HRMSt", # HMem Read  MasterStall
            0x120 : "HRAct", # HMem Read  Active
            0x128 : "HRIdl", # HMem Read  Idle
            0x130 : "HWCnt", # HMem Write TransCount
            0x138 : "HWLat", # HMem Write Latency
            0x140 : "HWSSt", # HMem Write SlaveStall
            0x148 : "HWMSt", # HMem Write MasterStall
            0x150 : "HWAct", # HMem Write Active
            0x158 : "HWIdl", # HMem Write Idle
            0x180 : "CRCnt", # CMem Read  TransCount
            0x188 : "CRLat", # CMem Read  Latency
            0x190 : "CRSSt", # CMem Read  SlaveStall
            0x198 : "CRMSt", # CMem Read  MasterStall
            0x1A0 : "CRAct", # CMem Read  Active
            0x1A8 : "CRIdl", # CMem Read  Idle
            0x1B0 : "CWCnt", # CMem Write TransCount
            0x1B8 : "CWLat", # CMem Write Latency
            0x1C0 : "CWSSt", # CMem Write SlaveStall
            0x1C8 : "CWMSt", # CMem Write MasterStall
            0x1D0 : "CWAct", # CMem Write Active
            0x1D8 : "CWIdl"} # CMem Write Idle

def align(val, boundary):
  val += boundary - 1
  return val % boundary

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

def gen_args(src='dummy', dst='dummy', size=0, srcoff=0, dstoff=0, srcburst=0, dstburst=0):
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
  cmem_base = align(0x1, 4096)

  src_stream = None
  if src == 'dummy':
    arguments.append('-s0x4C:0x{:08x}'.format(size))
    src_stream = 0xf
  else:
    arguments.append('-s0x4C:0x{:08x}'.format(0))
  if src == 'hmem':
    arguments.append('-a0x80:0x{:08x}+{:02d}'.format(srcalloc, srcoff << 6))
    arguments.append('-s0x88:0x{:08x}'.format(size))
    arguments.append('-s0x88:0x{:08x}'.format(srcburst))
    src_stream = 0x0
  else:
    arguments.append('-s0x80:0x{:08x}'.format(0))
    arguments.append('-s0x84:0x{:08x}'.format(0))
    arguments.append('-s0x88:0x{:08x}'.format(0))
    arguments.append('-s0x8C:0x{:08x}'.format(63))
  if src == 'cmem':
    addr = cmem_base + srcoff*64
    cmem_base = align(size*64 + srcoff*64, 4096)
    arguments.append('-s0xA0:0x{:08x}'.format(lower(addr)))
    arguments.append('-s0xA4:0x{:08x}'.format(upper(addr)))
    arguments.append('-s0xA8:0x{:08x}'.format(size))
    arguments.append('-s0xAC:0x{:08x}'.format(srcburst))
    src_stream = 0x1
  else:
    arguments.append('-s0xA0:0x{:08x}'.format(0))
    arguments.append('-s0xA4:0x{:08x}'.format(0))
    arguments.append('-s0xA8:0x{:08x}'.format(0))
    arguments.append('-s0xAC:0x{:08x}'.format(63))
  if src_stream is None:
    return None

  dst_stream = None
  if dst == 'dummy':
    dst_stream = 0xf
  if dst == 'hmem':
    arguments.append('-a0x90:0x{:08x}+{:02d}'.format(dstalloc, dstoff))
    arguments.append('-s0x98:0x{:08x}'.format(size))
    arguments.append('-s0x98:0x{:08x}'.format(dstburst))
    dst_stream = 0x0
  else:
    arguments.append('-s0x90:0x{:08x}'.format(0))
    arguments.append('-s0x94:0x{:08x}'.format(0))
    arguments.append('-s0x98:0x{:08x}'.format(0))
    arguments.append('-s0x9C:0x{:08x}'.format(63))
  if dst == 'cmem':
    addr = cmem_base + dstoff*64
    cmem_base = align(size*64 + dstoff*64, 4096)
    arguments.append('-s0xB0:0x{:08x}'.format(lower(addr)))
    arguments.append('-s0xB4:0x{:08x}'.format(upper(addr)))
    arguments.append('-s0xB8:0x{:08x}'.format(size))
    arguments.append('-s0xBC:0x{:08x}'.format(dstburst))
    dst_stream = 0x1
  else:
    arguments.append('-s0xB0:0x{:08x}'.format(0))
    arguments.append('-s0xB4:0x{:08x}'.format(0))
    arguments.append('-s0xB8:0x{:08x}'.format(0))
    arguments.append('-s0xBC:0x{:08x}'.format(63))
  if dst_stream is None:
    return None

  map = mapcfg([(src_stream, dst_stream)])
  arguments.append('-s0x40:0x{:08x}'.format(lower(map)))
  arguments.append('-s0x44:0x{:08x}'.format(upper(map)))
  arguments.append('-s0x48:0x{:08x}'.format(lower(src_stream)))

  arguments.append('-s0x50:0x0') # Reset Stream Monitor
  arguments.append('-s0x100:0x0') # Reset HMem Monitor
  arguments.append('-s0x180:0x0') # Reset CMem Monitor

  for addr in observe.keys():
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
  for reg,name in observe.items():
    value = (reg_values.get(reg+4, 0) << 32) + reg_values.get(reg,0)
    values[name] = value 
  return values

def gen_params(args):
  param_sets = []
  for src in list(set(args.src)):
    for dst in list(set(args.dst)):
      for size_step in range(args.size_steps):
        size = int(args.size_base * args.size_factor**size_step)
        if src == 'dummy' and dst == 'dummy' or not args.use_blen:
          param_sets.append({'src':src, 'dst':dst, 'size':size})
        elif src == 'dummy':
          for blen_step in range(args.blen_steps):
            blen = int(args.blen_base * args.blen_factor**blen_step)
            param_sets.append({'src':src, 'dst':dst, 'size':size, 'dstburst':blen})
        elif dst == 'dummy':
          for blen_step in range(blen_steps):
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
    cmdline = [args.binary, '-I', '-t{:d}'.format(args.timeout)]
    cmdline.extend(gen_args(**params))
    for run in range(args.runs):
      proc = subprocess.run(cmdline, stdout=subprocess.PIPE, universal_newlines=True)
      print('    Run {:d} Returncode: {:d}'.format(run, proc.returncode), file=sys.stderr)
      if proc.returncode == 0:
        runs.append(parse_results(proc.stdout))
    results.append({'params':params, 'runs':runs})
  json.dump(results, args.out, sort_keys=True, indent=2)

if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('--binary', required=True)
  parser.add_argument('--out', type=argparse.FileType('w'), default=sys.stdout)
  parser.add_argument('--timeout', type=int, default=60)
  parser.add_argument('--runs', type=int, default=1)
  parser.add_argument('--src', action='append', choices=('dummy', 'hmem', 'cmem'), required=True)
  parser.add_argument('--dst', action='append', choices=('dummy', 'hmem', 'cmem'), required=True)
  parser.add_argument('--size-steps', type=int, default=1)
  parser.add_argument('--size-base', type=int, default=16)
  parser.add_argument('--size-factor', type=float, default=2.0)
  parser.add_argument('--use-blen', action='store_true')
  parser.add_argument('--blen-steps', type=int, default=4)
  parser.add_argument('--blen-base', type=int, default=1)
  parser.add_argument('--blen-factor', type=float, default=4.0)
  main(parser.parse_args())
