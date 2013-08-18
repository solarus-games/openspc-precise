/*

 SPC700 opcodes 0x50-0x5F:
    50: BVC rel         2,2/4
    51: TCALL 5         1,8
    52: CLR1 dp.2       2,4
    53: BBC dp.2,rel    3,5/7
    54: EOR A,dp+X      2,4
    55: EOR A,labs+X    3,5
    56: EOR A,labs+Y    3,5
    57: EOR A,(dp)+Y    2,6
    58: EOR dp,#imm     3,5
    59: EOR (X),(Y)     1,5
    5A: CMPW YA,dp      2,4
    5B: LSR dp+X        2,5
    5C: LSR A           1,2
    5D: MOV X,A         1,2
    5E: CMP Y,labs      3,4
    5F: JMP labs        3,3

*/

/* 50 */

.balign 16
SPC_BVC:
    SPC_BFC SPC_FLAG_V
    jmp SPC_BACK

/* 51 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_5:
    TCALL 5
    jmp SPC_BACK

/* 52 */
/* SPC_CLR1 in SPCmain.S */

/* 53 */
/* SPC_BBC in SPCmain.S */

/* 54 */

.balign 16
SPC_EOR_A_Odp_XO:
    SPC_EOR_A Odp_XO
    jmp SPC_BACK

/* 55 */

.balign 16
SPC_EOR_A_Oabs_XO:
    SPC_EOR_A OABS_XO
    jmp SPC_BACK

/* 56 */

.balign 16
SPC_EOR_A_Oabs_YO:
    SPC_EOR_A OABS_YO
    jmp SPC_BACK

/* 57 */

.balign 16
SPC_EOR_A_OOdpO_YO:
    SPC_EOR_A OOdpO_YO
    jmp SPC_BACK

/* 58 */

.balign 16
SPC_EOR_dp_IM:
    SPC_ADDR_dp_IM
    movb 1(%esi),%dl    // immediate byte in %dl
    GET_BYTE_SPC
    xorb %dl,%al
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    SET_BYTE_SPC
    jmp SPC_BACK

/* 59 */

.balign 16
SPC_EOR_OXO_OYO:
    SPC_ADDR_OXO_OYO
    movb %al,%dl
    GET_BYTE_SPC
    xorb %dl,%al
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    SET_BYTE_SPC
    jmp SPC_BACK

/* 5A */

.balign 16
SPC_CMPW_YA_dp:
    SPC_ADDR_dp
    movl _YA,%edx
    GET_WORD_SPC        // get DP word
    cmpw %ax,%dx
    cmc
    // (0.30) Butcha: + C flag
    STORE_FLAGS_SPC (SPC_FLAG_NZC)
    jmp SPC_BACK

/* 5B */

.balign 16
SPC_LSR_Odp_XO:
    SPC_LSR Odp_XO
    jmp SPC_BACK

/* 5C */

.balign 16
SPC_LSR_A:
    movw %bx,_PC
    shrb $1,_A
    STORE_FLAGS_SPC (SPC_FLAG_NZC)
    jmp SPC_BACK

/* 5D */

.balign 16
SPC_MOV_X_A:
    movw %bx,_PC
    movb _A,%al
    testb %al,%al
    movb %al,_X
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* 5E */

.balign 16
SPC_CMP_Y_abs:
    SPC_CMP_Y ABS
    jmp SPC_BACK

/* 5F */

.balign 16
SPC_JMP_abs:
  movb 1(%esi),%al
  movb 2(%esi),%ah
  cmpl $0xFFC0,%eax
  movl %eax,_PC
  movl SPC_FFC0_Address,%eax
  jnb 0f
  movl $_SPCRAM,%eax
0:movl %eax,SPC_Code_Base
  jmp SPC_BACK
