/*

 SPC700 opcodes 0xA0-0xAF:
    A0: EI              1,3
    A1: TCALL 10        1,8
    A2: SET1 dp.5       2,4
    A3: BBS dp.5,rel    3,5/7
    A4: SBC A,dp        2,3
    A5: SBC A,labs      3,4
    A6: SBC A,(X)       1,3
    A7: SBC A,(dp+X)    2,6
    A8: SBC A,#imm      2,2
    A9: SBC dp(d),dp(s) 3,6
    AA: MOV1 C,mem.bit  3,4
    AB: INC dp          2,4
    AC: INC labs        3,5
    AD: CMP Y,#imm      2,2
    AE: POP A           1,4
    AF: MOV (X)+,A      1,4

*/

/* A0 */

.balign 16
SPC_EI:
    movw %bx,_PC
    SET_FLAG_SPC(SPC_FLAG_I)
    jmp SPC_BACK

/* A1 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_10:
    TCALL 10
    jmp SPC_BACK

/* A2 */
/* SPC_SET1 in SPCmain.S */

/* A3 */
/* SPC_BBS in SPCmain.S */

/* A4 */

.balign 16
SPC_SBC_A_dp:
    SPC_SBC_A dp
    jmp SPC_BACK

/* A5 */

.balign 16
SPC_SBC_A_abs:
    SPC_SBC_A ABS
    jmp SPC_BACK

/* A6 */

.balign 16
SPC_SBC_A_OXO:
    SPC_SBC_A OXO
    jmp SPC_BACK

/* A7 */

.balign 16
SPC_SBC_A_OOdp_XOO:
    SPC_SBC_A OOdp_XOO
    jmp SPC_BACK

/* A8 */

.balign 16
SPC_SBC_A_IM:
    movb 1(%esi),%al
    incl %ebx
    CLR_FLAG_SPC(SPC_FLAG_V)    // Done cos STORE_FLAGS cant alter V!
    movw %bx,_PC
    MAKE_NOT_CARRY
    sbbb %al,_A
    cmc
    lahf
    jno 1f
    SET_FLAG_SPC(SPC_FLAG_V)
1:  STORE_FLAGS_SPC_FROM SPC_FLAG_NHZC,%ah
    jmp SPC_BACK

/* A9 */

.balign 16
SPC_SBC_dp_dp:
    SPC_SBC_mem dp_dp,%al
    jmp SPC_BACK

/* AA */

.balign 16
SPC_MOV1_C_:        // Carry flag = mem.bit
    SPC_ADDR_membit     // %bx contains mem and %dx contains bit number
    GET_BYTE_SPC        // Get byte at location
    btl %edx,%eax
    jnc 0f
    SET_FLAG_SPC (SPC_FLAG_C)
    jmp SPC_BACK
.balign 16
0:	CLR_FLAG_SPC (SPC_FLAG_C)
    jmp SPC_BACK

/* AB */

.balign 16
SPC_INC_dp:
    SPC_INC dp
    jmp SPC_BACK

/* AC */

.balign 16
SPC_INC_abs:
    SPC_INC ABS
    jmp SPC_BACK

/* AD */

.balign 16
SPC_CMP_Y_IM:
    movb 1(%esi),%al
    incl %ebx
    cmpb %al,_Y
    cmc
    movw %bx,_PC
    STORE_FLAGS_SPC (SPC_FLAG_NZC)
    jmp SPC_BACK

/* AE */

.balign 16
SPC_POP_A:
    movw %bx,_PC
    POP_B
    movb %al,_A
    jmp SPC_BACK

/* AF */

.balign 16
SPC_MOV_OXOInc_A:
    SPC_ADDR_OXOInc
    movb _A,%al
    SET_BYTE_SPC
    jmp SPC_BACK
