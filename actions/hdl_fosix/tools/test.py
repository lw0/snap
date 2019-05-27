#!/usr/bin/env python3
import argparse
import itertools
import json
import pathlib
import subprocess
import sys

from registers import RegInfo, BlockMapperConfig, configure_extent_store, configure_dma, configure_switch

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

def gen_commands(regs, src, dst, tcount, srcburst, dstburst, srcfrag, dstfrag):
  tcount &= 0xFFFFFFFF
  # Allocation sizes must be multiples of 4K blocks to ensure that the
  # Block Mapper remaps no half-allocated blocks
  alloc_size = Allocator.align(tcount*64, 4096)
  cmem = Allocator(0x1, 4096)

  srcburst = (srcburst-1)%64 if srcburst > 0 else 63
  dstburst = (dstburst-1)%64 if dstburst > 0 else 63

  srcstream = None
  dststream = None
  srcmonitor = None
  dstmonitor = None
  mapper_config = {}

  if src=='dummy':
    configure_dma(regs.src, 0, tcount)
    srcstream = regs.src.switch_id
  else:
    configure_dma(regs.src)
  if src=='hmem':
    alloc_id = regs.alloc(alloc_size)
    mapper_config[regs.hrd.ext_id] = BlockMapperConfig(size=alloc_size, ext_count=srcfrag, loffset=0, poffset=0, alloc_id=alloc_id)
    configure_dma(regs.hrd, 0, tcount, srcburst)
    srcstream = regs.hrd.switch_id
    srcmonitor = regs.hrd.aximon_id
  else:
    configure_dma(regs.hrd)
  if src=='cmem':
    alloc_addr = cmem.alloc(alloc_size)
    mapper_config[regs.crd.ext_id] = BlockMapperConfig(size=alloc_size, ext_count=srcfrag, loffset=0, poffset=alloc_addr, alloc_id=None)
    configure_dma(regs.crd, 0, tcount, srcburst)
    srcstream = regs.crd.switch_id
    srcmonitor = regs.crd.aximon_id
  else:
    configure_dma(regs.crd)

  if dst=='dummy':
    configure_dma(regs.snk, 0, tcount)
    dststream = regs.snk.switch_id
  else:
    configure_dma(regs.snk)
  if dst=='hmem':
    alloc_id = regs.alloc(alloc_size)
    mapper_config[regs.hwr.ext_id] = BlockMapperConfig(size=alloc_size, ext_count=dstfrag, loffset=0, poffset=0, alloc_id=alloc_id)
    configure_dma(regs.hwr, 0, tcount, dstburst)
    dststream = regs.hwr.switch_id
    dstmonitor = regs.hwr.aximon_id
  else:
    configure_dma(regs.hwr)
  if dst=='cmem':
    alloc_addr = cmem.alloc(alloc_size)
    mapper_config[regs.cwr.ext_id] = BlockMapperConfig(size=alloc_size, ext_count=dstfrag, loffset=0, poffset=alloc_addr, alloc_id=None)
    configure_dma(regs.cwr, 0, tcount, dstburst)
    dststream = regs.cwr.switch_id
    dstmonitor = regs.cwr.aximon_id
  else:
    configure_dma(regs.cwr)

  if srcstream is None or dststream is None:
    return None
  if srcmonitor is None:
    srcmonitor = 0xf
  if dstmonitor is None:
    dstmonitor = 0xf

  configure_extent_store(regs.estor, mapper_config)

  switch_config = [(srcstream, dststream)]
  monitor_config = [(srcmonitor, 0), (dstmonitor, 1), (dststream, 2)]
  print('src', src, file=sys.stderr)
  print('dst', dst, file=sys.stderr)
  print('srcmonitor:', srcmonitor, file=sys.stderr)
  print('srcstream:', srcstream, file=sys.stderr)
  print('dstmonitor:', dstmonitor, file=sys.stderr)
  print('dststream:', dststream, file=sys.stderr)
  print('switch_config:', switch_config, file=sys.stderr)
  print('monitor_config:', monitor_config, file=sys.stderr)
  configure_switch(regs.switch, switch_config)
  configure_switch(regs.mon, monitor_config)
  # configure_switch(regs.switch, [(srcstream, dststream)])
  # configure_switch(regs.mon, [(srcmonitor or 0xf, 0), (dstmonitor or 0xf, 1), (dststream, 2)])

  regs.run()

  regs.mon.ASAct.read()
  regs.mon.ASMSt.read()
  regs.mon.ASSSt.read()
  regs.mon.ASIdl.read()
  regs.mon.ASByt.read()
  if srcmonitor is not None:
    regs.mon.ARCnt.read()
    regs.mon.ARLat.read()
    regs.mon.ARAct.read()
    regs.mon.ARMSt.read()
    regs.mon.ARSSt.read()
    regs.mon.ARIdl.read()
    regs.mon.ARByt.read()
  if dstmonitor is not None:
    regs.mon.AWCnt.read()
    regs.mon.AWLat.read()
    regs.mon.AWMSt.read()
    regs.mon.AWAct.read()
    regs.mon.AWSSt.read()
    regs.mon.AWIdl.read()
    regs.mon.AWByt.read()

  regs.quit()


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
      for blen,frag in itertools.product(blens, frags):
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
  regs = RegInfo(args.reg_config)
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
      gen_commands(regs, **params)
      commands = regs.takeCmds()
      input = '\n'.join(commands)
      runs = []
      if args.binary is not None:
        for run in range(args.runs):
          proc = subprocess.run(cmd, env=env, input=input,
                                stdout=subprocess.PIPE,
                                universal_newlines=True)
          print('    Run {:d} Returncode: {:d}'.format(run, proc.returncode), file=sys.stderr)
          metrics = regs.decode_reads(proc.stdout)
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
  parser.add_argument('--reg-config', type=pathlib.Path, default='./registers.yml')
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
