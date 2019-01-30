#!/usr/bin/python3
import argparse
from functools import reduce
from statistics import mean,median,stdev
import json
import sys

def derive_metrics(run):
  metrics = dict(run)
  try:
    cyc = metrics['Cycle']
    metrics['CycleSec'] = cyc * 0.000000004 # @250MHz
  except:
    pass
  try:
    sst = metrics['ASSSt']
    mst = metrics['ASMSt']
    act = metrics['ASAct']
    idl = metrics['ASIdl']
    byt = metrics['ASByt']
    tot = sst + mst + act + idl
    metrics['ASTot'] = tot
    totSec = tot * 0.000000004
    metrics['ASTotSec'] = totSec
    metrics['ASBpSec'] = byt / totSec
    maxB = act * 64
    metrics['ASMaxB'] = maxB
    metrics['ASMaxBpSec'] = maxB / totSec
    metrics['ASSStPerc'] = sst * 100.0 / tot
    metrics['ASMStPerc'] = mst * 100.0 / tot
    metrics['ASActPerc'] = act * 100.0 / tot
  except:
    pass
  for prefix in ('AR', 'AW'):
    try:
      cnt = metrics['{}Cnt'.format(prefix)]
      lat = metrics['{}Lat'.format(prefix)]
      sst = metrics['{}SSt'.format(prefix)]
      mst = metrics['{}MSt'.format(prefix)]
      act = metrics['{}Act'.format(prefix)]
      idl = metrics['{}Idl'.format(prefix)]
      byt = metrics['{}Byt'.format(prefix)]
      tot = lat + sst + mst + act + idl
      metrics['{}Tot'.format(prefix)] = tot
      metrics['{}TrnLat'.format(prefix)] = lat / cnt
      metrics['{}TrnSSt'.format(prefix)] = sst / cnt
      metrics['{}TrnMSt'.format(prefix)] = mst / cnt
      metrics['{}TrnTot'.format(prefix)] = tot / cnt
      totSec = tot * 0.000000004
      metrics['{}TotSec'.format(prefix)] = totSec
      metrics['{}BpSec'.format(prefix)] = byt / totSec
      maxB = act * 64
      metrics['{}MaxB'.format(prefix)] = maxB
      metrics['{}MaxBpSec'.format(prefix)] = maxB / totSec
      metrics['{}LatPerc'.format(prefix)] = lat * 100.0 / tot
      metrics['{}SStPerc'.format(prefix)] = sst * 100.0 / tot
      metrics['{}MStPerc'.format(prefix)] = mst * 100.0 / tot
      metrics['{}ActPerc'.format(prefix)] = act * 100.0 / tot
    except:
      pass
  return metrics

def derive_statistics(metric_sets, params):
  if len(metric_sets) == 0:
    return
  common_keys = list(reduce(lambda acc,new: acc.intersection(new), (set(metrics.keys()) for metrics in metric_sets)))
  series = {}
  series['params'] = params
  series['raw'] = metric_sets
  series['min'] = {}
  series['max'] = {}
  series['avg'] = {}
  series['med'] = {}
  series['std'] = {}
  for key in common_keys:
    series['min'][key] = min(metrics[key] for metrics in metric_sets)
    series['max'][key] = max(metrics[key] for metrics in metric_sets)
    series['avg'][key] = mean(metrics[key] for metrics in metric_sets)
    series['med'][key] = median(metrics[key] for metrics in metric_sets)
    if len(metric_sets) > 1:
      series['std'][key] = stdev(metrics[key] for metrics in metric_sets)
  return series

def main(args):
  data = json.load(args.input)

  count = 0
  results = []
  for res in data['results']:
    count += 1
    print('{:d}/{:d}: {:s}'.format(count, len(data['results']), str(res['params'])), file=sys.stderr)
    metric_sets = []
    for run in res['runs']:
      if run['returncode'] == 0:
        metric_sets.append(derive_metrics(run['metrics']))
    results.append(derive_statistics(metric_sets, res['params']))

  json.dump(results, args.output, default=str, sort_keys=True, indent=2)


if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('--input', type=argparse.FileType('r'), default=sys.stdin)
  parser.add_argument('--output', type=argparse.FileType('w'), default=sys.stdout)
  main(parser.parse_args())
