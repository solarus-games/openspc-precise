/*

 SPC700 opcodes 0x40-0x4F:
    40: SETP            1,2
    41: TCALL 4         1,8
    42: SET1 dp.2       2,4
    43: BBS dp.2,rel    3,5/7
    44: EOR A,dp        2,3
    45: EOR A,labs      3,4
    46: EOR A,(X)       1,3
    47: EOR A,(dp+X)    2,6
    48: EOR A,#imm      2,2
    49: EOR dp(d),dp(s) 3,6
    4A: AND1 C,mem.bit  3,4
    4B: LSR dp          2,4
    4C: LSR labs        3,5
    4D: PUSH X          1,4
    4E: TCLR1 labs      3,6
    4F: PCALL upage     2,6

*/

/* 40 */

.balign 16
SPC_SETP:
    movw %bx,_PC
    SET_FLAG_SPC(SPC_FLAG_P)
    CLR_FLAG_SPC(SPC_FLAG_I)
    movb $1,SPC_PAGE+1
    jmp SPC_BACK

/* 41 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_4:
    TCALL 4
    jmp SPC_BACK

/* 42 */
/* SPC_SET1 in SPCmain.S */

/* 43 */
/* SPC_BBS in SPCmain.S */

/* 44 */

.balign 16
SPC_EOR_A_dp:
    SPC_EOR_A dp
    jmp SPC_BACK

/* 45 */

.balign 16
SPC_EOR_A_abs:
    SPC_EOR_A ABS
    jmp SPC_BACK

/* 46 */

.balign 16
SPC_EOR_A_OXO:
    SPC_EOR_A OXO
    jmp SPC_BACK

/* 47 */

.balign 16
SPC_EOR_A_OOdp_XOO:
    SPC_EOR_A OOdp_XOO
    jmp SPC_BACK

/* 48 */

.balign 16
SPC_EOR_A_IM:
    movb 1(%esi),%al
    incl %ebx
    xorb %al,_A
    movw %bx,_PC
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* 49 */

.balign 16
SPC_EOR_dp_dp:
    SPC_ADDR_dp_dp
    movb %al,%dl        // source byte in %dl
    GET_BYTE_SPC
    xorb %dl,%al
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    SET_BYTE_SPC
    jmp SPC_BACK

/* 4A */

.balign 16
SPC_AND1:       // Carry flag = Carry flag AND mem.bit
    SPC_ADDR_membit     // %bx contains mem and %dx contains bit number
    GET_BYTE_SPC        // Get byte at location
    btl %edx,%eax
    jc  SPC_BACK        // C & 1 = C
    CLR_FLAG_SPC (SPC_FLAG_C)   // C & 0 = 0
    jmp SPC_BACK

/* 4B */

.balign 16
SPC_LSR_dp:
    SPC_LSR dp
    jmp SPC_BACK

/* 4C */

.balign 16
SPC_LSR_abs:
    SPC_LSR ABS
    jmp SPC_BACK

/* 4D */

.balign 16
SPC_PUSH_X:
    movw %bx,_PC
    movb _X,%al
    PUSH_B
    jmp SPC_BACK

/* 4E */

.balign 16
SPC_TCLR1:          // I have done this as TRB (65816) including the flag setting based on AND
    SPC_ADDR_ABS
    GET_BYTE_SPC    // Get byte
    movb _A,%dl
    testb %al,%dl   // NZ set for: mem & A
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    notb %dl
    andb %dl,%al
    SET_BYTE_SPC    // mem &= ~A
    jmp SPC_BACK

/* 4F */

.balign 16
SPC_PCALL:  // u-page is the last page on the SPC RAM (uppermost-page!)
  movl $0xFF00,%eax
  incl %ebx
  movb 1(%esi),%al    // upage offset
  cmpb $0xC0,%al
  movl %eax,_PC
  movl SPC_FFC0_Address,%eax
  jnb 0f
  movl $_SPCRAM,%eax
0:movl %eax,SPC_Code_Base
  movl %ebx,%eax
  PUSH_W
  jmp SPC_BACK
