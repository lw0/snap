from collections import OrderedDict



class FOSIXError(Exception):
  def __init__(self, msg):
    self.msg = msg


def Assert(condition, msg):
  if not condition:
    raise FOSIXError(msg)


class IndexedObj():
  def __init__(self, obj, idx, len):
    self._obj = obj
    self._idx = idx
    self._len = len

  def __getattr__(self, key):
    try:
      return self._obj[key]
    except TypeError:
      pass
    except KeyError:
      pass
    return getattr(self._obj, key)

  def _last(self):
    return self._idx == (self._len - 1)

  def _first(self):
    return self._idx == 0


class IndexWrapper():
  def __init__(self, lst):
    self._iter = iter(lst)
    self._lst = lst
    self._idx = 0

  def __iter__(self):
    return self

  def __next__(self):
    item = IndexedObj(next(self._iter), self._idx, len(self._lst))
    self._idx += 1
    return item

  def _len(self):
    return len(self._lst)


class Registry():
  def __init__(self):
    self.map = OrderedDict()
    self.idx_cache = {}

  def __iter__(self):
    return IndexWrapper(self.map.values())

  def __len__(self):
    return len(self.map)

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


