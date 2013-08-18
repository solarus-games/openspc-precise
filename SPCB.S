/*

 SPC700 opcodes 0xB0-0xBF:
    B0: BCS rel         2,2/4
    B1: TCALL 11        1,8
    B2: CLR1 dp.5       2,4
    B3: BBC dp.5,rel    3,5/7
    B4: SBC A,dp+X      2,4
    B5: SBC A,labs+X    3,5
    B6: SBC A,labs+Y    3,5
    B7: SBC A,(dp)+Y    2,6
    B8: SBC dp,#imm     3,5
    B9: SBC (X),(Y)     1,5
    BA: MOVW YA,dp      2,5
    BB: INC dp+X        2,5
    BC: INC A           1,2
    BD: MOV SP,X        1,2
    BE: DAS A           1,3
    BF: MOV A,(X)+      1,4

*/

/* B0 */

.balign 16
SPC_BCS:
    SPC_BFS SPC_FLAG_C
    jmp SPC_BACK

/* B1 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_11:
    TCALL 11
    jmp SPC_BACK

/* B2 */
/* SPC_CLR1 in SPCmain.S */

/* B3 */
/* SPC_BBC in SPCmain.S */

/* B4 */

.balign 16
SPC_SBC_A_Odp_XO:
    SPC_SBC_A Odp_XO
    jmp SPC_BACK

/* B5 */

.balign 16
SPC_SBC_A_Oabs_XO:
    SPC_SBC_A OABS_XO
    jmp SPC_BACK

/* B6 */

.balign 16
SPC_SBC_A_Oabs_YO:
    SPC_SBC_A OABS_YO
    jmp SPC_BACK

/* B7 */

.balign 16
SPC_SBC_A_OOdpO_YO:
    SPC_SBC_A OOdpO_YO
    jmp SPC_BACK

/* B8 */

.balign 16
SPC_SBC_dp_IM:
    SPC_SBC_mem dp_IM,1(%esi)
    jmp SPC_BACK

/* B9 */

.balign 16
SPC_SBC_OXO_OYO:
    SPC_SBC_mem OXO_OYO,%al
    jmp SPC_BACK

/* BA */

.balign 16
SPC_MOV_YA_dp:
    SPC_ADDR_dp
    xorl %eax,%eax
    GET_WORD_SPC
    testw %ax,%ax
    movl %eax,_YA
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* BB */

.balign 16
SPC_INC_Odp_XO:
    SPC_INC Odp_XO
    jmp SPC_BACK

/* BC */

.balign 16
SPC_INC_A:
    movw %bx,_PC
    incb _A
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* BD */

.balign 16
SPC_MOV_SP_X:
    movb _X,%al
    movw %bx,_PC
    movb %al,_SP
    jmp SPC_BACK

/* BE */

/* DAS - not yet implemented */

/* BF */

.balign 16
SPC_MOV_A_OXOInc:
    SPC_ADDR_OXOInc
    GET_BYTE_SPC
    testb %al,%al
    movb %al,_A
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK
