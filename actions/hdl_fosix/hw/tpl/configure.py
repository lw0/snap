import argparse
import glob
import os
import pystache

print(__file__, '   |   ', os.path.realpath(__file__))


# def main(args):
#   template_paths = glob.glob(os.path.join(args.indir, args.templates), recursive=True)
#   templates = {}
#   for path in template_paths:
#     name = os.path.basename(path)
#     if name[-len(args.suffix)] == args.suffix:
#       name = name[:-len(args.suffix)]
#     with open(path, 'r') as f:
#       templates[name] = pystache.parse(f.read())

#   partial_paths = glob.glob(os.path.join(args.indir, args.partials), recursive=True)
#   partials = {}
#   for path in partial_paths:
#     name = os.path.basename(path)
#     if name[-len(args.suffix)] == args.suffix:
#       name = name[:-len(args.suffix)]
#     with open(path, 'r') as f:
#       partials[name] = pystache.parse(f.read())

#   fosix 
#   globals = {}
#   globals['F'] = fosix.Fosix()




# def arg_dirname(arg):
#   path = os.path.realpath(arg)
#   if not os.path.isdir(path):
#     msg = '{} does not exist or is not a directory'.format(arg)
#     raise argparse.ArgumentTypeError(msg)
#   return path

# if __name__ == "__main__":
#   parser = argparse.ArgumentParser()
#   parser.add_argument('--indir', type=arg_dirname, default='.')
#   parser.add_argument('--outdir', type=arg_dirname, default='.')
#   parser.add_argument('--config', type=argparse.FileType('r'))
#   parser.add_argument('--templates', nargs='*', default='**/*.vhd.tpl')
#   parser.add_argument('--partials', nargs='*', default='**/*.part.tpl')
#   parser.add_argument('--suffix', default='.tpl')
#   main(parser.parse_args())



