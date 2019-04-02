from enum import Enum


class FOSIXError(Exception):
  def __init__(self, msg):
    self.msg = msg

def FOSIXAssert(condition, msg):
  if not condition:
    raise FOSIXError(msg)

class FOSIXRegistry():
  def __init__(self):
    self.map = {}
    self.idx_cache = {}

  def register(self, name, obj):
    FOSIXAssert(name not in self.map, 'Name collision: "{}" is already defined'.format(name))
    self.map[name] = obj

  def lookup(self, name):
    FOSIXAssert(name in self.map, 'Unresolved reference: "{}" is not defined'.format(name))
    return self.map[name]

  def has(self, name):
    return name in self.map

  def contents(self):
    return self.map.items()

  def uniqueName(self, prefix):
    idx = self.idx_cache.get(prefix, 0)
    while '{}{:d}'.format(prefix, idx) in self.map:
      idx += 1
    self.idx_cache[prefix] = idx
    return '{}{:d}'.format(prefix, idx)


class FOSIXRole(Enum):
  Input      = 0x1  # Port
  Output     = 0x2  # Port
  Simple     = 0x3  #      Signal, Type
  Slave      = 0x4  # Port
  Master     = 0x8  # Port
  Complex    = 0xc  #      Signal, Type
  VecInput   = 0x10 # Port
  VecOutput  = 0x11 # Port
  VecSimple  = 0x13 #      Signal
  VecSlave   = 0x14 # Port
  VecMaster  = 0x18 # Port
  VecComplex = 0x1c #      Signal

  def is_type_role(self):
    return self.value in (0x3, 0xc)

  def to_type_role(self):
    if self.value in (0x1, 0x2, 0x3, 0x11, 0x12, 0x13):
      return FOSIXRole(0x3)
    else: # self.value in (0x4, 0x8, 0xc, 0x14, 0x18, 0x1c):
      return FOSIXRole(0xc)

  def is_signal_role(self):
    return self.value in (0x3, 0xc, 0x13, 0x1c)

  def to_signal_role(self):
    if self.value in (0x1, 0x2, 0x3):
      return FOSIXRole(0x3)
    elif self.value in (0x11, 0x12, 0x13):
      return FOSIXRole(0x13)
    elif self.value in (0x4, 0x8, 0xc):
      return FOSIXRole(0xc)
    else: # self.value in (0x14, 0x18, 0x1c):
      return FOSIXRole(0x1c)

  def is_port_role(self):
    return self.value in (0x1, 0x2, 0x4, 0x8, 0x11, 0x12, 0x14, 0x18)

  def is_simple(self):
    return (self.value & 0xf) in (0x1, 0x2, 0x3)

  def is_complex(self):
    return (self.value & 0xf) in (0x4, 0x8, 0xc)

  def is_scalar(self):
    return (self.value & 0x10) == 0x0

  def is_vector(self):
    return (self.value & 0x10) == 0x10

  def is_input(self):
    return self.value in (0x1, 0x11)

  def is_output(self):
    return self.value in (0x2, 0x12)

  def is_slave(self):
    return self.value in (0x8, 0x18)

  def is_master(self):
    return self.value in (0x4, 0x14)

  def is_compatible(self, other):
    if (self.value & 0x10) != (other.value & 0x10):
      return False
    sval = self.value & 0xf
    oval = other.value & 0xf
    if sval == 0x1:
      return oval in (0x1, 0x3)
    elif sval == 0x2:
      return oval in (0x2, 0x3)
    elif sval == 0x3:
      return oval in (0x1, 0x2, 0x3)
    if sval == 0x4:
      return oval in (0x4, 0xc)
    elif sval == 0x8:
      return oval in (0x8, 0xc)
    elif sval == 0xc:
      return oval in (0x4, 0x8, 0xc)
    return False

  def to_opposite(self):
    vecmask = self.value & 0x10
    val = self.value & 0xf
    if val == 0x1:
      return FOSIXRole(0x2 | vecmask)
    elif val == 0x2:
      return FOSIXRole(0x1 | vecmask)
    elif val == 0x3:
      return FOSIXRole(0x3 | vecmask)
    if val == 0x4:
      return FOSIXRole(0x8 | vecmask)
    elif val == 0x8:
      return FOSIXRole(0x4 | vecmask)
    elif val == 0xc:
      return FOSIXRole(0xc | vecmask)
    return False

  def to_scalar(self):
    return FOSIXRole(self.value & 0xf)

  def to_vector(self):
    return FOSIXRole(self.value | 0x10)


