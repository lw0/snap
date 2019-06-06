# Reference Design for Performance Measurement
Env((0x040, 0x08, 'regsSwitch'),   # 2  Registers
    (0x050, 0x04, 'regsSource'),   # 1  Register
    (0x060, 0x04, 'regsSink'),     # 1  Register
    (0x080, 0x10, 'regsHRd'),      # 4  Registers
    (0x090, 0x10, 'regsHWr'),      # 4  Registers
    (0x0A0, 0x10, 'regsCRd'),      # 4  Registers
    (0x0B0, 0x10, 'regsCWr'),      # 4  Registers
    (0x0C0, 0x40, 'regsExtStore'), # 16 Registers
    (0x100, 0xA0, 'regsMon'),      # 40 Registers
    g_ActionType=0x6c, g_ActionRev=0x1,
    p_start='start', p_ready=['readyHRd', 'readyHWr', 'readyCRd', 'readyCWr', 'readySrc', 'readySnk'],
    p_int1='intExtStore',
    p_hmem='hmem', p_cmem='cmem')

Ins('AxiSplitter',
    p_axi='hmem', p_axiRd='hmemRd', p_axiWr='hmemWr')
Ins('AxiSplitter',
    p_axi='cmem', p_axiRd='cmemRd', p_axiWr='cmemWr')

Ins('AxiRdBlockMapper',
    p_map='extmapHRd',
    p_axiLog='hmemRdLog', p_axiPhy='hmemRd')
Ins('AxiWrBlockMapper',
    p_map='extmapHWr',
    p_axiLog='hmemWrLog', p_axiPhy='hmemWr')
Ins('AxiRdBlockMapper',
    p_map='extmapCRd',
    p_axiLog='cmemRdLog', p_axiPhy='cmemRd')
Ins('AxiWrBlockMapper',
    p_map='extmapCWr',
    p_axiLog='cmemWrLog', p_axiPhy='cmemWr')

Ins('AxiReader', g_FIFOLogDepth=3, p_regs='regsHRd',
    p_start='start', p_ready='readyHRd',
    p_axiRd='hmemRdLog', p_stm='stmHRd')
Ins('AxiWriter', g_FIFOLogDepth=1, p_regs='regsHWr',
    p_start='start', p_ready='readyHWr',
    p_axiWr='hmemWrLog', p_stm='stmHWr')
Ins('AxiReader', g_FIFOLogDepth=8, p_regs='regsCRd',
    p_start='start', p_ready='readyCRd',
    p_axiRd='cmemRdLog', p_stm='stmCRd')
Ins('AxiWriter', g_FIFOLogDepth=1, p_regs='regsCWr',
    p_start='start', p_ready='readyCWr',
    p_axiWr='cmemWrLog', p_stm='stmCWr')

Ins('ExtentStore', p_regs='regsExtStore',
    p_int='intExtStore',
    p_ports=['extmapHRd', 'extmapHWr', 'extmapCRd', 'extmapCWr'])

Ins('NativeStreamSource', p_regs='regsSource',
    p_start='start', p_ready='readySrc',
    p_stm='stmSrc')
Ins('NativeStreamSink', p_regs='regsSink',
    p_start='start', p_ready='readySnk',
    p_stm='stmSnk')

Ins('NativeStreamSwitch', p_regs='regsSwitch',
    p_stmIn=['stmHRd', 'stmCRd', 'stmSrc'], p_stmOut=['stmHWr', 'stmCWr', 'stmSnk'])

Ins('AxiMonitor', p_regs='regsMon',
    p_start='start',
    p_axiRd=['hmemRd', 'cmemRd'],
    p_axiWr=['hmemWr', 'cmemWr'],
    p_stream=['stmHWr', 'stmCWr', 'stmSnk'])


