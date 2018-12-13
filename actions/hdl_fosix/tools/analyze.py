#!/usr/bin/python3
import argparse
from functools import reduce
from statistics import mean,median,stdev
import json
import sys

def derive_metrics(run):
  try:
    cyc = run['Cycle']
    run['CycleSec'] = cyc * 0.000000004 # @250MHz
    sst = run['ASSSt']
    mst = run['ASMSt']
    act = run['ASAct']
    idl = run['ASIdl']
    byt = run['ASByt']
    tot = sst + mst + act + idl
    run['ASTot'] = tot
    totSec = tot * 0.000000004
    run['ASTotSec'] = totSec
    run['ASBpSec'] = byt / totSec
    maxB = act * 64
    run['ASMaxB'] = maxB
    run['ASMaxBpSec'] = maxB / totSec
    run['ASSStPerc'] = sst * 100.0 / tot
    run['ASMStPerc'] = mst * 100.0 / tot
    run['ASActPerc'] = act * 100.0 / tot
  except:
    pass
  for prefix in ('AR', 'AW'):
    try:
      cnt = run['{}Cnt'.format(prefix)]
      lat = run['{}Lat'.format(prefix)]
      sst = run['{}SSt'.format(prefix)]
      mst = run['{}MSt'.format(prefix)]
      act = run['{}Act'.format(prefix)]
      idl = run['{}Idl'.format(prefix)]
      byt = run['{}Byt'.format(prefix)]
      tot = lat + sst + mst + act + idl
      run['{}Tot'.format(prefix)] = tot
      run['{}TrnLat'.format(prefix)] = lat / cnt
      run['{}TrnSSt'.format(prefix)] = sst / cnt
      run['{}TrnMSt'.format(prefix)] = mst / cnt
      run['{}TrnTot'.format(prefix)] = tot / cnt
      totSec = tot * 0.000000004
      run['{}TotSec'.format(prefix)] = totSec
      run['{}BpSec'.format(prefix)] = byt / totSec
      maxB = act * 64
      run['{}MaxB'.format(prefix)] = maxB
      run['{}MaxBpSec'.format(prefix)] = maxB / totSec
      run['{}LatPerc'.format(prefix)] = lat * 100.0 / tot
      run['{}SStPerc'.format(prefix)] = sst * 100.0 / tot
      run['{}MStPerc'.format(prefix)] = mst * 100.0 / tot
      run['{}ActPerc'.format(prefix)] = act * 100.0 / tot
    except:
      pass

def derive_statistics(res):
  common_keys = list(reduce(lambda acc,new: acc.intersection(new), (set(run.keys()) for run in res['runs'])))
  res['min'] = {}
  res['max'] = {}
  res['avg'] = {}
  res['med'] = {}
  if len(res['runs']) > 1:
    res['std'] = {}
  for key in common_keys:
    res['min'][key] = min(run[key] for run in res['runs'])
    res['max'][key] = max(run[key] for run in res['runs'])
    res['avg'][key] = mean(run[key] for run in res['runs'])
    res['med'][key] = median(run[key] for run in res['runs'])
    if len(res['runs']) > 1:
      res['std'][key] = stdev(run[key] for run in res['runs'])

def main(args):
  data = json.load(args.input)

  count = 0
  for res in data['results']:
    count += 1
    print('{:d}/{:d}: {:s}'.format(count, len(data['results']), str(res['params'])), file=sys.stderr)
    for run in res['runs']:
      derive_metrics(run)
    derive_statistics(res)

  json.dump(data, args.output, default=str, sort_keys=True, indent=2)


if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('--input', type=argparse.FileType('r'), default=sys.stdin)
  parser.add_argument('--output', type=argparse.FileType('w'), default=sys.stdout)
  main(parser.parse_args())
