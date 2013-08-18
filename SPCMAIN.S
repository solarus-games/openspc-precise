/*
 SNEeSe SPC700 CPU emulation core
 Originally written by Savoury SnaX (Not quite sure if I like AT&T)
 Maintained/rewritten by Charles Bilyue'
 Modified by Butcha for use with OpenSPC

 Compile under DJGPP (GNU-AS)
  NOTE - This must have .S (capital) or the # stuff wont be pre-processed!!!

 This file contains:
  CPU core info
  Reset
  Execution Loop
  Invalid Opcode Handler
  Variable definitions (registers, interrupt vectors, etc.)
  CPU opcode emulation handlers
  CPU opcode handler table
  CPU opcode timing table

 CPU core info:
  Nearly all general registers are now used in SPC700 emulation:
   EAX,EBX are used by the memory mapper;
   CL is used to hold PSW register;
   EDX is used as CPU work register;
   EBP is used to hold cycle counter;
   ESI is used by the opcode fetcher;
   EDI is used as memory mapper work register.

    A register              - _A
    Y register              - _Y
    YA register pair        - _YA
    X register              - _X
    Stack pointer           - _SP
    Program Counter         - _PC
    Processor status word   - _PSW
       True x86 layout = |V|-|-|-|S|Z|-|A|-|-|-|C|
    True SPC700 layout =         |N|V|P|B|H|I|Z|C|
                   Using         |N|Z|P|H|B|I|V|C|

 SPC timers
  SPC700 timing is directly related to 65c816 timing, SPC gets 3 cycles for
  every 32 (21.47 MHz) 65c816 cycles. Since the timers run at 8KHz and 64KHz
  and the main chip runs at 2.048Mhz, the timers are clocked as follows:
    2.048MHz / 8KHz  = 256 cycles    (Timers 0 and 1)
    2.048MHz / 64KHz = 32  cycles    (Timer 2)

*/

#include "misc.i"

.globl _spc_Start
_spc_Start:

SPC_FLAG_C = 1  // These are the bits for flag set/clr operations
SPC_FLAG_V = 2
SPC_FLAG_I = 4
SPC_FLAG_B = 8
SPC_FLAG_H = 0x10
SPC_FLAG_P = 0x20
SPC_FLAG_Z = 0x40
SPC_FLAG_N = 0x80

SPC_FLAG_NZ = (SPC_FLAG_N | SPC_FLAG_Z)
SPC_FLAG_NC = (SPC_FLAG_N | SPC_FLAG_C)
SPC_FLAG_NZC = (SPC_FLAG_N | SPC_FLAG_Z | SPC_FLAG_C)
SPC_FLAG_NHZC = (SPC_FLAG_N | SPC_FLAG_H | SPC_FLAG_Z | SPC_FLAG_C)

#define _PSW __SPC_PSW
#define _YA __SPC_YA
#define _A  __SPC_A
#define _Y  __SPC_Y
#define _X  __SPC_X
#define _SP __SPC_SP
#define _PC __SPC_PC

#define _PSW_B    %cl

// Load PSW to register _PSW_B
.macro LOAD_PSW
 movb _PSW,_PSW_B
.endm

// Save register _PSW_B to PSW
.macro SAVE_PSW
 movb _PSW_B,_PSW
.endm

/* SPC MEMORY MAPPER IS PLACED HERE (ITS SIMPLER THAN THE CPU ONE!) */

/* bx - contains the actual address, al is where the info should be stored, edi is free */
/* NB bx is not corrupted! edi is corrupted! */
/* NB eax is not corrupted barring returnvalue in al... e.g. ah should not be used etc! */

.balign 16
SPC_READ_MAPPER:
    testb %bh,%bh
    movl %ebx,%edi
    jz  SPC_READ_ZERO_PAGE

    cmpl $0xFFC0,%ebx
    jae SPC_READ_RAM_ROM
.balign 16
SPC_READ_RAM:
    andl $0xFFFF,%edi
    movb _SPCRAM(%edi),%al
    ret

.balign 16
SPC_READ_RAM_ROM:
    andl $0xFFFF,%edi
    movb SPC_ROM_CODE-0xFFC0(%edi),%al
SPC_FFC0_Address=.-4
    ret

.balign 16
SPC_READ_ZERO_PAGE:
    cmpb $0xF0,%bl
    jb  SPC_READ_RAM

SPC_READ_FUNC:
    andl $0x0F,%edi
    jmpl Read_Func_Map(,%edi,4)

.balign 16
SPC_READ_INVALID:
    movb $0xFF,%al          // v0.15
    ret

/*   --------   */

SPC_WRITE_MAPPER:
    testb %bh,%bh
    movl %ebx,%edi
    jz  SPC_WRITE_ZERO_PAGE

SPC_WRITE_RAM:
    andl $0xFFFF,%edi
    movb %al,_SPCRAM(%edi)
    ret

.balign 16
SPC_WRITE_ZERO_PAGE:
    cmpb $0xF0,%bl
    jb  SPC_WRITE_RAM

SPC_WRITE_FUNC:
    andl $0x0F,%edi
    jmpl Write_Func_Map(,%edi,4)

