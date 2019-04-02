from fosix import FOSIX

fosix = FOSIX()
Inst = fosix.Instance
Regs = fosix.RegPort
Entity = fosix.Entity

Regs('regExtStore', 0x040, 0x10)
Regs('regSwitch', 0x050, 0x10)

Inst('AxiSplit',
      p_axi='hmem', p_axiRd='hmemRd', p_axiWr='hmemWr')
Inst('AxiSplit',
      p_axi='cmem', p_axiRd='cmemRd', p_axiWr='cmemWr')

Inst('AxiBlockMap',
      p_map='extmapHRd', p_axiLog='hmemRdLog', p_axiPhy='hmemRd')

Inst('AxiBlockMap',
      p_map='extmapHWr', p_axiLog='hmemWrLog', p_axiPhy='hmemWr')

Inst('AxiBlockMap',
      p_map='extmapCRd', p_axiLog='cmemRdLog', p_axiPhy='cmemRd')

Inst('AxiBlockMap',
      p_map='extmapCWr', p_axiLog='cmemWrLog', p_axiPhy='cmemWr')

Inst('ExtentStore',
      p_reg='regExtStore', pl_extmaps=['hmemRd', 'hmemWr', 'cmemRd', 'cmemWr'])

Inst('AxiReader', g_FIFODepth=8,
      p_axiRd='hmemRdLog', p_stm='stmHRd')
Inst('AxiWriter', g_FIFODepth=1,
      p_axiWr='hmemWrLog', p_stm='stmHWr')
Inst('AxiReader', g_FIFODepth=8,
      p_axiRd='cmemRdLog', p_stm='stmCRd')
Inst('AxiWriter', g_FIFODepth=1,
      p_axiWr='cmemWrLog', p_stm='stmCWr')

Inst('StreamSwitch', p_reg='regSwitch',
      pl_stmIn=['stmHRd', 'stmCRd'], pl_stmOut=['stmHWr', 'stmCWr'])

ent = Entity('HLSFilter')
ent.Port('stmIn', FOSIXRole.Slave, 'NativeStream')
ent.Port('stmRef', FOSIXRole.Slave, 'NativeStream')
ent.Port('stmOut', FOSIXRole.Master, 'NativeStream')
ent.Port('regLConst', FOSIXRole.Input, 'RegData')
ent.Port('regRConst', FOSIXRole.Input, 'RegData')
ent.Port('regMode', FOSIXRole.Input, 'RegData')

Inst('HLSFilter', p_stmIn=


