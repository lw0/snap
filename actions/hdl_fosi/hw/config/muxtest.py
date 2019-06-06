###############################################################################
# FOSI Environment and Register Map
###############################################################################
regmap = [ (0x040+idx*0x10, 0x10, 'regsRd%d'%idx) for idx in range(4) ] + \
         [ (0x080+idx*0x10, 0x10, 'regsWr%d'%idx) for idx in range(4) ] + \
         [ (0x0C0+idx*0x08, 0x08, 'regsSnk%d'%idx) for idx in range(4) ] + \
         [ (0x0E0+idx*0x08, 0x08, 'regsSrc%d'%idx) for idx in range(4) ] + \
         [ (0x100,          0xA0, 'regsMon') ]
# regmap = [ (0x040+idx*0x10, 0x10, 'regsRd%d'%idx) for idx in range(4) ] + \
#          [ (0x080+idx*0x10, 0x10, 'regsWr%d'%idx) for idx in range(4) ] + \
#          [ (0x100,          0xA0, 'regsMon') ]

Env(*regmap, g_ActionType=0x6c, g_ActionRev=0x0,
    p_start='start',
    p_ready=Seq('readyRd{}', 'readyWr{}', 'readySnk{}', 'readySrc{}', f=range(4)),
    p_hmem='hmem')
###############################################################################


###############################################################################
# User Design
###############################################################################
Ins('AxiSplitter',
    p_axi='hmem',
    p_axiRd='axiRd',
    p_axiWr='axiWr')

Ins('AxiRdMultiplexer', name='axiRdMultiplexer',
      g_FIFOLogDepth=4,
    p_axiRd='axiRd',
    p_axiRds=Seq('axiRd{}', f=range(4)))
Ins('AxiWrMultiplexer', name='axiWrMultiplexer',
      g_FIFOLogDepth=4,
    p_axiWr='axiWr',
    p_axiWrs=Seq('axiWr{}', f=range(4)))

# Independent Read and Write:
for idx in range(4):
  Ins('AxiReader', index=idx, g_FIFOLogDepth=8,
      p_regs='regsRd{}',
      p_start='start',
      p_ready='readyRd{}',
      p_axiRd='axiRd{}',
      p_stm='stmRd{}')
  Ins('NativeStreamSink', index=idx,
      p_start='start',
      p_ready='readySnk{}',
      p_regs='regsSnk{}',
      p_stm='stmRd{}')
  Ins('NativeStreamSource', index=idx,
      p_regs='regsSrc{}',
      p_start='start',
      p_ready='readySrc{}',
      p_stm='stmWr{}')
  Ins('AxiWriter', index=idx, g_FIFOLogDepth=1,
      p_regs='regsWr{}',
      p_start='start',
      p_ready='readyWr{}',
      p_stm='stmWr{}',
      p_axiWr='axiWr{}')

# Buffered Read to Write
# for idx in range(4):
#   Ins('AxiReader', index=idx,
#         g_FIFOLogDepth=3, #->FIFODepth=8
#       p_regs='regsRd{}',
#       p_start='start',
#       p_ready='readyRd{}',
#       p_hold='holdRd{}',
#       p_axiRd='axiRd{}',
#       p_stm='stmRd{}')
#   Ins('NativeStreamBuffer', index=idx,
#         g_LogDepth=9, #->FIFODepth=512
#         g_InThreshold=128,
#         g_OutThreshold=128,
#       p_stmIn='stmRd{}',
#       p_stmOut='stmWr{}',
#       p_inHold='holdRd{}',
#       p_outHold='holdWr{}')
#   Ins('AxiWriter', index=idx, g_FIFOLogDepth=0, #->NoFIFO
#       p_regs='regsWr{}',
#       p_start='start',
#       p_ready='readyWr{}',
#       p_hold='holdWr{}',
#       p_stm='stmWr{}',
#       p_axiWr='axiWr{}')


Ins('AxiMonitor', p_regs='regsMon',
    p_start='start',
    p_axiRd=['axiRd'], p_axiWr=['axiWr'],
    p_stream=[])
###############################################################################

