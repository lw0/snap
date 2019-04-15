###############################################################################
# FOSIX Environment and Register Map
###############################################################################
regmap = [ (0x040+idx*0x10, 0x10, 'regsRd%d'%idx) for idx in range(4) ] + \
         [ (0x080+idx*0x10, 0x10, 'regsWr%d'%idx) for idx in range(4) ] + \
         [ (0x0C0+idx*0x08, 0x08, 'regsSnk%d'%idx) for idx in range(4) ] + \
         [ (0x0E0+idx*0x08, 0x08, 'regsSrc%d'%idx) for idx in range(4) ]

Env(*regmap, g_ActionType=0x6c, g_ActionRev=0x0,
    p_start='start',
    p_ready=Seq('readyRd{}', 'readyWr{}', f=range(4)),
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
    p_axiRd='axiRd',
    p_axiRds=Seq('axiRd{}', f=range(4)))
Ins('AxiWrMultiplexer', name='axiWrMultiplexer',
    p_axiWr='axiWr',
    p_axiWrs=Seq('axiWr{}', f=range(4)))

# Independent Read and Write
# for idx in range(4):
#   Ins('AxiReader', index=idx, g_FIFOCountWidth=8,
#       p_regs='regsRd{}',
#       p_start='start',
#       p_ready='readyRd{}',
#       p_axiRd='axiRd{}',
#       p_stm='stmRd{}')
#   Ins('NativeStreamSink', index=idx,
#       p_regs='regsSnk{}'
#       p_stm='stmRd{}')
#   Ins('NativeStreamSource', index=idx,
#       p_regs='regsSrc{}'
#       p_stm='stmWr{}')
#   Ins('AxiWriter', index=idx, g_FIFOCountWidth=1,
#       p_regs='regsWr{}',
#       p_start='start',
#       p_ready='readyWr{}',
#       p_stm='stmWr{}',
#       p_axiWr='axiWr{}')

# Buffered Read to Write
for idx in range(4):
  Ins('AxiReader', index=idx,
        g_FIFOCountWidth=3, #->FIFODepth=8
      p_regs='regsRd{}',
      p_start='start',
      p_ready='readyRd{}',
      p_hold='stmRd{}Hold',
      p_axiRd='axiRd{}',
      p_stm='stmRd{}')
  Ins('NativeStreamBuffer', index=idx,
        g_LogDepth=7, #->FIFODepth=128
        g_UsedThreshold=64,
        g_FreeThreshold=64,
      p_stmIn='stmRd{}',
      p_stmOut='stmWr{}',
      p_freeBelow='stmRd{}Hold',
      p_usedBelow='stmWr{}Hold')
  Ins('AxiWriter', index=idx, g_FIFOCountWidth=0, #->NoFIFO
      p_regs='regsWr{}',
      p_start='start',
      p_ready='readyWr{}',
      p_hold='stmWr{}Hold',
      p_stm='stmWr{}',
      p_axiWr='axiWr{}')
###############################################################################

