import argparse
import codecs
import glob
import os
import pystache
import sys
import traceback

from fosix import FOSIXError, Role, FOSIX

global_templates = [
  'Action.vhd',
  'fosix_user.vhd' ]

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

  fosix = FOSIX()
  globals = {
    'Role':   Role,
    'Typ': fosix.Type,
    'Ent': fosix.Entity,
    'Env': fosix.Env,
    'Ins': fosix.Inst,
    'Sig': fosix.Signal }
  exec(script, globals)
  # try:
  #   exec(script, globals)
  # except FOSIXError:
  #   e_type,e_msg,e_tb = sys.exc_info()
  #   e_trace = traceback.extract_tb(e_tb)
  #   print('FOSIXError: {}'.format(e_msg), file=sys.stderr)
  #   print(' at [{}:{}] "{}"'.format(os.path.relpath(e_trace[1][0]), e_trace[1][1], e_trace[1][3]), file=sys.stderr)
  #   sys.exit(1)

  if args.debug:
    import pdb; pdb.set_trace()

  for tpl_name in global_templates:
    path = os.path.join(args.outdir, tpl_name)
    template = templates[tpl_name]
    contents = pystache.render(template, fosix, partials=partials)
    with codecs.open(path, 'w', 'utf_8') as f:
      f.write(contents)

  for entity in fosix.entities.contents():
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

def arg_filename(arg):
  path = os.path.realpath(arg)
  if not os.path.isfile(path):
    msg = '{} does not exist or is not a file'.format(arg)
    raise argparse.ArgumentTypeError(msg)
  return path

if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('--tpldir', type=arg_dirname, default='.')
  parser.add_argument('--outdir', type=arg_dirname, default='.')
  parser.add_argument('--config', type=arg_filename)
  parser.add_argument('--debug', action='store_true')
  main(parser.parse_args())

