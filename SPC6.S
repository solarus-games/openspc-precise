/*

 SPC700 opcodes 0x60-0x6F:
    60: CLRC            1,2
    61: TCALL 6         1,8
    62: SET1 dp.3       2,4
    63: BBS dp.3,rel    3,5/7
    64: CMP A,dp        2,3
    65: CMP A,labs      3,4
    66: CMP A,(X)       1,3
    67: CMP A,(dp+X)    2,6
    68: CMP A,#imm      2,2
    69: CMP dp(d),dp(s) 3,6
    6A: AND1 C,/mem.bit 3,4
    6B: ROR dp          2,4
    6C: ROR labs        3,5
    6D: PUSH Y          1,4
    6E: DBNZ dp,rel     3,5/7
    6F: RET             1,5

*/

/* 60 */

.balign 16
SPC_CLRC:
    movw %bx,_PC
    CLR_FLAG_SPC (SPC_FLAG_C)
    jmp SPC_BACK

/* 61 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_6:
    TCALL 6
    jmp SPC_BACK

/* 62 */
/* SPC_SET1 in SPCmain.S */

/* 63 */
/* SPC_BBS in SPCmain.S */

/* 64 */

.balign 16
SPC_CMP_A_dp:
    SPC_CMP_A dp
    jmp SPC_BACK

/* 65 */

.balign 16
SPC_CMP_A_abs:
    SPC_CMP_A ABS
    jmp SPC_BACK

/* 66 */

.balign 16
SPC_CMP_A_OXO:
    SPC_CMP_A OXO
    jmp SPC_BACK

/* 67 */

.balign 16
SPC_CMP_A_OOdp_XOO:
    SPC_CMP_A OOdp_XOO
    jmp SPC_BACK

/* 68 */

.balign 16
SPC_CMP_A_IM:
    movb 1(%esi),%al
    incl %ebx
    cmpb %al,_A
    cmc
    movw %bx,_PC
    STORE_FLAGS_SPC (SPC_FLAG_NZC)
    jmp SPC_BACK

/* 69 */

.balign 16
SPC_CMP_dp_dp:
    SPC_ADDR_dp_dp
    movb %al,%dl        // source byte in %dl
    GET_BYTE_SPC
    cmpb %dl,%al
    cmc
    STORE_FLAGS_SPC (SPC_FLAG_NZC)
    jmp SPC_BACK

/* 6A */

.balign 16
SPC_AND1C:      // Carry flag = Carry flag AND !mem.bit
    SPC_ADDR_membit     // %bx contains mem and %dx contains bit number
    GET_BYTE_SPC        // Get byte at location
    btl %edx,%eax
    jnc SPC_BACK        // C & ~0 = C
    CLR_FLAG_SPC (SPC_FLAG_C)   // C & ~1 = 0
    jmp SPC_BACK

/* 6B */

.balign 16
SPC_ROR_dp:
    SPC_ROR dp
    jmp SPC_BACK

/* 6C */

.balign 16
SPC_ROR_abs:
    SPC_ROR ABS
    jmp SPC_BACK

/* 6D */

.balign 16
SPC_PUSH_Y:
    movw %bx,_PC
    movb _Y,%al
    PUSH_B
    jmp SPC_BACK

/* 6E */

.balign 16
SPC_DBNZ_dp:
    pushl %ebx
    movl SPC_PAGE,%ebx
    movb 1(%esi),%bl    // get dp
    GET_BYTE_SPC        // get (dp)
    decl %eax
    SET_BYTE_SPC
    testb %al,%al
    popl %ebx
    jz 9f
    movsbl 2(%esi),%eax // sign extend for addition
    addl $2,%ebp        // Branch taken
    addl %eax,%ebx
//  addl $2,_TotalCycles    // (0.32) Butcha - fix 'lost' SPC timer ticks!
9:  addl $2,%ebx
    movw %bx,_PC
    jmp SPC_BACK

/* 6F */

.balign 16
SPC_RET:
  POP_W
  cmpl $0xFFC0,%eax
  movl %eax,_PC
  movl SPC_FFC0_Address,%eax
  jnb 0f
  movl $_SPCRAM,%eax
0:movl %eax,SPC_Code_Base
  jmp SPC_BACK
