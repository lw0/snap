#!/usr/bin/env python3
import argparse
import itertools
import json
import pathlib
import subprocess
import sys

from registers import RegInfo, configure_dma_alloc, configure_dma

def align(val, boundary):
  val += boundary-1
  val -= val % boundary
  return val

def gen_commands(regs, tcount, srcburst, dstburst):
  tcount &= 0xFFFFFFFF
  # Allocation sizes must be multiples of 4K blocks to ensure that the
  # Block Mapper remaps no half-allocated blocks
  alloc_size = align(tcount*64, 4096)

  srcburst = (srcburst-1)%64 if srcburst > 0 else 63
  dstburst = (dstburst-1)%64 if dstburst > 0 else 63

  for idx in range(4):
    rd_alloc_id = regs.alloc(alloc_size)
    configure_dma_alloc(regs['rd%d'%idx], rd_alloc_id, tcount, srcburst)
    configure_dma(regs['snk%d'%idx], count=tcount)
    configure_dma(regs['src%d'%idx], count=tcount)
    wr_alloc_id = regs.alloc(alloc_size)
    configure_dma_alloc(regs['wr%d'%idx], wr_alloc_id, tcount, dstburst)

  regs.run()

  regs.quit()


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
  cmd,env = setup_runs(args)
  results = []
  try:
    gen_commands(regs, args.tcount, args.srcburst, args.dstburst)
    commands = regs.takeCmds()
    input = '\n'.join(commands)
    if args.binary is not None:
      proc = subprocess.run(cmd, env=env, input=input,
                            stdout=subprocess.PIPE,
                            universal_newlines=True)
      print('    Returncode: {:d}'.format(proc.returncode), file=sys.stderr)
  except KeyboardInterrupt:
    print('ABORT due to Ctrl-C', file=sys.stderr)

if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('--binary', default=None)
  parser.add_argument('--reg-config', type=pathlib.Path, default='./registers_mux.yml')
  parser.add_argument('--verbose', action='store_true')
  parser.add_argument('--interrupt', action='store_true')
  parser.add_argument('--timeout', type=int, default=0)
  parser.add_argument('--tcount', type=int, default=1)
  parser.add_argument('--srcburst', type=int, default=64)
  parser.add_argument('--dstburst', type=int, default=64)
  main(parser.parse_args())
