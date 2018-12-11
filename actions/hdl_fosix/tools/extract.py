#!/usr/bin/python3
import argparse
import json
import sys

def print_human(args, res):
  print('{}:'.format(str(res['params'])))
  for key in args.min:
    if key in res['min']:
      print('  min.{:12s} = {:12.0f}'.format(key, float(res['min'][key])))
  for key in args.max:
    if key in res['max']:
      print('  max.{:12s} = {:12.0f}'.format(key, float(res['max'][key])))
  for key in args.avg:
    if key in res['avg']:
      print('  avg.{:12s} = {:12.0f}'.format(key, float(res['avg'][key])))
  for key in args.med:
    if key in res['med']:
      print('  med.{:12s} = {:12.0f}'.format(key, float(res['med'][key])))
  for key in args.std:
    if key in res['std']:
      print('  std.{:12s} = {:12.0f}'.format(key, float(res['std'][key])))

def print_csv_header(args):
  fields = [ 'size', 'src', 'dst', 'srcburst', 'dstburst' ]
  fields.extend('min.{}'.format(key) for key in args.min)
  fields.extend('max.{}'.format(key) for key in args.max)
  fields.extend('avg.{}'.format(key) for key in args.avg)
  fields.extend('med.{}'.format(key) for key in args.med)
  fields.extend('std.{}'.format(key) for key in args.std)
  print(','.join(fields))

def print_csv(args, res):
  values = [
    res['params'].get('size', 0),
    res['params'].get('src', 0),
    res['params'].get('dst', 0),
    res['params'].get('srcburst', 64),
    res['params'].get('dstburst', 64) ]
  for key in args.min:
    values.append(float(res['min'].get(key, float('nan'))))
  for key in args.max:
    values.append(float(res['max'].get(key, float('nan'))))
  for key in args.avg:
    values.append(float(res['avg'].get(key, float('nan'))))
  for key in args.med:
    values.append(float(res['med'].get(key, float('nan'))))
  for key in args.med:
    values.append(float(res['med'].get(key, float('nan'))))
  print(','.join(str(val) for val in values))

def main(args):
  data = json.load(args.input)

  if args.csv:
    print_csv_header(args)

  for res in data['results']:
    if eval(args.filter, {'p': res['params']}):
      if args.csv:
        print_csv(args, res)
      else:
        print_human(args, res)

if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('--input', type=argparse.FileType('r'), default=sys.stdin)
  parser.add_argument('--filter', default='True')
  parser.add_argument('--csv', action='store_true')
  parser.add_argument('--min', action='append', default=[])
  parser.add_argument('--max', action='append', default=[])
  parser.add_argument('--avg', action='append', default=[])
  parser.add_argument('--med', action='append', default=[])
  parser.add_argument('--std', action='append', default=[])
  main(parser.parse_args())
