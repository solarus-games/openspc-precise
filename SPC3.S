/*

 SPC700 opcodes 0x30-0x3F:
    30: BMI rel         2,2/4
    31: TCALL 3         1,8
    32: CLR1 dp.1       2,4
    33: BBC dp.1,rel    3,5/7
    34: AND A,dp+X      2,4
    35: AND A,labs+X    3,5
    36: AND A,labs+Y    3,5
    37: AND A,(dp)+Y    2,6
    38: AND dp,#imm     3,5
    39: AND (X),(Y)     1,5
    3A: INCW dp         2,6
    3B: ROL dp+X        2,5
    3C: ROL A           1,2
    3D: INC X           1,2
    3E: CMP X,dp        2,3
    3F: CALL labs       3,8

*/

/* 30 */

.balign 16
SPC_BMI:
    SPC_BFS SPC_FLAG_N
    jmp SPC_BACK

/* 31 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_3:
    TCALL 3
    jmp SPC_BACK

/* 32 */
/* SPC_CLR1 in SPCmain.S */

/* 33 */
/* SPC_BBC in SPCmain.S */

/* 34 */

.balign 16
SPC_AND_A_Odp_XO:
    SPC_AND_A Odp_XO
    jmp SPC_BACK

/* 35 */

.balign 16
SPC_AND_A_Oabs_XO:
    SPC_AND_A OABS_XO
    jmp SPC_BACK

/* 36 */

.balign 16
SPC_AND_A_Oabs_YO:
    SPC_AND_A OABS_YO
    jmp SPC_BACK

/* 37 */

.balign 16
SPC_AND_A_OOdpO_YO:
    SPC_AND_A OOdpO_YO
    jmp SPC_BACK

/* 38 */

.balign 16
SPC_AND_dp_IM:
    SPC_ADDR_dp_IM      // dl contains IM, %bx dp
    movb 1(%esi),%dl    // immediate byte in %dl
    GET_BYTE_SPC
    andb %dl,%al
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    SET_BYTE_SPC
    jmp SPC_BACK

/* 39 */

.balign 16
SPC_AND_OXO_OYO:
    SPC_ADDR_OXO_OYO
    movb %al,%dl
    GET_BYTE_SPC
    andb %dl,%al
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    SET_BYTE_SPC
    jmp SPC_BACK

/* 3A */

.balign 16
SPC_INCW_dp:
    SPC_ADDR_dp
    GET_WORD_SPC        // get DP word
    movl %eax,%edx
    incw %dx
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    decw %bx
    movl %edx,%eax
    SET_WORD_SPC
    jmp SPC_BACK

/* 3B */

.balign 16
SPC_ROL_Odp_XO:
    SPC_ROL Odp_XO
    jmp SPC_BACK

/* 3C */

.balign 16
SPC_ROL_A:
    movw %bx,_PC
    MAKE_CARRY
    movb _A,%al
    adcb %al,%al
    movb %al,_A
    STORE_FLAGS_SPC (SPC_FLAG_NZC)
    jmp SPC_BACK

/* 3D */

.balign 16
SPC_INC_X:
    movw %bx,_PC
    incb _X
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* 3E */

.balign 16
SPC_CMP_X_dp:
    SPC_CMP_X dp
    jmp SPC_BACK

/* 3F */

.balign 16
SPC_CALL:
    movb 1(%esi),%al
    addl $2,%ebx
    movb 2(%esi),%ah
    cmpl $0xFFC0,%eax
    movw %ax,_PC
    movl SPC_FFC0_Address,%eax
    jnb 0f
    movl $_SPCRAM,%eax
0:  movl %eax,SPC_Code_Base
    movl %ebx,%eax
    PUSH_W
    jmp SPC_BACK
