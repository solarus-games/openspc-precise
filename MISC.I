.macro  DUPLICATE vartype, count, data
.rept \count
.\vartype \data
.endr
.endm

.macro skipb count=1
.skip (\count)
.endm

.macro skipw count=1
.skip (\count)*2
.endm

.macro skipl count=1
.skip (\count)*4
.endm

.macro skipk count=1
.skip (\count)*1024
.endm
