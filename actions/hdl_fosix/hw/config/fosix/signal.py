from collections import defaultdict

from fosix.base import Assert



class Signal():
  def __init__(self, fosix, name, type=None):
    self.fosix = fosix
    self.name = name
    self.fosix.signals.register(self.name, self)
    self.identifier = 's_{}'.format(self.name)
    self.fosix.identifiers.register(self.identifier, self)
    self.type = type
    self.connections = defaultdict(list)

  def __str__(self):
    if self.type is None:
      return 's_{}?'.format(self.name)
    else:
      return 's_{}:{}'.format(self.name, self.type)

  def is_a(self, cls):
    return cls == Signal

  def connect_port(self, port):
    if self.type is None:
      self.type = port.type.base()
    else:
      Assert(self.type.is_compatible(port.type),
        'Can not connect signal {} to port {} with incompatible type.'.format(self, port))
    role = port.type.role
    self.connections[role].append(port)
    Assert(role.is_input() or len(self.connections[role]) == 1,
      'Signal {} can not be connected to multiple ports of role {}'.format(self, role))


