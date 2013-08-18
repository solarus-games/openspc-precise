/*

 SPC700 opcodes 0x10-0x1F:
    10: BPL rel         2,2/4
    11: TCALL 1         1,8
    12: CLR1 dp.0       2,4
    13: BBC dp.0,rel    3,5/7
    14: OR  A,dp+X      2,4
    15: OR  A,labs+X    3,5
    16: OR  A,labs+Y    3,5
    17: OR  A,(dp)+Y    2,6
    18: OR  dp,#imm     3,5
    19: OR  (X),(Y)     1,5
    1A: DECW dp         2,6
    1B: ASL dp+X        2,5
    1C: ASL A           1,2
    1D: DEC X           1,2
    1E: CMP X,labs      3,4
    1F: JMP (labs+X)    3,6

*/

/* 10 */

.balign 16
SPC_BPL:
    SPC_BFC SPC_FLAG_N
    jmp SPC_BACK

/* 11 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_1:
    TCALL 1
    jmp SPC_BACK

/* 12 */
/* SPC_CLR1 in SPCmain.S */

/* 13 */
/* SPC_BBC in SPCmain.S */

/* 14 */

.balign 16
SPC_OR_A_Odp_XO:
    SPC_OR_A Odp_XO
    jmp SPC_BACK

/* 15 */

.balign 16
SPC_OR_A_Oabs_XO:
    SPC_OR_A OABS_XO
    jmp SPC_BACK

/* 16 */

.balign 16
SPC_OR_A_Oabs_YO:
    SPC_OR_A OABS_YO
    jmp SPC_BACK

/* 17 */

.balign 16
SPC_OR_A_OOdpO_YO:
    SPC_OR_A OOdpO_YO
    jmp SPC_BACK

/* 18 */

.balign 16
SPC_OR_dp_IM:
    SPC_ADDR_dp_IM      // %dl contains immediate, %bx dest address
    movb 1(%esi),%dl    // immediate byte in %dl
    GET_BYTE_SPC        // get (dp)
    orb %dl,%al
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    SET_BYTE_SPC
    jmp SPC_BACK

/* 19 */

.balign 16
SPC_OR_OXO_OYO:
    SPC_ADDR_OXO_OYO    // %dl contains (Y), %bx dest address
    movb %al,%dl
    GET_BYTE_SPC        // get (X)
    orb %dl,%al
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    SET_BYTE_SPC
    jmp SPC_BACK

/* 1A */

.balign 16
SPC_DECW_dp:
    SPC_ADDR_dp
    GET_WORD_SPC            // get DP word
    movl %eax,%edx
    decw %dx
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    decw %bx
    movl %edx,%eax
    SET_WORD_SPC
    jmp SPC_BACK

/* 1B */

.balign 16
SPC_ASL_Odp_XO:
    SPC_ASL Odp_XO
    jmp SPC_BACK

/* 1C */

.balign 16
SPC_ASL_A:
    movw %bx,_PC
    shlb $1,_A
    STORE_FLAGS_SPC (SPC_FLAG_NZC)
    jmp SPC_BACK

/* 1D */

.balign 16
SPC_DEC_X:
    movw %bx,_PC
    decb _X
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* 1E */

.balign 16
SPC_CMP_X_abs:
    SPC_CMP_X ABS
    jmp SPC_BACK

/* 1F */

.balign 16
SPC_JMP_Oabs_XO:
  SPC_ADDR_OABS_XO
  GET_WORD_SPC
  cmpl $0xFFC0,%eax
  movl %eax,_PC
  movl SPC_FFC0_Address,%eax
  jnb 0f
  movl $_SPCRAM,%eax
0:movl %eax,SPC_Code_Base
  jmp SPC_BACK
