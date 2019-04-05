import re

from fosix.base import Assert,Registry
from fosix.type import Role,Type
from fosix.entity import Port,Generic,Entity
from fosix.signal import Signal



class Environment():
  def __init__(self, fosix):
    self.fosix = fosix
    self.entity_name = '[ENV]'
    self.name = '[ENV]'
    self.instance = self
    self.reg_map = None
    self.ports = Registry()
    self.generics = Registry()
    self.identifiers = Registry()
    self.generic_insts = Registry()
    self.port_insts = Registry()
    self._init_builtin()

  def _init_builtin(self):
    self.g_action_type = Generic(self, 'ActionType').instantiate(self)
    self.g_action_rev = Generic(self, 'ActionRev').instantiate(self)
    self.g_ready_cnt = Generic(self, 'ReadyCount').instantiate(self)
    self.g_reg_cnt = Generic(self, 'RegPortCount').instantiate(self)
    self.p_start = Port(self, 'start', Role.Output, self.fosix.t_logic).instantiate(self)
    self.p_ready = Port(self, 'ready', Role.Input, self.fosix.t_logic, self.g_ready_cnt).instantiate(self)
    self.p_regs = Port(self, 'regPorts', Role.Master, self.fosix.t_regPort, self.g_reg_cnt).instantiate(self)
    self.p_hmem = Port(self, 'hmem', Role.Slave, self.fosix.t_axi).instantiate(self)
    self.p_cmem = Port(self, 'cmem', Role.Slave, self.fosix.t_axi).instantiate(self)
    self.p_nvme = Port(self, 'nvme', Role.Slave, self.fosix.t_ctrl).instantiate(self)

  def __str__(self):
    return '[ENV]'

  def is_a(self, cls):
    return cls == Environment

  def is_instance(self):
    return True

  def regmap(self, ranges, signals):
    Assert(self.reg_map is None, 'Can not redefine register map')
    self.reg_map = []
    reg_set = set()
    for offset,count in ranges:
      Assert(offset%4 == 0,
        'Register address range offset must be a multiple of 4')
      Assert(count%4 == 0,
        'Register address range count must be a multiple of 4')
      for reg_adr in range(offset, offset+count, 4):
        Assert(reg_adr not in reg_set,
          'Overlapping register {} from range [{}+{}]'.format(reg_adr, offset, count))
        reg_set.add(reg_adr)
      self.reg_map.append((offset/4, count/4))
    self.p_regs.connect(signals)

  def assign(self, generic_name, value):
    Assert(self.instance is not None,
      'Can not connect generic {} of non-instantiated entity {}'.format(generic_name, self))
    self.generic_insts.lookup(generic_name).assign(value)

  def connect(self, port_name, to):
    Assert(self.instance is not None,
      'Can not connect port {} of non-instantiated entity {}'.format(port_name, self))
    self.port_insts.lookup(port_name).connect(to)


