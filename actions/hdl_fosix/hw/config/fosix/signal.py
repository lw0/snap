from collections import defaultdict

from fosix.base import Assert



class Signal():
  def __init__(self, fosix, name, type=None):
    self.fosix = fosix
    self.name = name
    self.fosix.signals.register(self.name, self)
    self._init_type(type)
    self.connections = defaultdict(list)
    self.width = None

  def _init_type(self, type):
    self.type = type
    if self.type is not None:
      if self.type.is_simple():
        self.identifier = 's_{}'.format(self.name)
        self.fosix.identifiers.register(self.identifier, self)
      elif self.type.is_complex():
        self.identifier_ms = 's_{}_ms'.format(self.name)
        self.identifier_sm = 's_{}_sm'.format(self.name)
        self.fosix.identifiers.register(self.identifier_ms, self)
        self.fosix.identifiers.register(self.identifier_sm, self)

  def __str__(self):
    if self.type is None:
      return 's_{}?'.format(self.name)
    else:
      return 's_{}:{}'.format(self.name, self.type)

  def is_a(self, cls):
    return cls == Signal

  def set_width(self, width):
    Assert(self.width is None,
      'Can not redefine width of signal {}'.format(self))
    self.width = width

  def connect_port(self, port):
    if self.type is None:
      self._init_type(port.type.base())
    else:
      Assert(self.type.is_compatible(port.type),
        'Can not connect signal {} to port {} with incompatible type.'.format(self, port))
    role = port.type.role
    self.connections[role].append(port)
    Assert(role.is_input() or len(self.connections[role]) == 1,
      'Signal {} can not be connected to multiple ports of role {}'.format(self, role))

  def has_type(self):
    return self.type is not None

  def has_width(self):
    return self.width is not None

  def is_simple(self):
    return self.type.is_simple()

  def is_complex(self):
    return self.type.is_complex()


