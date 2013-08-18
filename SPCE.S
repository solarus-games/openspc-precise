/*

 SPC700 opcodes 0xE0-0xEF:
    E0: CLRV            1,2
    E1: TCALL 14        1,8
    E2: SET1 dp.7       2,4
    E3: BBS dp.7,rel    3,5/7
    E4: MOV A,dp        2,3
    E5: MOV A,labs      3,4
    E6: MOV A,(X)       1,3
    E7: MOV A,(dp+X)    2,6
    E8: MOV A,#imm      2,2
    E9: MOV X,labs      3,4
    EA: NOT1 mem.bit    3,5
    EB: MOV Y,dp        2,3
    EC: MOV Y,labs      3,4
    ED: NOTC            1,3
    EE: POP Y           1,4
    EF: SLEEP           1,3

*/

/* E0 */

.balign 16
SPC_CLRV:
    movw %bx,_PC
    CLR_FLAG_SPC(SPC_FLAG_V+SPC_FLAG_H)
    jmp SPC_BACK

/* E1 */

/* TCALL: Call through table in pageable 64-bytes of RAM */
.balign 16
SPC_TCALL_14:
    TCALL 14
    jmp SPC_BACK

/* E2 */
/* SPC_SET1 in SPCmain.S */

/* E3 */
/* SPC_BBS in SPCmain.S */

/* E4 */

.balign 16
SPC_MOV_A_dp:
    SPC_MOV_A_ dp
    jmp SPC_BACK

/* E5 */

.balign 16
SPC_MOV_A_abs:
    SPC_MOV_A_ ABS
    jmp SPC_BACK

/* E6 */

.balign 16
SPC_MOV_A_OXO:
    SPC_MOV_A_ OXO
    jmp SPC_BACK

/* E7 */

.balign 16
SPC_MOV_A_OOdp_XOO:
    SPC_MOV_A_ OOdp_XOO
    jmp SPC_BACK

/* E8 */

.balign 16
SPC_MOV_A_IM:
    movb 1(%esi),%al
    incl %ebx
    testb %al,%al
    movb %al,_A
    movw %bx,_PC
    STORE_FLAGS_SPC (SPC_FLAG_NZ)
    jmp SPC_BACK

/* E9 */

.balign 16
SPC_MOV_X_abs:
    SPC_MOV_X_ ABS
    jmp SPC_BACK

/* EA */

.balign 16
SPC_NOT1:       // !mem.bit
    SPC_ADDR_membit     // %bx contains mem and %dx contains bit number
    GET_BYTE_SPC    // Get byte at location
    btcl %edx,%eax  // complement the bit
    SET_BYTE_SPC    // set byte
    jmp SPC_BACK

/* EB */

.balign 16
SPC_MOV_Y_dp:
    SPC_MOV_Y_ dp
    jmp SPC_BACK

/* EC */

.balign 16
SPC_MOV_Y_abs:
    SPC_MOV_Y_ ABS
    jmp SPC_BACK

/* ED */

.balign 16
SPC_NOTC:
    movw %bx,_PC
    CPL_FLAG_SPC(SPC_FLAG_C)
    jmp SPC_BACK

/* EE */

.balign 16
SPC_POP_Y:
    movw %bx,_PC
    POP_B
    movb %al,_Y
    jmp SPC_BACK

/* EF */

.balign 16
SPC_SLEEP:
    movw %bx,_PC
    decw _PC
    jmp SPC_BACK            // What else can sleep do?