class FOSIX():

  def __init__(self):
    self.identifiers= Registry()
    self.types = Registry()
    self.entities = Registry()
    self.instances = Registry()
    self.signals = Registry()
    self._init_builtin()
    self._init_entities()

  def _init_builtin(self):
    self.t_logic = Type(self,   'Logic',        Role.Simple)
    self.t_ctrl = Type(self,    'Ctrl',         Role.Complex)
    self.t_axi = Type(self,     'NativeAxi',    Role.Complex)
    self.t_axiRd = Type(self,   'NativeAxiRd',  Role.Complex)
    self.t_axiWr = Type(self,   'NativeAxiWr',  Role.Complex)
    self.t_regPort = Type(self, 'RegPort',      Role.Complex)
    self.t_mapPort = Type(self, 'BlkMap',       Role.Complex)
    self.t_reg = Type(self,     'RegData',      Role.Simple,  unsigned=True, width=32)
    self.t_stm = Type(self,     'NativeStream', Role.Complex, stream=True, datawidth=512)
    self.environment = Environment(self)

  def _init_entities(self):
    self.Entity('AxiSplitter',
      pm_axi='NativeAxi', ps_axiRd='NativeAxiRd', ps_axiWr='NativeAxiWr')
    self.Entity('AxiRdMultiplexer', g_PortCount=None,
      pm_axiRd='NativeAxiRd', ps_axiRd_v=('NativeAxiRd', 'PortCount'))
    self.Entity('AxiWrMultiplexer', g_PortCount=None,
      pm_axiWr='NativeAxiWr', ps_axiWr_v=('NativeAxiWr', 'PortCount'))

    self.Entity('AxiReader', g_FIFODepth=None,
      pi_start='Logic', po_ready='Logic',
      pm_axiRd='NativeAxiRd', pm_stm='NativeStream')
    self.Entity('AxiWriter', g_FIFODepth=None,
      pi_start='Logic', po_ready='Logic',
      pm_axiWr='NativeAxiWr', ps_stm='NativeStream')

    self.Entity('AxiRdBlockMapper',
      pm_map='BlkMap',
      ps_axiLog='NativeAxiRd', pm_axiPhy='NativeAxiRd')
    self.Entity('AxiWrBlockMapper',
      pm_map='BlkMap',
      ps_axiLog='NativeAxiWr', pm_axiPhy='NativeAxiWr')

    self.Entity('ExtentStore', g_PortCount=None,
      ps_reg='RegPort', ps_ports=('BlkMap', 'PortCount'))

    self.Entity('NativeStreamSwitch', g_InPortCount=None, g_OutPortCount=None,
      ps_reg='RegPort',
      ps_stmIn_v=('NativeStream', 'InPortCount'),
      pm_stmOut_v=('NativeStream', 'OutPortCount'),
      x_template='StreamSwitch.vhd', x_outfile='NativeStreamSwitch.vhd', xt_type='NativeStream')
    self.Entity('NativeStreamRouter', g_InPortCount=None, g_OutPortCount=None,
      ps_reg='RegPort',
      ps_stmIn=('NativeStream', 'InPortCount'),
      pm_stmOut=('NativeStream', 'OutPortCount'),
      x_template='StreamRouter.vhd', x_outfile='NativeStreamRouter.vhd', xt_type='NativeStream')

  def identifier_list(self):
    return self.identifiers.keys()

  def type_list(self):
    return self.types.contents()

  def entity_list(self):
    return self.entities.contents()

  def instance_list(self):
    return self.instances.contents()

  def signal_list(self):
    return self.signals.contents()

  def _get_signal(self, name):
    if self.signals.has(name):
      return self.signals.lookup(name)
    return Signal(self, name)

  # g_<name>=None
  # g_<name>=<value>
  GenericPattern = re.compile('g_(\w+)')
  def _resolve_generic(self, key, value):
    m = FOSIX.GenericPattern.match(key)
    if m:
      name = m.group(1)
      return (name, value)
    return None

  # p<role>_<name>='<type_name>'
  # p<role>_<name>=('<type_name>', '<size_generic_name>')
  PortRolePattern = re.compile('p(\w)_(\w+)')
  def _resolve_port_definition(self, key, value):
    m = FOSIX.PortRolePattern.match(key)
    if m:
      role = Role.parse(m.group(1))
      name = m.group(2)
      if isinstance(value, str):
        type = self.types.lookup(value)
        size_generic_name = None
      else:
        type = self.types.lookup(value[0])
        size_generic_name = value[1]
      return (name, type, role, size_generic_name)
    return None

  # p_<name>='<signal_name>'
  # p_<name>=['<signal_name>', ... ]
  PortConnectPattern = re.compile('p_(\w+)')
  def _resolve_port_connect(self, key, value):
    m = FOSIX.PortConnectPattern.match(key)
    if m:
      name = m.group(1)
      if isinstance(value, str):
        to = self._get_signal(value)
      else:
        to = [self._get_signal(signal) for signal in value]
      return (name, to)
    return None

  # x_<name>=<value>
  # xt_<name>='<type_name>'
  PropertyPattern = re.compile('x(t?)_(\w+)')
  def _resolve_property(self, key, value):
    m = FOSIX.PropertyPattern.match(key)
    if m:
      name = m.group(2)
      if m.group(1) == 't':
        value = self.types.lookup(value)
      return (name, value)
    return None


  def Type(self, name, role, **directives):
    props = {}
    for key,value in directives.items():
      res = self._resolve_property(key, value)
      if res is not None:
        props[res[0]] = res[1]
    return Type(self, name, role, **props)

  def Entity(self, name, **directives):
    generics = []
    ports = []
    props = {}
    for key,value in directives.items():
      res = self._resolve_generic(key, value)
      if res is not None:
        generics.append(res[0])
        continue
      res = self._resolve_port_definition(key, value)
      if res is not None:
        ports.append(res)
        continue
      res = self._resolve_property(key, value)
      if res is not None:
        props[res[0]] = res[1]
    entity = Entity(self, name, **props)
    for name in generics:
      entity.generic(name)
    for name,type,role,size_generic_name in ports:
      entity.port(name, type, role, size_generic_name)
    return entity

  def Env(self, *regmap, **directives):
    reg_signals = []
    reg_ranges = []
    for offset,count,signal_name in regmap:
      reg_signals.append(self._get_signal(signal_name))
      reg_ranges.append((offset, count))
    self.environment.regmap(reg_ranges, reg_signals)
    generics = []
    ports = []
    for key,value in directives.items():
      res = self._resolve_generic(key, value)
      if res is not None:
        generics.append(res)
        continue
      res = self._resolve_port_connect(key, value)
      if res is not None:
        ports.append(res)
        continue
    for name,value in generics:
      self.environment.assign(name, value)
    for name,to in ports:
      self.environment.connect(name, to)

  def Inst(self, entity_name, **directives):
    generics = []
    ports = []
    for key,value in directives.items():
      res = self._resolve_generic(key, value)
      if res is not None:
        generics.append(res)
        continue
      res = self._resolve_port_connect(key, value)
      if res is not None:
        ports.append(res)
        continue
    entity = self.entities.lookup(entity_name)
    name = directives.get('name', self.instances.uniqueName(entity_name))
    instance = entity.instantiate(name)
    for name,value in generics:
      instance.assign(name, value)
    for name,to in ports:
      instance.connect(name, to)

  def Signal(self, name, type_name=None):
    type = type_name and self.types.lookup(type_name)
    return Signal(self, name, type)