class FOSIXType():
  def __init__(self, fosix, name, role):
    self.fosix = fosix
    FOSIXAssert(role.is_type_role(), 'Can not define type {} with role {}'.format(name, role))
    self.role = role
    self.name = name
    self.fosix.types.register(self.name, self)
    if self.role.is_simple():
      self.scalar_identifier = 't_{}'.format(self.name)
      self.vector_identifier = 't_{}_v'.format(self.name)
      self.fosix.identifiers.register(self.scalar_identifier, self)
      self.fosix.identifiers.register(self.vector_identifier, self)
    elif self.role == FOSIXRole.Complex:
      self.scalar_identifier_ms = 't_{}_ms'.format(self.name)
      self.scalar_identifier_sm = 't_{}_sm'.format(self.name)
      self.vector_identifier_ms = 't_{}_v_ms'.format(self.name)
      self.vector_identifier_sm = 't_{}_v_sm'.format(self.name)
      self.fosix.identifiers.register(self.scalar_identifier_ms, self)
      self.fosix.identifiers.register(self.scalar_identifier_sm, self)
      self.fosix.identifiers.register(self.vector_identifier_ms, self)
      self.fosix.identifiers.register(self.vector_identifier_sm, self)

  def is_simple(self):
    return self.role.is_simple()

  def is_complex(self):
    return self.role.is_complex()

  def is_compatible(self, role):
    return self.role.is_compatible(role.to_scalar())


class FOSIXUserSimpleType():
  def __init__(self, fosix, name, width):
    self.fosix = fosix
    self.name = name
    self.width = width
    self.type = FOSIXType(self.fosix, self.name, FOSIXRole.Simple)

class FOSIXUserStreamType():
  def __init__(self, fosix, name, datawidth):
    self.fosix = fosix
    self.name = name
    self.datawidth = datawidth
    self.type = FOSIXType(self.fosix, self.name, FOSIXRole.Complex)

  # class FOSIXAxi():
#   def __init__(self, fosix, name, datawidth, addrwidth, idwidth, no_burst, no_attrib):
#     self.fosix = fosix
#     self.name = name
#     self.nameRd = '{}Rd'.format(name)
#     self.nameWr = '{}Wr'.format(name)
#     self.nameData = '{}Data'.format(name)
#     self.nameAddr = '{}Addr'.format(name)
#     self.datawidth = datawidth
#     self.addrwidth = addrwidth
#     self.idwidth = idwidth
#     self.no_burst = no_burst
#     self.no_attrib = no_attrib
#     self.type = ComplexType(self.fosix, self.name)
#     self.typeRd = ComplexType(self.fosix, self.nameRd)
#     self.typeWr = ComplexType(self.fosix, self.nameWr)
#     self.typeData = SimpleType(self.fosix, self.nameData)
#     self.typeAddr = SimpleType(self.fosix, self.nameAddr)

class FOSIXGeneric():
  def __init__(self, entity, name):
    self.fosix = entity.fosix
    self.entity = entity
    self.name = name
    entity.generics.register(self.name, self)
    self.identifier = 'g_{}'.format(self.name)
    entity.identifiers.register(self.identifier, self)