SPC_WRITE_INVALID:
    ret

// GET_BYTE & GET_WORD now assume ebx contains the read address and 
// eax the place to store value also, corrupts edi

.macro  GET_BYTE_SPC
    call SPC_READ_MAPPER
.endm

.macro  GET_WORD_SPC
    GET_BYTE_SPC
    movb %al,%ah
    incw %bx
    GET_BYTE_SPC
    xchgb %al,%ah
.endm

// SET_BYTE & SET_WORD now assume ebx contains the write address and 
// eax the value to write, corrupts edi

.macro  SET_BYTE_SPC
    call SPC_WRITE_MAPPER
.endm

.macro  SET_WORD_SPC
    SET_BYTE_SPC
    movb %ah,%al
    incw %bx
    SET_BYTE_SPC
.endm

// --- Ease up on the finger cramps ;-)

.macro SET_FLAG_SPC flag
    orb $\flag,_PSW_B
.endm

.macro CLR_FLAG_SPC flag
    andb $~(\flag),_PSW_B
.endm

.macro CPL_FLAG_SPC flag
    xorb $\flag,_PSW_B
.endm

.macro TEST_FLAG_SPC flag      // Set ZF=!flag
    testb $\flag,_PSW_B
.endm

.macro JUMP_FLAG_SPC flag,wheretogo
    TEST_FLAG_SPC \flag
    jnz \wheretogo
.endm

.macro JUMP_NOT_FLAG_SPC flag,wheretogo
    TEST_FLAG_SPC \flag
    jz  \wheretogo
.endm

// Push / Pop Macros assume eax contains value - corrupt ebx,edi
.macro PUSH_B           // Push Byte (SP--)
    movl _SP,%ebx
    movb %al,_SPCRAM(%ebx)  // Store data on stack
    decl %ebx
    movb %bl,_SP        // Decrement S (Byte)
.endm

.macro POP_B            // Pop Byte (++SP)
    movl _SP,%ebx
    incb %bl
    movb %bl,_SP
    movb _SPCRAM(%ebx),%al  // Fetch data from stack
.endm

.macro PUSH_W            // Push Word (SP--)
    movl _SP,%ebx
    movb %ah,_SPCRAM(%ebx)      // Store data on stack
    movb %al,_SPCRAM-1(%ebx)    // Store data on stack
    subb $2,%bl
    movb %bl,_SP        // Postdecrement SP
.endm

.macro POP_W            // Pop Word (++SP)
    movl _SP,%ebx
    addb $2,%bl         // Preincrement SP
    movb %bl,_SP
    movb _SPCRAM(%ebx),%ah      // Fetch data from stack
    movb _SPCRAM-1(%ebx),%al    // Fetch data from stack
.endm

// STORE_FLAGS_SPC corrupts ah

.macro	STORE_FLAGS_SPC flags
    lahf
    STORE_FLAGS_SPC_FROM \flags,%ah
.endm

// Set SPC700 flags to PC flags
// Can only set flags NHZC - corrupts loc
// Assumes loc has PC flags (as from lahf)
.macro STORE_FLAGS_SPC_FROM flags,loc
    andb $(~\flags),_PSW_B
    andb $(\flags),\loc
    orb \loc,_PSW_B
.endm

// Set PC Flags To SNES Flags (only sets required flags all others cleared!) corrupts eax

.macro	MAKE_FLAGS_SPC flags
    movb _PSW_B,%ah
    andb $\flags,%ah    // Flags ready
    sahf
.endm

// Set PC Flags To SNES Flags (Inverts bit (e.g. C=1 means clear carry)) corrupts eax

.macro	MAKE_FLAGS_SPC_INV flags
    movb _PSW_B,%ah
    notb %ah
    andb $\flags,%ah    // Flags ready
    sahf
.endm

// PC carry flag = SPC700 carry flag (all others undefined)
.macro MAKE_CARRY
    rolb $8,_PSW_B
.endm

// PC carry flag = NOT SPC700 carry flag (all others undefined)
.macro MAKE_NOT_CARRY
    rolb $8,_PSW_B
    cmc
.endm

// Set up the flags from PC Flag format to SPC Flag format stored in %al

.macro	SETUPFLAGS_SPC
    movb $0,%al
    TEST_FLAG_SPC(SPC_FLAG_N)
    jz  9f
    orb $0x80,%al
9:  TEST_FLAG_SPC(SPC_FLAG_V)
    jz  9f
    orb $0x40,%al
9:  TEST_FLAG_SPC(SPC_FLAG_P)
    jz  9f
    orb $0x20,%al
9:  TEST_FLAG_SPC(SPC_FLAG_H)
    jz  9f
    orb $8,%al
9:  TEST_FLAG_SPC(SPC_FLAG_I)
    jz  9f
    orb $4,%al
9:  TEST_FLAG_SPC(SPC_FLAG_Z)
    jz  9f
    orb $2,%al
9:  TEST_FLAG_SPC(SPC_FLAG_C)
    jz  9f
    orb $1,%al
9:
.endm

