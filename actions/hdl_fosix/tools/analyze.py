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
    tot = run['StTot']
    act = run['StSSt']
    sst = run['StMSt']
    mst = run['StAct']
    run['StIdl'] = tot - act - sst - mst
    totSec = tot * 0.000000004
    run['StTotSec'] = totSec
    datB = act * 64
    run['StDatB'] = datB
    run['StDatBpSec'] = datB / totSec
    run['StSStPerc'] = sst * 100.0 / tot
    run['StMStPerc'] = mst * 100.0 / tot
    run['StActPerc'] = act * 100.0 / tot
  except:
    pass
  for prefix in ('HR', 'HW', 'CR', 'CW'):
    try:
      cnt = run['{}Cnt'.format(prefix)]
      lat = run['{}Lat'.format(prefix)]
      sst = run['{}SSt'.format(prefix)]
      mst = run['{}MSt'.format(prefix)]
      act = run['{}Act'.format(prefix)]
      idl = run['{}Idl'.format(prefix)]
      tot = lat + sst + mst + act + idl
      run['{}Tot'.format(prefix)] = tot
      run['{}TrnLat'.format(prefix)] = lat / cnt
      run['{}TrnSSt'.format(prefix)] = sst / cnt
      run['{}TrnMSt'.format(prefix)] = mst / cnt
      run['{}TrnTot'.format(prefix)] = tot / cnt
      totSec = tot * 0.000000004
      run['{}TotSec'.format(prefix)] = totSec
      datB = act * 64
      run['{}DatB'.format(prefix)] = datB
      run['{}DatBpSec'.format(prefix)] = datB / totSec
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
  res['std'] = {}
  for key in common_keys:
    res['min'][key] = min(run[key] for run in res['runs'])
    res['max'][key] = max(run[key] for run in res['runs'])
    res['avg'][key] = mean(run[key] for run in res['runs'])
    res['med'][key] = median(run[key] for run in res['runs'])
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