class FOSIXPort():
  def __init__(self, entity, name, role, type, size_generic=None):
    self.fosix = entity.fosix
    self.entity = entity
    self.name = name
    entity.ports.register(self.name, self)
    FOSIXAssert(role.is_port_role(),
      'Can not define port {} with role {}'.format(name, role))
    self.role = role
    FOSIXAssert(type.is_compatible(role),
      'Assigning incompatible role {} to port {} of type {}'.format(role, name, type.name))
    self.type = type
    FOSIXAssert(not role.is_vector() or size_generic is not None,
      'Vector port {} requires a size generic'.format(name))
    self.size_generic = size_generic
    scalar_role = self.role.to_scalar()
    if scalar_role == FOSIXRole.Input:
      self.identifier = 'pi_{}'.format(self.name)
      entity.identifiers.register(self.identifier, self)
    elif scalar_role == FOSIXRole.Output:
      self.identifier = 'po_{}'.format(self.name)
      entity.identifiers.register(self.identifier, self)
    if scalar_role == FOSIXRole.Master:
      self.identifier_ms = 'po_{}_ms'.format(self.name)
      self.identifier_sm = 'pi_{}_sm'.format(self.name)
      entity.identifiers.register(self.identifier_ms, self)
      entity.identifiers.register(self.identifier_sm, self)
    elif scalar_role == FOSIXRole.Slave:
      self.identifier_ms = 'pi_{}_ms'.format(self.name)
      self.identifier_sm = 'po_{}_sm'.format(self.name)
      entity.identifiers.register(self.identifier_ms, self)
      entity.identifiers.register(self.identifier_sm, self)

  def is_simple(self):
    return self.role.is_simple()

  def is_complex(self):
    return self.role.is_complex()

  def is_scalar(self):
    return self.role.is_scalar()

  def is_vector(self):
    return self.role.is_vector()


class FOSIXEntity():
  def __init__(self, fosix, name):
    self.fosix = fosix
    self.name = name
    self.ports = FOSIXRegistry()
    self.generics = FOSIXRegistry()
    self.identifiers = FOSIXRegistry()

  def Generic(self, name):
    return FOSIXGeneric(self, name)

  def Port(self, name, role, type_name, size_generic_name=None):
    type = self.fosix.types.lookup(type_name)
    size_generic = size_generic_name and self.generics.lookup(size_generic_name)
    FOSIXAssert(not role.is_vector() or size_generic is not None,
      'Vector port {} requires a size generic'.format(name))
    return FOSIXPort(self, name, role, type, size_generic)



class FOSIXEnvironment():
  def __init__(self, fosix, name):
    self.fosix = fosix
    self.name = name
    fosix.entities.register(self.name, self)
    self.ports = FOSIXRegistry()

  def Generic(self, name):
    return FOSIXGeneric(self, name)

  def Port(self, name, type_name, role, size_generic_name=None):
    type = self.fosix.types.lookup(type_name)
    size_generic = size_generic_name and self.generics.lookup(size_generic_name)
    FOSIXAssert(not role.is_vector() or size_generic is not None,
      'Vector port {} requires a size generic'.format(name))
    return FOSIXPort(self, name, role, type, size_generic)


    self.value = value

  def is_complete(self):
    return self.value is not None

class FOSIXEntity():
  def __init__(self, fosix, name):
    self.fosix = fosix
    self.name = name
    fosix.entities.register(self.name, self)
    self.ports = FOSIXRegistry()
    self.generics = FOSIXRegistry()
    self.identifiers = FOSIXRegistry()

  def Generic(self, name):
    return FOSIXGeneric(self, name)

  def Port(self, name, type_name, role, size_generic_name=None):
    type = self.fosix.types.lookup(type_name)
    size_generic = size_generic_name and self.generics.lookup(size_generic_name)
    FOSIXAssert(not role.is_vector() or size_generic is not None,
      'Vector port {} requires a size generic'.format(name))
    return FOSIXPort(self, name, role, type, size_generic)


    self.value = value

  def is_complete(self):
    return self.value is not None


class FOSIXTemplateEntity(FOSIXEntity):
  def __init__(self, fosix, name, type, template_name):
    FOSIXEntity.__init__(self, fosix, name)
    self.template_name = template_name
    self.type = type


class FOSIXGenericInst():
  def __init__(self, instance, generic):
    self.fosix = instance.fosix
    self.entity = instance.entity
    self.instance = instance
    self.generic = generic

    self.value = None
    instance.generic_insts.register(port.name, self)

  def assign(self, value):
    FOSIXAssert(self.value is None or self.value == value,
      'Generic {} of value {} can not be redefined to {}'.format(self.generic.name, self.value, value))