// Restore the flags from SNES packed byte to PC format in %al

.macro	RESTOREFLAGS_SPC
    CLR_FLAG_SPC(SPC_FLAG_N)
    testb $0x80,%al
    jz  9f
    SET_FLAG_SPC(SPC_FLAG_N)
9:	CLR_FLAG_SPC(SPC_FLAG_V)
    testb $0x40,%al
    jz  9f
    SET_FLAG_SPC(SPC_FLAG_V)
9:	CLR_FLAG_SPC(SPC_FLAG_P)
    movb $0,SPC_PAGE+1      // Setup direct page bit
    testb $0x20,%al
    jz  9f
    SET_FLAG_SPC(SPC_FLAG_P)
    movb $1,SPC_PAGE+1      // Correct direct page bit
9:	CLR_FLAG_SPC(SPC_FLAG_H)
    testb $8,%al
    jz  9f
    SET_FLAG_SPC(SPC_FLAG_H)
9:	CLR_FLAG_SPC(SPC_FLAG_I)
    testb $4,%al
    jz  9f
    SET_FLAG_SPC(SPC_FLAG_I)
9:	CLR_FLAG_SPC(SPC_FLAG_Z)
    testb $2,%al
    jz  9f
    SET_FLAG_SPC(SPC_FLAG_Z)
9:	CLR_FLAG_SPC(SPC_FLAG_C)
    testb $1,%al
    jz  9f
    SET_FLAG_SPC(SPC_FLAG_C)
9:
.endm

