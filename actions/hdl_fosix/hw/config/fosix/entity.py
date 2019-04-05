from copy import copy

from fosix.base import Assert,Registry
from fosix.type import Role,Type
from fosix.signal import Signal



class Generic():
  def __init__(self, entity, name):
    self.fosix = entity.fosix
    self.entity = entity
    self.name = name
    self.entity.generics.register(self.name, self)
    self.identifier = 'g_{}'.format(self.name)
    self.entity.identifiers.register(self.identifier, self)
    self.instance = None

  def __str__(self):
    if self.instance is None:
      return '{}.g_{}'.format(self.entity, self.name)
    elif self.value is None:
      return '({}:{}).g_{}'.format(self.instance, self.entity, self.name)
    else:
      return '({}:{}).g_{}={}'.format(self.instance, self.entity, self.name, self.value)

  def is_a(self, cls):
    return cls == Generic

  def is_instance(self):
    return self.instance is not None

  def instantiate(self, instance):
    Assert(self.instance is None,
      'Can not instantiate already instantiated generic {}'.format(self))
    inst = copy(self)
    inst.instance = instance
    inst.value = None
    inst.instance.generic_insts.register(inst.name, inst)
    return inst

  def assign(self, value):
    Assert(self.instance is not None,
      'Can not assign value {} to non-instantiated generic {}'.format(value, self))
    Assert(self.value is None or self.value == value,
      'Can not redefine generic {} to {}'.format(self, value))
    self.value = value


class Port():
  def __init__(self, entity, name, role, type, size_generic=None):
    self.fosix = entity.fosix
    self.entity = entity
    self.name = name
    entity.ports.register(self.name, self)
    Assert(role.is_port(),
      'Can not define port {} with non-port role {}'.format(name, role))
    self.type = type.derive(role)
    self.size_generic = size_generic
    if self.type.is_input():
      self.mode = 'in'
      self.identifier = 'pi_{}'.format(self.name)
      entity.identifiers.register(self.identifier, self)
    elif self.type.is_output():
      self.mode = 'out'
      self.identifier = 'po_{}'.format(self.name)
      entity.identifiers.register(self.identifier, self)
    elif self.type.is_slave():
      self.mode_ms = 'in'
      self.mode_sm = 'out'
      self.identifier_ms = 'pi_{}_ms'.format(self.name)
      self.identifier_sm = 'po_{}_sm'.format(self.name)
      entity.identifiers.register(self.identifier_ms, self)
      entity.identifiers.register(self.identifier_sm, self)
    elif self.type.is_master():
      self.mode_ms = 'out'
      self.mode_sm = 'in'
      self.identifier_ms = 'po_{}_ms'.format(self.name)
      self.identifier_sm = 'pi_{}_sm'.format(self.name)
      entity.identifiers.register(self.identifier_ms, self)
      entity.identifiers.register(self.identifier_sm, self)
    self.instance = None

  def __str__(self):
    if self.instance is None:
      return '{}.p_{}:{}'.format(self.entity, self.name, self.type)
    elif self.connection is None:
      return '({}:{}).p_{}:{}'.format(self.instance, self.entity, self.name, self.type)
    else:
      return '({}:{}).p_{}:{}=>{}'.format(self.instance, self.entity, self.name, self.type, self.connection)

  def is_a(self, cls):
    return cls == Port

  def is_instance(self):
    return self.instance is not None

  def instantiate(self, instance):
    Assert(self.instance is None,
      'Can not instantiate already instantiated port {}'.format(self))
    inst = copy(self)
    inst.instance = instance
    inst.connection = None
    inst.instance.port_insts.register(inst.name, inst)
    inst.size_generic_inst = self.size_generic and instance.generic_insts.lookup(self.size_generic.name)
    # vector ports require an unpack signal
    if inst.is_vector():
      unpack_signal_name = 's_{}_{}'.format(instance.name, inst.name)
      unpack_signal_name = inst.fosix.signals.uniqueName(unpack_signal_name)
      inst.fosix.signals.register(unpack_signal_name, inst)
    return inst

  def connect(self, to):
    Assert(self.instance is not None,
      'Can not connect {} to non-instantiated port {}'.format(to, self))
    Assert(self.connection is None or self.connection == to,
      'Can not reconnect port {} to {}'.format(self, to))
    if self.is_vector():
      # assume <to> is a list of Signal instances
      try:
        for signal in to:
          signal.connect_port(self)
        self.size_generic_inst.assign(len(to))
      except TypeError:
        Assert(False,
          'Vector port {} connection expects a list of Signals'.format(self))
    else:
      # assume <to> is a single Signal instance
      Assert(to.is_a(Signal),
        'Scalar port {} connection expects a single Signal'.format(self))
      to.connect_port(self)
    self.connection = to

  def is_input(self):
    return self.type.is_input()

  def is_output(self):
    return self.type.is_output()

  def is_simple(self):
    return self.type.is_simple()

  def is_slave(self):
    return self.type.is_slave()

  def is_master(self):
    return self.type.is_master()

  def is_complex(self):
    return self.type.is_complex()

  def is_scalar(self):
    return self.size_generic is None

  def is_vector(self):
    return self.size_generic is not None


class Entity():
  def __init__(self, fosix, name, **props):
    self.fosix = fosix
    self.name = name
    self.fosix.entities.register(self.name, self)
    self.props = props
    self.ports = Registry()
    self.generics = Registry()
    self.identifiers = Registry()
    self.instance = None

  def __str__(self):
    if self.instance is None:
      return self.name
    else:
      return 'i_{}:{}'.format(self.name, self.entity_name)

  def is_a(self, cls):
    return cls == Entity

  def is_instance(self):
    return self.instance is not None

  def generic(self, name):
    return Generic(self, name)

  def port(self, name, type, role, size_generic_name=None):
    size_generic = size_generic_name and self.generics.lookup(size_generic_name)
    return Port(self, name, role, type, size_generic)

  def instantiate(self, name):
    inst = copy(self)
    inst.entity_name = self.name
    inst.name = name
    inst.instance = self
    inst.generic_insts = Registry()
    inst.port_insts = Registry()
    for generic in self.generics.contents():
      generic.instantiate(inst)
    for port in self.ports.contents():
      port.instantiate(inst)
    return inst

  def port_list(self):
    if self.instance is None:
      return self.ports.values()
    else:
      return self.port_insts.values()

  def generic_list(self):
    if self.instance is None:
      return self.generics.values()
    else:
      return self.generic_insts.values()

  def assign(self, generic_name, value):
    Assert(self.instance is not None,
      'Can not connect generic {} of non-instantiated entity {}'.format(generic_name, self))
    self.generic_insts.lookup(generic_name).assign(value)

  def connect(self, port_name, to):
    Assert(self.instance is not None,
      'Can not connect port {} of non-instantiated entity {}'.format(port_name, self))
    self.port_insts.lookup(port_name).connect(to)

