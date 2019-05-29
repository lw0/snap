#!/usr/bin/env python3
import argparse
import itertools
import json
import pathlib
import subprocess
import sys

from registers import RegInfo, configure_dma_alloc, configure_dma, configure_switch

def align(val, boundary):
  val += boundary-1
  val -= val % boundary
  return val

def gen_commands(regs, tcount, src, dst, srcburst, dstburst):
  tcount &= 0xFFFFFFFF
  # Allocation sizes must be multiples of 4K blocks to ensure that the
  # Block Mapper remaps no half-allocated blocks
  alloc_size = align(tcount*64, 4096)

  srcburst = (srcburst-1)%64 if srcburst > 0 else 63
  dstburst = (dstburst-1)%64 if dstburst > 0 else 63


  for idx in range(4):
    if idx < src:
      rd_alloc_id = regs.alloc(alloc_size)
      configure_dma_alloc(regs['rd%d'%idx], rd_alloc_id, tcount, srcburst)
      configure_dma(regs['snk%d'%idx], count=tcount)
    else:
      configure_dma(regs['rd%d'%idx])
      configure_dma(regs['snk%d'%idx])
    if idx < dst:
      configure_dma(regs['src%d'%idx], count=tcount)
      wr_alloc_id = regs.alloc(alloc_size)
      configure_dma_alloc(regs['wr%d'%idx], wr_alloc_id, tcount, dstburst)
    else:
      configure_dma(regs['src%d'%idx])
      configure_dma(regs['wr%d'%idx])

  configure_switch(regs.mon, [(0, 0), (0, 1), (0, 2)])

  regs.run()

  regs.mon.ASAct.read()
  regs.mon.ASMSt.read()
  regs.mon.ASSSt.read()
  regs.mon.ASIdl.read()
  regs.mon.ASByt.read()
  regs.mon.ARCnt.read()
  regs.mon.ARLat.read()
  regs.mon.ARAct.read()
  regs.mon.ARMSt.read()
  regs.mon.ARSSt.read()
  regs.mon.ARIdl.read()
  regs.mon.ARByt.read()
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
  tcounts = gen_series(args.tcount_base, args.tcount_steps, args.tcount_factor)
  scounts = gen_series(args.scount_base, args.scount_steps, args.scount_factor, condition=lambda cnt: 0<=cnt<=4)
  if args.bind_scount:
    sdcounts = [ (cnt, cnt) for cnt in scounts ]
  else:
    sdcounts = list(itertools.product(scounts, scounts))
  blens = gen_series(args.blen_base, args.blen_steps, args.blen_factor)
  blen_base = args.blen_base
  for tcount in tcounts:
    for src,dst in sdcounts:
      param_sets.append({'tcount':tcount,
                         'src':src, 'dst':dst,
                         'srcburst':blen_base, 'dstburst':blen_base})
      for blen in blens:
        if blen != blen_base:
          param_sets.append({'tcount':tcount,
                             'src':src, 'dst':dst,
                             'srcburst':blen, 'dstburst':blen_base})
          param_sets.append({'tcount':tcount,
                             'src':src, 'dst':dst,
                             'srcburst':blen_base, 'dstburst':blen})
          param_sets.append({'tcount':tcount,
                             'src':src, 'dst':dst,
                             'srcburst':blen, 'dstburst':blen})
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
  cmd,env = setup_runs(args)
  results = []
  try:
    for pidx,params in enumerate(param_sets):
      params_string = ', '.join(str(k)+'='+str(v) for k,v in params.items())
      print('  Param Set ({:d}/{:d}): [{}] Runs: {:d}'.format(pidx, len(param_sets), params_string, args.runs), file=sys.stderr)
      if args.binary is not None:
        gen_commands(regs, **params)
        commands = regs.takeCmds()
        input = '\n'.join(commands)
        runs = []
        for run in range(args.runs):
          proc = subprocess.run(cmd, env=env, input=input,
                                stdout=subprocess.PIPE,
                                universal_newlines=True)
          print('    Returncode: {:d}'.format(proc.returncode), file=sys.stderr)
          metrics = regs.decode_reads(proc.stdout)
          runs.append({'returncode':proc.returncode, 'output':proc.stdout, 'metrics':metrics})
        results.append({'params':params, 'commands':commands, 'runs':runs})
  except KeyboardInterrupt:
    print('ABORT due to Ctrl-C', file=sys.stderr)
  json.dump({'setup': vars(args), 'cmdline':cmd, 'environment':env, 'results': results}, args.out, default=str, sort_keys=True, indent=2)

if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('--binary', default=None)
  parser.add_argument('--out', type=argparse.FileType('w'), default=sys.stdout)
  parser.add_argument('--reg-config', type=pathlib.Path, default='./registers_mux.yml')
  parser.add_argument('--verbose', action='store_true')
  parser.add_argument('--interrupt', action='store_true')
  parser.add_argument('--timeout', type=int, default=0)
  parser.add_argument('--runs', type=int, default=1)
  parser.add_argument('--tcount-steps', type=int, default=1)
  parser.add_argument('--tcount-base', type=int, default=16)
  parser.add_argument('--tcount-factor', type=float, default=2.0)
  parser.add_argument('--blen-steps', type=int, default=1)
  parser.add_argument('--blen-base', type=int, default=64)
  parser.add_argument('--blen-factor', type=float, default=0.25)
  parser.add_argument('--scount-steps', type=int, default=1)
  parser.add_argument('--scount-base', type=int, default=4)
  parser.add_argument('--scount-factor', type=float, default=0.5)
  parser.add_argument('--bind-scount', action='store_true')
  main(parser.parse_args())
