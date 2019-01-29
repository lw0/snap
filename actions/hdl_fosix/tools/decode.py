#!/usr/bin/python3
import argparse
from functools import reduce
from statistics import mean,median,stdev
import json
import sys


def dec_val_rdy_4(bits):
  return ('V' if bits&0x8 else '-') + ('R' if bits&0x1 else '-')
axi_format = 'ARL:{} ARP:{} R:{}   AWL:{} ARP:{} W:{} B:{}'
def decode_axi(bits):
  return axi_format.format(dec_val_rdy_4(bits>>28),
                           dec_val_rdy_4(bits>>24),
                           dec_val_rdy_4(bits>>20),
                           dec_val_rdy_4(bits>>12),
                           dec_val_rdy_4(bits>>8),
                           dec_val_rdy_4(bits>>4),
                           dec_val_rdy_4(bits>>0))

def dec_val_rdy_2(bits):
  return ('V' if bits&0x2 else '-') + ('R' if bits&0x1 else '-')
def decode_stream(bits):
  return ' '.join('{:1X}:{}'.format(i, dec_val_rdy_2(bits>>(2*i))) for i in range(16))

def dec_mapper_state(bits):
  if bits&0xf == 0x0:
    return 'Idle'
  elif bits&0xf == 0x1:
    return 'MapWait'
  elif bits&0xf == 0x2:
    return 'TestAddr'
  elif bits&0xf == 0x3:
    return 'Pass'
  elif bits&0xf == 0x4:
    return 'FlushAck'
  elif bits&0xf == 0x7:
    return 'Blocked'
  else:
    return '<undef>'
def dec_data_state(bits):
  if bits&0xf == 0x0:
    return 'Idle'
  elif bits&0xf == 0x1:
    return 'Thru'
  elif bits&0xf == 0x2:
    return 'ThruWait'
  elif bits&0xf == 0x3:
    return 'ThruLast'
  elif bits&0xf == 0x5:
    return 'Fill'
  elif bits&0xf == 0x6:
    return 'FillWait'
  elif bits&0xf == 0x7:
    return 'FillLast'
  else:
    return '<undef>'
def dec_addr_state(bits):
  if bits&0xf == 0x0:
    return 'Idle'
  elif bits&0xf == 0x1:
    return 'Init'
  elif bits&0xf == 0x2:
    return 'WaitBurst'
  elif bits&0xf == 0x5:
    return 'ReqInit'
  elif bits&0xf == 0x9:
    return 'WaitADoneF'
  elif bits&0xf == 0xA:
    return 'DoneAWaitF'
  elif bits&0xf == 0xB:
    return 'WaitAWaitF'
  elif bits&0xf == 0xD:
    return 'WaitADoneFLast'
  elif bits&0xf == 0xE:
    return 'DoneAWaitFLast'
  elif bits&0xf == 0xF:
    return 'WaitAWaitFLast'
  else:
    return '<undef>'
dma_format = 'M:{}@{:x}-{:x} A:{} QW:{} QR:{} D:{}+{:x}{}'
def decode_dma(bits):
  return dma_format.format(dec_mapper_state(bits>>28),
                           (bits>>24)&0xf, (bits>>20)&0xf,
                           dec_addr_state(bits>>0),
                           dec_val_rdy_2(bits>>4),
                           dec_val_rdy_2(bits>>6),
                           dec_data_state(bits>>16),
                           (bits>>8)&0x3f,
                           'NLst' if (bits>>15)&0x1 else '')

def dec_extmap_state(bits):
  if bits&0xf == 0x0:
    return 'Idle'
  elif bits&0xf == 0x1:
    return 'FlushWait'
  elif bits&0xf == 0x3:
    return 'Halt'
  elif bits&0xf == 0x4:
    return 'ReqWait'
  elif bits&0xf == 0x5:
    return 'ResCollect'
  elif bits&0xf == 0x6:
    return 'MapAckCollect'
  elif bits&0xf == 0x7:
    return 'Collect'
  else:
    return '<undef>'
def decode_extmap(bits):
  return ' '.join('P{:x}:{}'.format(i, dec_extmap_state(bits>>(4*i))) for i in range(4))

def decode_status(run):
  status = {}
  if 'DbgHMem' in run:
    status['DbgHMem'] = decode_axi(run['DbgHMem'])
  if 'DbgCMem' in run:
    status['DbgCMem'] = decode_axi(run['DbgCMem'])
  if 'DbgSIn' in run:
    status['DbgSIn'] = decode_stream(run['DbgSIn'])
  if 'DbgSOut' in run:
    status['DbgSOut'] = decode_stream(run['DbgSOut'])
  if 'DbgHMRd' in run:
    status['DbgHMRd'] = decode_dma(run['DbgHMRd'])
  if 'DbgHMWr' in run:
    status['DbgHMWr'] = decode_dma(run['DbgHMWr'])
  if 'DbgCMRd' in run:
    status['DbgCMRd'] = decode_dma(run['DbgCMRd'])
  if 'DbgCMWr' in run:
    status['DbgCMWr'] = decode_dma(run['DbgCMWr'])
  if 'DbgEMap' in run:
    status['DbgEMap'] = decode_extmap(run['DbgEMap'])
  return status

def main(args):
  data = json.load(args.input)

  count = 0
  results = []
  for res in data['results']:
    count += 1
    print('{:d}/{:d}: {:s}'.format(count, len(data['results']), str(res['params'])), file=sys.stderr)
    for run in res['runs']:
      status = '\n'.join('    {}: {}'.format(k,v) for k,v in decode_status(run['metrics']).items())
      print('  Return Code {:d}: \n{}'.format(run['returncode'], status))


if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('--input', type=argparse.FileType('r'), default=sys.stdin)
  main(parser.parse_args())
