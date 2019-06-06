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

def csv_value(val, args):
  if not args.compact or not isinstance(val, float) or not math.isfinite(val) or val==0:
    return str(val)
  scale = math.pow(10, math.ceil(math.log10(abs(val))))
  val = scale * round(val / scale, args.digits)
  # prefix = {-4: 'p', -3: 'n', -2: 'u', -1: 'm', 0: '', 1: 'K', 2: 'M', 3: 'G', 4: 'T'}
  prefix = {0: '', 1: 'K', 2: 'M', 3: 'G', 4: 'T'}
  dim = int(math.floor(math.log(val, 1000)))
  if dim not in prefix:
    if abs(dim)*3 > args.digits:
      sval = '{:.{prec}e}'.format(val, prec=args.digits)
    else:
      sval = '{:f}'.format(val,)
  else:
    val = val / math.pow(1000, dim)
    sval = '{:f}'.format(val)
  sval = sval.rstrip('0')
  sval = sval.rstrip('.')
  return '{}{}'.format(sval, prefix.get(dim, ''))

param_format = 'Params({count:02d}): {size:9d} Units {src:>5}->{dst:<5} (frag: {srcfrag}->{dstfrag}) (burst: {srcburst}->{dstburst})'
def print_human(args, res):
  print(param_format.format_map(defaultdict(lambda: '<unset>', res['params'])))
  for kind,name in args.get:
    # value = float(res.get(kind,{}).get('mon_{}'.format(name), float('nan')))
    value = float(res.get(kind,{}).get(name, float('nan')))
    print('  {}.{:12s} = {:s}'.format(kind, name, numformat(value, args.digits)))

def print_csv_header(args):
  fields = [ 'tcount', 'src', 'dst', 'srcburst', 'dstburst', 'srcfrag', 'dstfrag' ]
  fields.extend('{}.{}'.format(kind, name) for kind,name in args.get)
  print(','.join(fields))

def print_csv(args, res):
  values = [
    '{:07d}'.format(res['params'].get('size', 0)),
    '{}'.format(res['params'].get('src', 0)),
    '{}'.format(res['params'].get('dst', 0)),
    '{:02d}'.format(res['params'].get('srcburst', 64)),
    '{:02d}'.format(res['params'].get('dstburst', 64)),
    '{:03d}'.format(res['params'].get('dstfrag', 1)),
    '{:03d}'.format(res['params'].get('srcfrag', 1)) ]
  for kind,name in args.get:
    # values.append(float(res.get(kind,{}).get('mon_{}'.format(name), float('nan'))))
    values.append(float(res.get(kind,{}).get(name, float('nan'))))
  print(','.join(csv_value(val, args) for val in values))

def main(args):
  data = json.load(args.input)

  if args.csv:
    print_csv_header(args)

  for res in data:
    if res is not None and eval(args.filter, {'p':  res['params'],
                          's':  res['params'].get('src', 0),
                          'd':  res['params'].get('dst', 0),
                          'sf': res['params'].get('srcfrag', 1),
                          'df': res['params'].get('dstfrag', 1),
                          'c':  res['params'].get('size', 0),
                          'sb': res['params'].get('srcburst', 64),
                          'db': res['params'].get('dstburst', 64)}):
      if args.csv:
        print_csv(args, res)
      else:
        print_human(args, res)

def parse_metric(arg):
  args = arg.split('.')
  if len(args) != 2 or args[0] not in ('min', 'max', 'avg', 'med', 'std', 'rmx', 'rmi'):
    raise argparse.ArgumentError('Invalid metric spec.')
  return (args[0], args[1])

if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('--input', type=argparse.FileType('r'), default=sys.stdin)
  parser.add_argument('--filter', default='True')
  parser.add_argument('--digits', type=int, default='4')
  parser.add_argument('--csv', action='store_true')
  parser.add_argument('--get', action='append', type=parse_metric, default=[])
  parser.add_argument('--compact', action='store_true')
  main(parser.parse_args())
