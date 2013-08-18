/*

 SPC700 opcodes 0x20-0x2F:
    20: CLRP            1,2
    21: TCALL 2         1,8
    22: SET1 dp.1       2,4
    23: BBS dp.1,rel    3,5/7
    24: AND A,dp        2,3
    25: AND A,labs      3,4
    26: AND A,(X)       1,3
    27: AND A,(dp+X)    2,6
    28: AND A,#imm      2,2
    29: AND dp(d),dp(s) 3,6
    2A: OR1 C,/mem.bit  3,5
    2B: ROL dp          2,4
    2C: ROL labs        3,5
    2D: PUSH A          1,4
    2E: CBNE dp,rel     3,5/7
    2F: BRA rel         2,4

*/

/* 20 */

.balign 16
SPC_CLRP:
    movw %bx,_PC
    CLR_FLAG_SPC(SPC_FLAG_P)
    movb $0,SPC_PAGE+1
    jmp SPC_BACK

/* 21 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_2:
    TCALL 2
    jmp SPC_BACK

/* 22 */
/* SPC_SET1 in SPCmain.S */

/* 23 */
/* SPC_BBS in SPCmain.S */

/* 24 */

.balign 16
SPC_AND_A_dp:
    SPC_AND_A dp
    jmp SPC_BACK

/* 25 */

.balign 16
SPC_AND_A_abs:
    SPC_AND_A ABS
    jmp SPC_BACK

/* 26 */

.balign 16
SPC_AND_A_OXO:
    SPC_AND_A OXO
    jmp SPC_BACK

/* 27 */

.balign 16
SPC_AND_A_OOdp_XOO:
    SPC_AND_A OOdp_XOO
    jmp SPC_BACK

/* 28 */

.balign 16
SPC_AND_A_IM:
    movb 1(%esi),%al
    incl %ebx
    andb %al,_A
    movw %bx,_PC
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* 29 */

.balign 16
SPC_AND_dp_dp:
    SPC_ADDR_dp_dp      // %dl is (s), %bx is d
    movb %al,%dl        // source byte in %dl
    GET_BYTE_SPC        // get (d)
    andb %dl,%al
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    SET_BYTE_SPC
    jmp SPC_BACK

/* 2A */

.balign 16
SPC_OR1C:       // Carry flag = Carry flag OR !mem.bit
    SPC_ADDR_membit     // %bx contains mem and %dx contains bit number
    GET_BYTE_SPC        // Get byte at location
    btl %edx,%eax
    jc  SPC_BACK        // C | ~1 = C
    SET_FLAG_SPC (SPC_FLAG_C)   // C | ~0 = 1
    jmp SPC_BACK

/* 2B */

.balign 16
SPC_ROL_dp:
    SPC_ROL dp
    jmp SPC_BACK

/* 2C */

.balign 16
SPC_ROL_abs:
    SPC_ROL ABS
    jmp SPC_BACK

/* 2D */

.balign 16
SPC_PUSH_A:
    movw %bx,_PC
    movb _A,%al
    PUSH_B
    jmp SPC_BACK

/* 2E */

.balign 16
SPC_CBNE_dp:
    pushl %ebx
    movl SPC_PAGE,%ebx
    movb 1(%esi),%bl    // get dp
    GET_BYTE_SPC        // get (dp)
    cmpb %al,_A
    popl %ebx
    je  9f
    movsbl 2(%esi),%eax // sign extend for addition
    addl $2,%ebp        // Branch taken
    addl %eax,%ebx
//  addl $2,_TotalCycles    // (0.32) Butcha - fix 'lost' SPC timer ticks!
9:  addl $2,%ebx
    movw %bx,_PC
    jmp SPC_BACK

/* 2F */

.balign 16
SPC_BRA:
    incl %ebx
    movsbl 1(%esi),%eax // sign extend for addition
    addl %eax,%ebx
    movw %bx,_PC
    jmp SPC_BACK
