#!/usr/bin/python3
import argparse
import json
import sys

def main(args):
  data = json.load(args.input)

  # for res in data.results:
  for res in data:
    print('{}:'.format(str(res["params"])))
    for key in args.min:
      if key in res["min"]:
        print('  min.{:12s} = {:12.0f}'.format(key, float(res["min"][key])))
    for key in args.max:
      if key in res["max"]:
        print('  max.{:12s} = {:12.0f}'.format(key, float(res["max"][key])))
    for key in args.avg:
      if key in res["avg"]:
        print('  avg.{:12s} = {:12.0f}'.format(key, float(res["avg"][key])))
    for key in args.med:
      if key in res["med"]:
        print('  med.{:12s} = {:12.0f}'.format(key, float(res["med"][key])))

if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('--input', type=argparse.FileType('r'), default=sys.stdin)
  parser.add_argument('--min', action='append', default=[])
  parser.add_argument('--max', action='append', default=[])
  parser.add_argument('--avg', action='append', default=[])
  parser.add_argument('--med', action='append', default=[])
  main(parser.parse_args())
