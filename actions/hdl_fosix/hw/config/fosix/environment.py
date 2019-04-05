from fosix.base import Assert
from fosix.entity import Port



class Environment():
  def __init__(self, fosix):
    self.fosix = fosix
    fosix.entities.register(self.name, self)
    self.ports = Registry()

  def __str__(self):
    return '[ENV]'

  def is_a(self, cls):
    return cls == Environment

  def Generic(self, name):
    return Generic(self, name)

  def Port(self, name, type_name, role, size_generic_name=None):
    type = self.fosix.types.lookup(type_name)
    size_generic = size_generic_name and self.generics.lookup(size_generic_name)
    Assert(not role.is_vector() or size_generic is not None,
      'Vector port {} requires a size generic'.format(name))
    return Port(self, name, role, type, size_generic)


    self.value = value

  def is_complete(self):
    return self.value is not None



