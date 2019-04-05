
Typ('MaskStream', Role.Complex, x_user=True, x_stream=True, x_datawidth=16)

Ent('MaskStreamRouter', g_InPortCount=None, g_OutPortCount=None,
    ps_reg='RegPort',
    ps_stmIn_v=('MaskStream', 'InPortCount'),
    pm_stmOut_v=('MaskStream', 'OutPortCount'),
    x_template='StreamRouter.vhd', x_outfile='MaskStreamRouter.vhd', xt_type='MaskStream')

Ent('HLSFilter',
    ps_stmIn='NativeStream', ps_stmRef='NativeStream', pm_stmOut= 'NativeStream',
    pi_regLConst='RegData', pi_regRConst='RegData', pi_regMode='RegData',
    x_template='HLSWrapper.vhd', x_outfile='HLSFilter.vhd', x_hls_name='hls_filter')

Env((0x040, 0x10, 'regExtStore'),
    (0x050, 0x10, 'regSwitch'),
    g_ActionType=0x108, g_ActionRev=0x1,
    p_start='start', p_ready=['readyHRd', 'readyHWr', 'readyCRd', 'readyCWr'],
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

Ins('ExtentStore',
    p_reg='regExtStore',
    pl_extmaps=['hmemRd', 'hmemWr', 'cmemRd', 'cmemWr'])

Ins('AxiReader', g_FIFODepth=3,
    p_start='start', p_ready='readyHRd',
    p_axiRd='hmemRdLog', p_stm='stmHRd')
Ins('AxiWriter', g_FIFODepth=1,
    p_start='start', p_ready='readyHWr',
    p_axiWr='hmemWrLog', p_stm='stmHWr')
Ins('AxiReader', g_FIFODepth=8,
    p_start='start', p_ready='readyCRd',
    p_axiRd='cmemRdLog', p_stm='stmCRd')
Ins('AxiWriter', g_FIFODepth=1,
    p_start='start', p_ready='readyCWr',
    p_axiWr='cmemWrLog', p_stm='stmCWr')

Ins('NativeStreamSwitch', p_reg='regSwitch',
    pl_stmIn=['stmHRd', 'stmCRd'], pl_stmOut=['stmHWr', 'stmCWr'])