.data
.balign 16
.globl SPCOpTable
SPCOpTable:
/* 00 */ .long SPC_NOP          ,SPC_TCALL_0      ,SPC_SET1         ,SPC_BBS 
/* 04 */ .long SPC_OR_A_dp      ,SPC_OR_A_abs     ,SPC_OR_A_OXO     ,SPC_OR_A_OOdp_XOO
/* 08 */ .long SPC_OR_A_IM      ,SPC_OR_dp_dp     ,SPC_OR1          ,SPC_ASL_dp
/* 0C */ .long SPC_ASL_abs      ,SPC_PUSH_PSW     ,SPC_TSET1        ,SPC_INVALID
/* 10 */ .long SPC_BPL          ,SPC_TCALL_1      ,SPC_CLR1         ,SPC_BBC 
/* 14 */ .long SPC_OR_A_Odp_XO  ,SPC_OR_A_Oabs_XO ,SPC_OR_A_Oabs_YO ,SPC_OR_A_OOdpO_YO
/* 18 */ .long SPC_OR_dp_IM     ,SPC_OR_OXO_OYO   ,SPC_DECW_dp      ,SPC_ASL_Odp_XO
/* 1C */ .long SPC_ASL_A        ,SPC_DEC_X        ,SPC_CMP_X_abs    ,SPC_JMP_Oabs_XO
/* 20 */ .long SPC_CLRP         ,SPC_TCALL_2      ,SPC_SET1         ,SPC_BBS 
/* 24 */ .long SPC_AND_A_dp     ,SPC_AND_A_abs    ,SPC_AND_A_OXO    ,SPC_AND_A_OOdp_XOO
/* 28 */ .long SPC_AND_A_IM     ,SPC_AND_dp_dp    ,SPC_OR1C         ,SPC_ROL_dp
/* 2C */ .long SPC_ROL_abs      ,SPC_PUSH_A       ,SPC_CBNE_dp      ,SPC_BRA
/* 30 */ .long SPC_BMI          ,SPC_TCALL_3      ,SPC_CLR1         ,SPC_BBC 
/* 34 */ .long SPC_AND_A_Odp_XO ,SPC_AND_A_Oabs_XO,SPC_AND_A_Oabs_YO,SPC_AND_A_OOdpO_YO
/* 38 */ .long SPC_AND_dp_IM    ,SPC_AND_OXO_OYO  ,SPC_INCW_dp      ,SPC_ROL_Odp_XO
/* 3C */ .long SPC_ROL_A        ,SPC_INC_X        ,SPC_CMP_X_dp     ,SPC_CALL
/* 40 */ .long SPC_SETP         ,SPC_TCALL_4      ,SPC_SET1         ,SPC_BBS 
/* 44 */ .long SPC_EOR_A_dp     ,SPC_EOR_A_abs    ,SPC_EOR_A_OXO    ,SPC_EOR_A_OOdp_XOO
/* 48 */ .long SPC_EOR_A_IM     ,SPC_EOR_dp_dp    ,SPC_AND1         ,SPC_LSR_dp
/* 4C */ .long SPC_LSR_abs      ,SPC_PUSH_X       ,SPC_TCLR1        ,SPC_PCALL
/* 50 */ .long SPC_BVC          ,SPC_TCALL_5      ,SPC_CLR1         ,SPC_BBC 
/* 54 */ .long SPC_EOR_A_Odp_XO ,SPC_EOR_A_Oabs_XO,SPC_EOR_A_Oabs_YO,SPC_EOR_A_OOdpO_YO
/* 58 */ .long SPC_EOR_dp_IM    ,SPC_EOR_OXO_OYO  ,SPC_CMPW_YA_dp   ,SPC_LSR_Odp_XO
/* 5C */ .long SPC_LSR_A        ,SPC_MOV_X_A      ,SPC_CMP_Y_abs    ,SPC_JMP_abs
/* 60 */ .long SPC_CLRC         ,SPC_TCALL_6      ,SPC_SET1         ,SPC_BBS 
/* 64 */ .long SPC_CMP_A_dp     ,SPC_CMP_A_abs    ,SPC_CMP_A_OXO    ,SPC_CMP_A_OOdp_XOO
/* 68 */ .long SPC_CMP_A_IM     ,SPC_CMP_dp_dp    ,SPC_AND1C        ,SPC_ROR_dp
/* 6C */ .long SPC_ROR_abs      ,SPC_PUSH_Y       ,SPC_DBNZ_dp      ,SPC_RET
/* 70 */ .long SPC_BVS          ,SPC_TCALL_7      ,SPC_CLR1         ,SPC_BBC 
/* 74 */ .long SPC_CMP_A_Odp_XO ,SPC_CMP_A_Oabs_XO,SPC_CMP_A_Oabs_YO,SPC_CMP_A_OOdpO_YO
/* 78 */ .long SPC_CMP_dp_IM    ,SPC_CMP_OXO_OYO  ,SPC_ADDW_YA_dp   ,SPC_ROR_Odp_XO
/* 7C */ .long SPC_ROR_A        ,SPC_MOV_A_X      ,SPC_CMP_Y_dp     ,SPC_INVALID
/* 80 */ .long SPC_SETC         ,SPC_TCALL_8      ,SPC_SET1         ,SPC_BBS 
/* 84 */ .long SPC_ADC_A_dp     ,SPC_ADC_A_abs    ,SPC_ADC_A_OXO    ,SPC_ADC_A_OOdp_XOO
/* 88 */ .long SPC_ADC_A_IM     ,SPC_ADC_dp_dp    ,SPC_EOR1         ,SPC_DEC_dp
/* 8C */ .long SPC_DEC_abs      ,SPC_MOV_Y_IM     ,SPC_POP_PSW      ,SPC_MOV_dp_IM
/* 90 */ .long SPC_BCC          ,SPC_TCALL_9      ,SPC_CLR1         ,SPC_BBC 
/* 94 */ .long SPC_ADC_A_Odp_XO ,SPC_ADC_A_Oabs_XO,SPC_ADC_A_Oabs_YO,SPC_ADC_A_OOdpO_YO
/* 98 */ .long SPC_ADC_dp_IM    ,SPC_ADC_OXO_OYO  ,SPC_SUBW_YA_dp   ,SPC_DEC_Odp_XO
/* 9C */ .long SPC_DEC_A        ,SPC_MOV_X_SP     ,SPC_DIV          ,SPC_XCN
/* A0 */ .long SPC_EI           ,SPC_TCALL_10     ,SPC_SET1         ,SPC_BBS 
/* A4 */ .long SPC_SBC_A_dp     ,SPC_SBC_A_abs    ,SPC_SBC_A_OXO    ,SPC_SBC_A_OOdp_XOO
/* A8 */ .long SPC_SBC_A_IM     ,SPC_SBC_dp_dp    ,SPC_MOV1_C_      ,SPC_INC_dp
/* AC */ .long SPC_INC_abs      ,SPC_CMP_Y_IM     ,SPC_POP_A        ,SPC_MOV_OXOInc_A
/* B0 */ .long SPC_BCS          ,SPC_TCALL_11     ,SPC_CLR1         ,SPC_BBC 
/* B4 */ .long SPC_SBC_A_Odp_XO ,SPC_SBC_A_Oabs_XO,SPC_SBC_A_Oabs_YO,SPC_SBC_A_OOdpO_YO
/* B8 */ .long SPC_SBC_dp_IM    ,SPC_SBC_OXO_OYO  ,SPC_MOV_YA_dp    ,SPC_INC_Odp_XO
/* BC */ .long SPC_INC_A        ,SPC_MOV_SP_X     ,SPC_INVALID      ,SPC_MOV_A_OXOInc
/* C0 */ .long SPC_DI           ,SPC_TCALL_12     ,SPC_SET1         ,SPC_BBS 
/* C4 */ .long SPC_MOV_dp_A     ,SPC_MOV_abs_A    ,SPC_MOV_OXO_A    ,SPC_MOV_OOdp_XOO_A
/* C8 */ .long SPC_CMP_X_IM     ,SPC_MOV_abs_X    ,SPC_MOV1__C      ,SPC_MOV_dp_Y
/* CC */ .long SPC_MOV_abs_Y    ,SPC_MOV_X_IM     ,SPC_POP_X        ,SPC_MUL
/* D0 */ .long SPC_BNE          ,SPC_TCALL_13     ,SPC_CLR1         ,SPC_BBC 
/* D4 */ .long SPC_MOV_Odp_XO_A ,SPC_MOV_Oabs_XO_A,SPC_MOV_Oabs_YO_A,SPC_MOV_OOdpO_YO_A
/* D8 */ .long SPC_MOV_dp_X     ,SPC_MOV_Odp_YO_X ,SPC_MOV_dp_YA    ,SPC_MOV_Odp_XO_Y
/* DC */ .long SPC_DEC_Y        ,SPC_MOV_A_Y      ,SPC_CBNE_Odp_XO  ,SPC_INVALID
/* E0 */ .long SPC_CLRV         ,SPC_TCALL_14     ,SPC_SET1         ,SPC_BBS 
/* E4 */ .long SPC_MOV_A_dp     ,SPC_MOV_A_abs    ,SPC_MOV_A_OXO    ,SPC_MOV_A_OOdp_XOO
/* E8 */ .long SPC_MOV_A_IM     ,SPC_MOV_X_abs    ,SPC_NOT1         ,SPC_MOV_Y_dp
/* EC */ .long SPC_MOV_Y_abs    ,SPC_NOTC         ,SPC_POP_Y        ,SPC_INVALID /*SPC_SLEEP*/
/* F0 */ .long SPC_BEQ          ,SPC_TCALL_15     ,SPC_CLR1         ,SPC_BBC 
/* F4 */ .long SPC_MOV_A_Odp_XO ,SPC_MOV_A_Oabs_XO,SPC_MOV_A_Oabs_YO,SPC_MOV_A_OOdpO_YO
/* F8 */ .long SPC_MOV_X_dp     ,SPC_MOV_X_Odp_YO ,SPC_MOV_dp_dp    ,SPC_MOV_Y_Odp_XO
/* FC */ .long SPC_INC_Y        ,SPC_MOV_Y_A      ,SPC_DBNZ_Y       ,SPC_INVALID /*SPC_STOP*/

