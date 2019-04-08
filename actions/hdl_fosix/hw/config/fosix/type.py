from copy import copy
from enum import Enum

from fosix.base import Assert



class Role(Enum):
  Input      = 0x1  # Port
  Output     = 0x2  # Port
  Simple     = 0x3  #      Signal
  Slave      = 0x4  # Port
  Master     = 0x8  # Port
  Complex    = 0xc  #      Signal

  @staticmethod
  def parse(string):
    if string == 'i':
      return Role.Input
    elif string == 'o':
      return Role.Output
    elif string == 'io':
      return Role.Simple
    elif string == 's':
      return Role.Slave
    elif string == 'm':
      return Role.Master
    elif string == 'sm':
      return Role.Complex
    Assert(False, '"{}" is not a role identifier'.format(string))

  def __str__(self):
    if self.value == 0x1:
      return 'i'
    elif self.value == 0x2:
      return 'o'
    elif self.value == 0x3:
      return 'io'
    elif self.value == 0x4:
      return 's'
    elif self.value == 0x8:
      return 'm'
    elif self.value == 0xc:
      return 'sm'
    return '!'

  def is_a(self, cls):
    return cls == Role

  def is_signal(self):
    return self.value in (0x3, 0xc)

  def is_port(self):
    return self.value in (0x1, 0x2, 0x4, 0x8)

  def is_input(self):
    return self.value == 0x1

  def is_output(self):
    return self.value == 0x2

  def is_simple(self):
    return self.value in (0x1, 0x2, 0x3)

  def is_slave(self):
    return self.value == 0x4

  def is_master(self):
    return self.value == 0x8

  def is_complex(self):
    return self.value in (0x4, 0x8, 0xc)

  def is_compatible(self, other):
    if self.value == 0x1:
      return other.value in (0x1, 0x3)
    elif self.value == 0x2:
      return other.value in (0x2, 0x3)
    elif self.value == 0x3:
      return other.value in (0x1, 0x2, 0x3)
    elif self.value == 0x4:
      return other.value in (0x4, 0xc)
    elif self.value == 0x8:
      return other.value in (0x8, 0xc)
    elif self.value == 0xc:
      return other.value in (0x4, 0x8, 0xc)
    return False


class Type():
  def __init__(self, fosix, name, role, **props):
    self.fosix = fosix
    self.name = name
    Assert(role.is_signal(),
      'Can not define type {} with port role {}'.format(name, role))
    self.role = role
    self.fosix.types.register(self.name, self)
    self.props = props
    if self.role.is_simple():
      self.identifier = 't_{}'.format(self.name)
      self.identifier_v = 't_{}_v'.format(self.name)
      self.fosix.identifiers.register(self.identifier, self)
      self.fosix.identifiers.register(self.identifier_v, self)
    elif self.role.is_complex():
      self.identifier_ms = 't_{}_ms'.format(self.name)
      self.identifier_sm = 't_{}_sm'.format(self.name)
      self.identifier_v_ms = 't_{}_v_ms'.format(self.name)
      self.identifier_v_sm = 't_{}_v_sm'.format(self.name)
      self.const_null_ms = 'c_{}Null_ms'.format(self.name)
      self.const_null_sm = 'c_{}Null_sm'.format(self.name)
      self.fosix.identifiers.register(self.identifier_ms, self)
      self.fosix.identifiers.register(self.identifier_sm, self)
      self.fosix.identifiers.register(self.identifier_v_ms, self)
      self.fosix.identifiers.register(self.identifier_v_sm, self)
      self.fosix.identifiers.register(self.const_null_ms, self)
      self.fosix.identifiers.register(self.const_null_sm, self)
    self.derived_from = None
    self.derivates = {self.role: self}

  def __str__(self):
    return 't{}_{}'.format(self.role, self.name)

  def __getattr__(self, key):
    if key.startswith('x_') and key[2:] in self.props:
      return self.props[key[2:]]
    else:
      raise AttributeError(key)

  def is_a(self, cls):
    return cls == Type

  def derive(self, role):
    Assert(self.derived_from is None,
      'Can not derive from already derived type {}'.format(self))
    Assert(self.role.is_compatible(role),
      'Can not derive incompatible role {} from type {}'.format(role, self))
    if role in self.derivates:
      return self.derivates[role]
    derivate = copy(self)
    derivate.role = role
    derivate.derived_from = self
    self.derivates[role] = derivate
    return derivate

  def base(self):
    if self.derived_from is None:
      return self
    return self.derived_from

  def is_signal(self):
    return self.role.is_signal()

  def is_port(self):
    return self.role.is_port()

  def is_input(self):
    return self.role.is_input()

  def is_output(self):
    return self.role.is_output()

  def is_simple(self):
    return self.role.is_simple()

  def is_slave(self):
    return self.role.is_slave()

  def is_master(self):
    return self.role.is_master()

  def is_complex(self):
    return self.role.is_complex()

  def is_compatible(self, other):
    if self.name != other.name:
      return False
    return self.role.is_compatible(other.role)

