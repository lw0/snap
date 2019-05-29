#!/usr/bin/python3
import argparse
from collections import defaultdict
from itertools import chain
import json
import sys
import math


def rpart(string, length):
  fill = len(string) % length
  parts = [string[fill+length*i:fill+length*(i+1)] for i in range(len(string)//length)]
  if fill != 0:
    parts.insert(0, string[0:fill])
  return parts

def lpart(string, length):
  fill = length * (len(string) // length)
  parts = [string[length*i:length*(i+1)] for i in range(len(string)//length)]
  if fill != len(string):
    parts.append(string[fill:])
  return parts

def numformat(num, digits=4, space=16):
  num = float(num)
  if num != 0:
    mag = int(math.ceil(math.log10(abs(num))))
    scale = 10 ** mag
    rnd = scale * round(num / scale, digits)
    ilen = max(mag,1)
    flen = max(digits - mag, 0)
  else:
    rnd = 0.0
    ilen = 1
    flen = max(digits-1, 0)
  fill = max(space - ilen - (ilen//3), 0)
  strs = '{:.{l}f}'.format(rnd, l=flen).split('.')
  integ = '\''.join(rpart(strs[0], 3))
  frac  = '\''.join(lpart(strs[1], 3)) if len(strs) > 1 else ''
  return '{}{}.{}'.format(fill*' ', integ, frac)

param_format = 'Params({count:02d}): {tcount:9d} Units {src:>5}->{dst:<5} (frag: {srcfrag}->{dstfrag}) (burst: {srcburst}->{dstburst})'
def print_human(args, res):
  print(param_format.format_map(defaultdict(lambda: '<unset>', res['params'])))
  if 'min' in res:
    for key in chain(args.min, args.any):
      if key in res['min']:
        print('  min.{:12s} = {:s}'.format(key, numformat(res['min'][key], args.digits)))
  if 'max' in res:
    for key in chain(args.max, args.any):
      if key in res['max']:
        print('  max.{:12s} = {:s}'.format(key, numformat(res['max'][key], args.digits)))
  if 'avg' in res:
    for key in chain(args.avg, args.any):
      if key in res['avg']:
        print('  avg.{:12s} = {:s}'.format(key, numformat(res['avg'][key], args.digits)))
  if 'med' in res:
    for key in chain(args.med, args.any):
      if key in res['med']:
        print('  med.{:12s} = {:s}'.format(key, numformat(res['med'][key], args.digits)))
  if 'std' in res:
    for key in chain(args.std, args.any):
      if key in res['std']:
        print('  std.{:12s} = {:s}'.format(key, numformat(res['std'][key], args.digits)))

def print_csv_header(args):
  fields = [ 'tcount', 'src', 'dst', 'srcburst', 'dstburst', 'srcfrag', 'dstfrag' ]
  fields.extend('min.{}'.format(key) for key in chain(args.min, args.any))
  fields.extend('rmi.{}'.format(key) for key in chain(args.rmi, args.any))
  fields.extend('max.{}'.format(key) for key in chain(args.max, args.any))
  fields.extend('rmx.{}'.format(key) for key in chain(args.rmx, args.any))
  fields.extend('avg.{}'.format(key) for key in chain(args.avg, args.any))
  fields.extend('med.{}'.format(key) for key in chain(args.med, args.any))
  fields.extend('std.{}'.format(key) for key in chain(args.std, args.any))
  print(','.join(fields))

def print_csv(args, res):
  values = [
    res['params'].get('tcount', 0),
    res['params'].get('src', 0),
    res['params'].get('dst', 0),
    res['params'].get('srcburst', 64),
    res['params'].get('dstburst', 64),
    res['params'].get('dstfrag', 1),
    res['params'].get('srcfrag', 1) ]
  for key in chain(args.min, args.any):
    values.append(float(res['min'].get(key, float('nan'))))
  for key in chain(args.rmi, args.any):
    values.append(float(res['avg'].get(key, float('nan'))) - float(res['min'].get(key, float('nan'))))
  for key in chain(args.max, args.any):
    values.append(float(res['max'].get(key, float('nan'))))
  for key in chain(args.rmx, args.any):
    values.append(float(res['max'].get(key, float('nan'))) - float(res['avg'].get(key, float('nan'))))
  for key in chain(args.avg, args.any):
    values.append(float(res['avg'].get(key, float('nan'))))
  for key in chain(args.med, args.any):
    values.append(float(res['med'].get(key, float('nan'))))
  for key in chain(args.med, args.any):
    values.append(float(res['med'].get(key, float('nan'))))
  print(','.join(str(val) for val in values))

def main(args):
  data = json.load(args.input)

  if args.csv:
    print_csv_header(args)

  for res in data:
    if eval(args.filter, {'p':  res['params'],
                          's':  res['params'].get('src', None),
                          'd':  res['params'].get('dst', None),
                          'sf': res['params'].get('srcfrag', None),
                          'df': res['params'].get('dstfrag', None),
                          'c':  res['params'].get('tcount', None),
                          'x':  res['params'].get('scount', None),
                          'sb': res['params'].get('srcburst', None),
                          'db': res['params'].get('dstburst', None)}):
      if args.csv:
        print_csv(args, res)
      else:
        print_human(args, res)

if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('--input', type=argparse.FileType('r'), default=sys.stdin)
  parser.add_argument('--filter', default='True')
  parser.add_argument('--digits', type=int, default='4')
  parser.add_argument('--csv', action='store_true')
  parser.add_argument('--min', action='append', default=[])
  parser.add_argument('--max', action='append', default=[])
  parser.add_argument('--avg', action='append', default=[])
  parser.add_argument('--med', action='append', default=[])
  parser.add_argument('--std', action='append', default=[])
  parser.add_argument('--rmx', action='append', default=[])
  parser.add_argument('--rmi', action='append', default=[])
  parser.add_argument('--any', action='append', default=[])
  parser.add_argument('--count', action='store_true')
  main(parser.parse_args())