// This holds the base instruction timings in cycles
SPCCycleTable:
/* 00 */ .byte 2,8,4,5,3,4,3,6,2,6,5,4,5,4,6,8
/* 10 */ .byte 2,8,4,5,4,5,5,6,5,5,6,5,2,2,4,6
/* 20 */ .byte 2,8,4,5,3,4,3,6,2,6,5,4,5,4,5,4
/* 30 */ .byte 2,8,4,5,4,5,5,6,5,5,6,5,2,2,3,8
/* 40 */ .byte 2,8,4,5,3,4,3,6,2,6,4,4,5,4,6,6
/* 50 */ .byte 2,8,4,5,4,5,5,6,5,5,4,5,2,2,4,3
/* 60 */ .byte 2,8,4,5,3,4,3,6,2,6,4,4,5,4,5,5
/* 70 */ .byte 2,8,4,5,4,5,5,6,5,5,5,5,2,2,3,6
/* 80 */ .byte 2,8,4,5,3,4,3,6,2,6,5,4,5,2,4,5
/* 90 */ .byte 2,8,4,5,4,5,5,6,5,5,5,5,2,2,12,5
/* A0 */ .byte 3,8,4,5,3,4,3,6,2,6,4,4,5,2,4,4
/* B0 */ .byte 2,8,4,5,4,5,5,6,5,5,5,5,2,2,3,4
/* C0 */ .byte 3,8,4,5,4,5,4,7,2,5,6,4,5,2,4,9
/* D0 */ .byte 2,8,4,5,5,6,6,7,4,5,4,5,2,2,6,3
/* E0 */ .byte 2,8,4,5,3,4,3,6,2,4,5,3,4,3,4,3
/* F0 */ .byte 2,8,4,5,4,5,5,6,3,4,5,4,2,2,4,3

.balign 16
offset_to_bit:  .byte 0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80
offset_to_not:  .byte 0xFE,0xFD,0xFB,0xF7,0xEF,0xDF,0xBF,0x7F

.balign 16
.globl _SPCRAM
_SPCRAM:        skipk 64    // Buffer for SPC RAM/ROM

_PC:.long   0
_SP:.long   0
SPC_PAGE:   .long   0

.balign 4
_YA:
_A: .byte   0
_Y: .byte   0
    .word   0

_PSW:   .byte   0   // Processor status word
_X: .byte   0

SPC_TEMP:	.byte	0

.balign 4
SPC_PORT0R:   .byte   0
SPC_PORT1R:   .byte   0
SPC_PORT2R:   .byte   0
SPC_PORT3R:   .byte   0

.text
.balign 16
SPC_SET1:
    incl %ebx
    shrl $5,%eax
    movw %bx,_PC
    movl SPC_PAGE,%ebx
    movb offset_to_bit(%eax),%dl
    movb 1(%esi),%bl     
    GET_BYTE_SPC     
    orb %dl,%al
    SET_BYTE_SPC
    jmp SPC_BACK

.balign 16
SPC_CLR1:
    incl %ebx
    shrl $5,%eax
    movw %bx,_PC
    movl SPC_PAGE,%ebx
    movb offset_to_not(%eax),%dl
    movb 1(%esi),%bl     
    GET_BYTE_SPC     
    andb %dl,%al
    SET_BYTE_SPC
    jmp SPC_BACK

