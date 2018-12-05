#!/usr/bin/python3
import argparse
from functools import reduce
import json
import sys

counters = { 0x18  : "Cycle", # Cycles
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

def derive_metrics(run):
  try:
    cyc = float(run['Cycle'.format(prefix)])
    stot = float(run['StTot'.format(prefix)])
    sact = float(run['StSSt'.format(prefix)])
    ssst = float(run['StMSt'.format(prefix)])
    smst = float(run['StAct'.format(prefix)])
    dataB = sact * 64
    timeSec = cyc * 0.000000004 # @250MHz
    rateBpSec = dataB / timeSec
    swaitSec = ssst * 0.000000004
    mwaitSec = smst * 0.000000004
    run["timeSec"] = timeSec
    run["dataB"] = dataB
    run["rateBpSec"] = rateBpSec
    run["swaitSec"] = swaitSec
    run["mwaitSec"] = mwaitSec
  except:
    pass
  for prefix in ('HR', 'HW', 'CR', 'CW'):
    try:
      cnt = float(run['{}Cnt'.format(prefix)])
      lat = float(run['{}Lat'.format(prefix)])
      sst = float(run['{}SSt'.format(prefix)])
      mst = float(run['{}MSt'.format(prefix)])
      act = float(run['{}Act'.format(prefix)])
      idl = float(run['{}Idl'.format(prefix)])
      trnLat = lat / cnt
      trnSst = sst / cnt
      trnMst = mst / cnt
      tot = lat + sst + mst + act + idl
      trnTot = tot / cnt
      run["{}TrnLat".format(prefix.lower())] = trnLat
      run["{}TrnSSt".format(prefix.lower())] = trnSst
      run["{}TrnMSt".format(prefix.lower())] = trnMst
      run["{}TrnTot".format(prefix.lower())] = trnTot
      dataB = act * 64
      timeSec = tot * 0.000000004
      rateBpSec = dataB / timeSec
      swaitSec = sst * 0.000000004
      mwaitSec = mst * 0.000000004
      latSec = mst * 0.000000004
      run["{}TimeSec".format(prefix.lower())] = timeSec
      run["{}DataB".format(prefix.lower())] = dataB
      run["{}RateBpSec".format(prefix.lower())] = rateBpSec
      run["{}SwaitSec".format(prefix.lower())] = swaitSec
      run["{}MwaitSec".format(prefix.lower())] = mwaitSec
      run["{}LatSec".format(prefix.lower())] = latSec
    except:
      pass

def derive_statistics(res):
  common_keys = list(reduce(lambda acc,new: acc.intersection(new), (set(run.keys()) for run in res["runs"])))
  count = len(res["runs"])
  res["min"] = {}
  res["max"] = {}
  res["avg"] = {}
  res["med"] = {}
  for key in common_keys:
    res["min"][key] = min(run[key] for run in res['runs'])
    res["max"][key] = max(run[key] for run in res['runs'])
    res["avg"][key] = float(sum(run[key] for run in res['runs'])) / count
    res["med"][key] = sorted(run[key] for run in res['runs'])[count//2]

def main(args):
  data = json.load(args.input)

  count = 0
  # for res in data.results:
  for res in data:
    count += 1
    print('{:d}/{:d}: {:s}'.format(count, len(data), str(res["params"])), file=sys.stderr)
    for run in res["runs"]:
      derive_metrics(run)
    derive_statistics(res)

  json.dump(data, args.output, default=str, sort_keys=True, indent=2)

#         runs.append(metrics)
#     results.append({'params':params, 'runs':runs})
#   json.dump({'setup': vars(args), 'results': results}, args.out, default=str, sort_keys=True, indent=2)

if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('--input', type=argparse.FileType('r'), default=sys.stdin)
  parser.add_argument('--output', type=argparse.FileType('w'), default=sys.stdout)
  main(parser.parse_args())