class FOSIXPortInst():
  def __init__(self, instance, port):
    self.fosix = instance.fosix
    self.instance = instance
    self.port = port
    self.size_generic_inst = port.size_generic and instance.generic_insts.lookup(port.size_generic.name)

    self.connection = None
    instance.port_insts.register(port.name, self)

  def connect_signal(self, signal):
    FOSIXAssert(self.connection is None,
      'Port {} is already assigned to {}'.format(self.port.name, self.connection))
    signal.connect_port(self)
    self.connection = signal

  def connect_signals(self, signals):
    FOSIXAssert(self.connection is None,
      'Port {} is already assigned to {}'.format(self.port.name, self.connection.name))
    FOSIXAssert(self.port.role.is_vector(), 'Type must be vector to assign signal list')
    self.connection = []
    for signal in signals:
      signal.connect_port(self, self.port.role.to_scalar())
      self.connection.append(signal)
    if self.size_generic_inst is not None:
      self.size_generic_inst.assign(len(signals))

  def is_complete(self):
    return self.connection is not None



class FOSIXInstance():
  def __init__(self, entity, name):
    self.fosix = entity.fosix
    self.entity = entity
    self.name = name
    self.fosix.instances.register(self.name, self)
    self.generic_insts = FOSIXRegistry()
    self.port_insts = FOSIXRegistry()
    for gname,generic in entity.generics.contents():
      FOSIXGenericInst(self, generic)
    for pname,port in entity.ports.contents():
      FOSIXPortInst(self, port)
    self.identifier = 'i_{}'.format(name)
    self.fosix.identifiers.register(self.identifier, self)

  def is_complete(self):
    for gname,generic in self.generic_insts.contents():
      if not generic.is_complete():
        return False
    for pname,port in self.generic_insts.contents():
      if not port.is_complete():
        return False
    return True




class FOSIXSignal():
  def __init__(self, fosix, name, type=None, role=None):
    self.fosix = fosix
    self.name = name
    fosix.signals.register(self.name, self)
    self.identifier = 's_{}'.format(self.name)
    fosix.identifiers.register(self.identifier, self)
    self.type = type
    self.role = role or (type and type.role)
    self.connections = {}

  def connect_port(self, port_inst, role=None):
    port = port_inst.port
    role = role or port.role
    if self.type is None:
      self.type = port.type
      self.role = role.to_signal_role()
    else:
      FOSIXAssert(self.type == port.type,
        'Attaching port {} with incompatible type {} to signal {} of type {}'.format(port.name, port.type.name, self.name, self.type.name))
      FOSIXAssert(self.role.is_compatible(role),
        'Attaching port {} with incompatible role {} to signal {} of role {}'.format(port.name, role, self.name, self.role))
    port_list = self.connections.get(role, [])
    port_list.append(port_inst)
    FOSIXAssert(role.is_input() or len(port_list) == 1,
      'Signal {} can not be to multiple ports of role {}'.format(self.name, role))
    self.connections[role] = port_list


