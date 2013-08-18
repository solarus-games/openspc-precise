/*

 SPC700 opcodes 0x70-0x7F:
    70: BVS rel         2,2/4
    71: TCALL 7         1,8
    72: CLR1 dp.3       2,4
    73: BBC dp.3,rel    3,5/7
    74: CMP A,dp+X      2,4
    75: CMP A,labs+X    3,5
    76: CMP A,labs+Y    3,5
    77: CMP A,(dp)+Y    2,6
    78: CMP dp,#imm     3,5
    79: CMP (X),(Y)     1,5
    7A: ADDW YA,dp      2,5
    7B: ROR dp+X        2,5
    7C: ROR A           1,2
    7D: MOV A,X         1,2
    7E: CMP Y,dp        2,3
    7F: RETI            1,6

*/

/* 70 */

.balign 16
SPC_BVS:
    SPC_BFS SPC_FLAG_V
    jmp SPC_BACK

/* 71 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_7:
    TCALL 7
    jmp SPC_BACK

/* 72 */
/* SPC_CLR1 in SPCmain.S */

/* 73 */
/* SPC_BBC in SPCmain.S */

/* 74 */

.balign 16
SPC_CMP_A_Odp_XO:
    SPC_CMP_A Odp_XO
    jmp SPC_BACK

/* 75 */

.balign 16
SPC_CMP_A_Oabs_XO:
    SPC_CMP_A OABS_XO
    jmp SPC_BACK

/* 76 */

.balign 16
SPC_CMP_A_Oabs_YO:
    SPC_CMP_A OABS_YO
    jmp SPC_BACK

/* 77 */

.balign 16
SPC_CMP_A_OOdpO_YO:
    SPC_CMP_A OOdpO_YO
    jmp SPC_BACK

/* 78 */

.balign 16
SPC_CMP_dp_IM:
    SPC_ADDR_dp_IM
    movb 1(%esi),%dl    // immediate byte in %dl
    GET_BYTE_SPC
    cmpb %dl,%al
    cmc
    STORE_FLAGS_SPC (SPC_FLAG_NZC)
    jmp SPC_BACK

/* 79 */

.balign 16
SPC_CMP_OXO_OYO:
    SPC_ADDR_OXO_OYO
    movb %al,%dl
    GET_BYTE_SPC
    cmpb %dl,%al
    cmc
    STORE_FLAGS_SPC (SPC_FLAG_NZC)
    jmp SPC_BACK

/* 7A */

.balign 16
SPC_ADDW_YA_dp:
    SPC_ADDR_dp
    CLR_FLAG_SPC(SPC_FLAG_V)    // Done cos STORE_FLAGS cant alter V!
    movl _YA,%edx
    GET_WORD_SPC        // get DP word
    addw %ax,%dx
    lahf
    jno 1f
    SET_FLAG_SPC(SPC_FLAG_V)
1:  STORE_FLAGS_SPC_FROM SPC_FLAG_NHZC,%ah
    movl %edx,_YA
    jmp SPC_BACK

/* 7B */

.balign 16
SPC_ROR_Odp_XO:
    SPC_ROR Odp_XO
    jmp SPC_BACK

/* 7C */

.balign 16
SPC_ROR_A:
    movw %bx,_PC
    shrb $1,_PSW_B      //MAKE_CARRY
    movb _A,%al
    rcrb $1,%al
    movb %al,_A
    adcb _PSW_B,_PSW_B  //STORE_FLAGS_SPC (SPC_FLAG_C)
    testb %al,%al
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* 7D */

.balign 16
SPC_MOV_A_X:
    movw %bx,_PC
    movb _X,%al
    testb %al,%al
    movb %al,_A
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* 7E */

.balign 16
SPC_CMP_Y_dp:
    SPC_CMP_Y dp
    jmp SPC_BACK

/* 7F */

/* RETI - not yet implemented */