.balign 16
SPC_BBS:
    shrl $5,%eax
    pushl %ebx
    movl SPC_PAGE,%ebx
    movb offset_to_bit(%eax),%dl
    movb 1(%esi),%bl     
    GET_BYTE_SPC         
    testb %dl,%al
    popl %ebx
    jz  9f               
    movsbl 2(%esi),%eax  
    addl %eax,%ebx
    addl $2,%ebp
9:  addl $2,%ebx
    movw %bx,_PC 
    jmp SPC_BACK

.balign 16
SPC_BBC:
    shrl $5,%eax
    pushl %ebx
    movl SPC_PAGE,%ebx
    movb offset_to_bit(%eax),%dl
    movb 1(%esi),%bl     
    GET_BYTE_SPC         
    testb %dl,%al
    popl %ebx
    jnz 9f               
    movsbl 2(%esi),%eax  
    addl %eax,%ebx
    addl $2,%ebp
9:  addl $2,%ebx
    movw %bx,_PC 
    jmp SPC_BACK

SPC_INVALID:
    movb %al,_Map_Byte      // al contains opcode!

    xorl %eax,%eax
    decw _PC                // Adjust address to correct for pre-increment
    movl _PC,%eax
    movl %eax,_Map_Address  // this just sets the error output up correctly!

    movl _PC,%eax
    movl %eax,_S_PC
    movl _SP,%eax
    movl %eax,_S_SP
    movb _A,%al
    movb %al,_S_A
    movb _X,%al
    movb %al,_S_X
    movb _Y,%al
    movb %al,_S_Y
    xorl %eax,%eax
    movb _PSW_B,%al
    movl %eax,_S_P 

    popa
    jmp _InvalidSPCOpcode      // This exits.. avoids conflict with other things!

.balign 16
.globl _Reset_SPC
_Reset_SPC:
    pusha

    cld

    // This sets up the ROM code, done before registers as it
    // contains the reset address for the ROM code (0xFFC0)
    movl $SPC_ROM_CODE,%esi
    movl $_SPCRAM+0xFFC0,%edi
    movl $64/4,%ecx
    rep; movsl

    // Reset the sound DSP registers
    xorl %eax,%eax
    movl $_SPC_DSP_Buffer,%edi
    movl $128/4,%ecx
    rep; stosl

    movl %eax,SPC_Cycles    // Clear Cycle Count
    movl %eax,SPC_PAGE      // Used to save looking up P flag for Direct page stuff!
    movb %al,_PSW           // Clear Flags Register
    movl %eax,_YA           // Reset registers
    movb %al,_X
    movl $0x01FF,_SP

    movb $0x80,_SPC_CTRL
    movl $SPC_ROM_CODE-0xFFC0,SPC_FFC0_Address
    movl $SPC_ROM_CODE-0xFFC0,SPC_Code_Base

    // Reset timers
    movb %al,_SPC_CNT0
    movb %al,_SPC_CNT1
    movb %al,_SPC_CNT2
    movb %al,_SPC_TIM0
    movb %al,_SPC_TIM1
    movb %al,_SPC_TIM2
    movb %al,_SPC_TIMT0
    movb %al,_SPC_TIMT1
    movb %al,_SPC_TIMT2
    movl %eax,_SPC_TIMER0
    movl %eax,_SPC_TIMER1
    movl %eax,_SPC_TIMER2
    movl %eax,_CycleLatch0
    movl %eax,_CycleLatch1
    movl %eax,_CycleLatch2

    decl %eax
    // Reset SPC700 input ports
    movb %al,SPC_PORT0R
    movb %al,SPC_PORT1R
    movb %al,SPC_PORT2R
    movb %al,SPC_PORT3R

    // Reset sound DSP port address
    movb %al,_SPC_DSP_ADDR

    movzwl _SPCRAM+0xFFFE,%eax  // Get ROM reset vector
    movl %eax,_PC               // Setup Program Counter

    popa
    ret

.balign 16
.globl _LOAD_SPC
_LOAD_SPC:
	pusha
	movw _S_PC,%ax
        cmpw $0xFFC0,%ax
        movw %ax,_PC
        movl SPC_FFC0_Address,%eax
        jnb 0f
        movl $_SPCRAM,%eax
0:      movl %eax,SPC_Code_Base
	movw _S_SP,%ax
        movw %ax,_SP
	movb _S_A,%al
        movb %al,_A
	movb _S_X,%al
        movb %al,_X
	movb _S_Y,%al
        movb %al,_Y
	movw _S_P,%ax
	RESTOREFLAGS_SPC
        SAVE_PSW
        movl $_SPCRAM+0xF4,%esi
        movl (%esi),%eax
        movl %eax,SPC_PORT0R		// mov long should get all four bytes
	popa
	ret

#ifdef SPCDEBUG
.balign 16
.globl _SPC_SHOW_REGISTERS
_SPC_SHOW_REGISTERS:
    pusha
    movl _PC,%eax
    movl %eax,_S_PC 
    movl _SP,%eax
    movl %eax,_S_SP
    movb _A,%al
    movb %al,_S_A
    movb _X,%al
    movb %al,_S_X
    movb _Y,%al
    movb %al,_S_Y
    LOAD_PSW
    SETUPFLAGS_SPC
    movb %al,_S_P
    call _DisplaySPC
    popa
    ret
