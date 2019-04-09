
Typ('MaskStream', Role.Complex, x_user=True, x_stream=True, x_datawidth=16)

Ent('MaskStreamRouter', g_InPortCount=None, g_OutPortCount=None,
    ps_regs='RegPort',
    ps_stmIn=('MaskStream', 'InPortCount'),
    pm_stmOut=('MaskStream', 'OutPortCount'),
    x_template='StreamRouter.vhd', x_outfile='MaskStreamRouter.vhd', xt_type='MaskStream')

Ent('HLSFilter',
    ps_stmIn='NativeStream', ps_stmRef='NativeStream', pm_stmOut= 'MaskStream',
    pi_regLConst='RegData', pi_regRConst='RegData', pi_regMode='RegData',
    x_template='HLSWrapper.vhd', x_outfile='HLSFilter.vhd', x_hls_name='hls_filter')

Env((0x040, 0x10, 'regExtStore'),
    (0x050, 0x10, 'regSwitch'),
    g_ActionType=0x108, g_ActionRev=0x1,
    p_start='start', p_ready=['readyHRd', 'readyHWr', 'readyCRd', 'readyCWr'],
    p_hmem='hmem')

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
    p_regs='regExtStore',
    p_ports=['extmapHRd', 'extmapHWr', 'extmapCRd', 'extmapCWr'])

Ins('AxiReader', g_FIFOCountWidth=3,
    p_start='start', p_ready='readyHRd',
    p_axiRd='hmemRdLog', p_stm='stmHRd')
Ins('AxiWriter', g_FIFOCountWidth=1,
    p_start='start', p_ready='readyHWr',
    p_axiWr='hmemWrLog', p_stm='stmHWr')
Ins('AxiReader', g_FIFOCountWidth=8,
    p_start='start', p_ready='readyCRd',
    p_axiRd='cmemRdLog', p_stm='stmCRd')
Ins('AxiWriter', g_FIFOCountWidth=1,
    p_start='start', p_ready='readyCWr',
    p_axiWr='cmemWrLog', p_stm='stmCWr')

Ins('NativeStreamSwitch', p_regs='regSwitch',
    p_stmIn=['stmHRd', 'stmCRd'], p_stmOut=['stmHWr', 'stmCWr'])


