/* SPC instruction macros
 *  Original code by Savoury SnaX
 *  Rewritten/maintained by TRAC
 */

.macro TCALL vecnum
  movl %ebx,%eax
  PUSH_W
  movw _SPCRAM+0xFFC0+((15 - (\vecnum)) << 1),%ax
  cmpw $0xFFC0,%ax
  movw %ax,_PC
  movl SPC_FFC0_Address,%eax
  jnb 0f
  movl $_SPCRAM,%eax
0:movl %eax,SPC_Code_Base
.endm

.macro SPC_BFC flag
    JUMP_FLAG_SPC \flag,0f      // flag set
    movsbl 1(%esi),%eax     // sign extend for addition
    addl $2,%ebp            // Branch taken
//  addl $2,_TotalCycles    // (0.32) Butcha - fix 'lost' SPC timer ticks!
    addl %eax,%ebx
0:  incl %ebx
    movw %bx,_PC
.endm

.macro SPC_BFS flag
    JUMP_NOT_FLAG_SPC \flag,0f  // flag set
    movsbl 1(%esi),%eax     // sign extend for addition
    addl $2,%ebp            // Branch taken
//  addl $2,_TotalCycles    // (0.32) Butcha - fix 'lost' SPC timer ticks!
    addl %eax,%ebx
0:  incl %ebx
    movw %bx,_PC
.endm

.macro SPC_OR_A addr
    SPC_ADDR_\addr
    GET_BYTE_SPC
    orb %al,_A
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
.endm

.macro SPC_AND_A addr
    SPC_ADDR_\addr
    GET_BYTE_SPC
    andb %al,_A
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
.endm

.macro SPC_EOR_A addr
    SPC_ADDR_\addr
    GET_BYTE_SPC
    xorb %al,_A
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
.endm

.macro SPC_CMP reg addr
    SPC_ADDR_\addr
    GET_BYTE_SPC
    cmpb %al,\reg
    cmc
    STORE_FLAGS_SPC (SPC_FLAG_NZC)
.endm

.macro SPC_CMP_A addr
    SPC_CMP _A,\addr
.endm

.macro SPC_CMP_X addr
    SPC_CMP _X,\addr
.endm

.macro SPC_CMP_Y addr
    SPC_CMP _Y,\addr
.endm

.macro SPC_ADC_A addr
    SPC_ADDR_\addr
    CLR_FLAG_SPC(SPC_FLAG_V)    // Done cos STORE_FLAGS cant alter V!
    GET_BYTE_SPC
    MAKE_CARRY
    adcb %al,_A
    lahf
    jno 1f
    SET_FLAG_SPC(SPC_FLAG_V)
1:  STORE_FLAGS_SPC_FROM SPC_FLAG_NHZC,%ah
.endm

.macro SPC_ADC_mem addr,loc
    SPC_ADDR_\addr
    movb \loc,%dl
    CLR_FLAG_SPC(SPC_FLAG_V)    // Done cos STORE_FLAGS cant alter V!
    GET_BYTE_SPC
    MAKE_CARRY
    adcb %dl,%al
    lahf
    jno 1f
    SET_FLAG_SPC(SPC_FLAG_V)
1:  STORE_FLAGS_SPC_FROM SPC_FLAG_NHZC,%ah
    SET_BYTE_SPC
.endm

.macro SPC_SBC_A addr
    SPC_ADDR_\addr
    CLR_FLAG_SPC(SPC_FLAG_V)    // Done cos STORE_FLAGS cant alter V!
    GET_BYTE_SPC
    MAKE_NOT_CARRY
    sbbb %al,_A
    cmc
    lahf
    jno 1f
    SET_FLAG_SPC(SPC_FLAG_V)
1:  STORE_FLAGS_SPC_FROM SPC_FLAG_NHZC,%ah
.endm

.macro SPC_SBC_mem addr,loc
    SPC_ADDR_\addr
    movb \loc,%dl
    CLR_FLAG_SPC(SPC_FLAG_V)    // Done cos STORE_FLAGS cant alter V!
    GET_BYTE_SPC
    MAKE_NOT_CARRY
    sbbb %dl,%al    // (0.30) Butcha - switched these, wrong order
    cmc
    lahf
    jno 1f
    SET_FLAG_SPC(SPC_FLAG_V)
1:  STORE_FLAGS_SPC_FROM SPC_FLAG_NHZC,%ah
    SET_BYTE_SPC
.endm

.macro SPC_DEC addr
    SPC_ADDR_\addr
    GET_BYTE_SPC
    decb %al
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    SET_BYTE_SPC
.endm

.macro SPC_INC addr
    SPC_ADDR_\addr
    GET_BYTE_SPC
    incb %al
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    SET_BYTE_SPC
.endm

.macro SPC_ASL addr
    SPC_ADDR_\addr
    GET_BYTE_SPC
    addb %al,%al
    STORE_FLAGS_SPC (SPC_FLAG_NZC)
    SET_BYTE_SPC
.endm

.macro SPC_LSR addr
    SPC_ADDR_\addr
    GET_BYTE_SPC
    shrb $1,%al
    STORE_FLAGS_SPC (SPC_FLAG_NZC)
    SET_BYTE_SPC
.endm

.macro SPC_ROL addr
    SPC_ADDR_\addr
    GET_BYTE_SPC
    movb %al,%dl
    MAKE_CARRY
    adcb %dl,%dl
    STORE_FLAGS_SPC (SPC_FLAG_NZC)
    movb %dl,%al
    SET_BYTE_SPC
.endm

.macro SPC_ROR addr
    SPC_ADDR_\addr
    GET_BYTE_SPC
    shrb $1,_PSW_B      //MAKE_CARRY
    rcrb $1,%al
    adcb _PSW_B,_PSW_B  //STORE_FLAGS_SPC (SPC_FLAG_C)
    testb %al,%al
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    SET_BYTE_SPC
.endm

.macro SPC_MOV_ reg addr
    SPC_ADDR_\addr
    movb \reg,%al
    SET_BYTE_SPC
.endm

.macro SPC_MOV__A addr
    SPC_MOV_ _A,\addr
.endm

.macro SPC_MOV__X addr
    SPC_MOV_ _X,\addr
.endm

.macro SPC_MOV__Y addr
    SPC_MOV_ _Y,\addr
.endm

.macro SPC_MOV reg addr
    SPC_ADDR_\addr
    GET_BYTE_SPC
    testb %al,%al
    movb %al,\reg
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
.endm

.macro SPC_MOV_A_ addr
    SPC_MOV _A,\addr
.endm

.macro SPC_MOV_X_ addr
    SPC_MOV _X,\addr
.endm

.macro SPC_MOV_Y_ addr
    SPC_MOV _Y,\addr
.endm
