###############################################################################
# User Definitions
###############################################################################
Typ('MaskStream', Role.Complex, x_user=True, x_stream=True, x_datawidth=16)

Ent('MaskStreamRouter', g_InPortCount=None, g_OutPortCount=None,
    ps_regs='RegPort',
    ps_stmIn=('MaskStream', 'InPortCount'),
    pm_stmOut=('MaskStream', 'OutPortCount'),
    x_template='StreamRouter.vhd',
    x_outfile='MaskStreamRouter.vhd',
    xt_type='MaskStream')

Ent('MaskStreamMultiplier', g_PortCount=None,
    ps_stm='MaskStream',
    pm_stms=('MaskStream', 'PortCount'),
    x_template='StreamMultiplier.vhd',
    x_outfile='MaskStreamMultiplier.vhd',
    xt_type='MaskStream')

Ent('HLSFilter',
    ps_stmIn='NativeStream',
    ps_stmRef='NativeStream',
    pm_stmOut= 'MaskStream',
    pi_regLConst='RegData',
    pi_regRConst='RegData',
    pi_regMode='RegData',
    x_template='HLSWrapper.vhd',
    x_outfile='HLSFilter.vhd',
    x_hls_name='hls_filter')

Ent('HLSSelector',
    ps_stmIn='NativeStream',
    ps_stmMsk='MaskStream',
    pm_stmOut= 'NativeStream',
    x_template='HLSWrapper.vhd',
    x_outfile='HLSSelector.vhd',
    x_hls_name='hls_selector')

Ent('HLSLogic',
    ps_stmIn0='MaskStream',
    ps_stmIn1='MaskStream',
    ps_stmIn2='MaskStream',
    ps_stmIn3='MaskStream',
    pm_stmOut='MaskStream',
    pi_regFunc='RegData',
    x_template='HLSWrapper.vhd',
    x_outfile='HLSLogic.vhd',
    x_hls_name='hls_logic')
###############################################################################


###############################################################################
# FOSI Environment and Register Map
###############################################################################
regmap = [ (0x040,          0x08, 'regsCmpSwitch'),
           (0x050,          0x08, 'regsLogSwitch'),
           (0x060,          0x40, 'regsUser') ] + \
         [ (0x100+idx*0x10, 0x10, 'regsRd%d'%idx) for idx in range(4) ] + \
         [ (0x140+idx*0x10, 0x10, 'regsWr%d'%idx) for idx in range(4) ]
Env(*regmap,
    g_ActionType=0x80, g_ActionRev=0x0,
    p_start='start', p_ready=Seq('readyRd{}', 'readyWr{}', f=range(4)),
    p_hmem='hmem')

userRegs = \
  Seq('regMode{}', 'regLConst{}', 'regRConst{}', f=range(4)) + \
  Seq('regFunc{}', f=range(2))
Ins('RegisterFile', name='userRegFile', p_regs='regsUser',
    p_regRd=userRegs, p_regWr=userRegs)
###############################################################################


###############################################################################
# User Design
###############################################################################
Ins('AxiSplitter',
    p_axi='hmem',
    p_axiRd='axiRd',
    p_axiWr='axiWr')
Ins('AxiRdMultiplexer', name='axiRdMultiplexer',
    p_axiRd='axiRd',
    p_axiRds=Seq('axiRd{}', f=range(4)))
Ins('AxiWrMultiplexer', name='axiWrMultiplexer',
    p_axiWr='axiWr',
    p_axiWrs=Seq('axiWr{}', f=range(4)))

for idx in range(4):
  Ins('AxiReader', index=idx,
      p_regs='regsRd{}',
      p_axiRd='axiRd{}',
      p_stm='stmRd{}')
  Ins('NativeStreamBuffer', index=idx,
        g_LogDepth=7, # Depth = 128
        g_OmitKeep=True,
      p_stmIn='stmRd{}',
      p_stmOut='stmRdBuf{}')
  Ins('NativeStreamMultiplier', index=idx,
      p_stm='stmRdBuf{}',
      p_stms=['stmCmp{}', 'stmBuf{}'])
  Ins('NativeStreamBuffer', index=idx,
        g_LogDepth=7, # Depth = 128
        g_OmitKeep=True,
      p_stmIn='stmBuf{}',
      p_stmOut='stmSel{}')
  Ins('HLSSelector', index=idx,
      p_stmIn='stmSel{}',
      p_stmMsk='stmMsk{}',
      p_stmOut='stmWr{}')
  Ins('AxiWriter', index=idx,
      p_regs='regsWr{}',
      p_axiWr='axiWr{}',
      p_stm='stmWr{}')

Ins('NativeStreamRouter', name='cmpSwitch',
    p_regs='regsCmpSwitch',
    p_stmIn=Seq('stmCmp{}', f=range(4)),
    p_stmOut=Seq('stmCmpIn{}', 'stmCmpRef{}', f=range(4)))

for idx in range(4):
  Ins('HLSFilter', index=idx,
      p_stmIn='stmCmpIn{}',
      p_stmRef='stmCmpRef{}',
      p_stmOut='stmFil{}',
      p_regLConst='regLConst{}',
      p_regRConst='regRConst{}',
      p_regMode='regMode{}')
  Ins('MaskStreamMultiplier', index=idx,
      p_stm='stmFil{}',
      p_stms=['stmFil{}0', 'stmFil{}1'])

for idx in range(2):
  Ins('HLSLogic', index=idx,
      p_stmIn0='stmFil0{}',
      p_stmIn1='stmFil1{}',
      p_stmIn2='stmFil2{}',
      p_stmIn3='stmFil3{}',
      p_stmOut='stmLog{}',
      p_regFunc='regFunc{}')

Ins('MaskStreamRouter', name='logSwitch',
    p_regs='regsLogSwitch',
    p_stmIn=Seq('stmLog{}', f=range(2)),
    p_stmOut=Seq('stmMsk{}', f=range(4)))
###############################################################################