class FOSIX():
  def __init__(self):
    self.fosix = fosix
    self.ports = FOSIXRegistry() # acting as environment
    self.types = FOSIXRegistry()
    self.identifiers= FOSIXRegistry()
    self.user_stream_types = FOSIXRegistry()
    self.user_simple_types = FOSIXRegistry()
    self.entities = FOSIXRegistry()
    self.instances = FOSIXRegistry()
    self.signals = FOSIXRegistry()
    self.register_map = []
    self._init_builtin()

  def _init_builtin(self):
    FOSIXType(self, 'Logic',        FOSIXRole.Simple)
    FOSIXType(self, 'NativeAxi',    FOSIXRole.Complex)
    FOSIXType(self, 'NativeAxiRd',  FOSIXRole.Complex)
    FOSIXType(self, 'NativeAxiWr',  FOSIXRole.Complex)
    FOSIXType(self, 'RegPort',      FOSIXRole.Complex)
    FOSIXType(self, 'BlkMap',       FOSIXRole.Complex)
    self.SimpleType('RegData',      32)
    self.StreamType('NativeStream', 512)
    FOSIXPort(self, 'hmem',     FOSIXRole.Slave,    'NativeAxi')
    FOSIXPort(self, 'cmem',     FOSIXRole.Slave,    'NativeAxi')
    FOSIXPort(self, 'nvme',     FOSIXRole.Slave,    'NativeAxi')
    ent = self.Entity('AxiRdMultiplexer')
    ent.Generic('PortCount')
    ent.Port(       'axi',      FOSIXRole.Master,   'NativeAxiRd')
    ent.Port(       'axi_v',    FOSIXRole.VecSlave, 'NativeAxiRd', 'PortCount')
    ent = self.Entity('AxiWrMultiplexer')
    ent.Generic('PortCount')
    ent.Port(       'axi',      FOSIXRole.Master,   'NativeAxiWr')
    ent.Port(       'axi_v',    FOSIXRole.VecSlave, 'NativeAxiWr', 'PortCount')
    ent = self.Entity('AxiReader')
    ent.Port(       'axiRd',    FOSIXRole.Master,   'NativeAxiRd')
    ent.Port(       'stm',      FOSIXRole.Master,   'NativeStream')
    ent = self.Entity('AxiWriter')
    ent.Port(       'axiWr',    FOSIXRole.Master,   'NativeAxiWr')
    ent.Port(       'stm',      FOSIXRole.Slave,    'NativeStream')
    ent = self.Entity('AxiRdBlockMapper')
    ent.Port(       'axiLog',   FOSIXRole.Slave,    'NativeAxiRd')
    ent.Port(       'axiPhy',   FOSIXRole.Master,   'NativeAxiRd')
    ent.Port(       'map',      FOSIXRole.Master,   'BlkMap')
    ent = self.Entity('AxiWrBlockMapper')
    ent.Port(       'axiLog',   FOSIXRole.Slave,    'NativeAxiWr')
    ent.Port(       'axiPhy',   FOSIXRole.Master,   'NativeAxiWr')
    ent.Port(       'map',      FOSIXRole.Master,   'BlkMap')
    ent = self.Entity('AxiSplitter')
    ent.Port(       'axi',      FOSIXRole.Master,   'NativeAxi')
    ent.Port(       'axiRd',    FOSIXRole.Slave,    'NativeAxiRd')
    ent.Port(       'axiWr',    FOSIXRole.Slave,    'NativeAxiWr')
    ent = self.Entity('ExtentStore')
    ent.Port(       'reg',      FOSIXRole.Slave,    'RegPort')
    ent.Port(       'extmaps',    FOSIXRole.VecSlave, 'BlkMap', 'PortCount')
    ent = self.Entity('StreamSwitch')
    ent.Port(       'reg',      FOSIXRole.Slave,    'RegPort')
    ent.Port(       'stmIn',  FOSIXRole.VecSlave, 'NativeStream', 'InPortCount')
    ent.Port(       'stmOut', FOSIXRole.VecMaster, 'NativeStream', 'OutPortCount')
    ent = self.Entity('StreamRouter')
    ent.Port(       'reg',      FOSIXRole.Slave,    'RegPort')
    ent.Port(       'stmIn',  FOSIXRole.VecSlave, 'NativeStream', 'InPortCount')
    ent.Port(       'stmOut', FOSIXRole.VecMaster, 'NativeStream', 'OutPortCount')

  def get_signal(self, name):
    if self.signals.has(name):
      return self.signals.lookup(name)
    return FOSIXSignal(self, name)

  def SimpleType(self, type_name, width):
    return FOSIXUserSimpleType(self, type_name, width)

  def StreamType(self, type_name, datawidth):
    return FOSIXUserStreamType(self, type_name, datawidth)

  def Signal(self, name, type_name=None, role=None):
    type = type_name and self.types.lookup(type_name)
    return FOSIXSignal(self, name, type, role)

  def Entity(self, name):
    return FOSIXEntity(self, name)

  def TemplateEntity(self, name, type_name, template_name):
    type = self.types.lookup(type_name)
    return FOSIXTemplateEntity(self, name, type, template_name)

  def Instance(self, entity_name, **directives):
    entity = self.entities.lookup(entity_name)
    name = directives.get('name', self.instances.uniqueName(entity_name))
    instance = FOSIXInstance(entity, name)
    for key, value in directives.items():
      if key.startswith('g_'):
        generic_name = key[2:]
        instance.generic_insts.lookup(generic_name).assign(value)
      if key.startswith('p_'): # Map port to a single signal
        port_name = key[2:]
        port_inst = instance.port_insts.lookup(port_name)
        signal = self.get_signal(value)
        port_inst.connect_signal(signal)
      if key.startswith('pl_'): # Map port to a list of signals
        port_name = key[3:]
        port_inst = instance.port_insts.lookup(port_name)
        signals = [self.get_signal(sig_name) for sig_name in value]
        port_inst.connect_signals(signals)
    FOSIXAssert(instance.is_complete(), 'Incomplete definition of instance {} entity {}'.format(name, entity_name))




