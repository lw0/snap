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
    sst = metrics['mon_ASSSt']
    mst = metrics['mon_ASMSt']
    act = metrics['mon_ASAct']
    idl = metrics['mon_ASIdl']
    byt = metrics['mon_ASByt']
    tot = sst + mst + act + idl
    metrics['mon_ASTot'] = tot
    totSec = tot * 0.000000004
    metrics['mon_ASTotSec'] = totSec
    metrics['mon_ASBpSec'] = byt / totSec
    maxB = act * 64
    metrics['mon_ASMaxB'] = maxB
    metrics['mon_ASMaxBpSec'] = maxB / totSec
    metrics['mon_ASSStPerc'] = sst * 100.0 / tot
    metrics['mon_ASMStPerc'] = mst * 100.0 / tot
    metrics['mon_ASActPerc'] = act * 100.0 / tot
  except:
    pass
  for prefix in ('AR', 'AW'):
    try:
      cnt = metrics['mon_{}Cnt'.format(prefix)]
      lat = metrics['mon_{}Lat'.format(prefix)]
      sst = metrics['mon_{}SSt'.format(prefix)]
      mst = metrics['mon_{}MSt'.format(prefix)]
      act = metrics['mon_{}Act'.format(prefix)]
      idl = metrics['mon_{}Idl'.format(prefix)]
      byt = metrics['mon_{}Byt'.format(prefix)]
      tot = lat + sst + mst + act + idl
      metrics['mon_{}Tot'.format(prefix)] = tot
      metrics['mon_{}TrnLat'.format(prefix)] = lat / cnt
      metrics['mon_{}TrnSSt'.format(prefix)] = sst / cnt
      metrics['mon_{}TrnMSt'.format(prefix)] = mst / cnt
      metrics['mon_{}TrnTot'.format(prefix)] = tot / cnt
      totSec = tot * 0.000000004
      metrics['mon_{}TotSec'.format(prefix)] = totSec
      metrics['mon_{}BpSec'.format(prefix)] = byt / totSec
      maxB = act * 64
      metrics['mon_{}MaxB'.format(prefix)] = maxB
      metrics['mon_{}MaxBpSec'.format(prefix)] = maxB / totSec
      metrics['mon_{}LatPerc'.format(prefix)] = lat * 100.0 / tot
      metrics['mon_{}SStPerc'.format(prefix)] = sst * 100.0 / tot
      metrics['mon_{}MStPerc'.format(prefix)] = mst * 100.0 / tot
      metrics['mon_{}ActPerc'.format(prefix)] = act * 100.0 / tot
      metrics['mon_{}IdlPerc'.format(prefix)] = idl * 100.0 / tot
    except:
      pass
  return metrics

def derive_statistics(metric_sets, params):
  if len(metric_sets) == 0:
    return
  common_keys = list(reduce(lambda acc,new: acc.intersection(new), (set(metrics.keys()) for metrics in metric_sets)))
  series = {}
  series['params'] = params
  series['params']['count'] = len(metric_sets)
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
  errors = []
  for res in data['results']:
    print('{:d}/{:d}: {:s}'.format(count, len(data['results']), str(res['params'])), file=sys.stderr)
    count += 1
    metric_sets = []
    for run in res['runs']:
      print('  RetC {:d}'.format(run['returncode']), file=sys.stderr)
      if run['returncode'] == 0:
        metric_sets.append(derive_metrics(run['metrics']))
      else:
        errors.append({'run': run, 'params': res['params']})
    results.append(derive_statistics(metric_sets, res['params']))

  json.dump(results, args.output, default=str, sort_keys=True, indent=2)
  if args.error is not None:
    json.dump(errors, args.error, default=str, sort_keys=True, indent=2)


if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('--input', type=argparse.FileType('r'), default=sys.stdin)
  parser.add_argument('--output', type=argparse.FileType('w'), default=sys.stdout)
  parser.add_argument('--error', type=argparse.FileType('w'), default=None)
  main(parser.parse_args())
