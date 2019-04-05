from collections import OrderedDict



class FOSIXError(Exception):
  def __init__(self, msg):
    self.msg = msg

def Assert(condition, msg):
  if not condition:
    raise FOSIXError(msg)

class Registry():
  def __init__(self):
    self.map = OrderedDict()
    self.idx_cache = {}

  def __getitem__(self, key):
    return self.map.get(key, None)

  def register(self, name, obj):
    Assert(name not in self.map, 'Name collision: "{}" is already defined'.format(name))
    self.map[name] = obj

  def lookup(self, name):
    Assert(name in self.map, 'Unresolved reference: "{}" is not defined'.format(name))
    return self.map[name]

  def has(self, name):
    return name in self.map

  def keys(self):
    return self.map.keys()

  def contents(self):
    return self.map.values()

  def uniqueName(self, prefix):
    idx = self.idx_cache.get(prefix, 0)
    while '{}{:d}'.format(prefix, idx) in self.map:
      idx += 1
    self.idx_cache[prefix] = idx
    return '{}{:d}'.format(prefix, idx)