#endif

.balign 16
.globl _SPC_RUN
_SPC_RUN:
  pusha
  movl _SPCcyc,%ebp
  addl %ebp,SPC_Cycles
  movl _TotalCycles,%ebp    // Get cycle counter

  LOAD_PSW

.balign 16
SPC_LOOP:
  movl _PC,%ebx         // PC now setup
  movl $0x80000000,%esi
SPC_Code_Base=.-4
  addl %ebx,%esi
  xorl %eax,%eax
  xorl %edx,%edx
movb (%esi),%al       // Fetch opcode
  incl %ebx
  // %esi still contains pointer for operand fetches
  movb SPCCycleTable(%eax),%dl  
  addl %edx,%ebp
  jmpl SPCOpTable(,%eax,4)      // jmp to opcode handler

.balign 16
SPC_BACK:
  cmpl $0x80000000,%ebp
.globl SPC_Cycles
SPC_Cycles=.-4          // Number of cycles to execute for SPC
  jle SPC_LOOP          // Do another instruction if cycles left
    
  SAVE_PSW

  movl %ebp,_TotalCycles  // Save cycle counter
  popa
  ret         // Return to CPU emulation

#include "SPCaddr.S"    // Include addressing mode macros
#include "SPCmacro.S"   // Include instruction macros

#include "SPC0.S"       // Include opcodes 0x00-0x0F
#include "SPC1.S"       // Include opcodes 0x10-0x1F
#include "SPC2.S"       // Include opcodes 0x20-0x2F
#include "SPC3.S"       // Include opcodes 0x30-0x3F
#include "SPC4.S"       // Include opcodes 0x40-0x4F
#include "SPC5.S"       // Include opcodes 0x50-0x5F
#include "SPC6.S"       // Include opcodes 0x60-0x6F
#include "SPC7.S"       // Include opcodes 0x70-0x7F
#include "SPC8.S"       // Include opcodes 0x80-0x8F
#include "SPC9.S"       // Include opcodes 0x90-0x9F
#include "SPCA.S"       // Include opcodes 0xA0-0xAF
#include "SPCB.S"       // Include opcodes 0xB0-0xBF
#include "SPCC.S"       // Include opcodes 0xC0-0xCF
#include "SPCD.S"       // Include opcodes 0xD0-0xDF
#include "SPCE.S"       // Include opcodes 0xE0-0xEF
#include "SPCF.S"       // Include opcodes 0xF0-0xFF

// This code should be copied into the top of the address space
SPC_ROM_CODE:
    .byte	0xCD,0xEF,0xBD,0xE8,0x00,0xC6,0x1D,0xD0
    .byte	0xFC,0x8F,0xAA,0xF4,0x8F,0xBB,0xF5,0x78
    .byte	0xCC,0xF4,0xD0,0xFB,0x2F,0x19,0xEB,0xF4
    .byte	0xD0,0xFC,0x7E,0xF4,0xD0,0x0B,0xE4,0xF5
    .byte	0xCB,0xF4,0xD7,0x00,0xFC,0xD0,0xF3,0xAB
    .byte	0x01,0x10,0xEF,0x7E,0xF4,0x10,0xEB,0xBA
    .byte	0xF6,0xDA,0x00,0xBA,0xF4,0xC4,0xF4,0xDD
    .byte	0x5D,0xD0,0xDB,0x1F,0x00,0x00,0xC0,0xFF

SPC_READ_DSP_ADDR:
    movb _SPC_DSP_ADDR,%al
    ret

SPC_READ_DSP_DATA:
    pusha
    call _SPC_READ_DSP
    popa
    pushl %ebx
    movb _SPC_DSP_ADDR,%bl
    andl $0x7F,%ebx
    movb _SPC_DSP_Buffer(,%ebx),%al    // read from DSP register
    popl %ebx
    ret

SPC_READ_PORT0R:
    movb SPC_PORT0R,%al
    ret
SPC_READ_PORT1R:
    movb SPC_PORT1R,%al
    ret
SPC_READ_PORT2R:
    movb SPC_PORT2R,%al
    ret
SPC_READ_PORT3R:
    movb SPC_PORT3R,%al
    ret

// WOOPS... TIMER registers are write only, the actual timer clock is internal not accessible!

// COUNTERS ARE 4 BIT, upon read they reset to 0 status

SPC_READ_COUNTER_0:
    pusha
    movl %ebp,_TotalCycles
    call _Sort_Count0
    popa
    movb _SPC_CNT0,%al
    movb $0,_SPC_CNT0
    ret

SPC_READ_COUNTER_1:
    pusha
    movl %ebp,_TotalCycles
    call _Sort_Count1
    popa
    movb _SPC_CNT1,%al
    movb $0,_SPC_CNT1
    ret

SPC_READ_COUNTER_2:
    pusha
    movl %ebp,_TotalCycles
    call _Sort_Count2
    popa
    movb _SPC_CNT2,%al
    movb $0,_SPC_CNT2
    ret

