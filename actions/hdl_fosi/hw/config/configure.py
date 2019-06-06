#!/usr/bin/env python3
import argparse
import codecs
import glob
import os
import pystache
import sys
import traceback

from fosi import FOSIError, Role, Seq, FOSI

global_templates = [
  'Action.vhd',
  'fosi_user.vhd' ]

def read_template(path):
  with codecs.open(path, 'r', 'utf_8') as f:
    name = os.path.basename(path)[:-4] # strip '.tpl' suffix
    template = pystache.parse(f.read())
    return (name, template)

def read_config(path):
  with codecs.open(path, 'r', 'utf_8') as f:
    return compile(f.read(), path, 'exec')


def main(args):
  template_paths = glob.glob(os.path.join(args.tpldir, '*.vhd.tpl'))
  templates = dict(read_template(path) for path in template_paths)

  partial_paths = glob.glob(os.path.join(args.tpldir, '*.part.tpl'))
  partials = dict(read_template(path) for path in partial_paths)

  script = read_config(args.config)

  fosi = FOSI()
  globals = {
    'Role': Role,
    'Seq': Seq,
    'Typ': fosi.Type,
    'Ent': fosi.Entity,
    'Env': fosi.Env,
    'Ins': fosi.Inst,
    'Sig': fosi.Signal }
  exec(script, globals)
  # try:
  #   exec(script, globals)
  # except FOSIError:
  #   e_type,e_msg,e_tb = sys.exc_info()
  #   e_trace = traceback.extract_tb(e_tb)
  #   print('FOSIError: {}'.format(e_msg), file=sys.stderr)
  #   print(' at [{}:{}] "{}"'.format(os.path.relpath(e_trace[1][0]), e_trace[1][1], e_trace[1][3]), file=sys.stderr)
  #   sys.exit(1)

  if args.debug:
    import pdb; pdb.set_trace()

  for tpl_name in global_templates:
    path = os.path.join(args.outdir, tpl_name)
    template = templates[tpl_name]
    contents = pystache.render(template, fosi, partials=partials)
    with codecs.open(path, 'w', 'utf_8') as f:
      f.write(contents)

  for entity in fosi.entities.contents():
    if 'template' not in entity.props:
      continue
    tpl_name = entity.props['template']
    outfile = entity.props.get('outfile', tpl_name)
    path = os.path.join(args.outdir, outfile)
    template = templates[tpl_name]
    contents = pystache.render(template, entity, partials=partials)
    with codecs.open(path, 'w', 'utf_8') as f:
      f.write(contents)

def arg_dirname(arg):
  path = os.path.realpath(arg)
  if not os.path.isdir(path):
    msg = '{} does not exist or is not a directory'.format(arg)
    raise argparse.ArgumentTypeError(msg)
  return path

def arg_emptydir(arg):
  path = os.path.realpath(arg)
  if not os.path.isdir(path):
    os.makedirs(path)
  else:
    files = [os.path.join(path, f) for f in os.listdir(path) if os.path.isfile(os.path.join(path, f))]
    for f in files:
      os.remove(f)
  return path

def arg_filename(arg):
  path = os.path.realpath(arg)
  if not os.path.isfile(path):
    msg = '{} does not exist or is not a file'.format(arg)
    raise argparse.ArgumentTypeError(msg)
  return path

if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('--tpldir', type=arg_dirname, default='.')
  parser.add_argument('--outdir', type=arg_emptydir, default='.')
  parser.add_argument('--config', type=arg_filename)
  parser.add_argument('--debug', action='store_true')
  main(parser.parse_args())