// | ---- | ---- | PC32 | PC10 | ---- | ST2  | ST1  | ST0  |
SPC_WRITE_CTRL:
    pushl %eax
    movb $0,%ah
    testb %al,%al       // New for 0.25 - read hidden RAM
    movl $_SPCRAM,%edi
    jns 1f
    movl $SPC_ROM_CODE-0xFFC0,%edi
1:  movl %edi,SPC_FFC0_Address
    testb $0x10,%al     // Reset ports 0/1 to 00 if set
    jz  0f
    movb %ah,SPC_PORT0R // Ports read by SPC should be reset! 
    movb %ah,SPC_PORT1R // Thanks to Butcha for fix!
0:  testb $0x20,%al     // Reset ports 2/3 to 00 if set
    jz  0f
    movb %ah,SPC_PORT2R
    movb %ah,SPC_PORT3R
0:  movl _TotalCycles,%edi
    testb $4,_SPC_CTRL
    jnz 0f
    testb $4,%al
    jz  0f
    movb $0,_SPC_CNT2
    movl $0,_SPC_TIMER2
    movl %edi,_CycleLatch2
0:  testb $2,_SPC_CTRL
    jnz 0f
    testb $2,%al
    jz  0f
    movb $0,_SPC_CNT1
    movl $0,_SPC_TIMER1
    movl %edi,_CycleLatch1
0:  testb $1,_SPC_CTRL
    jnz 0f
    testb $1,%al
    jz  0f
    movb $0,_SPC_CNT0
    movl $0,_SPC_TIMER0
    movl %edi,_CycleLatch0
0:  popl %eax
    movb %al,_SPC_CTRL
    ret

SPC_WRITE_DSP_ADDR:
    movb %al,_SPC_DSP_ADDR
    ret

SPC_WRITE_DSP_DATA:
    movb %al,_SPC_DSP_DATA
    pusha
    call _SPC_WRITE_DSP
    popa
    ret

SPC_WRITE_PORT0W:
SPC_WRITE_PORT1W:
SPC_WRITE_PORT2W:
SPC_WRITE_PORT3W:
    ret

SPC_WRITE_TIMER_0:
    pusha
    movl %ebp,_TotalCycles
    call _Sort_Count0   // Timer must catch up before target is changed
    popa
    testb %al,%al
    movb %al,_SPC_TIMT0 // (0.32) Butcha - timer targets are writable
    jz  0f
    movb $0,_SPC_TIMT0+1
    ret
0:  movb $1,_SPC_TIMT0+1    // 0 = 256
    ret

SPC_WRITE_TIMER_1:
    pusha
    movl %ebp,_TotalCycles
    call _Sort_Count1   // Timer must catch up before target is changed
    popa
    testb %al,%al
    movb %al,_SPC_TIMT1 // (0.32) Butcha - timer targets are writable
    jz  0f
    movb $0,_SPC_TIMT1+1
    ret
0:  movb $1,_SPC_TIMT1+1    // 0 = 256
    ret

SPC_WRITE_TIMER_2:
    pusha
    movl %ebp,_TotalCycles
    call _Sort_Count2   // Timer must catch up before target is changed
    popa
    testb %al,%al
    movb %al,_SPC_TIMT2 // (0.32) Butcha - timer targets are writable
    jz  0f
    movb $0,_SPC_TIMT2+1
    ret
0:  movb $1,_SPC_TIMT2+1    // 0 = 256
    ret

Read_Func_Map:              // Mappings for SPC Registers
    .long	SPC_READ_INVALID
    .long	SPC_READ_INVALID
    .long	SPC_READ_DSP_ADDR
    .long	SPC_READ_DSP_DATA
    .long   SPC_READ_PORT0R
    .long   SPC_READ_PORT1R
    .long   SPC_READ_PORT2R
    .long   SPC_READ_PORT3R
    .long	SPC_READ_INVALID
    .long	SPC_READ_INVALID
    .long	SPC_READ_INVALID
    .long	SPC_READ_INVALID
    .long	SPC_READ_INVALID
    .long	SPC_READ_COUNTER_0
    .long	SPC_READ_COUNTER_1
    .long	SPC_READ_COUNTER_2

Write_Func_Map:             // Mappings for SPC Registers
    .long	SPC_WRITE_INVALID
    .long	SPC_WRITE_CTRL
    .long	SPC_WRITE_DSP_ADDR
    .long	SPC_WRITE_DSP_DATA
    .long   SPC_WRITE_PORT0W
    .long   SPC_WRITE_PORT1W
    .long   SPC_WRITE_PORT2W
    .long   SPC_WRITE_PORT3W
    .long	SPC_WRITE_INVALID
    .long	SPC_WRITE_INVALID
    .long	SPC_WRITE_TIMER_0
    .long	SPC_WRITE_TIMER_1
    .long	SPC_WRITE_TIMER_2
    .long	SPC_WRITE_INVALID
    .long	SPC_WRITE_INVALID
    .long	SPC_WRITE_INVALID
